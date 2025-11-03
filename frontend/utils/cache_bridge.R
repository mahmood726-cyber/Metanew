# R Bridge to Python Caching Layer
# Provides R interface to Parquet caching for fast meta-analysis results storage

library(reticulate)
library(digest)
library(jsonlite)

#' Initialize cache manager
#'
#' @param cache_dir Directory for cache storage (default: "cache/parquet")
#' @return Cache manager object
init_cache_manager <- function(cache_dir = "cache/parquet") {
  tryCatch({
    # Import Python cache module
    cache_module <- import_from_path("cache_manager", path = "../../backend/cache")
    cache_manager <- cache_module$CacheManager(cache_dir = cache_dir)
    return(cache_manager)
  }, error = function(e) {
    warning(paste("Could not initialize cache manager:", e$message))
    return(NULL)
  })
}

#' Generate cache key from analysis parameters
#'
#' @param analysis_type Type of analysis (e.g., "meta_analysis")
#' @param parameters List of analysis parameters
#' @return SHA256 hash as cache key
generate_cache_key <- function(analysis_type, parameters) {
  # Sort parameters for consistency
  param_str <- toJSON(parameters[order(names(parameters))], auto_unbox = TRUE)
  key_input <- paste0(analysis_type, ":", param_str)
  digest(key_input, algo = "sha256", serialize = FALSE)
}

#' Check if analysis results are cached
#'
#' @param cache_manager Cache manager object
#' @param analysis_type Type of analysis
#' @param parameters Analysis parameters
#' @return TRUE if cached, FALSE otherwise
is_cached <- function(cache_manager, analysis_type, parameters) {
  if (is.null(cache_manager)) return(FALSE)

  tryCatch({
    cached <- cache_manager$get(analysis_type, parameters)
    return(!is.null(cached))
  }, error = function(e) {
    return(FALSE)
  })
}

#' Get cached analysis results
#'
#' @param cache_manager Cache manager object
#' @param analysis_type Type of analysis
#' @param parameters Analysis parameters
#' @return Data frame with results or NULL
get_cached_results <- function(cache_manager, analysis_type, parameters) {
  if (is.null(cache_manager)) return(NULL)

  tryCatch({
    cached <- cache_manager$get(analysis_type, parameters)
    if (is.null(cached)) return(NULL)

    # Convert pandas DataFrame to R data.frame
    return(as.data.frame(cached))
  }, error = function(e) {
    warning(paste("Error retrieving cache:", e$message))
    return(NULL)
  })
}

#' Save analysis results to cache
#'
#' @param cache_manager Cache manager object
#' @param analysis_type Type of analysis
#' @param parameters Analysis parameters
#' @param results Data frame with results
#' @param metadata Optional metadata list
#' @return Cache key or NULL on error
cache_results <- function(cache_manager, analysis_type, parameters, results, metadata = NULL) {
  if (is.null(cache_manager)) return(NULL)

  tryCatch({
    # Convert to pandas DataFrame
    results_pd <- r_to_py(results)

    cache_key <- cache_manager$put(
      analysis_type = analysis_type,
      parameters = parameters,
      data = results_pd,
      metadata = metadata
    )

    message(sprintf("✓ Cached %s results (key: %s)", analysis_type, substr(cache_key, 1, 8)))
    return(cache_key)

  }, error = function(e) {
    warning(paste("Error caching results:", e$message))
    return(NULL)
  })
}

#' Run meta-analysis with caching
#'
#' @param cache_manager Cache manager object
#' @param analysis_func Function that performs analysis
#' @param analysis_type Type of analysis
#' @param parameters Analysis parameters
#' @param force_refresh Force re-computation even if cached
#' @return Analysis results data frame
run_with_cache <- function(cache_manager, analysis_func, analysis_type,
                           parameters, force_refresh = FALSE) {

  # Check cache first
  if (!force_refresh && !is.null(cache_manager)) {
    cached <- get_cached_results(cache_manager, analysis_type, parameters)

    if (!is.null(cached)) {
      message(sprintf("✓ Cache hit for %s", analysis_type))
      return(cached)
    }
  }

  # Run analysis
  message(sprintf("→ Computing %s...", analysis_type))
  start_time <- Sys.time()

  results <- analysis_func()

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Cache results
  if (!is.null(cache_manager)) {
    metadata <- list(
      computation_time = elapsed,
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )

    cache_results(cache_manager, analysis_type, parameters, results, metadata)
  }

  message(sprintf("✓ Computed in %.2fs", elapsed))

  return(results)
}

#' Invalidate cached results
#'
#' @param cache_manager Cache manager object
#' @param analysis_type Type of analysis
#' @param parameters Analysis parameters
#' @return TRUE if cache was invalidated
invalidate_cache <- function(cache_manager, analysis_type, parameters) {
  if (is.null(cache_manager)) return(FALSE)

  tryCatch({
    result <- cache_manager$invalidate(analysis_type, parameters)
    if (result) {
      message(sprintf("✓ Invalidated cache for %s", analysis_type))
    }
    return(result)
  }, error = function(e) {
    warning(paste("Error invalidating cache:", e$message))
    return(FALSE)
  })
}

#' Get cache statistics
#'
#' @param cache_manager Cache manager object
#' @return List with cache statistics
get_cache_stats <- function(cache_manager) {
  if (is.null(cache_manager)) {
    return(list(
      total_entries = 0,
      total_size_mb = 0,
      error = "Cache manager not initialized"
    ))
  }

  tryCatch({
    stats <- cache_manager$get_stats()
    return(stats)
  }, error = function(e) {
    return(list(error = e$message))
  })
}

#' Clear old cache entries
#'
#' @param cache_manager Cache manager object
#' @param days Age threshold in days (default: 30)
#' @return Number of entries cleared
clear_old_cache <- function(cache_manager, days = 30) {
  if (is.null(cache_manager)) return(0)

  tryCatch({
    count <- cache_manager$clear_old(days = as.integer(days))
    message(sprintf("✓ Cleared %d cache entries older than %d days", count, days))
    return(count)
  }, error = function(e) {
    warning(paste("Error clearing cache:", e$message))
    return(0)
  })
}

#' Format cache stats for display
#'
#' @param stats Cache statistics from get_cache_stats()
#' @return HTML formatted stats
format_cache_stats <- function(stats) {
  if (!is.null(stats$error)) {
    return(tags$div(class = "alert alert-warning", stats$error))
  }

  tags$div(
    class = "cache-stats",
    h5("Cache Statistics"),
    tags$ul(
      tags$li(sprintf("Total entries: %d", stats$total_entries)),
      tags$li(sprintf("Total size: %.2f MB", stats$total_size_mb)),
      if (length(stats$analysis_types) > 0) {
        tags$li(
          "Analysis types:",
          tags$ul(
            lapply(names(stats$analysis_types), function(type) {
              tags$li(sprintf("%s: %d", type, stats$analysis_types[[type]]))
            })
          )
        )
      }
    )
  )
}
