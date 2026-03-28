cran <- "https://cloud.r-project.org/"
pkgs <- c("DT", "plotly")
need <- setdiff(pkgs, rownames(installed.packages()))
if (length(need) > 0) {
  install.packages(need, repos = cran, dependencies = TRUE)
} else {
  message("DT/plotly already installed")
}

