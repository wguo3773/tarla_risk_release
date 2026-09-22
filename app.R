library(shiny)
library(glmnet)

source("predict.R")
bundle <- readRDS("models/locked_models.rds")

percent <- function(x) sprintf("%.1f%%", 100 * x)

coefficient_table <- function(spec) {
  x <- spec$coefficients
  x <- x[order(abs(x$coefficient), decreasing = TRUE), ]
  names(x) <- c("Original model term", "Coefficient")
  x
}

ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { background: #f6f7f7; color: #20272b; font-family: Arial, sans-serif; }
    .container-fluid { max-width: 1120px; }
    h1 { font-size: 27px; font-weight: 700; margin-top: 28px; }
    h2 { font-size: 20px; font-weight: 700; margin-top: 4px; }
    .sub { color: #536169; margin-bottom: 20px; }
    .form-section { font-size: 13px; font-weight: 700; color: #536169;
      text-transform: uppercase; margin: 16px 0 9px; }
    .result { background: white; border: 1px solid #dce1e3; border-radius: 6px;
      padding: 17px; min-height: 170px; margin-bottom: 14px; }
    .result-label { font-weight: 700; font-size: 16px; }
    .result-value { font-size: 35px; font-weight: 700; margin: 8px 0 3px; }
    .result-note, .footnote { color: #536169; font-size: 13px; line-height: 1.5; }
    .caution { border-left: 3px solid #af6c0b; background: #fff8eb;
      padding: 10px 12px; margin: 12px 0 20px; font-size: 13px; }
    table { font-size: 13px; }
  "))),
  h1("Tarlatamab toxicity risk calculator"),
  div(class = "sub", "Research-use estimates for grade 2 or higher CRS and any-grade ICANS"),
  tabsetPanel(
    id = "outcome_tab",
    tabPanel("CRS", value = "crs", br(),
      fluidRow(
        column(5,
          div(class = "form-section", "CRS inputs"),
          numericInput("crs_age", "Age at cycle 1, day 1 (years)", value = NA_real_, min = 0, step = 1),
          selectInput("crs_sex", "Sex", choices = c("Select" = "", "Female", "Male")),
          numericInput("crs_ldh", "LDH at cycle 1, day 1 (U/L)", value = NA_real_, min = 0, step = 1),
          selectInput("crs_liver", "Liver lesion count", choices = c("Select" = "", "0", "1-5", "6+")),
          selectInput("crs_other", "Other-site lesion count", choices = c("Select" = "", "0", "1-5", "6+"))
        ),
        column(7,
          div(class = "caution", "Exploratory estimate from a small development cohort. Do not use this output alone to make treatment or monitoring decisions."),
          div(class = "result",
            div(class = "result-label", "Grade 2 or higher CRS"),
            div(class = "result-value", textOutput("crs_probability", inline = TRUE)),
            div(class = "result-note", textOutput("crs_threshold", inline = TRUE))
          ),
          uiOutput("crs_warning"),
          div(class = "footnote", "Exploratory cutoff: 25.2%. Out-of-fold sensitivity 81.8% and specificity 78.1% (11 events among 43 patients). The cutoff and performance have not been externally validated.")
        )
      )
    ),
    tabPanel("ICANS", value = "icans", br(),
      fluidRow(
        column(5,
          div(class = "form-section", "ICANS inputs"),
          numericInput("icans_age", "Age at cycle 1, day 1 (years)", value = NA_real_, min = 0, step = 1),
          numericInput("icans_ecog", "ECOG performance status", value = NA_real_, min = 0, max = 4, step = 1),
          numericInput("icans_ldh", "LDH at cycle 1, day 1 (U/L)", value = NA_real_, min = 0, step = 1),
          selectInput("icans_met3", "Metastatic sites", choices = c(
            "Select" = "", "Fewer than 3" = "<3 mets", "3 or more" = "≥3 mets"))
        ),
        column(7,
          div(class = "caution", "Exploratory estimate from a small development cohort. Do not use this output alone to make treatment or monitoring decisions."),
          div(class = "result",
            div(class = "result-label", "Any-grade ICANS"),
            div(class = "result-value", textOutput("icans_probability", inline = TRUE)),
            div(class = "result-note", textOutput("icans_threshold", inline = TRUE))
          ),
          uiOutput("icans_warning"),
          div(class = "footnote", "Exploratory cutoff: 31.5%. Out-of-fold sensitivity 66.7% and specificity 78.1% (12 events among 44 patients). The cutoff and performance have not been externally validated.")
        )
      )
    ),
    tabPanel("Model details", value = "details", br(),
      p("These are the original fitted coefficients used by the calculator. Numeric and indicator columns were centered and scaled during model fitting; the coefficient table must not be applied directly to unprocessed inputs."),
      h2("Grade 2 or higher CRS"),
      tableOutput("crs_coefs"),
      h2("Any-grade ICANS"),
      tableOutput("icans_coefs"),
      div(class = "footnote", "Coefficients of zero are retained to show the complete fitted model. The calculator uses the saved preprocessing and full-precision coefficients.")
    )
  )
)

check_values <- function(values, spec, active_numeric) {
  if (any(vapply(active_numeric, function(nm) values[[nm]] < 0, logical(1))) ||
      ("ECOG_numeric" %in% active_numeric &&
       (values$ECOG_numeric > 4 || values$ECOG_numeric != floor(values$ECOG_numeric)))) {
    return(list(error = "Check the numeric inputs."))
  }
  outside <- active_numeric[vapply(active_numeric, function(nm) {
    range <- spec$numeric_ranges[[nm]]
    values[[nm]] < range[1] || values[[nm]] > range[2]
  }, logical(1))]
  list(probability = predict_risk(values, spec), outside = outside)
}

inputs_missing <- function(values) {
  any(vapply(values, function(x) length(x) != 1 || is.na(x) || identical(x, ""), logical(1)))
}

server <- function(input, output, session) {
  crs_prediction <- reactive({
    values <- list(
      Age.at.C1D1 = input$crs_age, Sex = input$crs_sex,
      C1D1.LDH_clean = input$crs_ldh,
      Lesion.Cat = input$crs_liver, Other.Lesion.Cat = input$crs_other
    )
    if (inputs_missing(values)) return(list(error = "Enter all CRS inputs to see the estimate."))
    values <- c(values, list(
      ECOG_numeric = 0,
      Sum.of.Top.5.Liver.Lesions..mm. = 0,
      Sum.of.Top.5.Other.Lesions..mm. = 0,
      Sum.of.Top.5.Brain.Lesions..mm. = 0,
      Brain.Lesion.Num.Cat = "0", extracranial_rad = "0"
    ))
    check_values(values, bundle$crs, c("Age.at.C1D1", "C1D1.LDH_clean"))
  })

  icans_prediction <- reactive({
    values <- list(
      Age.at.C1D1 = input$icans_age, ECOG_numeric = input$icans_ecog,
      C1D1.LDH_clean = input$icans_ldh, met3 = input$icans_met3
    )
    if (inputs_missing(values)) return(list(error = "Enter all ICANS inputs to see the estimate."))
    values <- c(values, list(
      Sex = "Female", Sum.of.Top.5.Brain.Lesions..mm. = 0,
      Sum.of.Top.5.Other.Lesions..mm. = 0
    ))
    check_values(values, bundle$icans,
                 c("Age.at.C1D1", "ECOG_numeric", "C1D1.LDH_clean"))
  })

  output$crs_probability <- renderText({
    result <- crs_prediction()
    if (!is.null(result$error)) return("Not calculated")
    percent(result$probability)
  })
  output$icans_probability <- renderText({
    result <- icans_prediction()
    if (!is.null(result$error)) return("Not calculated")
    percent(result$probability)
  })
  output$crs_threshold <- renderText({
    result <- crs_prediction()
    if (!is.null(result$error)) return(result$error)
    if (result$probability >= bundle$crs$threshold) "At or above exploratory cutoff" else "Below exploratory cutoff"
  })
  output$icans_threshold <- renderText({
    result <- icans_prediction()
    if (!is.null(result$error)) return(result$error)
    if (result$probability >= bundle$icans$threshold) "At or above exploratory cutoff" else "Below exploratory cutoff"
  })
  output$crs_warning <- renderUI({
    result <- crs_prediction()
    if (!is.null(result$error) || !length(result$outside)) return(NULL)
    div(class = "caution", paste("Outside the development cohort range:",
                                 paste(result$outside, collapse = ", ")))
  })
  output$icans_warning <- renderUI({
    result <- icans_prediction()
    if (!is.null(result$error) || !length(result$outside)) return(NULL)
    div(class = "caution", paste("Outside the development cohort range:",
                                 paste(result$outside, collapse = ", ")))
  })
  output$crs_coefs <- renderTable(coefficient_table(bundle$crs), digits = 6,
                                  striped = TRUE, bordered = TRUE)
  output$icans_coefs <- renderTable(coefficient_table(bundle$icans), digits = 6,
                                    striped = TRUE, bordered = TRUE)
}

shinyApp(ui, server)
