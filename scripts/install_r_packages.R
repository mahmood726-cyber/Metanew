packages <- c(
  "shiny", "bslib", "DT", "plotly", "shinyvalidate",
  "metafor", "netmeta", "dosresmeta",
  "rmarkdown", "officer", "readxl", "httr", "jsonlite"
)

cran <- "https://cloud.r-project.org/"

needed <- setdiff(packages, rownames(installed.packages()))
if (length(needed) > 0) {
  message("Installing R packages: ", paste(needed, collapse=", "))
  install.packages(needed, repos = cran, dependencies = TRUE)
} else {
  message("All required R packages already installed")
}

message("R package installation complete")

