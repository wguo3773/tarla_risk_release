library(caret)
library(glmnet)

build_model_row <- function(values, spec) {
  dat <- as.data.frame(values[spec$predictors], stringsAsFactors = FALSE)
  for (nm in spec$numeric) dat[[nm]] <- as.numeric(dat[[nm]])
  for (nm in spec$categorical) {
    dat[[nm]] <- factor(dat[[nm]], levels = spec$levels[[nm]])
    if (is.na(dat[[nm]][1])) stop("Invalid value for ", nm)
  }
  if (anyNA(dat)) stop("All model inputs are required")
  form <- as.formula(paste("~", paste(spec$predictors, collapse = " + "), "- 1"))
  x <- as.data.frame(model.matrix(form, dat))
  names(x) <- make.names(names(x), unique = TRUE)
  for (nm in setdiff(spec$columns, names(x))) x[[nm]] <- 0
  x[, spec$columns, drop = FALSE]
}

predict_risk <- function(values, spec) {
  x <- build_model_row(values, spec)
  transformed <- predict(spec$preprocessing, newdata = x)
  as.numeric(predict(spec$model, newx = as.matrix(transformed),
                     s = spec$lambda, type = "response"))
}
