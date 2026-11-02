# Tarlatamab CRS and ICANS Risk Calculator

**Authors:** Wanru Guo\*, Graeme Fenton\*, Curtis Tatsuoka, and Samuel Rosner

\*Wanru Guo and Graeme Fenton contributed equally and are co-first authors of the associated manuscript.

[Open the Shiny calculator](https://wguo3.shinyapps.io/tarla_risk_calculator/) | [medRxiv manuscript](https://doi.org/10.64898/2026.10.02.26364624) | [Zenodo software archive](https://doi.org/10.5281/zenodo.22890432)

A calculator for estimating grade 2 or higher cytokine release syndrome (CRS) and any-grade immune effector cell-associated neurotoxicity syndrome (ICANS) after tarlatamab. Separate forms allow each outcome to be calculated using its required clinical inputs. The application returns fitted model probabilities using the original preprocessing and coefficients.

## Use the calculator

1. Select CRS or ICANS.
2. Enter the clinical inputs for that outcome. The ICANS form requires age, ECOG performance status, LDH, and metastatic-site category.
3. Calculate the estimated probability. The model details view provides the fitted coefficients and thresholds.

The models were developed in a small cohort and require independent external validation. Estimates are exploratory and should not be used alone to make treatment or monitoring decisions.

## Associated manuscript

Fenton G\*, Guo W\*, et al. **Predictive markers of response and toxicity to tarlatamab in patients with extensive stage small cell lung cancer: a multi-institutional real-world analysis.** medRxiv; 2026. [Read the manuscript](https://doi.org/10.64898/2026.10.02.26364624).

\*Equal contribution; co-first authors. This manuscript is a preprint and has not been peer reviewed.

## Run locally

From the repository folder in R:

```r
install.packages(c("shiny", "glmnet", "caret"))
shiny::runApp()
```

The repository contains application code, fitted model parameters, and supplied manuscript figures. It contains no patient-level data.

## Citation

Guo W, Fenton G, Tatsuoka C, Rosner S. *Tarlatamab CRS and ICANS Risk Calculator*. Version 1.0.0. Zenodo; 2026. https://doi.org/10.5281/zenodo.22890432.

The Zenodo v1.0.0 archive preserves the application and fitted models.
