# Python Bridge Utilities - WITH RETRY LOGIC
# Functions to call Python FastAPI backend

library(httr)
library(jsonlite)

# API base URL
API_BASE <- Sys.getenv("API_BASE_URL", "http://localhost:8000")

# Retry wrapper with exponential backoff
retry_api_call <- function(func, max_retries = 4, initial_delay = 2) {
  """
  Wrapper for API calls with exponential backoff retry logic
  Args:
    func: Function to call (should return httr response)
    max_retries: Maximum number of retry attempts (default 4)
    initial_delay: Initial delay in seconds (default 2)
  """
  delays <- initial_delay * 2^(0:(max_retries - 1))  # Exponential: 2, 4, 8, 16

  for (attempt in 1:max_retries) {
    result <- tryCatch({
      func()
    }, error = function(e) {
      if (attempt < max_retries) {
        message(sprintf("API call failed (attempt %d/%d): %s. Retrying in %ds...",
                       attempt, max_retries, e$message, delays[attempt]))
        Sys.sleep(delays[attempt])
        NULL
      } else {
        # Final attempt failed - try R fallback if available
        message(sprintf("API call failed after %d attempts. Error: %s",
                       max_retries, e$message))
        NULL
      }
    })

    if (!is.null(result)) {
      return(result)
    }
  }

  # All retries failed
  stop("API call failed after ", max_retries, " attempts. Falling back to R-only mode.")
}

# Health check
check_api_health <- function() {
  tryCatch({
    response <- GET(paste0(API_BASE, "/health"), timeout(5))
    if (status_code(response) == 200) {
      list(healthy = TRUE, response = content(response))
    } else {
      list(healthy = FALSE, error = "API returned non-200 status")
    }
  }, error = function(e) {
    list(healthy = FALSE, error = e$message)
  })
}

# Validate data via API
validate_via_api <- function(data, data_type) {
  url <- paste0(API_BASE, "/validate")

  body <- list(
    data = jsonlite::toJSON(data, dataframe = "rows", auto_unbox = FALSE),
    data_type = data_type
  )

  # Use retry wrapper
  retry_api_call(function() {
    response <- POST(
      url,
      body = body,
      encode = "json",
      content_type_json(),
      timeout(10)
    )

    if (status_code(response) == 200) {
      return(content(response))
    } else {
      stop("Validation API error: ", content(response)$detail)
    }
  })
}

# Compute effect sizes via API
compute_yi_via_api <- function(data, measure) {
  url <- paste0(API_BASE, "/compute/yi")

  body <- list(
    data = jsonlite::toJSON(data, dataframe = "rows", auto_unbox = FALSE),
    measure = measure
  )

  # Use retry wrapper
  retry_api_call(function() {
    response <- POST(
      url,
      body = body,
      encode = "json",
      content_type_json(),
      timeout(10)
    )

    if (status_code(response) == 200) {
      result <- content(response)
      result$data <- as.data.frame(do.call(rbind, result$data))
      return(result)
    } else {
      stop("Effect size computation error: ", content(response)$detail)
    }
  })
}

# Compute evidence hash
compute_evidence_hash <- function(evidence_object) {
  url <- paste0(API_BASE, "/evidence/hash")

  # Use retry wrapper
  retry_api_call(function() {
    response <- POST(
      url,
      body = evidence_object,
      encode = "json",
      content_type_json(),
      timeout(10)
    )

    if (status_code(response) == 200) {
      return(content(response))
    } else {
      stop("Hash computation error")
    }
  })
}

# Validate evidence object
validate_evidence_object <- function(evidence_object) {
  url <- paste0(API_BASE, "/evidence/validate")

  # Use retry wrapper
  retry_api_call(function() {
    response <- POST(
      url,
      body = evidence_object,
      encode = "json",
      content_type_json(),
      timeout(10)
    )

    if (status_code(response) == 200) {
      return(content(response))
    } else {
      stop("Evidence validation error: ", content(response)$detail)
    }
  })
}
