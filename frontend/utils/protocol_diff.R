# Protocol Diff Comparison
# Track changes to protocol specifications over time

library(digest)
library(jsonlite)
library(diffobj)

#' Save protocol version
#'
#' @param protocol List containing protocol details
#' @param version_name Optional version name (defaults to timestamp)
#' @param versions_dir Directory to store versions
#' @return Version ID
save_protocol_version <- function(protocol, version_name = NULL, versions_dir = "data/protocol_versions") {
  # Create versions directory
  if (!dir.exists(versions_dir)) {
    dir.create(versions_dir, recursive = TRUE)
  }

  # Generate version ID
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  version_id <- paste0("v_", timestamp)

  if (is.null(version_name)) {
    version_name <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  }

  # Create version object
  version <- list(
    version_id = version_id,
    version_name = version_name,
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    protocol = protocol,
    hash = digest(protocol, algo = "sha256")
  )

  # Save to JSON
  version_file <- file.path(versions_dir, paste0(version_id, ".json"))
  write_json(version, version_file, pretty = TRUE, auto_unbox = TRUE)

  message(sprintf("✓ Saved protocol version: %s (%s)", version_name, version_id))

  return(version_id)
}

#' Load protocol version
#'
#' @param version_id Version ID
#' @param versions_dir Directory containing versions
#' @return Protocol list or NULL
load_protocol_version <- function(version_id, versions_dir = "data/protocol_versions") {
  version_file <- file.path(versions_dir, paste0(version_id, ".json"))

  if (!file.exists(version_file)) {
    warning(paste("Version not found:", version_id))
    return(NULL)
  }

  tryCatch({
    version <- read_json(version_file, simplifyVector = TRUE)
    return(version)
  }, error = function(e) {
    warning(paste("Error loading version:", e$message))
    return(NULL)
  })
}

#' List all protocol versions
#'
#' @param versions_dir Directory containing versions
#' @return Data frame with version metadata
list_protocol_versions <- function(versions_dir = "data/protocol_versions") {
  if (!dir.exists(versions_dir)) {
    return(data.frame(
      version_id = character(),
      version_name = character(),
      created_at = character(),
      hash = character(),
      stringsAsFactors = FALSE
    ))
  }

  version_files <- list.files(versions_dir, pattern = "\\.json$", full.names = TRUE)

  if (length(version_files) == 0) {
    return(data.frame(
      version_id = character(),
      version_name = character(),
      created_at = character(),
      hash = character(),
      stringsAsFactors = FALSE
    ))
  }

  versions <- lapply(version_files, function(f) {
    tryCatch({
      v <- read_json(f, simplifyVector = TRUE)
      data.frame(
        version_id = v$version_id,
        version_name = v$version_name,
        created_at = v$created_at,
        hash = v$hash,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      NULL
    })
  })

  versions <- versions[!sapply(versions, is.null)]

  if (length(versions) == 0) {
    return(data.frame(
      version_id = character(),
      version_name = character(),
      created_at = character(),
      hash = character(),
      stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, versions)
}

#' Compare two protocol versions
#'
#' @param version_id_1 First version ID
#' @param version_id_2 Second version ID
#' @param versions_dir Directory containing versions
#' @return List with diff details
compare_protocol_versions <- function(version_id_1, version_id_2, versions_dir = "data/protocol_versions") {
  v1 <- load_protocol_version(version_id_1, versions_dir)
  v2 <- load_protocol_version(version_id_2, versions_dir)

  if (is.null(v1) || is.null(v2)) {
    return(list(error = "Could not load one or both versions"))
  }

  # Check if identical
  if (v1$hash == v2$hash) {
    return(list(
      identical = TRUE,
      message = "Protocols are identical"
    ))
  }

  # Compare each field
  changes <- list()

  # Get all unique fields
  all_fields <- unique(c(names(v1$protocol), names(v2$protocol)))

  for (field in all_fields) {
    val1 <- v1$protocol[[field]]
    val2 <- v2$protocol[[field]]

    # Check if field exists in both
    if (is.null(val1) && !is.null(val2)) {
      changes[[field]] <- list(
        type = "added",
        old_value = NULL,
        new_value = val2
      )
    } else if (!is.null(val1) && is.null(val2)) {
      changes[[field]] <- list(
        type = "removed",
        old_value = val1,
        new_value = NULL
      )
    } else if (!identical(val1, val2)) {
      changes[[field]] <- list(
        type = "modified",
        old_value = val1,
        new_value = val2
      )
    }
  }

  return(list(
    identical = FALSE,
    version_1 = list(
      id = v1$version_id,
      name = v1$version_name,
      created_at = v1$created_at
    ),
    version_2 = list(
      id = v2$version_id,
      name = v2$version_name,
      created_at = v2$created_at
    ),
    changes = changes,
    n_changes = length(changes)
  ))
}

#' Generate diff report HTML
#'
#' @param diff_result Result from compare_protocol_versions()
#' @return HTML tags for display
generate_diff_report_html <- function(diff_result) {
  if (!is.null(diff_result$error)) {
    return(tags$div(class = "alert alert-danger", diff_result$error))
  }

  if (diff_result$identical) {
    return(tags$div(class = "alert alert-success", "✓ Protocols are identical"))
  }

  tags$div(
    class = "protocol-diff-report",
    h4("Protocol Comparison"),

    # Version info
    tags$div(
      class = "row mb-3",
      tags$div(
        class = "col-md-6",
        h5("Version 1"),
        tags$ul(
          tags$li(strong("ID:"), diff_result$version_1$id),
          tags$li(strong("Name:"), diff_result$version_1$name),
          tags$li(strong("Created:"), diff_result$version_1$created_at)
        )
      ),
      tags$div(
        class = "col-md-6",
        h5("Version 2"),
        tags$ul(
          tags$li(strong("ID:"), diff_result$version_2$id),
          tags$li(strong("Name:"), diff_result$version_2$name),
          tags$li(strong("Created:"), diff_result$version_2$created_at)
        )
      )
    ),

    hr(),

    # Changes
    h5(sprintf("%d Changes Detected", diff_result$n_changes)),

    lapply(names(diff_result$changes), function(field) {
      change <- diff_result$changes[[field]]

      badge_class <- switch(change$type,
                           "added" = "badge bg-success",
                           "removed" = "badge bg-danger",
                           "modified" = "badge bg-warning",
                           "badge bg-secondary")

      tags$div(
        class = "change-item mb-3",
        tags$div(
          tags$span(class = badge_class, toupper(change$type)),
          tags$strong(paste0("  ", field))
        ),
        if (change$type == "added") {
          tags$div(
            class = "mt-2",
            tags$div(class = "text-success", sprintf("+ %s", format_value(change$new_value)))
          )
        } else if (change$type == "removed") {
          tags$div(
            class = "mt-2",
            tags$div(class = "text-danger", sprintf("- %s", format_value(change$old_value)))
          )
        } else {
          tags$div(
            class = "mt-2",
            tags$div(class = "text-danger", sprintf("- %s", format_value(change$old_value))),
            tags$div(class = "text-success", sprintf("+ %s", format_value(change$new_value)))
          )
        },
        hr()
      )
    })
  )
}

#' Format value for display
#'
#' @param value Value to format
#' @return Character string
format_value <- function(value) {
  if (is.null(value)) {
    return("NULL")
  }

  if (is.list(value)) {
    return(toJSON(value, auto_unbox = TRUE, pretty = TRUE))
  }

  if (length(value) > 1) {
    return(paste(value, collapse = ", "))
  }

  as.character(value)
}

#' Export diff report to Word
#'
#' @param diff_result Result from compare_protocol_versions()
#' @param output_file Output file path
#' @return TRUE if successful
export_diff_report <- function(diff_result, output_file) {
  if (!requireNamespace("officer", quietly = TRUE)) {
    warning("officer package required for Word export")
    return(FALSE)
  }

  library(officer)

  doc <- read_docx()

  # Title
  doc <- doc %>%
    body_add_par("Protocol Comparison Report", style = "heading 1") %>%
    body_add_par(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), style = "Normal")

  # Version info
  doc <- doc %>%
    body_add_par("Version 1", style = "heading 2") %>%
    body_add_par(sprintf("ID: %s", diff_result$version_1$id)) %>%
    body_add_par(sprintf("Name: %s", diff_result$version_1$name)) %>%
    body_add_par(sprintf("Created: %s", diff_result$version_1$created_at)) %>%
    body_add_par("Version 2", style = "heading 2") %>%
    body_add_par(sprintf("ID: %s", diff_result$version_2$id)) %>%
    body_add_par(sprintf("Name: %s", diff_result$version_2$name)) %>%
    body_add_par(sprintf("Created: %s", diff_result$version_2$created_at))

  # Changes
  doc <- doc %>%
    body_add_par(sprintf("Changes Detected: %d", diff_result$n_changes), style = "heading 2")

  for (field in names(diff_result$changes)) {
    change <- diff_result$changes[[field]]

    doc <- doc %>%
      body_add_par(sprintf("[%s] %s", toupper(change$type), field), style = "heading 3")

    if (change$type == "added") {
      doc <- doc %>% body_add_par(sprintf("Added: %s", format_value(change$new_value)))
    } else if (change$type == "removed") {
      doc <- doc %>% body_add_par(sprintf("Removed: %s", format_value(change$old_value)))
    } else {
      doc <- doc %>%
        body_add_par(sprintf("Old value: %s", format_value(change$old_value))) %>%
        body_add_par(sprintf("New value: %s", format_value(change$new_value)))
    }
  }

  # Save
  tryCatch({
    print(doc, target = output_file)
    message(sprintf("✓ Exported diff report to %s", output_file))
    return(TRUE)
  }, error = function(e) {
    warning(paste("Error exporting report:", e$message))
    return(FALSE)
  })
}
