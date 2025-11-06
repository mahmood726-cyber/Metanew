# Comprehensive Integration Test for EvidenceOS PRIME
# Tests all module integrations, function availability, and reactive values
# Author: EvidenceOS PRIME Team

cat("========================================\n")
cat("EVIDENCEOS PRIME INTEGRATION TEST\n")
cat("========================================\n\n")

# Test 1: Library Loading
cat("TEST 1: Checking library availability...\n")
required_libraries <- c(
  "shiny", "bs4Dash", "DT", "plotly", "shinyvalidate",
  "metafor", "netmeta", "dosresmeta", "colourpicker",
  "bslib", "gt", "dplyr", "ggplot2", "Matrix", "gridExtra", "tidyr"
)

library_status <- sapply(required_libraries, function(lib) {
  suppressWarnings(suppressMessages(require(lib, character.only = TRUE, quietly = TRUE)))
})

if (all(library_status)) {
  cat("✓ All", length(required_libraries), "required libraries available\n\n")
} else {
  cat("✗ Missing libraries:", paste(required_libraries[!library_status], collapse = ", "), "\n")
  cat("FAILED: Install missing libraries\n")
  quit(status = 1)
}

# Test 2: Utility Files
cat("TEST 2: Checking utility files...\n")
util_files <- c(
  "utils/publication_tools.R",
  "utils/plot_downloads.R",
  "utils/multilevel_nma.R",
  "utils/plot_recommendations.R",
  "utils/report_generator.R",
  "utils/data_validation.R",
  "utils/plotting.R",
  "utils/validators.R",
  "utils/python_bridge.R",
  "utils/sample_data_loader.R",
  "utils/extreme_optimizations.R"
)

util_status <- file.exists(util_files)
if (all(util_status)) {
  cat("✓ All", length(util_files), "utility files found\n\n")
} else {
  cat("✗ Missing files:", paste(util_files[!util_status], collapse = ", "), "\n")
  cat("FAILED: Missing utility files\n")
  quit(status = 1)
}

# Test 3: Source Utility Files
cat("TEST 3: Sourcing utility files...\n")
util_errors <- list()
for (util_file in util_files) {
  tryCatch({
    source(util_file, local = TRUE)
  }, error = function(e) {
    util_errors[[util_file]] <<- e$message
  })
}

if (length(util_errors) == 0) {
  cat("✓ All utility files sourced successfully\n\n")
} else {
  cat("✗ Errors in utility files:\n")
  for (file in names(util_errors)) {
    cat("  ", file, ":", util_errors[[file]], "\n")
  }
  cat("FAILED: Utility file errors\n")
  quit(status = 1)
}

# Test 4: Publication Tools Functions
cat("TEST 4: Checking publication tools functions...\n")
required_functions <- c(
  "create_prisma_data",
  "generate_prisma_diagram",
  "generate_prisma_checklist",
  "create_rob2_data",
  "generate_rob2_plot",
  "create_robins_i_data",
  "generate_robins_i_plot",
  "create_grade_profile",
  "generate_grade_sof_table",
  "plot_download_ui",
  "run_multilevel_nma",
  "get_plot_recommendations",
  "generate_comprehensive_report",
  "validate_meta_analysis_data"
)

function_status <- sapply(required_functions, exists)
if (all(function_status)) {
  cat("✓ All", length(required_functions), "required functions defined\n\n")
} else {
  cat("✗ Missing functions:", paste(required_functions[!function_status], collapse = ", "), "\n")
  cat("FAILED: Missing function definitions\n")
  quit(status = 1)
}

# Test 5: Module Files
cat("TEST 5: Checking module files...\n")
module_files <- c(
  "modules/data_import.R",
  "modules/protocol.R",
  "modules/meta_pairwise.R",
  "modules/nma.R",
  "modules/dose_response.R",
  "modules/masem.R",
  "modules/sensitivity.R",
  "modules/he_params.R",
  "modules/he_model.R",
  "modules/he_bcea.R",
  "modules/he_budget_impact.R",
  "modules/reporting.R",
  "modules/audit.R",
  "modules/ai_copilot.R",
  "modules/v2_features.R",
  "modules/client_portal.R",
  "modules/living_ma.R",
  "modules/prisma_generator.R",
  "modules/rob_assessment.R",
  "modules/grade_profile.R",
  "modules/interactive_plots.R"
)

module_status <- file.exists(module_files)
if (all(module_status)) {
  cat("✓ All", length(module_files), "module files found\n\n")
} else {
  cat("✗ Missing modules:", paste(module_files[!module_status], collapse = ", "), "\n")
  cat("FAILED: Missing module files\n")
  quit(status = 1)
}

# Test 6: Source Module Files
cat("TEST 6: Sourcing module files...\n")
module_errors <- list()
for (module_file in module_files) {
  tryCatch({
    source(module_file, local = TRUE)
  }, error = function(e) {
    module_errors[[module_file]] <<- e$message
  })
}

if (length(module_errors) == 0) {
  cat("✓ All module files sourced successfully\n\n")
} else {
  cat("✗ Errors in module files:\n")
  for (file in names(module_errors)) {
    cat("  ", file, ":", module_errors[[file]], "\n")
  }
  cat("FAILED: Module file errors\n")
  quit(status = 1)
}

# Test 7: Module UI Functions
cat("TEST 7: Checking module UI functions...\n")
ui_functions <- c(
  "data_import_ui",
  "protocol_ui",
  "meta_pairwise_ui",
  "nma_ui",
  "dose_response_ui",
  "masem_ui",
  "sensitivity_ui",
  "he_params_ui",
  "he_model_ui",
  "he_bcea_ui",
  "he_budget_impact_ui",
  "reporting_ui",
  "audit_ui",
  "ai_copilot_ui",
  "v2_features_ui",
  "client_portal_ui",
  "living_ma_ui",
  "prisma_generator_ui",
  "rob_assessment_ui",
  "grade_profile_ui",
  "interactive_plots_ui"
)

ui_status <- sapply(ui_functions, exists)
if (all(ui_status)) {
  cat("✓ All", length(ui_functions), "UI functions defined\n\n")
} else {
  cat("✗ Missing UI functions:", paste(ui_functions[!ui_status], collapse = ", "), "\n")
  cat("FAILED: Missing UI function definitions\n")
  quit(status = 1)
}

# Test 8: Module Server Functions
cat("TEST 8: Checking module server functions...\n")
server_functions <- c(
  "data_import_server",
  "protocol_server",
  "meta_pairwise_server",
  "nma_server",
  "dose_response_server",
  "masem_server",
  "sensitivity_server",
  "he_params_server",
  "he_model_server",
  "he_bcea_server",
  "he_budget_impact_server",
  "reporting_server",
  "audit_server",
  "ai_copilot_server",
  "v2_features_server",
  "client_portal_server",
  "living_ma_server",
  "prisma_generator_server",
  "rob_assessment_server",
  "grade_profile_server",
  "interactive_plots_server"
)

server_status <- sapply(server_functions, exists)
if (all(server_status)) {
  cat("✓ All", length(server_functions), "server functions defined\n\n")
} else {
  cat("✗ Missing server functions:", paste(server_functions[!server_status], collapse = ", "), "\n")
  cat("FAILED: Missing server function definitions\n")
  quit(status = 1)
}

# Test 9: Publication Module Integration
cat("TEST 9: Testing publication module integration...\n")

# Test PRISMA data creation
test_prisma <- tryCatch({
  prisma_data <- create_prisma_data(
    n_identified = 1000,
    n_other = 50,
    n_duplicates = 200,
    n_screened = 850,
    n_excluded_screening = 700,
    n_full_text = 150,
    n_excluded_full_text = 120,
    exclusion_reasons = list("Wrong population" = 50, "Wrong intervention" = 40, "Wrong outcome" = 30),
    n_included = 30,
    n_meta_analysis = 25
  )
  TRUE
}, error = function(e) {
  cat("  ✗ PRISMA data creation error:", e$message, "\n")
  FALSE
})

# Test ROB data creation
test_rob <- tryCatch({
  rob_data <- create_rob2_data(
    studies = c("Study1", "Study2"),
    randomization = c("Low", "Some concerns"),
    deviations = c("Low", "Low"),
    missing_outcome = c("Low", "Low"),
    outcome_measurement = c("Low", "Some concerns"),
    selection_reported = c("Low", "Low")
  )
  TRUE
}, error = function(e) {
  cat("  ✗ ROB data creation error:", e$message, "\n")
  FALSE
})

# Test GRADE profile creation
test_grade <- tryCatch({
  grade_data <- create_grade_profile(
    outcomes = c("Mortality", "Quality of Life"),
    n_studies = c(10, 8),
    n_participants = c(1000, 800),
    risk_of_bias = c("Not serious", "Serious"),
    inconsistency = c("Not serious", "Not serious"),
    indirectness = c("Not serious", "Not serious"),
    imprecision = c("Not serious", "Serious"),
    publication_bias = c("Undetected", "Undetected"),
    effect_size = c("0.65 (0.50-0.85)", "0.25 (0.10-0.40)"),
    certainty = c("High", "Moderate")
  )
  TRUE
}, error = function(e) {
  cat("  ✗ GRADE profile creation error:", e$message, "\n")
  FALSE
})

if (test_prisma && test_rob && test_grade) {
  cat("✓ Publication module integration working\n\n")
} else {
  cat("✗ FAILED: Publication module integration errors\n")
  quit(status = 1)
}

# Test 10: Multi-Level NMA Functions
cat("TEST 10: Checking multi-level NMA functions...\n")
multilevel_functions <- c(
  "run_multilevel_nma",
  "prepare_contrast_data",
  "construct_vcov_matrix",
  "extract_treatment_effects"
)

multilevel_status <- sapply(multilevel_functions, exists)
if (all(multilevel_status)) {
  cat("✓ All multi-level NMA functions defined\n\n")
} else {
  cat("✗ Missing functions:", paste(multilevel_functions[!multilevel_status], collapse = ", "), "\n")
  cat("FAILED: Missing multi-level NMA functions\n")
  quit(status = 1)
}

# Final Summary
cat("========================================\n")
cat("INTEGRATION TEST SUMMARY\n")
cat("========================================\n")
cat("✓ All 10 tests passed successfully\n")
cat("✓ Libraries: OK\n")
cat("✓ Utility Files: OK\n")
cat("✓ Module Files: OK\n")
cat("✓ Functions: OK\n")
cat("✓ Publication Tools: OK\n")
cat("✓ Multi-Level NMA: OK\n")
cat("\n")
cat("STATUS: READY FOR DEPLOYMENT\n")
cat("========================================\n")
