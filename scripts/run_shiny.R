args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1) as.integer(args[[1]]) else 3838

setwd("C:/Users/user/Metanew/frontend")

options(shiny.port = port)
options(shiny.host = "0.0.0.0")

message(sprintf("Starting Shiny app on http://localhost:%d", port))

shiny::runApp(host = "0.0.0.0", port = port, launch.browser = FALSE)

