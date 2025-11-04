# Comprehensive Tests for AI Copilot Module
# Tests for frontend/modules/ai_copilot.R

library(testthat)
library(dplyr)
library(jsonlite)

# Source the module
source("../../frontend/modules/ai_copilot.R")

# ============================
# CONTEXT BUILDING TESTS
# ============================

test_that("build_analysis_context creates comprehensive context", {
  # Mock analysis data
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    year = sample(2010:2020, 10, replace = TRUE)
  )

  meta_result <- list(
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 45.2,
    tau_squared = 0.08,
    p_value = 0.001
  )

  context <- build_analysis_context(data, meta_result)

  expect_true(!is.null(context))
  expect_true("n_studies" %in% names(context))
  expect_true("pooled_estimate" %in% names(context))
  expect_true("heterogeneity" %in% names(context))
  expect_equal(context$n_studies, 10)
})

test_that("extract_key_findings identifies important results", {
  meta_result <- list(
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 65.2,
    tau_squared = 0.15,
    p_value = 0.001,
    egger_p = 0.12
  )

  findings <- extract_key_findings(meta_result)

  expect_true(!is.null(findings))
  expect_true(is.list(findings) || is.character(findings))

  if (is.list(findings)) {
    expect_true("effect_significant" %in% names(findings))
    expect_true("heterogeneity_level" %in% names(findings))
  }
})


# ============================
# QUERY PROCESSING TESTS
# ============================

test_that("process_user_query identifies query type", {
  # Interpretation query
  query1 <- "What does the I-squared value mean?"
  type1 <- process_user_query(query1)
  expect_true(type1$type %in% c("interpretation", "explanation", "question"))

  # Recommendation query
  query2 <- "Should I use fixed or random effects?"
  type2 <- process_user_query(query2)
  expect_true(type2$type %in% c("recommendation", "advice", "question"))

  # Data query
  query3 <- "How many studies are included?"
  type3 <- process_user_query(query3)
  expect_true(type3$type %in% c("data", "summary", "question"))
})

test_that("parse_query_intent extracts key entities", {
  query <- "What is the pooled effect size for studies published after 2015?"

  intent <- parse_query_intent(query)

  expect_true(!is.null(intent))
  expect_true("entities" %in% names(intent) || "keywords" %in% names(intent))

  # Should identify year as entity
  if ("entities" %in% names(intent)) {
    expect_true(any(grepl("2015|year|after", intent$entities, ignore.case = TRUE)))
  }
})


# ============================
# INTERPRETATION GENERATION TESTS
# ============================

test_that("interpret_pooled_effect generates narrative interpretation", {
  pooled_effect <- 0.52
  ci_lower <- 0.35
  ci_upper <- 0.69
  measure <- "OR"

  interpretation <- interpret_pooled_effect(pooled_effect, ci_lower, ci_upper, measure)

  expect_true(!is.null(interpretation))
  expect_true(is.character(interpretation))
  expect_true(nchar(interpretation) > 50)  # Should be descriptive

  # Should mention key values
  expect_true(grepl("0.52|52%", interpretation))
  expect_true(grepl("confidence interval|CI", interpretation, ignore.case = TRUE))
})

test_that("interpret_heterogeneity provides context-appropriate explanation", {
  # Low heterogeneity
  interpretation_low <- interpret_heterogeneity(i_squared = 15, tau_squared = 0.02)
  expect_true(grepl("low|minimal|little", interpretation_low, ignore.case = TRUE))

  # Moderate heterogeneity
  interpretation_mod <- interpret_heterogeneity(i_squared = 45, tau_squared = 0.08)
  expect_true(grepl("moderate", interpretation_mod, ignore.case = TRUE))

  # High heterogeneity
  interpretation_high <- interpret_heterogeneity(i_squared = 75, tau_squared = 0.25)
  expect_true(grepl("substantial|considerable|high", interpretation_high, ignore.case = TRUE))
})

test_that("interpret_publication_bias assesses bias indicators", {
  egger_p <- 0.03  # Significant publication bias
  trim_fill_adjusted <- 0.45
  original_estimate <- 0.52

  interpretation <- interpret_publication_bias(egger_p, trim_fill_adjusted, original_estimate)

  expect_true(!is.null(interpretation))
  expect_true(is.character(interpretation))
  expect_true(grepl("bias|asymmetry", interpretation, ignore.case = TRUE))
})


# ============================
# RECOMMENDATION ENGINE TESTS
# ============================

test_that("recommend_analysis_method suggests appropriate method", {
  # High heterogeneity → random effects
  data1 <- list(n_studies = 10, i_squared = 70)
  recommendation1 <- recommend_analysis_method(data1)

  expect_true(!is.null(recommendation1))
  expect_true(grepl("random", recommendation1, ignore.case = TRUE))

  # Low heterogeneity → fixed effects may be acceptable
  data2 <- list(n_studies = 15, i_squared = 10)
  recommendation2 <- recommend_analysis_method(data2)

  expect_true(!is.null(recommendation2))
})

test_that("recommend_sensitivity_analysis suggests relevant analyses", {
  context <- list(
    i_squared = 68,
    n_studies = 12,
    has_high_rob_studies = TRUE,
    publication_bias_p = 0.04
  )

  recommendations <- recommend_sensitivity_analysis(context)

  expect_true(!is.null(recommendations))
  expect_true(length(recommendations) > 0)

  # Should recommend leave-one-out due to high heterogeneity
  expect_true(any(grepl("leave.*one.*out|influence", recommendations, ignore.case = TRUE)))

  # Should recommend ROB exclusion
  expect_true(any(grepl("risk.*bias|quality", recommendations, ignore.case = TRUE)))
})

test_that("suggest_next_steps provides actionable guidance", {
  analysis_state <- list(
    completed = c("pairwise_ma", "heterogeneity_test"),
    pending = c("publication_bias", "sensitivity_analysis")
  )

  next_steps <- suggest_next_steps(analysis_state)

  expect_true(!is.null(next_steps))
  expect_true(length(next_steps) > 0)

  # Should suggest publication bias assessment
  expect_true(any(grepl("publication.*bias|funnel|egger", next_steps, ignore.case = TRUE)))
})


# ============================
# QUALITY ASSESSMENT TESTS
# ============================

test_that("assess_analysis_quality evaluates completeness", {
  analysis <- list(
    has_forest_plot = TRUE,
    has_heterogeneity_test = TRUE,
    has_publication_bias = FALSE,
    has_sensitivity_analysis = FALSE,
    n_studies = 8
  )

  quality_assessment <- assess_analysis_quality(analysis)

  expect_true(!is.null(quality_assessment))
  expect_true("score" %in% names(quality_assessment) || "completeness" %in% names(quality_assessment))

  # Should flag missing publication bias and sensitivity analyses
  if ("recommendations" %in% names(quality_assessment)) {
    expect_true(length(quality_assessment$recommendations) > 0)
  }
})

test_that("check_reporting_standards identifies missing elements", {
  report <- list(
    has_prisma_flowchart = FALSE,
    has_search_strategy = TRUE,
    has_risk_of_bias = TRUE,
    has_grade_assessment = FALSE
  )

  standards_check <- check_reporting_standards(report)

  expect_true(!is.null(standards_check))
  expect_true("missing_elements" %in% names(standards_check) ||
              "gaps" %in% names(standards_check))
})


# ============================
# NATURAL LANGUAGE GENERATION TESTS
# ============================

test_that("generate_results_summary creates readable summary", {
  results <- list(
    n_studies = 12,
    n_participants = 2450,
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 45.2,
    p_value = 0.001
  )

  summary <- generate_results_summary(results, measure = "OR")

  expect_true(!is.null(summary))
  expect_true(is.character(summary))
  expect_true(nchar(summary) > 100)  # Should be substantive

  # Should mention key results
  expect_true(grepl("12.*stud", summary, ignore.case = TRUE))
  expect_true(grepl("0.52|52%", summary))
})

test_that("generate_interpretation_paragraph creates narrative", {
  findings <- list(
    effect_direction = "positive",
    effect_magnitude = "moderate",
    significance = TRUE,
    heterogeneity = "moderate",
    certainty = "moderate"
  )

  paragraph <- generate_interpretation_paragraph(findings)

  expect_true(!is.null(paragraph))
  expect_true(is.character(paragraph))
  expect_true(nchar(paragraph) > 150)

  # Should discuss effect and certainty
  expect_true(grepl("effect|treatment|intervention", paragraph, ignore.case = TRUE))
})


# ============================
# QUESTION ANSWERING TESTS
# ============================

test_that("answer_statistical_question provides correct answer", {
  question <- "What is I-squared?"
  answer <- answer_statistical_question(question)

  expect_true(!is.null(answer))
  expect_true(is.character(answer))
  expect_true(grepl("heterogeneity|variation|inconsistency", answer, ignore.case = TRUE))
})

test_that("answer_methodological_question explains methods", {
  question <- "What is the difference between fixed and random effects?"
  answer <- answer_methodological_question(question)

  expect_true(!is.null(answer))
  expect_true(is.character(answer))
  expect_true(grepl("fixed.*effect|random.*effect", answer, ignore.case = TRUE))
})

test_that("answer_interpretation_question helps interpret results", {
  context <- list(
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    measure = "OR"
  )

  question <- "Is this result clinically significant?"
  answer <- answer_interpretation_question(question, context)

  expect_true(!is.null(answer))
  expect_true(is.character(answer))
})


# ============================
# CONVERSATION MANAGEMENT TESTS
# ============================

test_that("manage_conversation_context maintains history", {
  # Initialize conversation
  conversation <- initialize_conversation()

  # Add user query
  conversation <- add_to_conversation(conversation, role = "user", message = "What is I-squared?")

  # Add assistant response
  conversation <- add_to_conversation(
    conversation,
    role = "assistant",
    message = "I-squared measures heterogeneity..."
  )

  expect_equal(length(conversation$history), 2)
  expect_equal(conversation$history[[1]]$role, "user")
  expect_equal(conversation$history[[2]]$role, "assistant")
})

test_that("get_conversation_summary summarizes interaction", {
  conversation <- list(
    history = list(
      list(role = "user", message = "What is I-squared?"),
      list(role = "assistant", message = "I-squared measures heterogeneity..."),
      list(role = "user", message = "Should I use random effects?"),
      list(role = "assistant", message = "Yes, given high I-squared...")
    )
  )

  summary <- get_conversation_summary(conversation)

  expect_true(!is.null(summary))
  expect_true("n_exchanges" %in% names(summary) || "turns" %in% names(summary))
})


# ============================
# AUTOCOMPLETE SUGGESTIONS TESTS
# ============================

test_that("suggest_query_completions provides relevant suggestions", {
  partial_query <- "What is the"

  suggestions <- suggest_query_completions(partial_query)

  expect_true(!is.null(suggestions))
  expect_true(length(suggestions) > 0)

  # Should suggest relevant completions
  expect_true(any(grepl("pooled effect|I-squared|heterogeneity", suggestions, ignore.case = TRUE)))
})

test_that("get_common_questions returns frequently asked questions", {
  common_q <- get_common_questions()

  expect_true(!is.null(common_q))
  expect_true(length(common_q) > 0)
  expect_true(is.character(common_q) || is.list(common_q))
})


# ============================
# CITATION GENERATION TESTS
# ============================

test_that("generate_methods_text creates methods section", {
  analysis_config <- list(
    method = "REML",
    model = "random",
    measure = "OR",
    subgroup_var = NULL,
    meta_regression = FALSE
  )

  methods_text <- generate_methods_text(analysis_config)

  expect_true(!is.null(methods_text))
  expect_true(is.character(methods_text))
  expect_true(nchar(methods_text) > 100)

  # Should mention key methodological details
  expect_true(grepl("random.*effect|REML", methods_text, ignore.case = TRUE))
  expect_true(grepl("odds ratio|OR", methods_text, ignore.case = TRUE))
})

test_that("generate_results_text creates results section", {
  results <- list(
    n_studies = 12,
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    p_value = 0.001,
    i_squared = 45.2
  )

  results_text <- generate_results_text(results, measure = "OR")

  expect_true(!is.null(results_text))
  expect_true(is.character(results_text))
  expect_true(nchar(results_text) > 100)

  # Should report key statistics
  expect_true(grepl("12.*stud", results_text, ignore.case = TRUE))
  expect_true(grepl("0.52", results_text))
  expect_true(grepl("45|heterogeneity", results_text, ignore.case = TRUE))
})


# ============================
# EXPORT ASSISTANCE TESTS
# ============================

test_that("prepare_export_data formats data for export", {
  results <- list(
    study_data = data.frame(
      study_id = paste0("S", 1:5),
      yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
      sei = c(0.1, 0.12, 0.09, 0.15, 0.11)
    ),
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69
  )

  export_data <- prepare_export_data(results, format = "table")

  expect_true(!is.null(export_data))
  expect_true(is.data.frame(export_data) || is.list(export_data))
})

test_that("generate_figure_caption creates descriptive caption", {
  figure_type <- "forest_plot"
  context <- list(
    n_studies = 12,
    measure = "OR",
    outcome = "Mortality"
  )

  caption <- generate_figure_caption(figure_type, context)

  expect_true(!is.null(caption))
  expect_true(is.character(caption))
  expect_true(nchar(caption) > 30)

  # Should describe figure
  expect_true(grepl("forest.*plot|meta.*analysis", caption, ignore.case = TRUE))
  expect_true(grepl("12|odds ratio|mortality", caption, ignore.case = TRUE))
})


# ============================
# ERROR DETECTION TESTS
# ============================

test_that("detect_potential_errors identifies data issues", {
  # Data with outlier
  data <- data.frame(
    study_id = paste0("S", 1:6),
    yi = c(0.5, 0.6, 0.4, 5.2, 0.5, 0.55),  # 5.2 is outlier
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11, 0.10)
  )

  potential_errors <- detect_potential_errors(data)

  expect_true(!is.null(potential_errors))

  if (length(potential_errors) > 0) {
    # Should detect outlier
    expect_true(any(grepl("outlier|extreme|unusual", potential_errors, ignore.case = TRUE)))
  }
})

test_that("check_data_quality identifies quality issues", {
  data <- data.frame(
    study_id = paste0("S", 1:5),
    yi = c(0.5, 0.6, NA, 0.7, 0.5),  # Missing value
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11)
  )

  quality_check <- check_data_quality(data)

  expect_true(!is.null(quality_check))
  expect_true("issues" %in% names(quality_check) || "warnings" %in% names(quality_check))
})


# ============================
# CONTEXTUAL HELP TESTS
# ============================

test_that("get_context_help provides relevant help", {
  context <- "publication_bias_test"

  help_text <- get_context_help(context)

  expect_true(!is.null(help_text))
  expect_true(is.character(help_text))
  expect_true(grepl("publication.*bias|funnel|egger", help_text, ignore.case = TRUE))
})

test_that("explain_parameter describes parameter meaning", {
  param <- "tau_squared"

  explanation <- explain_parameter(param)

  expect_true(!is.null(explanation))
  expect_true(is.character(explanation))
  expect_true(grepl("between.*study.*variance|heterogeneity", explanation, ignore.case = TRUE))
})


# ============================
# LEARNING & ADAPTATION TESTS
# ============================

test_that("track_user_preferences records preferences", {
  preferences <- initialize_preferences()

  # User always asks about clinical significance
  preferences <- record_query_preference(preferences, "clinical significance")
  preferences <- record_query_preference(preferences, "clinical significance")

  expect_true("clinical significance" %in% names(preferences$query_topics) ||
              any(grepl("clinical", preferences$common_queries)))
})

test_that("personalize_response adapts to user level", {
  # Expert user
  response_expert <- personalize_response(
    "I-squared measures heterogeneity",
    user_level = "expert"
  )

  # Novice user
  response_novice <- personalize_response(
    "I-squared measures heterogeneity",
    user_level = "novice"
  )

  # Novice response should be more explanatory
  expect_true(nchar(response_novice) >= nchar(response_expert) ||
              grepl("between.*stud", response_novice, ignore.case = TRUE))
})


# ============================
# INTEGRATION TESTS
# ============================

test_that("Full AI copilot workflow completes successfully", {
  # Step 1: Build context
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15)
  )

  meta_result <- list(
    pooled_effect = 0.52,
    ci_lower = 0.35,
    ci_upper = 0.69,
    i_squared = 65.2,
    p_value = 0.001
  )

  context <- build_analysis_context(data, meta_result)
  expect_true(!is.null(context))

  # Step 2: Extract key findings
  findings <- extract_key_findings(meta_result)
  expect_true(!is.null(findings))

  # Step 3: Generate interpretation
  interpretation <- interpret_pooled_effect(0.52, 0.35, 0.69, "OR")
  expect_true(nchar(interpretation) > 50)

  # Step 4: Recommend next steps
  recommendations <- recommend_sensitivity_analysis(list(i_squared = 65.2))
  expect_true(length(recommendations) > 0)

  # Step 5: Generate summary
  summary <- generate_results_summary(meta_result, measure = "OR")
  expect_true(nchar(summary) > 100)
})


# ============================
# PERFORMANCE TESTS
# ============================

test_that("AI copilot responds within reasonable time", {
  query <- "What does the I-squared value mean?"

  start_time <- Sys.time()
  response <- answer_statistical_question(query)
  end_time <- Sys.time()

  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  # Should respond quickly (< 2 seconds for local processing)
  expect_true(elapsed < 2)
  expect_true(!is.null(response))
})


# Run all tests
cat("\n=== Running AI Copilot Module Tests ===\n")
test_results <- test_dir(".", filter = "test_ai_copilot", reporter = "summary")
cat("\n=== AI Copilot Tests Complete ===\n")
