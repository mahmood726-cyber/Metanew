# Network Meta-Analysis Inconsistency Detection
# Implements node-splitting and design-by-treatment interaction tests
# Following NICE DSU TSD 4 guidance

library(netmeta)
library(meta)

#' Node-Splitting Analysis for NMA Inconsistency
#'
#' Implements node-splitting to detect inconsistency between direct and
#' indirect evidence for specific treatment comparisons
#'
#' @param data Data frame with columns: studyid, treatment1, treatment2, TE, seTE
#' @param comparison Character vector of length 2 specifying comparison to split
#' @param reference Reference treatment
#' @param sm Summary measure ("OR", "RR", "MD", etc.)
#' @return List with node-splitting results
#'
#' @details
#' Node-splitting methodology:
#' 1. Fit full network meta-analysis (consistency model)
#' 2. Remove direct evidence for target comparison
#' 3. Estimate indirect evidence from network
#' 4. Compare direct vs indirect estimates
#' 5. Test for inconsistency (difference between direct and indirect)
#'
#' References:
#' - Dias et al. (2010) NICE DSU TSD 4
#' - van Valkenhoef et al. (2016) Research Synthesis Methods
#'
#' @export
node_splitting <- function(data,
                          comparison,
                          reference = NULL,
                          sm = "OR") {

  # Input validation
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }

  required_cols <- c("studyid", "treatment1", "treatment2", "TE", "seTE")
  if (!all(required_cols %in% names(data))) {
    stop(paste("data must contain columns:", paste(required_cols, collapse = ", ")))
  }

  if (length(comparison) != 2) {
    stop("comparison must specify exactly 2 treatments")
  }

  # Fit full network (consistency model)
  net_full <- netmeta(
    TE = TE,
    seTE = seTE,
    treat1 = treatment1,
    treat2 = treatment2,
    studlab = studyid,
    data = data,
    reference = reference,
    sm = sm,
    comb.fixed = FALSE,
    comb.random = TRUE
  )

  # Identify studies with direct evidence for comparison
  treat1 <- comparison[1]
  treat2 <- comparison[2]

  direct_studies <- data$studyid[
    (data$treatment1 == treat1 & data$treatment2 == treat2) |
      (data$treatment1 == treat2 & data$treatment2 == treat1)
  ]

  n_direct <- length(unique(direct_studies))

  if (n_direct == 0) {
    warning("No direct evidence found for specified comparison")
    return(list(
      comparison = comparison,
      n_direct_studies = 0,
      direct_estimate = NA,
      indirect_estimate = NA,
      difference = NA,
      p_inconsistency = NA,
      conclusion = "No direct evidence available"
    ))
  }

  # Meta-analysis of direct evidence only
  direct_data <- data[data$studyid %in% direct_studies, ]

  # Ensure correct direction
  direct_data$TE_adj <- ifelse(
    direct_data$treatment1 == treat1,
    direct_data$TE,
    -direct_data$TE
  )

  ma_direct <- meta::metagen(
    TE = TE_adj,
    seTE = seTE,
    studlab = studyid,
    data = direct_data,
    sm = sm,
    comb.fixed = FALSE,
    comb.random = TRUE
  )

  direct_estimate <- ma_direct$TE.random
  direct_se <- ma_direct$seTE.random

  # Fit network excluding direct evidence (for indirect estimate)
  data_indirect <- data[!(data$studyid %in% direct_studies), ]

  if (nrow(data_indirect) < 2) {
    warning("Insufficient data for indirect estimate")
    return(list(
      comparison = comparison,
      n_direct_studies = n_direct,
      direct_estimate = direct_estimate,
      direct_se = direct_se,
      indirect_estimate = NA,
      difference = NA,
      p_inconsistency = NA,
      conclusion = "Insufficient data for indirect evidence"
    ))
  }

  net_indirect <- tryCatch({
    netmeta(
      TE = TE,
      seTE = seTE,
      treat1 = treatment1,
      treat2 = treatment2,
      studlab = studyid,
      data = data_indirect,
      reference = reference,
      sm = sm,
      comb.fixed = FALSE,
      comb.random = TRUE
    )
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(net_indirect)) {
    return(list(
      comparison = comparison,
      n_direct_studies = n_direct,
      direct_estimate = direct_estimate,
      direct_se = direct_se,
      indirect_estimate = NA,
      difference = NA,
      p_inconsistency = NA,
      conclusion = "Network meta-analysis of indirect evidence failed"
    ))
  }

  # Extract indirect estimate for comparison
  comp_name <- paste(treat1, treat2, sep = ":")

  if (comp_name %in% rownames(net_indirect$TE.random)) {
    indirect_estimate <- net_indirect$TE.random[comp_name, treat2]
    indirect_se <- net_indirect$seTE.random[comp_name, treat2]
  } else {
    # Try reverse comparison
    comp_name_rev <- paste(treat2, treat1, sep = ":")
    if (comp_name_rev %in% rownames(net_indirect$TE.random)) {
      indirect_estimate <- -net_indirect$TE.random[comp_name_rev, treat1]
      indirect_se <- net_indirect$seTE.random[comp_name_rev, treat1]
    } else {
      return(list(
        comparison = comparison,
        n_direct_studies = n_direct,
        direct_estimate = direct_estimate,
        indirect_estimate = NA,
        difference = NA,
        p_inconsistency = NA,
        conclusion = "Comparison not found in indirect network"
      ))
    }
  }

  # Calculate inconsistency
  difference <- direct_estimate - indirect_estimate
  se_difference <- sqrt(direct_se^2 + indirect_se^2)
  z_statistic <- difference / se_difference
  p_inconsistency <- 2 * pnorm(-abs(z_statistic))

  # Interpretation
  conclusion <- if (p_inconsistency < 0.05) {
    "Significant inconsistency detected (p < 0.05)"
  } else if (p_inconsistency < 0.10) {
    "Borderline inconsistency (0.05 ≤ p < 0.10)"
  } else {
    "No significant inconsistency detected (p ≥ 0.10)"
  }

  # Return results
  results <- list(
    comparison = comparison,
    n_direct_studies = n_direct,
    n_indirect_comparisons = nrow(data_indirect),
    direct_estimate = direct_estimate,
    direct_se = direct_se,
    direct_ci_lower = direct_estimate - 1.96 * direct_se,
    direct_ci_upper = direct_estimate + 1.96 * direct_se,
    indirect_estimate = indirect_estimate,
    indirect_se = indirect_se,
    indirect_ci_lower = indirect_estimate - 1.96 * indirect_se,
    indirect_ci_upper = indirect_estimate + 1.96 * indirect_se,
    difference = difference,
    se_difference = se_difference,
    z_statistic = z_statistic,
    p_inconsistency = p_inconsistency,
    conclusion = conclusion,
    network_full = net_full,
    network_indirect = net_indirect,
    meta_direct = ma_direct
  )

  class(results) <- "nodesplit"
  return(results)
}


#' Automated Node-Splitting for All Comparisons
#'
#' Performs node-splitting analysis for all comparisons with direct evidence
#'
#' @param data Data frame with network meta-analysis data
#' @param reference Reference treatment
#' @param sm Summary measure
#' @return Data frame with node-splitting results for all comparisons
#'
#' @export
node_splitting_all <- function(data,
                               reference = NULL,
                               sm = "OR") {

  # Identify all unique comparisons with direct evidence
  comparisons <- unique(rbind(
    data.frame(t1 = data$treatment1, t2 = data$treatment2),
    data.frame(t1 = data$treatment2, t2 = data$treatment1)
  ))

  comparisons <- comparisons[comparisons$t1 != comparisons$t2, ]

  # Remove duplicates (A-B is same as B-A)
  comparisons <- comparisons[!duplicated(t(apply(comparisons, 1, sort))), ]

  results_list <- list()

  for (i in seq_len(nrow(comparisons))) {
    comp <- c(as.character(comparisons$t1[i]), as.character(comparisons$t2[i]))

    result <- tryCatch({
      node_splitting(data, comparison = comp, reference = reference, sm = sm)
    }, error = function(e) {
      list(
        comparison = comp,
        error = as.character(e),
        conclusion = "Analysis failed"
      )
    })

    results_list[[i]] <- result
  }

  # Compile into summary data frame
  summary_df <- do.call(rbind, lapply(results_list, function(r) {
    data.frame(
      comparison = paste(r$comparison, collapse = " vs "),
      n_direct_studies = ifelse(is.null(r$n_direct_studies), NA, r$n_direct_studies),
      direct_estimate = ifelse(is.null(r$direct_estimate), NA, r$direct_estimate),
      indirect_estimate = ifelse(is.null(r$indirect_estimate), NA, r$indirect_estimate),
      difference = ifelse(is.null(r$difference), NA, r$difference),
      p_value = ifelse(is.null(r$p_inconsistency), NA, r$p_inconsistency),
      significant = ifelse(is.null(r$p_inconsistency), NA, r$p_inconsistency < 0.05),
      conclusion = r$conclusion,
      stringsAsFactors = FALSE
    )
  }))

  # Sort by p-value (most inconsistent first)
  summary_df <- summary_df[order(summary_df$p_value), ]

  attr(summary_df, "full_results") <- results_list

  return(summary_df)
}


#' Design-by-Treatment Interaction Test
#'
#' Tests for inconsistency using design-by-treatment interaction model
#'
#' @param data Data frame with network data
#' @param reference Reference treatment
#' @param sm Summary measure
#' @return List with interaction test results
#'
#' @details
#' The design-by-treatment interaction model extends the consistency model
#' to include interaction terms between study design and treatment effects.
#' Significant interaction indicates inconsistency.
#'
#' @export
design_by_treatment_test <- function(data,
                                     reference = NULL,
                                     sm = "OR") {

  # This requires the netmeta package's netsplit function
  # which implements the design-by-treatment interaction model

  net <- netmeta(
    TE = TE,
    seTE = seTE,
    treat1 = treatment1,
    treat2 = treatment2,
    studlab = studyid,
    data = data,
    reference = reference,
    sm = sm
  )

  # Use netsplit to perform design-by-treatment interaction test
  split_result <- tryCatch({
    netsplit(net)
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(split_result)) {
    return(list(
      conclusion = "Design-by-treatment interaction test failed",
      p_value = NA
    ))
  }

  # Extract global inconsistency p-value
  global_p <- if (!is.null(split_result$Q.inconsistency)) {
    split_result$Q.inconsistency$pval
  } else {
    NA
  }

  conclusion <- if (is.na(global_p)) {
    "Unable to assess inconsistency"
  } else if (global_p < 0.05) {
    "Significant inconsistency detected (p < 0.05)"
  } else {
    "No significant inconsistency detected (p ≥ 0.05)"
  }

  return(list(
    split_result = split_result,
    global_p_value = global_p,
    conclusion = conclusion
  ))
}


#' Print Method for Node-Split Results
#'
#' @param x Node-split results object
#' @param ... Additional arguments
#' @export
print.nodesplit <- function(x, ...) {
  cat("\nNode-Splitting Analysis\n")
  cat("=======================\n\n")
  cat("Comparison:", paste(x$comparison, collapse = " vs "), "\n")
  cat("Direct studies:", x$n_direct_studies, "\n\n")

  cat("Direct estimate:", round(x$direct_estimate, 3),
      "(95% CI:", round(x$direct_ci_lower, 3), "to",
      round(x$direct_ci_upper, 3), ")\n")

  cat("Indirect estimate:", round(x$indirect_estimate, 3),
      "(95% CI:", round(x$indirect_ci_lower, 3), "to",
      round(x$indirect_ci_upper, 3), ")\n\n")

  cat("Difference:", round(x$difference, 3), "(SE:", round(x$se_difference, 3), ")\n")
  cat("Z-statistic:", round(x$z_statistic, 3), "\n")
  cat("P-value:", format.pval(x$p_inconsistency, digits = 3), "\n\n")

  cat("Conclusion:", x$conclusion, "\n")

  invisible(x)
}
