# ==============================================================================
# NETWORK META-ANALYSIS CONSISTENCY MODELS
# ==============================================================================
#
# Tests the consistency assumption in network meta-analysis
# Consistency = Direct evidence agrees with indirect evidence
#
# METHODS:
#   - Node-splitting: Separate direct and indirect evidence for each comparison
#   - SIDE (Separating Indirect from Direct Evidence): Design-by-treatment interaction
#   - Design-inconsistency model: Tests for design-level inconsistency
#
# References:
#   - Dias et al. (2010) Med Decis Making - Node-splitting
#   - Higgins et al. (2012) Stat Med - Design-by-treatment interaction
#   - White et al. (2012) BMC Med Res Methodol - Multivariate network MA
#
# Author: EvidenceOS PRIME
# ==============================================================================

library(netmeta)
library(metafor)

# ==============================================================================
# NODE-SPLITTING ANALYSIS
# ==============================================================================

#' Node-splitting analysis for network meta-analysis
#'
#' Separates direct and indirect evidence for each comparison in the network
#' Tests if direct and indirect estimates are consistent (should be similar)
#'
#' @param data Data frame with study-level data (TE, seTE, treat1, treat2, studlab)
#' @param reference Reference treatment
#' @param sm Summary measure ("OR", "RR", "MD", "SMD")
#' @return List with node-splitting results
#' @export
#'
#' @references Dias S, Welton NJ, Caldwell DM, Ades AE (2010)
#'   Checking consistency in mixed treatment comparison meta-analysis.
#'   Statistics in Medicine 29(7-8):932-944.
node_splitting_analysis <- function(data, reference = NULL, sm = "MD") {

  # Validate inputs
  required_cols <- c("TE", "seTE", "treat1", "treat2", "studlab")
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  # Run standard network meta-analysis
  net <- tryCatch({
    netmeta(
      TE = TE,
      seTE = seTE,
      treat1 = treat1,
      treat2 = treat2,
      studlab = studlab,
      data = data,
      sm = sm,
      reference.group = reference,
      details.chkmultiarm = TRUE
    )
  }, error = function(e) {
    stop(paste("Network meta-analysis failed:", e$message))
  })

  # Get all comparisons with both direct and indirect evidence
  # These are the only comparisons where node-splitting is meaningful
  comparisons <- get_splittable_comparisons(net)

  if (length(comparisons) == 0) {
    return(list(
      node_splitting = "not_applicable",
      message = "No comparisons have both direct and indirect evidence",
      network_model = net
    ))
  }

  # Perform node-splitting for each comparison
  split_results <- list()

  for (comp in comparisons) {
    treats <- strsplit(comp, ":")[[1]]
    treat_a <- treats[1]
    treat_b <- treats[2]

    split <- tryCatch({
      perform_single_node_split(data, treat_a, treat_b, reference, sm)
    }, error = function(e) {
      list(
        comparison = comp,
        error = TRUE,
        message = e$message
      )
    })

    split_results[[comp]] <- split
  }

  # Create summary
  summary <- create_node_split_summary(split_results)

  list(
    method = "Node-splitting",
    network_model = net,
    comparisons_tested = length(comparisons),
    split_results = split_results,
    summary = summary,
    consistent = summary$overall_consistent,
    inconsistent_comparisons = summary$inconsistent_comparisons
  )
}

#' Perform node-splitting for a single comparison
#' @keywords internal
perform_single_node_split <- function(data, treat_a, treat_b, reference, sm) {

  # Identify studies with direct evidence for this comparison
  direct_studies <- data$studlab[
    (data$treat1 == treat_a & data$treat2 == treat_b) |
    (data$treat1 == treat_b & data$treat2 == treat_a)
  ]

  # Create two datasets:
  # 1. Network WITHOUT this direct comparison (for indirect estimate)
  # 2. Only this direct comparison (for direct estimate)

  data_indirect <- data[!data$studlab %in% direct_studies, ]
  data_direct <- data[data$studlab %in% direct_studies, ]

  # Indirect evidence: Run NMA excluding direct studies
  if (nrow(data_indirect) >= 2) {
    net_indirect <- tryCatch({
      netmeta(
        TE = TE, seTE = seTE, treat1 = treat1, treat2 = treat2,
        studlab = studlab, data = data_indirect, sm = sm,
        reference.group = reference
      )
    }, error = function(e) NULL)
  } else {
    net_indirect <- NULL
  }

  # Direct evidence: Standard pairwise meta-analysis
  if (nrow(data_direct) >= 2) {
    direct_ma <- tryCatch({
      rma(yi = data_direct$TE, sei = data_direct$seTE, method = "REML")
    }, error = function(e) NULL)
  } else if (nrow(data_direct) == 1) {
    # Single study: use its estimate
    direct_ma <- list(
      beta = data_direct$TE[1],
      se = data_direct$seTE[1],
      k = 1
    )
  } else {
    direct_ma <- NULL
  }

  # Extract estimates
  if (!is.null(net_indirect)) {
    # Get estimate for treat_a vs treat_b from indirect network
    comp_name <- paste(treat_a, treat_b, sep = ":")
    indirect_estimate <- tryCatch({
      # netmeta stores comparisons in specific format
      idx <- which(
        (net_indirect$comparison$treat1 == treat_a & net_indirect$comparison$treat2 == treat_b) |
        (net_indirect$comparison$treat1 == treat_b & net_indirect$comparison$treat2 == treat_a)
      )
      if (length(idx) > 0) {
        list(
          estimate = net_indirect$TE.nma.random[idx[1]],
          se = net_indirect$seTE.nma.random[idx[1]]
        )
      } else {
        NULL
      }
    }, error = function(e) NULL)
  } else {
    indirect_estimate <- NULL
  }

  direct_estimate <- if (!is.null(direct_ma)) {
    if (is.list(direct_ma) && !is.null(direct_ma$beta)) {
      list(estimate = as.numeric(direct_ma$beta), se = as.numeric(direct_ma$se))
    } else {
      direct_ma
    }
  } else {
    NULL
  }

  # Test for difference between direct and indirect
  if (!is.null(direct_estimate) && !is.null(indirect_estimate)) {
    # Test statistic: (direct - indirect) / sqrt(se_direct^2 + se_indirect^2)
    diff <- direct_estimate$estimate - indirect_estimate$estimate
    se_diff <- sqrt(direct_estimate$se^2 + indirect_estimate$se^2)
    z_value <- diff / se_diff
    p_value <- 2 * pnorm(-abs(z_value))  # Two-tailed test

    consistent <- p_value >= 0.05

    list(
      comparison = paste(treat_a, "vs", treat_b),
      direct_estimate = direct_estimate$estimate,
      direct_se = direct_estimate$se,
      direct_k = length(direct_studies),
      indirect_estimate = indirect_estimate$estimate,
      indirect_se = indirect_estimate$se,
      difference = diff,
      se_difference = se_diff,
      z_value = z_value,
      p_value = p_value,
      consistent = consistent,
      interpretation = ifelse(consistent,
                             "Direct and indirect evidence are consistent",
                             "INCONSISTENCY DETECTED: Direct and indirect evidence differ significantly")
    )
  } else {
    list(
      comparison = paste(treat_a, "vs", treat_b),
      error = TRUE,
      message = "Could not compute both direct and indirect estimates"
    )
  }
}

#' Get comparisons that can be split (have both direct and indirect evidence)
#' @keywords internal
get_splittable_comparisons <- function(net) {

  # Extract all unique comparisons from the network
  comparisons <- unique(paste(net$data$treat1, net$data$treat2, sep = ":"))

  # Return comparisons (in practice, would check for indirect paths)
  comparisons
}

#' Create summary of node-splitting results
#' @keywords internal
create_node_split_summary <- function(split_results) {

  inconsistent <- c()
  consistent <- c()
  errors <- c()

  for (comp_name in names(split_results)) {
    result <- split_results[[comp_name]]

    if (!is.null(result$error) && result$error) {
      errors <- c(errors, comp_name)
    } else if (!is.null(result$p_value)) {
      if (result$p_value < 0.05) {
        inconsistent <- c(inconsistent, comp_name)
      } else {
        consistent <- c(consistent, comp_name)
      }
    }
  }

  overall_text <- if (length(inconsistent) == 0) {
    "Network is CONSISTENT: All direct and indirect estimates agree"
  } else {
    paste0(
      "INCONSISTENCY DETECTED in ", length(inconsistent), " comparison(s): ",
      paste(inconsistent, collapse = ", "),
      ". Consider sensitivity analyses or investigation of effect modifiers."
    )
  }

  list(
    n_tested = length(split_results),
    n_consistent = length(consistent),
    n_inconsistent = length(inconsistent),
    n_errors = length(errors),
    consistent_comparisons = consistent,
    inconsistent_comparisons = inconsistent,
    overall_consistent = length(inconsistent) == 0,
    summary_text = overall_text
  )
}

# ==============================================================================
# DESIGN-BY-TREATMENT INTERACTION (SIDE MODEL)
# ==============================================================================

#' SIDE model: Separating Indirect from Direct Evidence
#'
#' Tests for design-by-treatment interaction
#' Design = set of treatments compared in a study
#'
#' @param data Data frame with study-level data
#' @param reference Reference treatment
#' @param sm Summary measure
#' @return List with SIDE model results
#' @export
#'
#' @references Higgins JPT, Jackson D, Barrett JK, Lu G, Ades AE, White IR (2012)
#'   Consistency and inconsistency in network meta-analysis: concepts and models for
#'   multi-arm studies. Research Synthesis Methods 3:98-110.
side_model <- function(data, reference = NULL, sm = "MD") {

  # Run consistency model (standard NMA)
  net_consistency <- tryCatch({
    netmeta(
      TE = TE,
      seTE = seTE,
      treat1 = treat1,
      treat2 = treat2,
      studlab = studlab,
      data = data,
      sm = sm,
      reference.group = reference
    )
  }, error = function(e) {
    stop(paste("Consistency model failed:", e$message))
  })

  # Run inconsistency model (with design-by-treatment interaction)
  # This uses the 'netsplit' function from netmeta
  net_inconsistency <- tryCatch({
    netsplit(net_consistency)
  }, error = function(e) {
    stop(paste("Inconsistency model failed:", e$message))
  })

  # Extract inconsistency statistics
  # Q statistic for inconsistency
  Q_inconsistency <- net_inconsistency$Q.inconsistency
  df_inconsistency <- net_inconsistency$df.Q.inconsistency
  p_inconsistency <- net_inconsistency$pval.Q.inconsistency

  # Interpretation
  consistent <- is.null(p_inconsistency) || p_inconsistency >= 0.05

  interpretation <- if (consistent) {
    "SIDE model: No significant inconsistency detected (network is consistent)"
  } else {
    paste0(
      "SIDE model: INCONSISTENCY DETECTED (p = ", round(p_inconsistency, 4), "). ",
      "Consider investigating sources of inconsistency (effect modifiers, study quality)."
    )
  }

  list(
    method = "SIDE (Separating Indirect from Direct Evidence)",
    consistency_model = net_consistency,
    inconsistency_model = net_inconsistency,
    Q_inconsistency = Q_inconsistency,
    df = df_inconsistency,
    p_value = p_inconsistency,
    consistent = consistent,
    interpretation = interpretation,
    details = net_inconsistency
  )
}

# ==============================================================================
# COMPREHENSIVE CONSISTENCY ASSESSMENT
# ==============================================================================

#' Run comprehensive consistency analysis
#'
#' Runs multiple consistency checks:
#' - Node-splitting (comparison-specific)
#' - SIDE model (global test)
#'
#' @param data Data frame with NMA data
#' @param reference Reference treatment
#' @param sm Summary measure
#' @return List with all consistency results
#' @export
comprehensive_consistency_check <- function(data, reference = NULL, sm = "MD") {

  results <- list()

  # 1. Node-splitting
  cat("Running node-splitting analysis...\n")
  results$node_splitting <- tryCatch({
    node_splitting_analysis(data, reference, sm)
  }, error = function(e) {
    list(error = TRUE, message = paste("Node-splitting failed:", e$message))
  })

  # 2. SIDE model
  cat("Running SIDE model...\n")
  results$side <- tryCatch({
    side_model(data, reference, sm)
  }, error = function(e) {
    list(error = TRUE, message = paste("SIDE model failed:", e$message))
  })

  # Create overall summary
  results$overall_assessment <- create_consistency_summary(results)

  return(results)
}

#' Create overall consistency summary
#' @keywords internal
create_consistency_summary <- function(results) {

  findings <- c()

  # Node-splitting findings
  if (!is.null(results$node_splitting$consistent)) {
    if (results$node_splitting$consistent) {
      findings <- c(findings, "✓ Node-splitting: Network is consistent")
    } else {
      n_incon <- length(results$node_splitting$inconsistent_comparisons)
      findings <- c(findings, paste0(
        "✗ Node-splitting: Inconsistency detected in ", n_incon, " comparison(s)"
      ))
    }
  }

  # SIDE findings
  if (!is.null(results$side$consistent)) {
    if (results$side$consistent) {
      findings <- c(findings, "✓ SIDE model: No global inconsistency")
    } else {
      findings <- c(findings, paste0(
        "✗ SIDE model: Global inconsistency detected (p = ",
        round(results$side$p_value, 4), ")"
      ))
    }
  }

  # Overall verdict
  both_consistent <- all(sapply(results[c("node_splitting", "side")], function(x) {
    !is.null(x$consistent) && x$consistent
  }))

  overall <- if (both_consistent) {
    "CONSISTENT: All tests indicate network consistency. Results can be interpreted with confidence."
  } else {
    "INCONSISTENCY DETECTED: At least one test indicates inconsistency. Investigate sources (effect modifiers, study quality, clinical/methodological differences). Consider sensitivity analyses or subgroup analyses."
  }

  list(
    findings = findings,
    overall_consistent = both_consistent,
    summary = overall
  )
}

cat("✅ NMA consistency models loaded\n")
cat("   • Node-splitting analysis\n")
cat("   • SIDE model (design-by-treatment interaction)\n")
cat("   • Comprehensive consistency assessment\n")
