# Python Bridge Utilities
# Functions to call Python FastAPI backend

library(httr)
library(jsonlite)

# API base URL
API_BASE <- Sys.getenv("API_BASE_URL", "http://localhost:8000")

# Health check
check_api_health <- function() {
  tryCatch({
    response <- GET(paste0(API_BASE, "/health"))
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

  response <- POST(
    url,
    body = body,
    encode = "json",
    content_type_json()
  )

  if (status_code(response) == 200) {
    content(response)
  } else {
    stop("Validation API error: ", content(response)$detail)
  }
}

# Compute effect sizes via API
compute_yi_via_api <- function(data, measure) {
  url <- paste0(API_BASE, "/compute/yi")

  body <- list(
    data = jsonlite::toJSON(data, dataframe = "rows", auto_unbox = FALSE),
    measure = measure
  )

  response <- POST(
    url,
    body = body,
    encode = "json",
    content_type_json()
  )

  if (status_code(response) == 200) {
    result <- content(response)
    result$data <- as.data.frame(do.call(rbind, result$data))
    return(result)
  } else {
    stop("Effect size computation error: ", content(response)$detail)
  }
}

# Compute evidence hash
compute_evidence_hash <- function(evidence_object) {
  url <- paste0(API_BASE, "/evidence/hash")

  response <- POST(
    url,
    body = evidence_object,
    encode = "json",
    content_type_json()
  )

  if (status_code(response) == 200) {
    content(response)
  } else {
    stop("Hash computation error")
  }
}

# Validate evidence object
validate_evidence_object <- function(evidence_object) {
  url <- paste0(API_BASE, "/evidence/validate")

  response <- POST(
    url,
    body = evidence_object,
    encode = "json",
    content_type_json()
  )

  if (status_code(response) == 200) {
    content(response)
  } else {
    stop("Evidence validation error: ", content(response)$detail)
  }
}
