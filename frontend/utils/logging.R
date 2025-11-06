# ==============================================================================
# LOGGING SYSTEM FOR EVIDENCEOS PRIME
# ==============================================================================
#
# Professional logging system with multiple levels and output options
# Replaces scattered cat() and print() statements
#
# USAGE:
#   log_info("Data loaded", studies = nrow(data))
#   log_warning("Missing values detected", count = n_missing)
#   log_error("Analysis failed", error = e$message)
#   log_debug("Intermediate result", value = x)
#
# ==============================================================================

# Global log settings
.log_config <- new.env()
.log_config$level <- "INFO"  # DEBUG, INFO, WARNING, ERROR
.log_config$output <- "console"  # console, file, both
.log_config$file_path <- "logs/evidenceos.log"
.log_config$include_timestamp <- TRUE
.log_config$include_session <- TRUE
.log_config$max_file_size_mb <- 10

# ==============================================================================
# LOG LEVELS
# ==============================================================================

LOG_LEVELS <- list(
  DEBUG = 1,
  INFO = 2,
  WARNING = 3,
  ERROR = 4
)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

#' Set logging level
#' @param level One of: "DEBUG", "INFO", "WARNING", "ERROR"
#' @export
set_log_level <- function(level = "INFO") {
  if (!level %in% names(LOG_LEVELS)) {
    stop("Invalid log level. Use: DEBUG, INFO, WARNING, ERROR")
  }
  .log_config$level <- level
  log_info("Log level set to", level = level)
}

#' Set logging output
#' @param output One of: "console", "file", "both"
#' @param file_path Path to log file (if using file output)
#' @export
set_log_output <- function(output = "console", file_path = "logs/evidenceos.log") {
  if (!output %in% c("console", "file", "both")) {
    stop("Invalid output. Use: console, file, both")
  }
  .log_config$output <- output
  .log_config$file_path <- file_path

  if (output %in% c("file", "both")) {
    # Create logs directory if it doesn't exist
    dir.create(dirname(file_path), showWarnings = FALSE, recursive = TRUE)
  }
}

# ==============================================================================
# CORE LOGGING FUNCTIONS
# ==============================================================================

#' Internal function to write log message
#' @keywords internal
write_log <- function(level, message, ...) {
  # Check if this level should be logged
  if (LOG_LEVELS[[level]] < LOG_LEVELS[[.log_config$level]]) {
    return(invisible())
  }

  # Build log message
  timestamp <- if (.log_config$include_timestamp) {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  } else {
    NULL
  }

  session_id <- if (.log_config$include_session) {
    substr(digest::digest(Sys.time()), 1, 8)
  } else {
    NULL
  }

  # Format additional arguments
  extra_args <- list(...)
  extra_text <- if (length(extra_args) > 0) {
    paste0(" [", paste(names(extra_args), extra_args, sep = "=", collapse = ", "), "]")
  } else {
    ""
  }

  # Build full log line
  log_parts <- c(timestamp, session_id, level, message)
  log_line <- paste0(
    paste(Filter(Negate(is.null), log_parts), collapse = " | "),
    extra_text
  )

  # Color coding for console output
  if (.log_config$output %in% c("console", "both")) {
    colored_level <- switch(level,
      DEBUG = crayon::cyan(level),
      INFO = crayon::green(level),
      WARNING = crayon::yellow(level),
      ERROR = crayon::red(level),
      level
    )

    colored_line <- paste0(
      if (!is.null(timestamp)) paste0(crayon::silver(timestamp), " | ") else "",
      if (!is.null(session_id)) paste0(crayon::silver(session_id), " | ") else "",
      colored_level, " | ",
      message,
      extra_text
    )

    cat(colored_line, "\n")
  }

  # Write to file if configured
  if (.log_config$output %in% c("file", "both")) {
    # Check file size and rotate if needed
    if (file.exists(.log_config$file_path)) {
      file_size_mb <- file.info(.log_config$file_path)$size / (1024^2)
      if (file_size_mb > .log_config$max_file_size_mb) {
        rotate_log_file()
      }
    }

    # Append to log file
    cat(log_line, "\n", file = .log_config$file_path, append = TRUE)
  }
}

#' Rotate log file when it gets too large
#' @keywords internal
rotate_log_file <- function() {
  if (file.exists(.log_config$file_path)) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    backup_path <- sub("\\.log$", paste0("_", timestamp, ".log"), .log_config$file_path)
    file.rename(.log_config$file_path, backup_path)
    cat(paste("Log file rotated to:", backup_path), "\n")
  }
}

# ==============================================================================
# PUBLIC LOGGING FUNCTIONS
# ==============================================================================

#' Log debug message
#' @param message Main message
#' @param ... Additional key-value pairs to log
#' @export
log_debug <- function(message, ...) {
  write_log("DEBUG", message, ...)
}

#' Log info message
#' @param message Main message
#' @param ... Additional key-value pairs to log
#' @export
log_info <- function(message, ...) {
  write_log("INFO", message, ...)
}

#' Log warning message
#' @param message Main message
#' @param ... Additional key-value pairs to log
#' @export
log_warning <- function(message, ...) {
  write_log("WARNING", message, ...)
}

#' Log error message
#' @param message Main message
#' @param ... Additional key-value pairs to log
#' @export
log_error <- function(message, ...) {
  write_log("ERROR", message, ...)
}

# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

#' Log function entry (for debugging function calls)
#' @param fn_name Function name
#' @param ... Function arguments to log
#' @export
log_enter <- function(fn_name, ...) {
  log_debug(paste0("→ Entering ", fn_name), ...)
}

#' Log function exit (for debugging function returns)
#' @param fn_name Function name
#' @param ... Return values to log
#' @export
log_exit <- function(fn_name, ...) {
  log_debug(paste0("← Exiting ", fn_name), ...)
}

#' Log performance timing
#' @param operation Operation name
#' @param start_time Start time from Sys.time()
#' @export
log_performance <- function(operation, start_time) {
  elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
  log_info(paste0("⏱ Performance: ", operation), elapsed_sec = round(elapsed, 3))
}

#' Log data loading
#' @param source Data source
#' @param rows Number of rows
#' @param cols Number of columns
#' @export
log_data_loaded <- function(source, rows, cols) {
  log_info(paste0("📊 Data loaded from ", source), rows = rows, cols = cols)
}

#' Log analysis completion
#' @param analysis_type Type of analysis
#' @param outcome Outcome analyzed
#' @export
log_analysis_complete <- function(analysis_type, outcome = NULL) {
  log_info(paste0("✓ ", analysis_type, " complete"), outcome = outcome)
}

# ==============================================================================
# ERROR HANDLING HELPERS
# ==============================================================================

#' Wrap tryCatch with logging
#' @param expr Expression to evaluate
#' @param error_msg Custom error message
#' @export
try_with_log <- function(expr, error_msg = "Operation failed") {
  tryCatch(
    expr,
    error = function(e) {
      log_error(error_msg, error = e$message, call = deparse(e$call))
      NULL
    },
    warning = function(w) {
      log_warning("Warning occurred", warning = w$message)
      suppressWarnings(expr)
    }
  )
}

# ==============================================================================
# SESSION LOGGING
# ==============================================================================

#' Log session start
#' @export
log_session_start <- function() {
  log_info("==========================================================")
  log_info("SESSION STARTED",
           R_version = R.version.string,
           platform = R.version$platform,
           user = Sys.info()["user"])
  log_info("==========================================================")
}

#' Log session end
#' @export
log_session_end <- function() {
  log_info("==========================================================")
  log_info("SESSION ENDED")
  log_info("==========================================================")
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================

# Check if crayon is available (for colored output)
if (!requireNamespace("crayon", quietly = TRUE)) {
  # Define fallback functions if crayon is not available
  crayon <- list(
    cyan = identity,
    green = identity,
    yellow = identity,
    red = identity,
    silver = identity
  )
}

# Simple hash function if digest is not available
if (!requireNamespace("digest", quietly = TRUE)) {
  .log_config$include_session <- FALSE
}

cat("✅ Logging system initialized\n")
cat("   • Log level: ", .log_config$level, "\n")
cat("   • Output: ", .log_config$output, "\n")
cat("\n")
cat("Available functions:\n")
cat("   log_debug(), log_info(), log_warning(), log_error()\n")
cat("   log_enter(), log_exit(), log_performance()\n")
cat("   try_with_log(), set_log_level(), set_log_output()\n")
cat("\n")
