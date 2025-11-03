# ============================================================================
# Bayesian NMA - Data Preparation Module
# ============================================================================
# Converts netmeta objects and network data to brms-compatible format
# Reference: Dias et al. (2013), brms NMA vignette
# ============================================================================

library(netmeta)
library(dplyr)
library(tidyr)

#' Prepare NMA Data for brms
#'
#' Converts netmeta object or pairwise comparison data to long format
#' suitable for brms Bayesian meta-analysis
#'
#' @param nma_obj netmeta object or pairwise data frame
#' @param format "contrast" (default) or "arm" level data
#' @return data.frame with columns: study, treat1, treat2, TE, seTE, n1, n2
#' @export
prepare_nma_data_for_brms <- function(nma_obj, format = "contrast") {

  if (inherits(nma_obj, "netmeta")) {
    # Extract pairwise comparisons from netmeta object
    data <- data.frame(
      study = nma_obj$studlab,
      treat1 = nma_obj$treat1,
      treat2 = nma_obj$treat2,
      TE = nma_obj$TE,
      seTE = nma_obj$seTE,
      n1 = nma_obj$n1,
      n2 = nma_obj$n2,
      stringsAsFactors = FALSE
    )

  } else if (is.data.frame(nma_obj)) {
    # Assume already in correct format, validate structure
    required_cols <- c("study", "treat1", "treat2", "TE", "seTE")
    if (!all(required_cols %in% names(nma_obj))) {
      stop("Data frame must contain columns: ", paste(required_cols, collapse = ", "))
    }
    data <- nma_obj

  } else {
    stop("Input must be netmeta object or data.frame")
  }

  # Create treatment numeric IDs for brms
  all_treatments <- unique(c(data$treat1, data$treat2))
  treat_map <- data.frame(
    treatment = all_treatments,
    treat_id = seq_along(all_treatments),
    stringsAsFactors = FALSE
  )

  data <- data %>%
    left_join(treat_map, by = c("treat1" = "treatment")) %>%
    rename(treat1_id = treat_id) %>%
    left_join(treat_map, by = c("treat2" = "treatment")) %>%
    rename(treat2_id = treat_id)

  # Add reference treatment indicator (treat1 is always reference in each comparison)
  data$is_baseline <- data$treat1_id < data$treat2_id

  # Create contrast variable (always positive)
  data$contrast <- ifelse(data$is_baseline, data$TE, -data$TE)

  # Store treatment mapping as attribute
  attr(data, "treatment_map") <- treat_map

  return(data)
}


#' Create Network Connectivity Matrix
#'
#' Builds adjacency matrix showing which treatments are directly compared
#'
#' @param brms_data Data prepared by prepare_nma_data_for_brms
#' @return Matrix with treatments as rows/columns, values = number of direct comparisons
#' @export
create_connectivity_matrix <- function(brms_data) {

  treat_map <- attr(brms_data, "treatment_map")
  n_treat <- nrow(treat_map)

  conn_matrix <- matrix(0, nrow = n_treat, ncol = n_treat)
  rownames(conn_matrix) <- colnames(conn_matrix) <- treat_map$treatment

  for (i in 1:nrow(brms_data)) {
    t1 <- brms_data$treat1_id[i]
    t2 <- brms_data$treat2_id[i]
    conn_matrix[t1, t2] <- conn_matrix[t1, t2] + 1
    conn_matrix[t2, t1] <- conn_matrix[t2, t1] + 1
  }

  return(conn_matrix)
}


#' Validate Network Connectivity
#'
#' Checks if network is connected (all treatments can be compared indirectly)
#'
#' @param connectivity_matrix Matrix from create_connectivity_matrix
#' @return List with is_connected (logical) and disconnected_treatments (vector)
#' @export
validate_network_connectivity <- function(connectivity_matrix) {

  # Use graph theory to check connectivity
  library(igraph)

  # Convert to graph
  g <- graph_from_adjacency_matrix(connectivity_matrix, mode = "undirected", weighted = TRUE)

  # Check if connected
  is_connected <- is_connected(g)

  if (!is_connected) {
    # Identify components
    components <- components(g)
    disconnected <- names(which(components$membership != 1))
  } else {
    disconnected <- character(0)
  }

  list(
    is_connected = is_connected,
    n_components = components(g)$no,
    disconnected_treatments = disconnected
  )
}


#' Convert to ARM-based format (for binomial/count data)
#'
#' Converts contrast-based data to arm-based format for count outcomes
#'
#' @param brms_data Data from prepare_nma_data_for_brms
#' @param outcome_type "binomial", "poisson", or "normal"
#' @return Long format data with one row per study arm
#' @export
convert_to_arm_based <- function(brms_data, outcome_type = "normal") {

  if (outcome_type == "normal") {
    warning("ARM-based format not typically used for continuous outcomes. Consider contrast-based.")
  }

  # Expand to arm level
  arm1 <- brms_data %>%
    select(study, treatment = treat1, treat_id = treat1_id,
           events = n1, TE_arm = TE) %>%
    mutate(arm = 1)

  arm2 <- brms_data %>%
    select(study, treatment = treat2, treat_id = treat2_id,
           events = n2, TE_arm = TE) %>%
    mutate(arm = 2)

  arm_data <- bind_rows(arm1, arm2) %>%
    arrange(study, arm)

  attr(arm_data, "treatment_map") <- attr(brms_data, "treatment_map")
  attr(arm_data, "outcome_type") <- outcome_type

  return(arm_data)
}


#' Create Design Matrix for Multi-Arm Trials
#'
#' Handles trials with >2 arms by creating appropriate contrast matrix
#'
#' @param brms_data Data with potential multi-arm trials
#' @return List with contrast_data and design_matrix
#' @export
handle_multi_arm_trials <- function(brms_data) {

  # Identify multi-arm trials
  arms_per_study <- brms_data %>%
    group_by(study) %>%
    summarise(
      n_comparisons = n(),
      n_arms = length(unique(c(treat1, treat2)))
    )

  multi_arm <- arms_per_study %>%
    filter(n_arms > 2)

  if (nrow(multi_arm) == 0) {
    return(list(
      has_multi_arm = FALSE,
      data = brms_data,
      design_matrix = NULL
    ))
  }

  # TODO: Implement proper multi-arm trial handling
  # This requires creating a design matrix that accounts for
  # within-study correlation structure
  # Reference: Dias et al. (2013) Section 5.4

  warning("Multi-arm trials detected. Advanced handling not yet implemented.")
  warning("Consider using gemtc or netmeta packages for multi-arm NMA")

  list(
    has_multi_arm = TRUE,
    n_multi_arm = nrow(multi_arm),
    multi_arm_studies = multi_arm$study,
    data = brms_data,
    design_matrix = NULL
  )
}


#' Prepare Data for Inconsistency Model
#'
#' Creates node-splitting or design-inconsistency setup
#'
#' @param brms_data Network data
#' @param method "node_split" or "design_inconsistency"
#' @return Modified data with inconsistency parameters
#' @export
prepare_inconsistency_data <- function(brms_data, method = "node_split") {

  if (method == "node_split") {
    # Identify indirect and direct evidence for each comparison

    # TODO: Implement node-splitting data preparation
    # For each treatment comparison A-B:
    # 1. Separate direct evidence (studies with A vs B)
    # 2. Estimate indirect evidence (via network)
    # 3. Test for difference (inconsistency)

    stop("Node-splitting not yet implemented. Use netsplit() from netmeta package.")

  } else if (method == "design_inconsistency") {
    # Design-by-treatment interaction approach

    # TODO: Add design variables to data
    # Reference: Higgins et al. (2012) design-by-treatment interaction

    stop("Design inconsistency not yet implemented.")
  }
}
