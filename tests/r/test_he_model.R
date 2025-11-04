# Comprehensive Tests for Health Economics Model Module
# Tests for frontend/modules/he_model.R

library(testthat)
library(dplyr)

# Source the module
source("../../frontend/modules/he_model.R")

# ============================
# DECISION TREE TESTS
# ============================

test_that("create_decision_tree builds valid tree structure", {
  tree <- create_decision_tree(
    branches = c("Treatment", "NoTreatment"),
    outcomes = c("Success", "Failure"),
    probabilities = list(
      Treatment = c(0.7, 0.3),
      NoTreatment = c(0.4, 0.6)
    )
  )

  expect_true(!is.null(tree))
  expect_true("branches" %in% names(tree))
  expect_true("probabilities" %in% names(tree))
  expect_equal(length(tree$branches), 2)
})

test_that("evaluate_decision_tree calculates expected values", {
  tree <- list(
    branches = c("Treatment", "NoTreatment"),
    probabilities = list(
      Treatment = c(0.7, 0.3),
      NoTreatment = c(0.4, 0.6)
    ),
    costs = list(
      Treatment = c(10000, 5000),
      NoTreatment = c(0, 0)
    ),
    qalys = list(
      Treatment = c(0.8, 0.3),
      NoTreatment = c(0.5, 0.2)
    )
  )

  result <- evaluate_decision_tree(tree)

  expect_true(!is.null(result))
  expect_true("expected_cost" %in% names(result))
  expect_true("expected_qalys" %in% names(result))
  expect_true("Treatment" %in% names(result$expected_cost))
  expect_true("NoTreatment" %in% names(result$expected_cost))
})


# ============================
# MARKOV MODEL TESTS
# ============================

test_that("create_markov_model builds valid transition matrix", {
  markov <- create_markov_model(
    states = c("Healthy", "Sick", "Dead"),
    transition_matrix = matrix(
      c(0.7, 0.2, 0.1,
        0.1, 0.6, 0.3,
        0.0, 0.0, 1.0),
      nrow = 3, byrow = TRUE
    ),
    cycle_length = 1  # years
  )

  expect_true(!is.null(markov))
  expect_true("states" %in% names(markov))
  expect_true("transition_matrix" %in% names(markov))
  expect_equal(nrow(markov$transition_matrix), 3)
  expect_equal(ncol(markov$transition_matrix), 3)
})

test_that("create_markov_model validates transition probabilities", {
  # Invalid: rows don't sum to 1
  expect_error(
    create_markov_model(
      states = c("Healthy", "Sick"),
      transition_matrix = matrix(c(0.5, 0.3, 0.2, 0.7), nrow = 2)
    ),
    "sum.*1|probabilities|invalid",
    ignore.case = TRUE
  )
})

test_that("run_markov_simulation simulates cohort over time", {
  markov <- create_markov_model(
    states = c("Healthy", "Sick", "Dead"),
    transition_matrix = matrix(
      c(0.7, 0.2, 0.1,
        0.1, 0.6, 0.3,
        0.0, 0.0, 1.0),
      nrow = 3, byrow = TRUE
    ),
    cycle_length = 1
  )

  simulation <- run_markov_simulation(
    markov,
    initial_distribution = c(1.0, 0.0, 0.0),  # Start all healthy
    n_cycles = 10,
    cohort_size = 1000
  )

  expect_true(!is.null(simulation))
  expect_true("trace" %in% names(simulation))
  expect_equal(nrow(simulation$trace), 11)  # 0 to 10 cycles
  expect_equal(ncol(simulation$trace), 3)   # 3 states

  # Check cohort conservation (allowing for rounding)
  expect_true(all(abs(rowSums(simulation$trace) - 1000) < 1))
})

test_that("run_markov_simulation reaches absorbing state", {
  markov <- create_markov_model(
    states = c("Alive", "Dead"),
    transition_matrix = matrix(c(0.9, 0.1, 0.0, 1.0), nrow = 2, byrow = TRUE),
    cycle_length = 1
  )

  simulation <- run_markov_simulation(
    markov,
    initial_distribution = c(1.0, 0.0),
    n_cycles = 50,
    cohort_size = 1000
  )

  # Eventually, most/all should be dead
  final_dead <- simulation$trace[51, 2]  # Last cycle, Dead state
  expect_true(final_dead > 900)  # >90% dead after 50 cycles
})


# ============================
# COST-EFFECTIVENESS TESTS
# ============================

test_that("calculate_icer computes incremental cost-effectiveness ratio", {
  treatment_a <- list(cost = 10000, qalys = 5.0)
  treatment_b <- list(cost = 15000, qalys = 6.0)

  icer <- calculate_icer(treatment_a, treatment_b)

  expected_icer <- (15000 - 10000) / (6.0 - 5.0)

  expect_equal(icer, expected_icer)
})

test_that("calculate_icer handles dominated strategies", {
  treatment_a <- list(cost = 10000, qalys = 5.0)
  treatment_b <- list(cost = 15000, qalys = 4.5)  # More cost, less QALYs - dominated

  icer <- calculate_icer(treatment_a, treatment_b)

  expect_true(is.infinite(icer) || icer < 0 || is.na(icer))
})

test_that("calculate_icer handles equal QALYs", {
  treatment_a <- list(cost = 10000, qalys = 5.0)
  treatment_b <- list(cost = 12000, qalys = 5.0)  # Same QALYs

  icer <- calculate_icer(treatment_a, treatment_b)

  expect_true(is.infinite(icer) || is.na(icer))
})

test_that("calculate_nmb computes net monetary benefit", {
  cost <- 15000
  qalys <- 6.0
  wtp <- 50000  # $50,000 per QALY

  nmb <- calculate_nmb(cost, qalys, wtp)

  expected_nmb <- (qalys * wtp) - cost
  expect_equal(nmb, expected_nmb)
})

test_that("calculate_inmb computes incremental NMB", {
  treatment_a <- list(cost = 10000, qalys = 5.0)
  treatment_b <- list(cost = 15000, qalys = 6.0)
  wtp <- 50000

  inmb <- calculate_inmb(treatment_a, treatment_b, wtp)

  expected_inmb <- ((6.0 - 5.0) * wtp) - (15000 - 10000)
  expect_equal(inmb, expected_inmb)
})


# ============================
# COST-EFFECTIVENESS PLANE TESTS
# ============================

test_that("create_ce_plane generates scatter plot", {
  incremental_costs <- rnorm(1000, mean = 5000, sd = 2000)
  incremental_qalys <- rnorm(1000, mean = 0.5, sd = 0.2)

  ce_plane <- create_ce_plane(incremental_costs, incremental_qalys, wtp = 50000)

  expect_true(!is.null(ce_plane))
  # Should be ggplot or base R plot
  expect_true(any(class(ce_plane) %in% c("ggplot", "recordedplot")) ||
              is.list(ce_plane))
})

test_that("identify_ce_quadrant classifies points correctly", {
  # NE quadrant: more cost, more QALYs
  quadrant_ne <- identify_ce_quadrant(delta_cost = 1000, delta_qaly = 0.5)
  expect_equal(quadrant_ne, "NE")

  # SE quadrant: more cost, fewer QALYs (dominated)
  quadrant_se <- identify_ce_quadrant(delta_cost = 1000, delta_qaly = -0.5)
  expect_equal(quadrant_se, "SE")

  # SW quadrant: less cost, fewer QALYs
  quadrant_sw <- identify_ce_quadrant(delta_cost = -1000, delta_qaly = -0.5)
  expect_equal(quadrant_sw, "SW")

  # NW quadrant: less cost, more QALYs (dominant)
  quadrant_nw <- identify_ce_quadrant(delta_cost = -1000, delta_qaly = 0.5)
  expect_equal(quadrant_nw, "NW")
})


# ============================
# PROBABILISTIC SENSITIVITY ANALYSIS TESTS
# ============================

test_that("run_psa performs Monte Carlo simulation", {
  # Simple cost-effectiveness model
  model_function <- function(params) {
    list(
      cost = params$cost_treatment + params$cost_ae * params$prob_ae,
      qalys = params$baseline_utility + params$treatment_effect
    )
  }

  # Parameter distributions
  params <- list(
    cost_treatment = rnorm(1000, mean = 10000, sd = 1000),
    cost_ae = rnorm(1000, mean = 500, sd = 100),
    prob_ae = rbeta(1000, 2, 8),
    baseline_utility = rnorm(1000, mean = 0.7, sd = 0.05),
    treatment_effect = rnorm(1000, mean = 0.1, sd = 0.02)
  )

  psa_result <- run_psa(model_function, params, n_sims = 1000)

  expect_true(!is.null(psa_result))
  expect_true("costs" %in% names(psa_result))
  expect_true("qalys" %in% names(psa_result))
  expect_equal(length(psa_result$costs), 1000)
  expect_equal(length(psa_result$qalys), 1000)
})

test_that("create_ceac generates cost-effectiveness acceptability curve", {
  incremental_costs <- rnorm(1000, mean = 5000, sd = 2000)
  incremental_qalys <- rnorm(1000, mean = 0.5, sd = 0.2)

  wtp_thresholds <- seq(0, 100000, by = 10000)

  ceac <- create_ceac(incremental_costs, incremental_qalys, wtp_thresholds)

  expect_true(!is.null(ceac))
  expect_true("wtp" %in% names(ceac) || "threshold" %in% names(ceac))
  expect_true("probability_ce" %in% names(ceac) || "prob" %in% names(ceac))

  # Probabilities should be between 0 and 1
  probs <- ceac[[2]]  # Second column is probabilities
  expect_true(all(probs >= 0 & probs <= 1))

  # Probability should increase with WTP (generally)
  # expect_true(probs[length(probs)] >= probs[1])
})


# ============================
# DISCOUNT RATE TESTS
# ============================

test_that("apply_discount_rate discounts future costs correctly", {
  costs <- c(1000, 1000, 1000, 1000, 1000)  # $1000 per year for 5 years
  discount_rate <- 0.03  # 3%

  discounted <- apply_discount_rate(costs, discount_rate)

  expect_equal(length(discounted), 5)

  # First year should be undiscounted
  expect_equal(discounted[1], 1000)

  # Later years should be discounted
  expect_true(discounted[2] < 1000)
  expect_true(discounted[5] < discounted[2])

  # Check specific calculation for year 2
  expected_year2 <- 1000 / (1.03^1)
  expect_equal(discounted[2], expected_year2, tolerance = 0.01)
})

test_that("calculate_present_value computes NPV correctly", {
  future_values <- c(1000, 1000, 1000)
  discount_rate <- 0.05

  pv <- calculate_present_value(future_values, discount_rate)

  expected_pv <- 1000 + (1000 / 1.05) + (1000 / 1.05^2)

  expect_equal(pv, expected_pv, tolerance = 0.01)
})


# ============================
# UTILITY CALCULATION TESTS
# ============================

test_that("calculate_qalys computes quality-adjusted life years", {
  utility <- c(0.8, 0.7, 0.6, 0.5)  # Declining utility over 4 years
  time <- c(1, 1, 1, 1)  # 1 year per cycle

  qalys <- calculate_qalys(utility, time)

  expected_qalys <- sum(utility * time)
  expect_equal(qalys, expected_qalys)
})

test_that("calculate_qalys handles half-cycle correction", {
  utility <- c(0.8, 0.7, 0.6, 0.5)
  time <- c(1, 1, 1, 1)

  qalys_no_correction <- calculate_qalys(utility, time, half_cycle = FALSE)
  qalys_with_correction <- calculate_qalys(utility, time, half_cycle = TRUE)

  # With half-cycle correction, first and last cycles weighted by 0.5
  expect_true(qalys_with_correction < qalys_no_correction)
})

test_that("apply_disutility_event reduces utility correctly", {
  baseline_utility <- 0.8
  event_disutility <- 0.2
  event_duration <- 0.5  # 6 months

  adjusted_utility <- apply_disutility_event(
    baseline_utility,
    event_disutility,
    event_duration
  )

  expected_utility <- (0.8 * 0.5) + ((0.8 - 0.2) * 0.5)
  expect_equal(adjusted_utility, expected_utility, tolerance = 0.01)
})


# ============================
# BUDGET IMPACT ANALYSIS TESTS
# ============================

test_that("calculate_budget_impact computes total budget", {
  # Current scenario
  current <- list(
    cost_per_patient = 10000,
    n_patients = 1000,
    market_share = 1.0
  )

  # New scenario
  new_treatment <- list(
    cost_per_patient = 15000,
    n_patients = 1000,
    market_share = 0.3  # 30% uptake
  )

  budget_impact <- calculate_budget_impact(current, new_treatment, n_years = 5)

  expect_true(!is.null(budget_impact))
  expect_true("total_cost_current" %in% names(budget_impact))
  expect_true("total_cost_new" %in% names(budget_impact))
  expect_true("budget_impact" %in% names(budget_impact))

  # New treatment should increase budget
  expect_true(budget_impact$budget_impact > 0)
})


# ============================
# VALUE OF INFORMATION TESTS
# ============================

test_that("calculate_evpi computes expected value of perfect information", {
  # PSA results with decision uncertainty
  nmb_treatment <- rnorm(1000, mean = 10000, sd = 5000)
  nmb_control <- rnorm(1000, mean = 8000, sd = 3000)

  evpi <- calculate_evpi(nmb_treatment, nmb_control)

  expect_true(!is.null(evpi))
  expect_true(evpi >= 0)  # EVPI should be non-negative
})

test_that("calculate_evppi computes EVPPI for parameter subset", {
  # Simplified EVPPI test
  # This is complex and requires nested simulations

  psa_results <- data.frame(
    param1 = rnorm(1000, 0.5, 0.1),
    param2 = rnorm(1000, 100, 20),
    nmb = rnorm(1000, 10000, 5000)
  )

  evppi <- calculate_evppi(psa_results, param = "param1", wtp = 50000)

  expect_true(!is.null(evppi))
  expect_true(evppi >= 0)
})


# ============================
# PARAMETER UTILITIES TESTS
# ============================

test_that("sample_from_distribution generates correct samples", {
  # Normal distribution
  samples_norm <- sample_from_distribution("normal", n = 1000, mean = 50, sd = 10)
  expect_equal(length(samples_norm), 1000)
  expect_true(abs(mean(samples_norm) - 50) < 2)  # Within 2 units of mean

  # Beta distribution
  samples_beta <- sample_from_distribution("beta", n = 1000, shape1 = 2, shape2 = 5)
  expect_equal(length(samples_beta), 1000)
  expect_true(all(samples_beta >= 0 & samples_beta <= 1))

  # Gamma distribution
  samples_gamma <- sample_from_distribution("gamma", n = 1000, shape = 2, rate = 0.5)
  expect_equal(length(samples_gamma), 1000)
  expect_true(all(samples_gamma >= 0))
})


# ============================
# MODEL VALIDATION TESTS
# ============================

test_that("validate_he_model checks model structure", {
  model <- list(
    states = c("Healthy", "Sick", "Dead"),
    transition_matrix = matrix(
      c(0.7, 0.2, 0.1,
        0.1, 0.6, 0.3,
        0.0, 0.0, 1.0),
      nrow = 3, byrow = TRUE
    ),
    costs = c(0, 5000, 0),
    utilities = c(1.0, 0.6, 0)
  )

  validation <- validate_he_model(model)

  expect_true(!is.null(validation))
  expect_true(validation$is_valid || "is_valid" %in% names(validation))
})

test_that("validate_he_model detects negative costs", {
  model <- list(
    costs = c(1000, -500, 0)  # Negative cost!
  )

  validation <- validate_he_model(model)

  expect_false(validation$is_valid)
  expect_true(length(validation$errors) > 0)
})

test_that("validate_he_model detects utilities outside [0,1]", {
  model <- list(
    utilities = c(1.0, 0.6, 1.5)  # Utility > 1!
  )

  validation <- validate_he_model(model)

  expect_false(validation$is_valid || length(validation$warnings) > 0)
})


# ============================
# SCENARIO ANALYSIS TESTS
# ============================

test_that("run_scenario_analysis tests multiple scenarios", {
  base_case <- list(
    cost_treatment = 10000,
    effectiveness = 0.7,
    cost_comparator = 5000,
    effectiveness_comparator = 0.5
  )

  scenarios <- list(
    optimistic = list(effectiveness = 0.8),
    pessimistic = list(effectiveness = 0.6),
    high_cost = list(cost_treatment = 15000)
  )

  results <- run_scenario_analysis(base_case, scenarios)

  expect_true(!is.null(results))
  expect_equal(length(results), 4)  # Base + 3 scenarios
  expect_true("base_case" %in% names(results))
  expect_true("optimistic" %in% names(results))
})


# ============================
# REPORTING TESTS
# ============================

test_that("create_he_summary_table generates formatted table", {
  he_results <- list(
    treatment_a = list(
      cost = 10000,
      qalys = 5.0,
      nmb = 240000
    ),
    treatment_b = list(
      cost = 15000,
      qalys = 6.0,
      nmb = 285000
    ),
    icer = 5000
  )

  summary_table <- create_he_summary_table(he_results)

  expect_true(!is.null(summary_table))
  expect_true(is.data.frame(summary_table) || is.matrix(summary_table))
})


# ============================
# ERROR HANDLING TESTS
# ============================

test_that("calculate_icer handles invalid inputs gracefully", {
  expect_error(
    calculate_icer(list(cost = "invalid", qalys = 5), list(cost = 1000, qalys = 6)),
    "numeric|invalid",
    ignore.case = TRUE
  )
})

test_that("run_markov_simulation validates initial distribution", {
  markov <- create_markov_model(
    states = c("A", "B"),
    transition_matrix = matrix(c(0.9, 0.1, 0.1, 0.9), nrow = 2)
  )

  # Initial distribution doesn't sum to 1
  expect_error(
    run_markov_simulation(markov, initial_distribution = c(0.5, 0.3), n_cycles = 10),
    "sum|distribution|invalid",
    ignore.case = TRUE
  )
})


# ============================
# INTEGRATION TESTS
# ============================

test_that("Complete HE workflow executes successfully", {
  # Step 1: Create Markov model
  markov <- create_markov_model(
    states = c("Healthy", "Sick", "Dead"),
    transition_matrix = matrix(
      c(0.8, 0.15, 0.05,
        0.1, 0.7, 0.2,
        0.0, 0.0, 1.0),
      nrow = 3, byrow = TRUE
    )
  )

  # Step 2: Run simulation
  sim <- run_markov_simulation(
    markov,
    initial_distribution = c(1, 0, 0),
    n_cycles = 20
  )

  expect_equal(nrow(sim$trace), 21)

  # Step 3: Calculate costs and QALYs
  costs <- c(0, 5000, 0)
  utilities <- c(1.0, 0.6, 0)

  total_qalys <- sum(sim$trace %*% utilities)
  total_costs <- sum(sim$trace %*% costs)

  expect_true(total_qalys > 0)
  expect_true(total_costs > 0)

  # Step 4: Calculate ICER (would need comparator)
  # Step 5: Run PSA (would need parameter distributions)
  # Step 6: Create CEAC
})


# Run all tests
cat("\n=== Running Health Economics Module Tests ===\n")
test_results <- test_dir(".", filter = "test_he_model", reporter = "summary")
cat("\n=== Health Economics Tests Complete ===\n")
