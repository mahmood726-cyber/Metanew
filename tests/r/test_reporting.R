# Comprehensive Tests for Reporting Module
# Tests for frontend/modules/reporting.R

library(testthat)
library(dplyr)

# Source the module
source("../../frontend/modules/reporting.R")

# ============================
# REPORT GENERATION TESTS
# ============================

test_that("generate_full_report creates complete report", {
  # Mock analysis results
  results <- list(
    meta_analysis = list(
      pooled_effect = 0.52,
      ci_lower = 0.35,
      ci_upper = 0.69,
      i_squared = 45.2,
      tau_squared = 0.08,
      p_value = 0.001,
      n_studies = 12
    ),
    data = data.frame(
      study_id = paste0("Study_", 1:12),
      yi = rnorm(12, 0.5, 0.2),
      sei = runif(12, 0.08, 0.15)
    )
  )

  report <- generate_full_report(results, format = "html")

  expect_true(!is.null(report))
  expect_true(is.character(report) || is.list(report))
})

test_that("generate_full_report supports multiple formats", {
  results <- list(
    meta_analysis = list(pooled_effect = 0.52, n_studies = 10)
  )

  # HTML format
  report_html <- generate_full_report(results, format = "html")
  expect_true(!is.null(report_html))

  # PDF format
  report_pdf <- generate_full_report(results, format = "pdf")
  expect_true(!is.null(report_pdf))

  # Word format
  report_docx <- generate_full_report(results, format = "docx")
  expect_true(!is.null(report_docx))
})


# ============================
# SUMMARY STATISTICS TESTS
# ============================

test_that("create_summary_statistics_table formats correctly", {
  results <- list(
    n_studies = 15,
    n_participants = 3450,
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 45.2,
    tau_squared = 0.08,
    p_value = 0.001
  )

  summary_table <- create_summary_statistics_table(results)

  expect_true(!is.null(summary_table))
  expect_true(is.data.frame(summary_table) || is.matrix(summary_table))
  expect_true(nrow(summary_table) > 5)  # Multiple statistics
})

test_that("format_effect_size_table presents study-level data", {
  study_data <- data.frame(
    study_id = paste0("Author ", LETTERS[1:8], " (", 2015:2022, ")"),
    yi = rnorm(8, 0.5, 0.2),
    sei = runif(8, 0.08, 0.15),
    n = sample(50:200, 8, replace = TRUE)
  )

  formatted_table <- format_effect_size_table(study_data, measure = "OR")

  expect_true(!is.null(formatted_table))
  expect_true(is.data.frame(formatted_table))
  expect_true("study_id" %in% names(formatted_table) ||
              "Study" %in% names(formatted_table))
})


# ============================
# RESULTS NARRATIVE TESTS
# ============================

test_that("generate_results_narrative creates prose description", {
  results <- list(
    n_studies = 12,
    n_participants = 2450,
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 45.2,
    p_value = 0.001
  )

  narrative <- generate_results_narrative(results, measure = "OR")

  expect_true(!is.null(narrative))
  expect_true(is.character(narrative))
  expect_true(nchar(narrative) > 100)

  # Should mention key findings
  expect_true(grepl("12.*stud", narrative, ignore.case = TRUE))
  expect_true(grepl("0.52|52%", narrative))
  expect_true(grepl("heterogeneity", narrative, ignore.case = TRUE))
})

test_that("generate_interpretation_text provides clinical context", {
  results <- list(
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    certainty = "moderate"
  )

  interpretation <- generate_interpretation_text(results, measure = "OR", outcome = "mortality")

  expect_true(!is.null(interpretation))
  expect_true(is.character(interpretation))
  expect_true(nchar(interpretation) > 150)

  # Should discuss clinical implications
  expect_true(grepl("treatment|intervention|effect", interpretation, ignore.case = TRUE))
})


# ============================
# METHODS SECTION TESTS
# ============================

test_that("generate_methods_section describes analysis", {
  config <- list(
    method = "REML",
    model = "random",
    measure = "OR",
    subgroup = FALSE,
    meta_regression = FALSE,
    publication_bias_tests = c("egger", "trim_and_fill")
  )

  methods_text <- generate_methods_section(config)

  expect_true(!is.null(methods_text))
  expect_true(is.character(methods_text))
  expect_true(nchar(methods_text) > 200)

  # Should describe key methods
  expect_true(grepl("random.*effect", methods_text, ignore.case = TRUE))
  expect_true(grepl("REML", methods_text))
  expect_true(grepl("egger|publication.*bias", methods_text, ignore.case = TRUE))
})

test_that("generate_search_strategy_section documents search", {
  search_info <- list(
    databases = c("PubMed", "Embase", "Cochrane"),
    search_date = "2023-12-01",
    terms = c("treatment", "outcome", "RCT"),
    n_results = 1250,
    n_screened = 1250,
    n_included = 15
  )

  search_section <- generate_search_strategy_section(search_info)

  expect_true(!is.null(search_section))
  expect_true(is.character(search_section))
  expect_true(grepl("PubMed|Embase|Cochrane", search_section))
})


# ============================
# FIGURE GENERATION TESTS
# ============================

test_that("create_forest_plot_figure generates publication-ready figure", {
  data <- data.frame(
    study_id = paste0("Study ", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15)
  )

  meta_result <- list(
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69
  )

  forest_plot <- create_forest_plot_figure(
    data,
    meta_result,
    title = "Forest Plot of Treatment Effect",
    measure = "OR"
  )

  expect_true(!is.null(forest_plot))
  expect_true(any(class(forest_plot) %in% c("ggplot", "grob", "recordedplot")))
})

test_that("create_funnel_plot_figure generates publication bias visualization", {
  data <- data.frame(
    study_id = paste0("Study ", 1:15),
    yi = rnorm(15, 0.5, 0.2),
    sei = runif(15, 0.08, 0.20)
  )

  funnel_plot <- create_funnel_plot_figure(data, title = "Funnel Plot")

  expect_true(!is.null(funnel_plot))
  expect_true(any(class(funnel_plot) %in% c("ggplot", "grob", "recordedplot")))
})

test_that("save_figure_high_resolution exports at correct DPI", {
  # Create simple plot
  plot_obj <- ggplot2::ggplot() + ggplot2::geom_blank()

  temp_file <- tempfile(fileext = ".png")

  save_figure_high_resolution(plot_obj, temp_file, dpi = 300, width = 8, height = 6)

  expect_true(file.exists(temp_file))

  # Check file size (high-res should be larger)
  file_size <- file.info(temp_file)$size
  expect_true(file_size > 10000)  # At least 10KB

  unlink(temp_file)
})


# ============================
# TABLE FORMATTING TESTS
# ============================

test_that("format_table_for_publication applies proper formatting", {
  raw_table <- data.frame(
    Study = paste0("Author ", LETTERS[1:5]),
    Effect = c(0.523, 0.612, 0.445, 0.701, 0.556),
    CI_Lower = c(0.312, 0.401, 0.289, 0.534, 0.378),
    CI_Upper = c(0.734, 0.823, 0.601, 0.868, 0.734),
    p_value = c(0.001, 0.023, 0.156, 0.0001, 0.034)
  )

  formatted_table <- format_table_for_publication(raw_table, digits = 2)

  expect_true(!is.null(formatted_table))
  expect_true(is.data.frame(formatted_table) || is.character(formatted_table))

  # Check p-values are formatted (e.g., "<0.001")
  if (is.data.frame(formatted_table)) {
    expect_true(any(grepl("<", as.character(formatted_table$p_value))))
  }
})

test_that("create_grade_summary_table generates evidence quality table", {
  grade_assessments <- list(
    outcome1 = list(
      name = "Mortality",
      quality = "Moderate",
      concerns = c("Risk of bias", "Imprecision")
    ),
    outcome2 = list(
      name = "Adverse events",
      quality = "Low",
      concerns = c("Risk of bias", "Inconsistency", "Imprecision")
    )
  )

  grade_table <- create_grade_summary_table(grade_assessments)

  expect_true(!is.null(grade_table))
  expect_true(is.data.frame(grade_table) || is.matrix(grade_table))
  expect_equal(nrow(grade_table), 2)
})


# ============================
# CITATION GENERATION TESTS
# ============================

test_that("generate_citation creates formatted reference", {
  study_info <- list(
    authors = c("Smith J", "Johnson A", "Williams B"),
    title = "Effect of Treatment on Outcome",
    journal = "JAMA",
    year = 2020,
    volume = 324,
    pages = "123-130"
  )

  citation_apa <- generate_citation(study_info, style = "APA")
  expect_true(!is.null(citation_apa))
  expect_true(grepl("Smith.*Johnson.*Williams", citation_apa))
  expect_true(grepl("2020", citation_apa))

  citation_vancouver <- generate_citation(study_info, style = "Vancouver")
  expect_true(!is.null(citation_vancouver))
  expect_true(grepl("JAMA", citation_vancouver))
})

test_that("create_references_section formats bibliography", {
  references <- list(
    list(authors = "Smith J", title = "Study 1", year = 2020, journal = "JAMA"),
    list(authors = "Jones A", title = "Study 2", year = 2019, journal = "Lancet"),
    list(authors = "Brown B", title = "Study 3", year = 2021, journal = "NEJM")
  )

  references_section <- create_references_section(references, style = "APA")

  expect_true(!is.null(references_section))
  expect_true(is.character(references_section))
  expect_true(length(references_section) >= 3)
})


# ============================
# SUPPLEMENTARY MATERIALS TESTS
# ============================

test_that("create_supplementary_data_file exports analysis data", {
  data <- data.frame(
    study_id = paste0("Study ", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    n = sample(50:200, 10, replace = TRUE)
  )

  temp_file <- tempfile(fileext = ".csv")

  create_supplementary_data_file(data, temp_file)

  expect_true(file.exists(temp_file))

  # Verify can be read back
  read_data <- read.csv(temp_file)
  expect_equal(nrow(read_data), 10)

  unlink(temp_file)
})

test_that("create_sensitivity_analysis_appendix documents analyses", {
  sensitivity_results <- list(
    base_case = list(pooled_effect = 0.52, n_studies = 10),
    high_quality_only = list(pooled_effect = 0.48, n_studies = 7),
    large_studies = list(pooled_effect = 0.55, n_studies = 6)
  )

  appendix <- create_sensitivity_analysis_appendix(sensitivity_results)

  expect_true(!is.null(appendix))
  expect_true(is.character(appendix) || is.list(appendix))
})


# ============================
# PRISMA COMPLIANCE TESTS
# ============================

test_that("check_prisma_compliance identifies missing elements", {
  report_components <- list(
    title = TRUE,
    abstract = TRUE,
    introduction = TRUE,
    methods = TRUE,
    results = TRUE,
    discussion = TRUE,
    prisma_flowchart = FALSE,  # Missing
    search_strategy = TRUE,
    risk_of_bias_assessment = FALSE,  # Missing
    funding_disclosure = TRUE
  )

  compliance_check <- check_prisma_compliance(report_components)

  expect_true(!is.null(compliance_check))
  expect_true("missing" %in% names(compliance_check) ||
              "incomplete" %in% names(compliance_check))

  # Should identify missing flowchart and ROB
  missing_items <- compliance_check$missing
  expect_true("prisma_flowchart" %in% missing_items)
  expect_true("risk_of_bias_assessment" %in% missing_items)
})

test_that("create_prisma_checklist generates compliance table", {
  prisma_checklist <- create_prisma_checklist()

  expect_true(!is.null(prisma_checklist))
  expect_true(is.data.frame(prisma_checklist))
  expect_true(nrow(prisma_checklist) >= 27)  # PRISMA has 27 items

  # Should have required columns
  expect_true("item" %in% names(prisma_checklist) ||
              "Item" %in% names(prisma_checklist))
  expect_true("page" %in% names(prisma_checklist) ||
              "Page" %in% names(prisma_checklist))
})


# ============================
# EXPORT FORMATS TESTS
# ============================

test_that("export_to_word creates Word document", {
  skip_if_not_installed("officer")

  report_content <- list(
    title = "Meta-Analysis Report",
    abstract = "This is the abstract...",
    results = "Results show...",
    conclusion = "In conclusion..."
  )

  temp_file <- tempfile(fileext = ".docx")

  export_to_word(report_content, temp_file)

  expect_true(file.exists(temp_file))

  unlink(temp_file)
})

test_that("export_to_pdf creates PDF document", {
  skip_if_not_installed("rmarkdown")

  report_content <- list(
    title = "Meta-Analysis Report",
    body = "Report content here..."
  )

  temp_file <- tempfile(fileext = ".pdf")

  # May require pandoc
  skip_if_not(rmarkdown::pandoc_available())

  export_to_pdf(report_content, temp_file)

  expect_true(file.exists(temp_file))

  unlink(temp_file)
})

test_that("export_to_html creates HTML document", {
  report_content <- list(
    title = "Meta-Analysis Report",
    sections = list(
      introduction = "Introduction text...",
      methods = "Methods text...",
      results = "Results text..."
    )
  )

  temp_file <- tempfile(fileext = ".html")

  export_to_html(report_content, temp_file)

  expect_true(file.exists(temp_file))

  # Check HTML is valid
  html_content <- readLines(temp_file)
  expect_true(any(grepl("<html", html_content, ignore.case = TRUE)))
  expect_true(any(grepl("</html>", html_content, ignore.case = TRUE)))

  unlink(temp_file)
})


# ============================
# CUSTOM BRANDING TESTS
# ============================

test_that("apply_custom_branding adds organization logo", {
  report <- list(
    content = "Report content...",
    branding = list(
      logo_path = NULL,
      organization = "Test Organization",
      colors = list(primary = "#003366")
    )
  )

  branded_report <- apply_custom_branding(report)

  expect_true(!is.null(branded_report))
  expect_true("organization" %in% names(branded_report$branding))
})

test_that("customize_report_template applies styling", {
  template_options <- list(
    font_family = "Arial",
    font_size = 12,
    line_spacing = 1.5,
    color_scheme = "blue"
  )

  customized_template <- customize_report_template(template_options)

  expect_true(!is.null(customized_template))
})


# ============================
# AUTOMATED REPORTING TESTS
# ============================

test_that("auto_generate_executive_summary creates concise summary", {
  full_results <- list(
    n_studies = 15,
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 45.2,
    certainty = "moderate",
    recommendation = "Evidence suggests benefit"
  )

  exec_summary <- auto_generate_executive_summary(full_results)

  expect_true(!is.null(exec_summary))
  expect_true(is.character(exec_summary))
  expect_true(nchar(exec_summary) > 100)
  expect_true(nchar(exec_summary) < 1000)  # Should be concise
})

test_that("auto_generate_key_findings extracts highlights", {
  results <- list(
    pooled_effect = 0.52,
    p_value = 0.001,
    i_squared = 65,
    egger_p = 0.03,
    n_studies = 12
  )

  key_findings <- auto_generate_key_findings(results)

  expect_true(!is.null(key_findings))
  expect_true(length(key_findings) >= 3)

  # Should highlight significance, heterogeneity, publication bias
  findings_text <- paste(key_findings, collapse = " ")
  expect_true(grepl("significant|heterogeneity|bias", findings_text, ignore.case = TRUE))
})


# ============================
# VERSIONING TESTS
# ============================

test_that("create_report_metadata records analysis details", {
  metadata <- create_report_metadata(
    analyst = "John Doe",
    analysis_date = Sys.Date(),
    software_version = "2.0.0",
    r_version = R.version.string
  )

  expect_true(!is.null(metadata))
  expect_true("analyst" %in% names(metadata))
  expect_true("analysis_date" %in% names(metadata))
  expect_true("software_version" %in% names(metadata))
})

test_that("track_report_revisions maintains version history", {
  report_versions <- list(
    v1 = list(date = "2024-01-01", changes = "Initial analysis"),
    v2 = list(date = "2024-01-15", changes = "Added sensitivity analyses")
  )

  new_version <- track_report_revisions(report_versions, changes = "Updated figures")

  expect_equal(length(new_version), 3)
  expect_true("v3" %in% names(new_version))
})


# ============================
# ERROR HANDLING TESTS
# ============================

test_that("generate_full_report handles missing results gracefully", {
  incomplete_results <- list(
    meta_analysis = list(pooled_effect = 0.52)
    # Missing other components
  )

  # Should still generate report with warnings
  report <- tryCatch(
    generate_full_report(incomplete_results, format = "html"),
    error = function(e) NULL,
    warning = function(w) "warning"
  )

  expect_true(!is.null(report))
})

test_that("export_to_word validates file path", {
  skip_if_not_installed("officer")

  report_content <- list(title = "Test")

  # Invalid path
  expect_error(
    export_to_word(report_content, "/invalid/path/report.docx"),
    "path|directory|permission",
    ignore.case = TRUE
  )
})


# ============================
# INTEGRATION TESTS
# ============================

test_that("Complete reporting workflow generates full report", {
  # Step 1: Prepare analysis results
  data <- data.frame(
    study_id = paste0("Study ", 1:12),
    yi = rnorm(12, 0.5, 0.2),
    sei = runif(12, 0.08, 0.15),
    year = sample(2010:2020, 12, replace = TRUE)
  )

  meta_result <- list(
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 45.2,
    p_value = 0.001,
    n_studies = 12
  )

  # Step 2: Generate figures
  forest_plot <- create_forest_plot_figure(data, meta_result)
  expect_true(!is.null(forest_plot))

  funnel_plot <- create_funnel_plot_figure(data)
  expect_true(!is.null(funnel_plot))

  # Step 3: Generate tables
  summary_table <- create_summary_statistics_table(meta_result)
  expect_true(!is.null(summary_table))

  # Step 4: Generate narrative
  results_narrative <- generate_results_narrative(meta_result, measure = "OR")
  expect_true(nchar(results_narrative) > 100)

  # Step 5: Generate methods
  config <- list(method = "REML", model = "random", measure = "OR")
  methods_text <- generate_methods_section(config)
  expect_true(nchar(methods_text) > 200)

  # Step 6: Compile full report
  full_report <- list(
    methods = methods_text,
    results = results_narrative,
    figures = list(forest = forest_plot, funnel = funnel_plot),
    tables = list(summary = summary_table)
  )

  expect_true(!is.null(full_report))
  expect_equal(length(full_report), 4)
})


# Run all tests
cat("\n=== Running Reporting Module Tests ===\n")
test_results <- test_dir(".", filter = "test_reporting", reporter = "summary")
cat("\n=== Reporting Tests Complete ===\n")
