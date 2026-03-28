args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("package name required")
pkg <- args[[1]]
repos <- if (length(args) >= 2) args[[2]] else "https://cran.rstudio.com"
if (!(pkg %in% rownames(installed.packages()))) {
  install.packages(pkg, repos = repos, dependencies = TRUE)
} else {
  message("Package already installed: ", pkg)
}

