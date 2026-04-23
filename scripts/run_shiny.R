script_args <- commandArgs(trailingOnly = FALSE)
args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1) as.integer(args[[1]]) else 3838

resolve_frontend_dir <- function() {
  script_arg <- grep("^--file=", script_args, value = TRUE)
  candidates <- c(
    normalizePath(file.path(getwd(), "frontend"), winslash = "/", mustWork = FALSE),
    if (length(script_arg) > 0) {
      normalizePath(
        file.path(dirname(sub("^--file=", "", script_arg[[1]])), "..", "frontend"),
        winslash = "/",
        mustWork = FALSE
      )
    }
  )
  candidates <- unique(candidates[nzchar(candidates)])

  for (candidate in candidates) {
    if (dir.exists(candidate) && file.exists(file.path(candidate, "app.R"))) {
      return(candidate)
    }
  }

  stop("frontend/app.R not found. Run from the repo root or invoke this script via Rscript.")
}

setwd(resolve_frontend_dir())

options(shiny.port = port)
options(shiny.host = "127.0.0.1")

message(sprintf("Starting Shiny app on http://127.0.0.1:%d", port))

shiny::runApp(host = "127.0.0.1", port = port, launch.browser = FALSE)
