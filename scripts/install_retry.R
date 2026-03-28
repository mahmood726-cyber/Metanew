mirrors <- c("https://cran.rstudio.com", "https://cloud.r-project.org/")
pkgs <- c("DT", "plotly")

success <- FALSE
for (cr in mirrors) {
  message("Trying mirror: ", cr)
  options(repos = cr)
  need <- setdiff(pkgs, rownames(installed.packages()))
  if (length(need) == 0) { success <- TRUE; break }
  try({
    install.packages(need, dependencies = TRUE)
  }, silent = TRUE)
  need <- setdiff(pkgs, rownames(installed.packages()))
  if (length(need) == 0) { success <- TRUE; break }
}

if (!success) {
  stop("Failed to install required packages: ", paste(setdiff(pkgs, rownames(installed.packages())), collapse = ", "))
} else {
  message("Packages installed: ", paste(pkgs, collapse = ", "))
}

