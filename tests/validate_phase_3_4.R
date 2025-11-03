#!/usr/bin/env Rscript
# Syntax Validation Script for Phase 3-4 Modules
# Validates that all new modules load without syntax errors

cat("╔═══════════════════════════════════════════════════════════╗\n")
cat("║   PHASE 3-4 MODULE SYNTAX VALIDATION                       ║\n")
cat("╚═══════════════════════════════════════════════════════════╝\n\n")

# Set working directory
setwd("/home/user/Metanew/frontend")

# Modules to test
modules <- list(
  Phase3 = c(
    "modules/publication_bias_advanced.R",
    "modules/report_templates.R",
    "modules/study_annotations.R"
  ),
  Phase4 = c(
    "modules/grade_assessment.R",
    "modules/nma_bayesian.R",
    "modules/ipd_meta_analysis.R",
    "modules/partition_survival.R"
  )
)

# Results tracking
results <- data.frame(
  Module = character(),
  Phase = character(),
  Status = character(),
  Message = character(),
  stringsAsFactors = FALSE
)

total_errors <- 0
total_warnings <- 0

# Test each module
for (phase in names(modules)) {
  cat("\n", phase, "\n")
  cat(strrep("─", 60), "\n")

  for (module in modules[[phase]]) {
    cat("Testing:", basename(module), "... ")

    result <- tryCatch({
      # Suppress warnings during source
      suppressWarnings(source(module, local = TRUE))

      cat("✓ OK\n")
      results <- rbind(results, data.frame(
        Module = basename(module),
        Phase = phase,
        Status = "PASS",
        Message = "Loaded successfully"
      ))
    }, error = function(e) {
      cat("✗ ERROR\n")
      cat("   ", e$message, "\n")
      total_errors <<- total_errors + 1

      results <<- rbind(results, data.frame(
        Module = basename(module),
        Phase = phase,
        Status = "FAIL",
        Message = substring(e$message, 1, 100)
      ))
    }, warning = function(w) {
      cat("⚠ WARNING\n")
      cat("   ", w$message, "\n")
      total_warnings <<- total_warnings + 1

      results <<- rbind(results, data.frame(
        Module = basename(module),
        Phase = phase,
        Status = "WARN",
        Message = substring(w$message, 1, 100)
      ))
    })
  }
}

# Summary
cat("\n")
cat("╔═══════════════════════════════════════════════════════════╗\n")
cat("║   VALIDATION SUMMARY                                       ║\n")
cat("╚═══════════════════════════════════════════════════════════╝\n\n")

cat("Total Modules Tested:", nrow(results), "\n")
cat("Passed:              ", sum(results$Status == "PASS"), "\n")
cat("Failed:              ", sum(results$Status == "FAIL"), "\n")
cat("Warnings:            ", sum(results$Status == "WARN"), "\n")

# Detailed results
if (sum(results$Status != "PASS") > 0) {
  cat("\nISSUES FOUND:\n")
  cat(strrep("─", 60), "\n")

  failed <- results[results$Status != "PASS", ]
  for (i in 1:nrow(failed)) {
    cat(sprintf("[%s] %s (%s)\n", failed$Status[i], failed$Module[i], failed$Phase[i]))
    cat("    ", failed$Message[i], "\n\n")
  }
}

# Exit status
if (total_errors == 0) {
  cat("\n✓ ALL MODULES PASSED SYNTAX VALIDATION\n\n")
  quit(status = 0)
} else {
  cat("\n✗ VALIDATION FAILED -", total_errors, "error(s) found\n\n")
  quit(status = 1)
}
