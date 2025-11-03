# Risk of Bias 2.0 (RoB 2.0) Tool Integration
# Implements Cochrane Risk of Bias tool for randomized trials
# Following Sterne et al. (2019) BMJ 366:l4898

library(ggplot2)
library(grid)
library(gridExtra)

#' RoB 2.0 Domain Definitions
#'
#' The five domains of RoB 2.0:
#' 1. Bias arising from the randomization process
#' 2. Bias due to deviations from intended interventions
#' 3. Bias due to missing outcome data
#' 4. Bias in measurement of the outcome
#' 5. Bias in selection of the reported result
#'
#' Each domain is rated: Low / Some concerns / High
#' Overall rating: worst rating across domains (with specific rules)
#'
#' @name rob2_domains
#' @keywords internal
NULL

ROB2_DOMAINS <- list(
  D1 = list(
    name = "Randomization process",
    code = "D1",
    signaling_questions = 5
  ),
  D2 = list(
    name = "Deviations from interventions",
    code = "D2",
    signaling_questions = 7
  ),
  D3 = list(
    name = "Missing outcome data",
    code = "D3",
    signaling_questions = 3
  ),
  D4 = list(
    name = "Measurement of outcome",
    code = "D4",
    signaling_questions = 5
  ),
  D5 = list(
    name = "Selection of reported result",
    code = "D5",
    signaling_questions = 3
  )
)


#' Create RoB 2.0 Assessment Template
#'
#' Creates a template data frame for RoB 2.0 assessments
#'
#' @param study_ids Character vector of study IDs
#' @return Data frame with template for RoB 2.0 assessments
#' @export
create_rob2_template <- function(study_ids) {

  template <- data.frame(
    study_id = rep(study_ids, each = 5),
    domain = rep(c("D1", "D2", "D3", "D4", "D5"), length(study_ids)),
    domain_name = rep(c(
      "Randomization process",
      "Deviations from interventions",
      "Missing outcome data",
      "Measurement of outcome",
      "Selection of reported result"
    ), length(study_ids)),
    rating = NA_character_,
    support_for_judgment = NA_character_,
    stringsAsFactors = FALSE
  )

  # Add overall risk column
  overall <- data.frame(
    study_id = study_ids,
    domain = "Overall",
    domain_name = "Overall risk of bias",
    rating = NA_character_,
    support_for_judgment = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- rbind(template, overall)
  result$rating <- factor(
    result$rating,
    levels = c("Low", "Some concerns", "High"),
    ordered = TRUE
  )

  return(result)
}


#' Calculate Overall RoB 2.0 Rating
#'
#' Calculates overall risk of bias based on domain ratings
#'
#' @param domain_ratings Named vector or data frame with domain ratings
#' @return Overall risk of bias rating
#'
#' @details
#' Algorithm from Sterne et al. (2019):
#' - Low: Low risk in all domains
#' - Some concerns: Some concerns in at least one domain, no high risk
#' - High: High risk in at least one domain, OR some concerns in multiple domains
#'
#' @export
calculate_overall_rob2 <- function(domain_ratings) {

  if (is.data.frame(domain_ratings)) {
    ratings <- domain_ratings$rating[domain_ratings$domain %in% c("D1", "D2", "D3", "D4", "D5")]
  } else {
    ratings <- domain_ratings[c("D1", "D2", "D3", "D4", "D5")]
  }

  # Convert to character if factor
  ratings <- as.character(ratings)

  # Count risk levels
  n_high <- sum(ratings == "High", na.rm = TRUE)
  n_some <- sum(ratings == "Some concerns", na.rm = TRUE)
  n_low <- sum(ratings == "Low", na.rm = TRUE)

  # Apply algorithm
  if (n_high > 0) {
    return("High")
  } else if (n_some > 0) {
    return("Some concerns")
  } else if (n_low == 5) {
    return("Low")
  } else {
    return(NA_character_)
  }
}


#' Validate RoB 2.0 Assessment
#'
#' Checks if RoB 2.0 assessment is complete and valid
#'
#' @param rob_data Data frame with RoB 2.0 assessments
#' @return List with validation results
#' @export
validate_rob2 <- function(rob_data) {

  errors <- character()
  warnings <- character()

  # Check required columns
  required_cols <- c("study_id", "domain", "rating")
  missing_cols <- setdiff(required_cols, names(rob_data))

  if (length(missing_cols) > 0) {
    errors <- c(errors, paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
    return(list(valid = FALSE, errors = errors, warnings = warnings))
  }

  # Check each study has all domains
  studies <- unique(rob_data$study_id[rob_data$domain != "Overall"])

  for (study in studies) {
    study_data <- rob_data[rob_data$study_id == study & rob_data$domain != "Overall", ]

    # Check all 5 domains present
    domains_present <- unique(study_data$domain)
    missing_domains <- setdiff(c("D1", "D2", "D3", "D4", "D5"), domains_present)

    if (length(missing_domains) > 0) {
      warnings <- c(warnings, paste0(
        "Study ", study, " missing domains: ",
        paste(missing_domains, collapse = ", ")
      ))
    }

    # Check all domains rated
    unrated_domains <- study_data$domain[is.na(study_data$rating)]
    if (length(unrated_domains) > 0) {
      warnings <- c(warnings, paste0(
        "Study ", study, " has unrated domains: ",
        paste(unrated_domains, collapse = ", ")
      ))
    }

    # Check valid ratings
    invalid_ratings <- study_data$rating[
      !is.na(study_data$rating) &
      !study_data$rating %in% c("Low", "Some concerns", "High")
    ]

    if (length(invalid_ratings) > 0) {
      errors <- c(errors, paste0(
        "Study ", study, " has invalid ratings: ",
        paste(invalid_ratings, collapse = ", ")
      ))
    }
  }

  valid <- length(errors) == 0

  return(list(
    valid = valid,
    errors = errors,
    warnings = warnings,
    n_studies = length(studies),
    n_complete = sum(sapply(studies, function(s) {
      all(!is.na(rob_data$rating[rob_data$study_id == s & rob_data$domain != "Overall"]))
    }))
  ))
}


#' Create RoB 2.0 Traffic Light Plot
#'
#' Creates traffic light plot showing risk of bias assessments
#'
#' @param rob_data Data frame with RoB 2.0 assessments
#' @param studies Optional vector of study IDs to include (default: all)
#' @return ggplot object
#' @export
rob2_traffic_light <- function(rob_data, studies = NULL) {

  # Filter to domain ratings only (exclude overall)
  rob_data <- rob_data[rob_data$domain != "Overall", ]

  if (!is.null(studies)) {
    rob_data <- rob_data[rob_data$study_id %in% studies, ]
  }

  # Convert ratings to factor with correct order
  rob_data$rating <- factor(
    rob_data$rating,
    levels = c("Low", "Some concerns", "High"),
    ordered = TRUE
  )

  # Color scheme: Green / Yellow / Red
  color_map <- c(
    "Low" = "#02C39A",
    "Some concerns" = "#F4D35E",
    "High" = "#EE6352"
  )

  # Create plot
  p <- ggplot(rob_data, aes(x = domain_name, y = study_id, fill = rating)) +
    geom_tile(color = "white", linewidth = 1) +
    scale_fill_manual(
      values = color_map,
      na.value = "grey90",
      drop = FALSE
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
      axis.text.y = element_text(size = 9),
      axis.title = element_blank(),
      legend.position = "bottom",
      legend.title = element_text(size = 10),
      panel.grid = element_blank(),
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
    ) +
    labs(
      title = "Risk of Bias Assessment (RoB 2.0)",
      fill = "Risk of Bias"
    ) +
    coord_fixed(ratio = 0.8)

  return(p)
}


#' Create RoB 2.0 Summary Plot
#'
#' Creates summary bar chart of risk of bias across domains
#'
#' @param rob_data Data frame with RoB 2.0 assessments
#' @return ggplot object
#' @export
rob2_summary <- function(rob_data) {

  # Filter to domain ratings only
  rob_data <- rob_data[rob_data$domain != "Overall", ]

  # Calculate percentages for each domain
  summary_data <- do.call(rbind, lapply(c("D1", "D2", "D3", "D4", "D5"), function(d) {
    domain_data <- rob_data[rob_data$domain == d, ]
    domain_name <- unique(domain_data$domain_name)[1]

    counts <- table(factor(
      domain_data$rating,
      levels = c("Low", "Some concerns", "High")
    ))

    pct <- counts / sum(counts) * 100

    data.frame(
      domain = domain_name,
      rating = c("Low", "Some concerns", "High"),
      count = as.numeric(counts),
      percentage = as.numeric(pct),
      stringsAsFactors = FALSE
    )
  }))

  # Convert to factor for correct ordering
  summary_data$rating <- factor(
    summary_data$rating,
    levels = c("High", "Some concerns", "Low"),
    ordered = TRUE
  )

  # Color scheme
  color_map <- c(
    "Low" = "#02C39A",
    "Some concerns" = "#F4D35E",
    "High" = "#EE6352"
  )

  # Create stacked bar chart
  p <- ggplot(summary_data, aes(x = domain, y = percentage, fill = rating)) +
    geom_bar(stat = "identity", color = "white", linewidth = 0.5) +
    scale_fill_manual(values = color_map) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
      axis.title.y = element_text(size = 11),
      legend.position = "bottom",
      legend.title = element_text(size = 10),
      panel.grid.major.x = element_blank(),
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
    ) +
    labs(
      title = "Risk of Bias Summary",
      x = NULL,
      y = "Percentage of Studies (%)",
      fill = "Risk of Bias"
    ) +
    coord_flip() +
    scale_y_continuous(expand = c(0, 0), limits = c(0, 100))

  return(p)
}


#' Bias-Adjusted Meta-Analysis
#'
#' Performs sensitivity meta-analysis excluding high risk of bias studies
#'
#' @param ma Meta-analysis object from meta package
#' @param rob_data Data frame with RoB 2.0 assessments
#' @param exclude_risk Level of risk to exclude ("High" or "Some concerns")
#' @return List with original and adjusted meta-analysis results
#' @export
rob2_sensitivity_analysis <- function(ma, rob_data, exclude_risk = "High") {

  # Calculate overall risk for each study
  studies <- unique(rob_data$study_id[rob_data$domain != "Overall"])

  overall_risk <- sapply(studies, function(s) {
    study_ratings <- rob_data[rob_data$study_id == s & rob_data$domain != "Overall", ]
    calculate_overall_rob2(study_ratings)
  })

  # Determine which studies to exclude
  if (exclude_risk == "High") {
    exclude_studies <- names(overall_risk)[overall_risk == "High"]
  } else if (exclude_risk == "Some concerns") {
    exclude_studies <- names(overall_risk)[overall_risk %in% c("High", "Some concerns")]
  } else {
    stop("exclude_risk must be 'High' or 'Some concerns'")
  }

  n_excluded <- length(exclude_studies)

  if (n_excluded == 0) {
    message("No studies excluded based on risk of bias criteria")
    return(list(
      original = ma,
      adjusted = ma,
      n_excluded = 0,
      excluded_studies = character(0)
    ))
  }

  # Create adjusted meta-analysis
  # Filter studies
  keep_idx <- !(ma$studlab %in% exclude_studies)

  # Update meta-analysis object
  ma_adjusted <- ma
  ma_adjusted$k <- sum(keep_idx)
  ma_adjusted$studlab <- ma$studlab[keep_idx]
  ma_adjusted$TE <- ma$TE[keep_idx]
  ma_adjusted$seTE <- ma$seTE[keep_idx]

  # Re-run meta-analysis
  if (inherits(ma, "metabin")) {
    ma_adjusted <- metabin(
      event.e = ma$event.e[keep_idx],
      n.e = ma$n.e[keep_idx],
      event.c = ma$event.c[keep_idx],
      n.c = ma$n.c[keep_idx],
      studlab = ma$studlab[keep_idx],
      sm = ma$sm,
      method = ma$method,
      comb.fixed = ma$comb.fixed,
      comb.random = ma$comb.random
    )
  } else if (inherits(ma, "metacont")) {
    ma_adjusted <- metacont(
      n.e = ma$n.e[keep_idx],
      mean.e = ma$mean.e[keep_idx],
      sd.e = ma$sd.e[keep_idx],
      n.c = ma$n.c[keep_idx],
      mean.c = ma$mean.c[keep_idx],
      sd.c = ma$sd.c[keep_idx],
      studlab = ma$studlab[keep_idx],
      sm = ma$sm,
      comb.fixed = ma$comb.fixed,
      comb.random = ma$comb.random
    )
  } else {
    # Generic approach
    ma_adjusted <- metagen(
      TE = ma$TE[keep_idx],
      seTE = ma$seTE[keep_idx],
      studlab = ma$studlab[keep_idx],
      sm = ma$sm,
      comb.fixed = ma$comb.fixed,
      comb.random = ma$comb.random
    )
  }

  # Compare results
  comparison <- data.frame(
    analysis = c("Original", "Adjusted (excl. high RoB)"),
    k = c(ma$k, ma_adjusted$k),
    estimate = c(ma$TE.random, ma_adjusted$TE.random),
    ci_lower = c(ma$lower.random, ma_adjusted$lower.random),
    ci_upper = c(ma$upper.random, ma_adjusted$upper.random),
    tau2 = c(ma$tau^2, ma_adjusted$tau^2),
    I2 = c(ma$I2, ma_adjusted$I2),
    stringsAsFactors = FALSE
  )

  return(list(
    original = ma,
    adjusted = ma_adjusted,
    n_excluded = n_excluded,
    excluded_studies = exclude_studies,
    overall_risk = overall_risk,
    comparison = comparison
  ))
}


#' Export RoB 2.0 Assessment to CSV
#'
#' Exports RoB 2.0 data to CSV format compatible with robvis package
#'
#' @param rob_data Data frame with RoB 2.0 assessments
#' @param file File path for CSV output
#' @export
export_rob2_csv <- function(rob_data, file) {

  # Reshape to wide format for robvis compatibility
  rob_wide <- reshape(
    rob_data[rob_data$domain != "Overall", ],
    idvar = "study_id",
    timevar = "domain",
    direction = "wide",
    v.names = "rating"
  )

  # Add overall risk
  rob_wide$Overall <- sapply(rob_wide$study_id, function(s) {
    study_data <- rob_data[rob_data$study_id == s & rob_data$domain != "Overall", ]
    calculate_overall_rob2(study_data)
  })

  # Clean column names
  names(rob_wide) <- gsub("rating\\.", "", names(rob_wide))

  # Write to CSV
  write.csv(rob_wide, file, row.names = FALSE)

  message("RoB 2.0 assessment exported to: ", file)
}


# Export documentation
#' @name rob2
#' @title Risk of Bias 2.0 (RoB 2.0) Tool
#' @description
#' Implementation of Cochrane Risk of Bias tool version 2.0 for assessing
#' risk of bias in randomized controlled trials.
#'
#' @details
#' The RoB 2.0 tool evaluates five domains:
#' \enumerate{
#'   \item Bias arising from the randomization process
#'   \item Bias due to deviations from intended interventions
#'   \item Bias due to missing outcome data
#'   \item Bias in measurement of the outcome
#'   \item Bias in selection of the reported result
#' }
#'
#' Each domain is rated as:
#' \itemize{
#'   \item Low risk
#'   \item Some concerns
#'   \item High risk
#' }
#'
#' Overall risk is determined by the worst rating across domains.
#'
#' Functions:
#' \itemize{
#'   \item \code{create_rob2_template}: Create assessment template
#'   \item \code{calculate_overall_rob2}: Calculate overall risk
#'   \item \code{validate_rob2}: Validate assessments
#'   \item \code{rob2_traffic_light}: Create traffic light plot
#'   \item \code{rob2_summary}: Create summary plot
#'   \item \code{rob2_sensitivity_analysis}: Bias-adjusted meta-analysis
#' }
#'
#' @references
#' Sterne JAC, Savović J, Page MJ, et al. (2019). RoB 2: a revised tool for
#' assessing risk of bias in randomised trials. BMJ, 366:l4898.
#'
#' @seealso \code{\link[robvis]{rob_summary}}, \code{\link[meta]{metabias}}
NULL
