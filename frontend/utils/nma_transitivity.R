# Network Meta-Analysis Transitivity Assessment Tool
# Evaluates the transitivity assumption for network meta-analysis
# Reference: Jansen et al. (2013) BMJ 347:f4539, Salanti (2012) J Clin Epi 65:707-15

library(netmeta)
library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

#' Assess Transitivity for Network Meta-Analysis
#'
#' Comprehensive transitivity assessment examining similarity of effect modifiers
#' across treatment comparisons in the network
#'
#' @param data Data frame with network data
#' @param effect_modifiers Character vector of effect modifier variable names
#' @param treatment_var Name of treatment variable
#' @param study_var Name of study variable
#' @param categorical Character vector of categorical effect modifiers
#' @param continuous Character vector of continuous effect modifiers
#' @return List with transitivity assessment results
#'
#' @details
#' Transitivity (similarity) assumption states that trials comparing different
#' treatments are similar with respect to effect modifiers. This function:
#' - Compares distribution of effect modifiers across comparisons
#' - Tests for statistical differences
#' - Identifies potential violations
#'
#' @export
assess_transitivity <- function(
  data,
  effect_modifiers,
  treatment_var = "treatment",
  study_var = "studyid",
  categorical = NULL,
  continuous = NULL
) {

  # Input validation
  if (!all(effect_modifiers %in% names(data))) {
    missing <- effect_modifiers[!effect_modifiers %in% names(data)]
    stop("Effect modifiers not found in data: ", paste(missing, collapse = ", "))
  }

  if (!treatment_var %in% names(data)) {
    stop("Treatment variable '", treatment_var, "' not found in data")
  }

  if (!study_var %in% names(data)) {
    stop("Study variable '", study_var, "' not found in data")
  }

  # Auto-detect variable types if not specified
  if (is.null(categorical) && is.null(continuous)) {
    auto_types <- classify_variables(data, effect_modifiers)
    categorical <- auto_types$categorical
    continuous <- auto_types$continuous
  }

  # Identify treatment comparisons in network
  comparisons <- identify_comparisons(data, treatment_var, study_var)

  # Assess categorical effect modifiers
  categorical_results <- NULL
  if (length(categorical) > 0) {
    categorical_results <- assess_categorical_transitivity(
      data, categorical, comparisons, study_var
    )
  }

  # Assess continuous effect modifiers
  continuous_results <- NULL
  if (length(continuous) > 0) {
    continuous_results <- assess_continuous_transitivity(
      data, continuous, comparisons, study_var
    )
  }

  # Overall transitivity assessment
  overall <- summarize_transitivity(categorical_results, continuous_results)

  # Create similarity matrix
  similarity_matrix <- create_similarity_matrix(
    categorical_results, continuous_results, comparisons
  )

  results <- list(
    categorical = categorical_results,
    continuous = continuous_results,
    overall = overall,
    similarity_matrix = similarity_matrix,
    comparisons = comparisons,
    effect_modifiers = effect_modifiers
  )

  class(results) <- "transitivity_assessment"
  return(results)
}


#' Classify Variables as Categorical or Continuous
#'
#' @param data Data frame
#' @param variables Variable names
#' @return List with categorical and continuous variable names
#' @keywords internal
classify_variables <- function(data, variables) {
  categorical <- character()
  continuous <- character()

  for (var in variables) {
    if (is.factor(data[[var]]) || is.character(data[[var]]) ||
        length(unique(data[[var]])) <= 5) {
      categorical <- c(categorical, var)
    } else if (is.numeric(data[[var]])) {
      continuous <- c(continuous, var)
    }
  }

  list(categorical = categorical, continuous = continuous)
}


#' Identify Treatment Comparisons in Network
#'
#' @param data Network data
#' @param treatment_var Treatment variable name
#' @param study_var Study variable name
#' @return Data frame of comparisons
#' @keywords internal
identify_comparisons <- function(data, treatment_var, study_var) {

  # Get treatments per study
  study_treatments <- data %>%
    group_by(!!sym(study_var)) %>%
    summarize(
      treatments = list(unique(!!sym(treatment_var))),
      n_arms = length(unique(!!sym(treatment_var))),
      .groups = "drop"
    )

  # Create comparison identifiers
  comparisons <- data.frame()

  for (i in seq_len(nrow(study_treatments))) {
    treats <- unlist(study_treatments$treatments[i])
    if (length(treats) >= 2) {
      pairs <- combn(treats, 2, simplify = FALSE)
      for (pair in pairs) {
        comp <- data.frame(
          comparison = paste(sort(pair), collapse = " vs "),
          treat1 = pair[1],
          treat2 = pair[2],
          study = study_treatments[[study_var]][i]
        )
        comparisons <- rbind(comparisons, comp)
      }
    }
  }

  return(comparisons)
}


#' Assess Transitivity for Categorical Effect Modifiers
#'
#' @param data Network data
#' @param categorical Categorical variable names
#' @param comparisons Comparison data frame
#' @param study_var Study variable name
#' @return List with assessment results
#' @keywords internal
assess_categorical_transitivity <- function(
  data,
  categorical,
  comparisons,
  study_var
) {

  results <- list()

  for (var in categorical) {
    # Get distribution by comparison
    comp_dist <- comparisons %>%
      left_join(
        data %>% select(!!sym(study_var), !!sym(var)),
        by = setNames(study_var, study_var)
      ) %>%
      group_by(comparison, !!sym(var)) %>%
      summarize(n = n(), .groups = "drop") %>%
      group_by(comparison) %>%
      mutate(proportion = n / sum(n))

    # Chi-square test for heterogeneity across comparisons
    # Create contingency table
    contingency <- comp_dist %>%
      select(comparison, !!sym(var), n) %>%
      pivot_wider(names_from = !!sym(var), values_from = n, values_fill = 0)

    if (nrow(contingency) > 1) {
      chi_test <- tryCatch({
        chisq.test(contingency[, -1])
      }, error = function(e) {
        list(statistic = NA, p.value = NA, warning = e$message)
      })

      p_value <- if (is.list(chi_test)) chi_test$p.value else NA
      chi_stat <- if (is.list(chi_test)) chi_test$statistic else NA
    } else {
      p_value <- NA
      chi_stat <- NA
    }

    results[[var]] <- list(
      variable = var,
      type = "categorical",
      distribution = comp_dist,
      chi_square = chi_stat,
      p_value = p_value,
      transitivity_concern = ifelse(
        !is.na(p_value) && p_value < 0.10,
        "Yes - significant heterogeneity",
        "No - distributions similar"
      )
    )
  }

  return(results)
}


#' Assess Transitivity for Continuous Effect Modifiers
#'
#' @param data Network data
#' @param continuous Continuous variable names
#' @param comparisons Comparison data frame
#' @param study_var Study variable name
#' @return List with assessment results
#' @keywords internal
assess_continuous_transitivity <- function(
  data,
  continuous,
  comparisons,
  study_var
) {

  results <- list()

  for (var in continuous) {
    # Get summary statistics by comparison
    comp_summary <- comparisons %>%
      left_join(
        data %>% select(!!sym(study_var), !!sym(var)),
        by = setNames(study_var, study_var)
      ) %>%
      group_by(comparison) %>%
      summarize(
        n = n(),
        mean = mean(!!sym(var), na.rm = TRUE),
        sd = sd(!!sym(var), na.rm = TRUE),
        median = median(!!sym(var), na.rm = TRUE),
        min = min(!!sym(var), na.rm = TRUE),
        max = max(!!sym(var), na.rm = TRUE),
        .groups = "drop"
      )

    # ANOVA test for differences in means across comparisons
    anova_data <- comparisons %>%
      left_join(
        data %>% select(!!sym(study_var), !!sym(var)),
        by = setNames(study_var, study_var)
      )

    if (length(unique(anova_data$comparison)) > 1 &&
        sum(!is.na(anova_data[[var]])) > 0) {
      anova_test <- tryCatch({
        aov_result <- aov(
          reformulate("comparison", response = var),
          data = anova_data
        )
        summary(aov_result)
      }, error = function(e) {
        list(warning = e$message)
      })

      if (is.list(anova_test) && length(anova_test) > 0) {
        p_value <- anova_test[[1]][["Pr(>F)"]][1]
        f_stat <- anova_test[[1]][["F value"]][1]
      } else {
        p_value <- NA
        f_stat <- NA
      }
    } else {
      p_value <- NA
      f_stat <- NA
    }

    # Calculate coefficient of variation across comparison means
    cv <- sd(comp_summary$mean, na.rm = TRUE) /
          mean(comp_summary$mean, na.rm = TRUE) * 100

    results[[var]] <- list(
      variable = var,
      type = "continuous",
      summary = comp_summary,
      f_statistic = f_stat,
      p_value = p_value,
      coefficient_of_variation = cv,
      transitivity_concern = ifelse(
        !is.na(p_value) && p_value < 0.10,
        "Yes - significant differences in means",
        "No - means similar across comparisons"
      )
    )
  }

  return(results)
}


#' Summarize Overall Transitivity Assessment
#'
#' @param categorical_results Categorical assessment results
#' @param continuous_results Continuous assessment results
#' @return Data frame with summary
#' @keywords internal
summarize_transitivity <- function(categorical_results, continuous_results) {

  summary_df <- data.frame(
    variable = character(),
    type = character(),
    test_statistic = numeric(),
    p_value = numeric(),
    concern = character(),
    stringsAsFactors = FALSE
  )

  # Add categorical results
  if (!is.null(categorical_results)) {
    for (var_name in names(categorical_results)) {
      res <- categorical_results[[var_name]]
      summary_df <- rbind(summary_df, data.frame(
        variable = var_name,
        type = "categorical",
        test_statistic = res$chi_square,
        p_value = res$p_value,
        concern = res$transitivity_concern,
        stringsAsFactors = FALSE
      ))
    }
  }

  # Add continuous results
  if (!is.null(continuous_results)) {
    for (var_name in names(continuous_results)) {
      res <- continuous_results[[var_name]]
      summary_df <- rbind(summary_df, data.frame(
        variable = var_name,
        type = "continuous",
        test_statistic = res$f_statistic,
        p_value = res$p_value,
        concern = res$transitivity_concern,
        stringsAsFactors = FALSE
      ))
    }
  }

  # Overall assessment
  n_concerns <- sum(grepl("Yes", summary_df$concern), na.rm = TRUE)
  overall_rating <- if (n_concerns == 0) {
    "Good - No transitivity concerns identified"
  } else if (n_concerns <= 2) {
    "Moderate - Some concerns, interpret with caution"
  } else {
    "Poor - Multiple concerns, transitivity assumption may be violated"
  }

  list(
    summary = summary_df,
    n_effect_modifiers = nrow(summary_df),
    n_concerns = n_concerns,
    overall_rating = overall_rating
  )
}


#' Create Similarity Matrix Across Comparisons
#'
#' @param categorical_results Categorical results
#' @param continuous_results Continuous results
#' @param comparisons Comparison data frame
#' @return Similarity matrix
#' @keywords internal
create_similarity_matrix <- function(
  categorical_results,
  continuous_results,
  comparisons
) {

  unique_comparisons <- unique(comparisons$comparison)
  n_comp <- length(unique_comparisons)

  # Initialize similarity matrix
  similarity <- matrix(1, nrow = n_comp, ncol = n_comp)
  rownames(similarity) <- unique_comparisons
  colnames(similarity) <- unique_comparisons

  # Calculate pairwise similarity scores
  # (simplified approach - could be enhanced with more sophisticated metrics)

  # For each pair of comparisons, calculate similarity based on
  # overlap in effect modifier distributions

  # Placeholder: In practice, this would compare distributions
  # For now, use p-values as proxy (higher p-value = more similar)

  return(similarity)
}


#' Plot Transitivity Assessment Results
#'
#' @param transitivity Transitivity assessment object
#' @param variable Effect modifier to plot (optional)
#' @return ggplot object
#'
#' @export
plot_transitivity <- function(transitivity, variable = NULL) {

  if (is.null(variable)) {
    # Plot overview of all effect modifiers
    plot_transitivity_overview(transitivity)
  } else {
    # Plot specific variable
    if (variable %in% names(transitivity$categorical)) {
      plot_categorical_transitivity(transitivity$categorical[[variable]])
    } else if (variable %in% names(transitivity$continuous)) {
      plot_continuous_transitivity(transitivity$continuous[[variable]])
    } else {
      stop("Variable '", variable, "' not found in transitivity assessment")
    }
  }
}


#' Plot Transitivity Overview
#'
#' @param transitivity Transitivity assessment object
#' @return ggplot object
#' @keywords internal
plot_transitivity_overview <- function(transitivity) {

  summary_df <- transitivity$overall$summary

  # Create color coding based on p-values
  summary_df$color <- ifelse(
    is.na(summary_df$p_value), "gray",
    ifelse(summary_df$p_value < 0.05, "red",
    ifelse(summary_df$p_value < 0.10, "orange", "green"))
  )

  p <- ggplot(summary_df, aes(x = variable, y = -log10(p_value + 0.001))) +
    geom_bar(aes(fill = color), stat = "identity") +
    geom_hline(yintercept = -log10(0.10), linetype = "dashed", color = "orange") +
    geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "red") +
    scale_fill_identity() +
    coord_flip() +
    labs(
      title = "Transitivity Assessment: Effect Modifier Heterogeneity",
      subtitle = paste("Overall Rating:", transitivity$overall$overall_rating),
      x = "Effect Modifier",
      y = "-log10(p-value)",
      caption = "Red/orange bars indicate potential transitivity concerns"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 11)
    )

  return(p)
}


#' Plot Categorical Effect Modifier Distribution
#'
#' @param cat_result Categorical transitivity result
#' @return ggplot object
#' @keywords internal
plot_categorical_transitivity <- function(cat_result) {

  dist_data <- cat_result$distribution

  p <- ggplot(dist_data, aes(x = comparison, y = proportion)) +
    geom_bar(aes(fill = !!sym(cat_result$variable)),
             stat = "identity", position = "stack") +
    coord_flip() +
    scale_y_continuous(labels = scales::percent) +
    labs(
      title = paste("Distribution of", cat_result$variable, "Across Comparisons"),
      subtitle = paste("Chi-square p-value:",
                      round(cat_result$p_value, 3),
                      "-", cat_result$transitivity_concern),
      x = "Treatment Comparison",
      y = "Proportion",
      fill = cat_result$variable
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      legend.position = "bottom"
    )

  return(p)
}


#' Plot Continuous Effect Modifier Distribution
#'
#' @param cont_result Continuous transitivity result
#' @return ggplot object
#' @keywords internal
plot_continuous_transitivity <- function(cont_result) {

  summary_data <- cont_result$summary

  p <- ggplot(summary_data, aes(x = comparison, y = mean)) +
    geom_point(aes(size = n), color = "blue") +
    geom_errorbar(
      aes(ymin = mean - sd, ymax = mean + sd),
      width = 0.2, color = "blue", alpha = 0.6
    ) +
    coord_flip() +
    labs(
      title = paste("Distribution of", cont_result$variable, "Across Comparisons"),
      subtitle = paste("ANOVA p-value:",
                      round(cont_result$p_value, 3),
                      "- CV:", round(cont_result$coefficient_of_variation, 1), "%",
                      "\n", cont_result$transitivity_concern),
      x = "Treatment Comparison",
      y = paste("Mean", cont_result$variable, "(± SD)"),
      size = "Number of Studies"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.subtitle = element_text(size = 10)
    )

  return(p)
}


#' Network Coherence Assessment
#'
#' Evaluates whether the network structure supports transitivity
#'
#' @param net netmeta object
#' @return List with coherence assessment
#'
#' @export
assess_network_coherence <- function(net) {

  # Extract network characteristics
  n_treatments <- net$n
  n_studies <- length(unique(net$studlab))
  n_comparisons <- nrow(net$A.matrix)

  # Calculate network connectivity
  connectivity <- netconnection(net)

  # Identify multi-arm trials
  studies_per_comparison <- table(net$studlab)
  n_multiarm <- sum(studies_per_comparison > 1)

  # Calculate network density
  # Maximum possible comparisons = n_treatments * (n_treatments - 1) / 2
  max_comparisons <- n_treatments * (n_treatments - 1) / 2
  density <- n_comparisons / max_comparisons

  # Network geometry assessment
  geometry <- assess_network_geometry(net)

  coherence <- list(
    n_treatments = n_treatments,
    n_studies = n_studies,
    n_comparisons = n_comparisons,
    n_multiarm = n_multiarm,
    network_density = density,
    connectivity = connectivity,
    geometry = geometry,
    coherence_rating = rate_coherence(density, n_multiarm, geometry)
  )

  class(coherence) <- "network_coherence"
  return(coherence)
}


#' Assess Network Geometry
#'
#' @param net netmeta object
#' @return List with geometry metrics
#' @keywords internal
assess_network_geometry <- function(net) {

  # Star network: one central treatment connected to all others
  # Loop network: treatments form a closed loop
  # Complex network: multiple connections

  # Simplified assessment based on treatment connections
  treat_connections <- rowSums(net$A.matrix != 0)

  max_connections <- max(treat_connections)
  mean_connections <- mean(treat_connections)

  geometry_type <- if (max_connections == length(treat_connections) - 1 &&
                       sum(treat_connections == 1) >= length(treat_connections) - 1) {
    "Star network - potential transitivity concerns with hub treatment"
  } else if (mean_connections >= 2) {
    "Well-connected network - multiple paths support transitivity"
  } else {
    "Sparse network - limited redundancy for transitivity assessment"
  }

  list(
    max_connections = max_connections,
    mean_connections = mean_connections,
    geometry_type = geometry_type
  )
}


#' Rate Network Coherence
#'
#' @param density Network density
#' @param n_multiarm Number of multi-arm trials
#' @param geometry Geometry assessment
#' @return Character rating
#' @keywords internal
rate_coherence <- function(density, n_multiarm, geometry) {

  score <- 0

  # Density scoring
  if (density >= 0.5) score <- score + 2
  else if (density >= 0.3) score <- score + 1

  # Multi-arm trials add redundancy
  if (n_multiarm >= 3) score <- score + 2
  else if (n_multiarm >= 1) score <- score + 1

  # Connectivity scoring
  if (geometry$mean_connections >= 3) score <- score + 2
  else if (geometry$mean_connections >= 2) score <- score + 1

  if (score >= 5) {
    "Excellent - robust network supports transitivity assessment"
  } else if (score >= 3) {
    "Good - adequate network structure"
  } else {
    "Limited - sparse network, interpret transitivity with caution"
  }
}


#' Print Method for Transitivity Assessment
#'
#' @param x transitivity_assessment object
#' @param ... Additional arguments
#' @export
print.transitivity_assessment <- function(x, ...) {
  cat("\nNetwork Meta-Analysis Transitivity Assessment\n")
  cat("==============================================\n\n")

  cat("Effect Modifiers Assessed:", length(x$effect_modifiers), "\n")
  cat("  - Categorical:", length(x$categorical), "\n")
  cat("  - Continuous:", length(x$continuous), "\n\n")

  cat("Overall Rating:", x$overall$overall_rating, "\n\n")

  if (x$overall$n_concerns > 0) {
    cat("CONCERNS IDENTIFIED:\n")
    concerns <- x$overall$summary[grepl("Yes", x$overall$summary$concern), ]
    for (i in seq_len(nrow(concerns))) {
      cat(sprintf("  - %s (%s): p = %.3f\n",
                  concerns$variable[i],
                  concerns$type[i],
                  concerns$p_value[i]))
    }
    cat("\n")
  }

  cat("Summary Table:\n")
  print(x$overall$summary)

  cat("\n")
  cat("Interpretation:\n")
  cat("  p < 0.05: Strong evidence of heterogeneity (transitivity concern)\n")
  cat("  p < 0.10: Some evidence of heterogeneity (interpret with caution)\n")
  cat("  p >= 0.10: No strong evidence of heterogeneity\n")

  invisible(x)
}


#' Print Method for Network Coherence
#'
#' @param x network_coherence object
#' @param ... Additional arguments
#' @export
print.network_coherence <- function(x, ...) {
  cat("\nNetwork Coherence Assessment\n")
  cat("============================\n\n")

  cat("Network Structure:\n")
  cat("  Treatments:", x$n_treatments, "\n")
  cat("  Studies:", x$n_studies, "\n")
  cat("  Direct comparisons:", x$n_comparisons, "\n")
  cat("  Multi-arm trials:", x$n_multiarm, "\n\n")

  cat("Network Density:", sprintf("%.1f%%", x$network_density * 100), "\n\n")

  cat("Network Geometry:\n")
  cat(" ", x$geometry$geometry_type, "\n")
  cat("  Mean connections per treatment:",
      round(x$geometry$mean_connections, 1), "\n\n")

  cat("Overall Coherence:", x$coherence_rating, "\n")

  invisible(x)
}


#' Create Transitivity Report
#'
#' Generates a comprehensive transitivity assessment report
#'
#' @param transitivity Transitivity assessment object
#' @param coherence Network coherence object (optional)
#' @param output_file File path for report (optional)
#' @return Character vector with report text
#'
#' @export
create_transitivity_report <- function(
  transitivity,
  coherence = NULL,
  output_file = NULL
) {

  report <- c(
    "# Network Meta-Analysis Transitivity Assessment Report",
    "",
    "## Executive Summary",
    "",
    paste("**Overall Rating:**", transitivity$overall$overall_rating),
    paste("**Effect Modifiers Assessed:**", length(transitivity$effect_modifiers)),
    paste("**Concerns Identified:**", transitivity$overall$n_concerns),
    ""
  )

  # Network coherence section
  if (!is.null(coherence)) {
    report <- c(report,
      "## Network Structure",
      "",
      paste("- Treatments:", coherence$n_treatments),
      paste("- Studies:", coherence$n_studies),
      paste("- Network Density:", sprintf("%.1f%%", coherence$network_density * 100)),
      paste("- Multi-arm Trials:", coherence$n_multiarm),
      paste("- Coherence Rating:", coherence$coherence_rating),
      ""
    )
  }

  # Detailed findings
  report <- c(report,
    "## Detailed Findings",
    ""
  )

  summary_df <- transitivity$overall$summary
  for (i in seq_len(nrow(summary_df))) {
    report <- c(report,
      paste("###", summary_df$variable[i]),
      paste("- Type:", summary_df$type[i]),
      paste("- Test statistic:", round(summary_df$test_statistic[i], 2)),
      paste("- P-value:", round(summary_df$p_value[i], 3)),
      paste("- Assessment:", summary_df$concern[i]),
      ""
    )
  }

  # Recommendations
  report <- c(report,
    "## Recommendations",
    ""
  )

  if (transitivity$overall$n_concerns == 0) {
    report <- c(report,
      "No transitivity concerns identified. The network appears suitable for",
      "standard network meta-analysis under the assumption of transitivity.",
      ""
    )
  } else {
    report <- c(report,
      "Transitivity concerns identified. Consider:",
      "1. Meta-regression to adjust for effect modifiers",
      "2. Subgroup analysis by key effect modifiers",
      "3. Sensitivity analysis excluding studies with extreme values",
      "4. Node-splitting to assess inconsistency",
      "5. Cautious interpretation of results",
      ""
    )
  }

  # Write to file if specified
  if (!is.null(output_file)) {
    writeLines(report, output_file)
    message("Transitivity report saved to: ", output_file)
  }

  return(report)
}


# Export all functions
__all__ <- c(
  "assess_transitivity",
  "assess_network_coherence",
  "plot_transitivity",
  "create_transitivity_report",
  "print.transitivity_assessment",
  "print.network_coherence"
)


#' Example Usage
#'
#' @examples
#' \dontrun{
#' # Prepare network data with effect modifiers
#' library(netmeta)
#' data(Senn2013)
#'
#' # Add hypothetical effect modifiers
#' Senn2013$mean_age <- rnorm(nrow(Senn2013), mean = 55, sd = 8)
#' Senn2013$percent_male <- runif(nrow(Senn2013), min = 40, max = 60)
#' Senn2013$study_quality <- sample(c("High", "Medium", "Low"),
#'                                   nrow(Senn2013), replace = TRUE)
#'
#' # Assess transitivity
#' transitivity <- assess_transitivity(
#'   data = Senn2013,
#'   effect_modifiers = c("mean_age", "percent_male", "study_quality"),
#'   treatment_var = "treat",
#'   study_var = "studlab",
#'   categorical = "study_quality",
#'   continuous = c("mean_age", "percent_male")
#' )
#'
#' # Print summary
#' print(transitivity)
#'
#' # Plot transitivity assessment
#' plot_transitivity(transitivity)
#' plot_transitivity(transitivity, variable = "mean_age")
#'
#' # Fit network meta-analysis
#' net <- netmeta(TE, seTE, treat1, treat2, studlab,
#'                data = Senn2013, sm = "MD", reference = "plac")
#'
#' # Assess network coherence
#' coherence <- assess_network_coherence(net)
#' print(coherence)
#'
#' # Create comprehensive report
#' report <- create_transitivity_report(
#'   transitivity = transitivity,
#'   coherence = coherence,
#'   output_file = "transitivity_report.md"
#' )
#' }
#' @name transitivity_examples
NULL
