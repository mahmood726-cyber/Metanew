# Living Meta-Analysis Update Tracker
# Monitors when meta-analyses need updating based on new evidence

library(jsonlite)
library(digest)

#' Register meta-analysis for living updates
#'
#' @param ma_id Unique meta-analysis ID
#' @param ma_name Meta-analysis name
#' @param outcome Outcome being analyzed
#' @param n_studies Number of studies included
#' @param effect_size Pooled effect size
#' @param i2 Heterogeneity statistic
#' @param search_terms Search terms for monitoring
#' @param update_trigger Trigger for update ("new_study", "quarterly", "signal")
#' @param registry_file File to store registrations
#' @return Registration ID
register_living_ma <- function(ma_id, ma_name, outcome, n_studies, effect_size, i2,
                               search_terms = NULL, update_trigger = "new_study",
                               registry_file = "data/living_ma_registry.json") {

  # Load existing registry
  if (file.exists(registry_file)) {
    registry <- read_json(registry_file, simplifyVector = TRUE)
    if (is.null(registry$meta_analyses)) {
      registry$meta_analyses <- list()
    }
  } else {
    registry <- list(meta_analyses = list())
  }

  # Create registration
  registration <- list(
    ma_id = ma_id,
    ma_name = ma_name,
    outcome = outcome,
    registered_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    last_updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    last_checked = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    baseline = list(
      n_studies = n_studies,
      effect_size = effect_size,
      i2 = i2,
      snapshot_date = format(Sys.Date(), "%Y-%m-%d")
    ),
    current = list(
      n_studies = n_studies,
      effect_size = effect_size,
      i2 = i2
    ),
    search_terms = search_terms,
    update_trigger = update_trigger,
    update_signals = list(),
    status = "active"
  )

  # Add to registry
  registry$meta_analyses[[ma_id]] <- registration

  # Save
  write_json(registry, registry_file, pretty = TRUE, auto_unbox = TRUE)

  message(sprintf("✓ Registered living MA: %s (ID: %s)", ma_name, ma_id))

  return(ma_id)
}

#' Check for update signals
#'
#' @param ma_id Meta-analysis ID
#' @param new_n_studies Updated number of studies
#' @param new_effect_size Updated effect size
#' @param new_i2 Updated I²
#' @param registry_file Registry file path
#' @return List with signal status
check_update_signal <- function(ma_id, new_n_studies = NULL, new_effect_size = NULL, new_i2 = NULL,
                                registry_file = "data/living_ma_registry.json") {

  if (!file.exists(registry_file)) {
    return(list(error = "Registry file not found"))
  }

  registry <- read_json(registry_file, simplifyVector = TRUE)

  if (is.null(registry$meta_analyses[[ma_id]])) {
    return(list(error = "MA not found in registry"))
  }

  ma <- registry$meta_analyses[[ma_id]]
  signals <- list()

  # Check for new studies
  if (!is.null(new_n_studies)) {
    n_new_studies <- new_n_studies - ma$current$n_studies

    if (n_new_studies > 0) {
      signals$new_studies <- list(
        type = "new_studies",
        severity = if (n_new_studies >= 5) "high" else if (n_new_studies >= 2) "medium" else "low",
        message = sprintf("%d new studies identified", n_new_studies),
        n_new = n_new_studies
      )
    }
  }

  # Check for substantial effect size change
  if (!is.null(new_effect_size) && !is.null(ma$current$effect_size)) {
    pct_change <- abs((new_effect_size - ma$current$effect_size) / ma$current$effect_size) * 100

    if (pct_change > 20) {
      signals$effect_change <- list(
        type = "effect_size_change",
        severity = if (pct_change > 50) "high" else "medium",
        message = sprintf("Effect size changed by %.1f%%", pct_change),
        old_effect = ma$current$effect_size,
        new_effect = new_effect_size,
        pct_change = pct_change
      )
    }
  }

  # Check for heterogeneity increase
  if (!is.null(new_i2) && !is.null(ma$current$i2)) {
    i2_increase <- new_i2 - ma$current$i2

    if (i2_increase > 25) {
      signals$heterogeneity_increase <- list(
        type = "heterogeneity_increase",
        severity = if (i2_increase > 50) "high" else "medium",
        message = sprintf("I² increased by %.1f%%", i2_increase),
        old_i2 = ma$current$i2,
        new_i2 = new_i2,
        increase = i2_increase
      )
    }
  }

  # Determine if update needed
  update_needed <- length(signals) > 0 &&
    any(sapply(signals, function(s) s$severity %in% c("high", "medium")))

  # Update registry
  ma$last_checked <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  if (update_needed) {
    # Add signals
    signal_record <- list(
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      signals = signals
    )

    if (is.null(ma$update_signals)) {
      ma$update_signals <- list()
    }
    ma$update_signals[[length(ma$update_signals) + 1]] <- signal_record

    # Update current values
    if (!is.null(new_n_studies)) ma$current$n_studies <- new_n_studies
    if (!is.null(new_effect_size)) ma$current$effect_size <- new_effect_size
    if (!is.null(new_i2)) ma$current$i2 <- new_i2
  }

  registry$meta_analyses[[ma_id]] <- ma
  write_json(registry, registry_file, pretty = TRUE, auto_unbox = TRUE)

  return(list(
    update_needed = update_needed,
    signals = signals,
    n_signals = length(signals),
    last_checked = ma$last_checked
  ))
}

#' Get all living MAs needing updates
#'
#' @param registry_file Registry file path
#' @return Data frame with MAs needing updates
get_mas_needing_update <- function(registry_file = "data/living_ma_registry.json") {
  if (!file.exists(registry_file)) {
    return(data.frame())
  }

  registry <- read_json(registry_file, simplifyVector = TRUE)

  if (is.null(registry$meta_analyses) || length(registry$meta_analyses) == 0) {
    return(data.frame())
  }

  # Extract MAs with signals
  mas_with_signals <- lapply(names(registry$meta_analyses), function(ma_id) {
    ma <- registry$meta_analyses[[ma_id]]

    if (ma$status != "active") return(NULL)
    if (is.null(ma$update_signals) || length(ma$update_signals) == 0) return(NULL)

    # Get most recent signal
    latest_signal <- ma$update_signals[[length(ma$update_signals)]]

    # Determine highest severity
    severities <- sapply(latest_signal$signals, function(s) s$severity)
    max_severity <- ifelse("high" %in% severities, "high",
                          ifelse("medium" %in% severities, "medium", "low"))

    data.frame(
      ma_id = ma_id,
      ma_name = ma$ma_name,
      outcome = ma$outcome,
      n_signals = length(latest_signal$signals),
      max_severity = max_severity,
      last_signal_time = latest_signal$timestamp,
      stringsAsFactors = FALSE
    )
  })

  # Remove NULLs and combine
  mas_with_signals <- mas_with_signals[!sapply(mas_with_signals, is.null)]

  if (length(mas_with_signals) == 0) {
    return(data.frame())
  }

  do.call(rbind, mas_with_signals)
}

#' Mark MA as updated
#'
#' @param ma_id Meta-analysis ID
#' @param new_n_studies Updated number of studies
#' @param new_effect_size Updated effect size
#' @param new_i2 Updated I²
#' @param registry_file Registry file path
#' @return TRUE if successful
mark_ma_updated <- function(ma_id, new_n_studies, new_effect_size, new_i2,
                            registry_file = "data/living_ma_registry.json") {

  if (!file.exists(registry_file)) {
    warning("Registry file not found")
    return(FALSE)
  }

  tryCatch({
    registry <- read_json(registry_file, simplifyVector = TRUE)

    if (is.null(registry$meta_analyses[[ma_id]])) {
      warning("MA not found in registry")
      return(FALSE)
    }

    ma <- registry$meta_analyses[[ma_id]]

    # Update values
    ma$last_updated <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    ma$current$n_studies <- new_n_studies
    ma$current$effect_size <- new_effect_size
    ma$current$i2 <- new_i2

    # Clear signals
    ma$update_signals <- list()

    # Save
    registry$meta_analyses[[ma_id]] <- ma
    write_json(registry, registry_file, pretty = TRUE, auto_unbox = TRUE)

    message(sprintf("✓ Marked MA as updated: %s", ma$ma_name))

    return(TRUE)

  }, error = function(e) {
    warning(paste("Error marking MA as updated:", e$message))
    return(FALSE)
  })
}

#' Generate update alert notification
#'
#' @param signal_result Result from check_update_signal()
#' @return HTML notification
generate_update_alert <- function(signal_result) {
  if (!signal_result$update_needed) {
    return(tags$div(class = "alert alert-success", "✓ No updates needed"))
  }

  # Determine alert class
  severities <- sapply(signal_result$signals, function(s) s$severity)
  alert_class <- if ("high" %in% severities) {
    "alert alert-danger"
  } else if ("medium" %in% severities) {
    "alert alert-warning"
  } else {
    "alert alert-info"
  }

  tags$div(
    class = alert_class,
    h5(sprintf("⚠ Update Recommended (%d signals)", signal_result$n_signals)),
    tags$ul(
      lapply(signal_result$signals, function(signal) {
        tags$li(signal$message)
      })
    ),
    tags$p(
      class = "mb-0",
      strong("Last checked:"), signal_result$last_checked
    )
  )
}

#' Create living MA dashboard
#'
#' @param registry_file Registry file path
#' @return HTML dashboard
create_living_ma_dashboard <- function(registry_file = "data/living_ma_registry.json") {
  mas_needing_update <- get_mas_needing_update(registry_file)

  if (nrow(mas_needing_update) == 0) {
    return(tags$div(
      class = "alert alert-success",
      h4("✓ All Meta-Analyses Up to Date"),
      tags$p("No living meta-analyses require updates at this time.")
    ))
  }

  # Sort by severity
  mas_needing_update <- mas_needing_update[order(
    match(mas_needing_update$max_severity, c("high", "medium", "low"))
  ), ]

  tags$div(
    h4(sprintf("Living Meta-Analyses Requiring Update (%d)", nrow(mas_needing_update))),

    # High priority
    if (any(mas_needing_update$max_severity == "high")) {
      tagList(
        h5(tags$span(class = "badge bg-danger", "HIGH PRIORITY")),
        tags$ul(
          lapply(which(mas_needing_update$max_severity == "high"), function(i) {
            ma <- mas_needing_update[i, ]
            tags$li(
              strong(ma$ma_name),
              sprintf(" - %d signal(s), last: %s", ma$n_signals, ma$last_signal_time)
            )
          })
        )
      )
    },

    # Medium priority
    if (any(mas_needing_update$max_severity == "medium")) {
      tagList(
        h5(tags$span(class = "badge bg-warning", "MEDIUM PRIORITY")),
        tags$ul(
          lapply(which(mas_needing_update$max_severity == "medium"), function(i) {
            ma <- mas_needing_update[i, ]
            tags$li(
              strong(ma$ma_name),
              sprintf(" - %d signal(s), last: %s", ma$n_signals, ma$last_signal_time)
            )
          })
        )
      )
    }
  )
}

#' Calculate time since last update
#'
#' @param last_updated_str Last updated timestamp string
#' @return Human-readable time difference
time_since_update <- function(last_updated_str) {
  last_updated <- as.POSIXct(last_updated_str)
  diff <- difftime(Sys.time(), last_updated, units = "days")

  if (diff < 1) {
    return("Today")
  } else if (diff < 7) {
    return(sprintf("%.0f days ago", diff))
  } else if (diff < 30) {
    return(sprintf("%.0f weeks ago", diff / 7))
  } else if (diff < 365) {
    return(sprintf("%.0f months ago", diff / 30))
  } else {
    return(sprintf("%.1f years ago", diff / 365))
  }
}
