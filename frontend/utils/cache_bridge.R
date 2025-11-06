# Cache Bridge - R Interface to FastAPI Cache Service
# Provides transparent caching for meta-analysis results via Redis
# Expected speedup: 100x for cache hits (5ms vs 500ms)

library(httr)
library(jsonlite)
library(digest)

# Cache service configuration
CACHE_SERVICE_URL <- Sys.getenv("CACHE_SERVICE_URL", "http://localhost:8000")
CACHE_ENABLED <- Sys.getenv("CACHE_ENABLED", "TRUE") == "TRUE"

#' Check if cache service is healthy
#'
#' @return Logical indicating if cache service is available
#' @export
is_cache_healthy <- function() {
  if (!CACHE_ENABLED) return(FALSE)

  tryCatch({
    response <- GET(paste0(CACHE_SERVICE_URL, "/health"), timeout(2))
    status_code(response) == 200
  }, error = function(e) {
    message("Cache service unavailable: ", e$message)
    FALSE
  })
}


#' Generate hash for data
#'
#' Creates SHA-256 hash of data for cache key generation
#' Ensures consistent hashing by sorting columns and rows
#'
#' @param data Data frame to hash
#' @return 32-character hash string
#' @export
hash_data <- function(data) {
  # Sort columns alphabetically for consistent hashing
  data_sorted <- data[, order(names(data)), drop = FALSE]

  # Sort rows if possible (for consistent hashing across identical datasets)
  if ("study_id" %in% names(data_sorted)) {
    data_sorted <- data_sorted[order(data_sorted$study_id), ]
  }

  # Create hash
  data_hash <- digest(data_sorted, algo = "sha256")

  # Return first 32 characters
  substr(data_hash, 1, 32)
}


#' Check cache for existing result
#'
#' @param data Data frame used in analysis
#' @param outcome Outcome variable name (can be NULL)
#' @param method Meta-analysis method (e.g., "REML", "DL")
#' @param model Model type (e.g., "random", "fixed")
#' @param subgroup Subgroup variable name (can be NULL)
#' @param moderators Vector of moderator variable names (can be NULL)
#' @return List with hit (TRUE/FALSE), result (if hit), source
#' @export
check_cache <- function(data, outcome = NULL, method = "REML",
                        model = "random", subgroup = NULL, moderators = NULL) {

  # If cache disabled or unhealthy, return miss
  if (!CACHE_ENABLED || !is_cache_healthy()) {
    return(list(hit = FALSE, result = NULL, source = "disabled"))
  }

  tryCatch({
    # Generate data hash
    data_hash <- hash_data(data)

    # Build request body
    request_body <- list(
      params = list(
        data_hash = data_hash,
        outcome = outcome %||% "",
        method = method,
        model = model,
        subgroup = subgroup %||% "",
        moderators = if (!is.null(moderators)) sort(moderators) else list()
      )
    )

    # Call cache service
    response <- POST(
      paste0(CACHE_SERVICE_URL, "/cache/check"),
      body = request_body,
      encode = "json",
      timeout(5)
    )

    if (status_code(response) != 200) {
      message("Cache check failed with status ", status_code(response))
      return(list(hit = FALSE, result = NULL, source = "error"))
    }

    # Parse response
    result <- content(response, as = "parsed", type = "application/json")

    if (result$hit) {
      message("✓ Cache HIT - Loading cached result (~5ms)")
      return(list(hit = TRUE, result = result$result, source = "cache"))
    } else {
      message("○ Cache MISS - Will compute and store result")
      return(list(hit = FALSE, result = NULL, source = "miss"))
    }

  }, error = function(e) {
    message("Cache check error: ", e$message)
    return(list(hit = FALSE, result = NULL, source = "error"))
  })
}


#' Store result in cache
#'
#' @param data Data frame used in analysis
#' @param result Meta-analysis result object to cache
#' @param outcome Outcome variable name (can be NULL)
#' @param method Meta-analysis method
#' @param model Model type
#' @param subgroup Subgroup variable name (can be NULL)
#' @param moderators Vector of moderator variable names (can be NULL)
#' @return Logical indicating success
#' @export
store_cache <- function(data, result, outcome = NULL, method = "REML",
                        model = "random", subgroup = NULL, moderators = NULL) {

  # If cache disabled, skip
  if (!CACHE_ENABLED || !is_cache_healthy()) {
    return(FALSE)
  }

  tryCatch({
    # Generate data hash
    data_hash <- hash_data(data)

    # Build request body
    request_body <- list(
      params = list(
        data_hash = data_hash,
        outcome = outcome %||% "",
        method = method,
        model = model,
        subgroup = subgroup %||% "",
        moderators = if (!is.null(moderators)) sort(moderators) else list()
      ),
      result = result
    )

    # Call cache service
    response <- POST(
      paste0(CACHE_SERVICE_URL, "/cache/store"),
      body = request_body,
      encode = "json",
      timeout(10)
    )

    if (status_code(response) == 200) {
      message("✓ Result cached successfully")
      return(TRUE)
    } else {
      message("Cache store failed with status ", status_code(response))
      return(FALSE)
    }

  }, error = function(e) {
    message("Cache store error: ", e$message)
    return(FALSE)
  })
}


#' Run meta-analysis with caching
#'
#' High-level wrapper that checks cache before computing
#' If result cached: returns in ~5ms (100x faster)
#' If not cached: computes, stores, and returns result (~500ms + cache overhead)
#'
#' @param data Data frame for meta-analysis
#' @param outcome Outcome variable name
#' @param method Meta-analysis method
#' @param model Model type
#' @param subgroup Subgroup variable name (optional)
#' @param moderators Vector of moderator names (optional)
#' @param compute_fn Function that computes the result (no arguments)
#' @return Meta-analysis result (from cache or fresh computation)
#' @export
#' @examples
#' \dontrun{
#' result <- with_cache(
#'   data = ma_data,
#'   outcome = "mortality",
#'   method = "REML",
#'   model = "random",
#'   compute_fn = function() {
#'     run_pairwise_ma(ma_data, outcome = "mortality", method = "REML")
#'   }
#' )
#' }
with_cache <- function(data, outcome = NULL, method = "REML", model = "random",
                       subgroup = NULL, moderators = NULL, compute_fn) {

  # Try cache first
  cache_result <- check_cache(
    data = data,
    outcome = outcome,
    method = method,
    model = model,
    subgroup = subgroup,
    moderators = moderators
  )

  # Cache HIT - return immediately
  if (cache_result$hit) {
    return(cache_result$result)
  }

  # Cache MISS - compute result
  message("⏱ Computing meta-analysis...")
  start_time <- Sys.time()

  result <- compute_fn()

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  message(sprintf("✓ Computation complete (%.2f seconds)", elapsed))

  # Store in cache for next time
  store_cache(
    data = data,
    result = result,
    outcome = outcome,
    method = method,
    model = model,
    subgroup = subgroup,
    moderators = moderators
  )

  return(result)
}


#' Get cache statistics
#'
#' @return List with cache stats (cached_analyses, total_memory_mb)
#' @export
cache_stats <- function() {
  if (!CACHE_ENABLED || !is_cache_healthy()) {
    return(list(
      status = "disabled",
      cached_analyses = 0,
      total_memory_mb = 0
    ))
  }

  tryCatch({
    response <- GET(paste0(CACHE_SERVICE_URL, "/cache/stats"), timeout(5))

    if (status_code(response) == 200) {
      content(response, as = "parsed", type = "application/json")
    } else {
      list(status = "error", cached_analyses = 0, total_memory_mb = 0)
    }
  }, error = function(e) {
    message("Error fetching cache stats: ", e$message)
    list(status = "error", cached_analyses = 0, total_memory_mb = 0)
  })
}


#' Clear all cached results
#'
#' @return Logical indicating success
#' @export
clear_cache <- function() {
  if (!CACHE_ENABLED || !is_cache_healthy()) {
    message("Cache is disabled or unavailable")
    return(FALSE)
  }

  tryCatch({
    response <- POST(paste0(CACHE_SERVICE_URL, "/cache/clear"), timeout(5))

    if (status_code(response) == 200) {
      message("✓ Cache cleared successfully")
      return(TRUE)
    } else {
      message("Cache clear failed with status ", status_code(response))
      return(FALSE)
    }
  }, error = function(e) {
    message("Error clearing cache: ", e$message)
    return(FALSE)
  })
}


#' Null-coalescing operator
#'
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
