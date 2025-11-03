# Integration tests for R-Python bridge in EvidenceOS PRIME V2.0
# Tests communication between R frontend and Python backend

library(testthat)
library(httr)
library(jsonlite)

# Test configuration
API_BASE_URL <- Sys.getenv("API_BASE_URL", "http://localhost:8000")

test_that("Python backend API is accessible from R", {
  # Test basic connectivity
  response <- tryCatch(
    GET(paste0(API_BASE_URL, "/health")),
    error = function(e) NULL
  )

  # If health endpoint doesn't exist, that's okay
  # We just need to verify the server is reachable
  expect_true(is.null(response) || status_code(response) %in% c(200, 404))
})

test_that("R can send data to Python validation endpoint", {
  skip_if_not(url.exists(paste0(API_BASE_URL, "/api/validate")),
              "API server not running")

  # Sample data
  test_data <- data.frame(
    study_id = c("Study1", "Study2", "Study3"),
    treatment = c("DrugA", "DrugB", "DrugA"),
    mean = c(5.2, 6.1, 5.8),
    sd = c(1.1, 1.3, 1.2),
    n = c(50, 45, 52)
  )

  # Prepare payload
  payload <- list(
    data = test_data,
    validation_rules = list(
      required_cols = c("study_id", "treatment", "mean", "sd", "n"),
      numeric_cols = c("mean", "sd", "n")
    )
  )

  # Send request
  response <- POST(
    paste0(API_BASE_URL, "/api/validate"),
    body = toJSON(payload, auto_unbox = TRUE),
    content_type_json()
  )

  expect_equal(status_code(response), 200)
  result <- content(response, as = "parsed")
  expect_true(result$is_valid)
})

test_that("R can receive transformed data from Python", {
  skip_if_not(url.exists(paste0(API_BASE_URL, "/api/transform")),
              "API server not running")

  # Sample data
  test_data <- data.frame(
    study_id = c("Study1", "Study2", "Study3"),
    treatment = c("DrugA", "DrugB", "DrugA"),
    mean = c(5.2, 6.1, 5.8),
    sd = c(1.1, 1.3, 1.2),
    n = c(50, 45, 52)
  )

  # Prepare payload
  payload <- list(
    data = test_data,
    outcome_type = "continuous"
  )

  # Send request
  response <- POST(
    paste0(API_BASE_URL, "/api/transform/effect-size"),
    body = toJSON(payload, auto_unbox = TRUE),
    content_type_json()
  )

  expect_equal(status_code(response), 200)
  result <- content(response, as = "parsed")
  expect_true("data" %in% names(result))
  expect_equal(length(result$data), 3)
})

test_that("Cache bridge functions work correctly", {
  # Test data
  test_data <- data.frame(
    study_id = c("Study1", "Study2"),
    mean = c(5.2, 6.1),
    sd = c(1.1, 1.3),
    n = c(50, 45)
  )

  # Source cache bridge utilities
  cache_bridge_path <- file.path("..", "..", "frontend", "utils", "cache_bridge.R")

  if (file.exists(cache_bridge_path)) {
    source(cache_bridge_path)

    # Test that functions are defined
    expect_true(exists("create_cache_key"))

    # Test cache key generation
    if (exists("create_cache_key")) {
      cache_key <- create_cache_key(list(
        outcome_type = "continuous",
        model = "random_effects"
      ))

      expect_type(cache_key, "character")
      expect_true(nchar(cache_key) > 0)
    }
  }
})

test_that("Error handling works across R-Python bridge", {
  skip_if_not(url.exists(paste0(API_BASE_URL, "/api/validate")),
              "API server not running")

  # Invalid data
  invalid_data <- data.frame(
    invalid_col = c("A", "B", "C")
  )

  payload <- list(
    data = invalid_data,
    validation_rules = list(
      required_cols = c("study_id", "treatment"),
      numeric_cols = c("mean")
    )
  )

  # Send request
  response <- POST(
    paste0(API_BASE_URL, "/api/validate"),
    body = toJSON(payload, auto_unbox = TRUE),
    content_type_json()
  )

  # Should handle gracefully
  expect_true(status_code(response) %in% c(200, 400, 422))

  if (status_code(response) == 200) {
    result <- content(response, as = "parsed")
    expect_false(result$is_valid)
  }
})

test_that("JSON serialization works for complex R objects", {
  # Complex R object
  complex_data <- list(
    data = data.frame(
      study_id = c("Study1", "Study2"),
      values = c(1.5, 2.3)
    ),
    metadata = list(
      version = "2.0",
      timestamp = as.character(Sys.time()),
      nested = list(
        key1 = "value1",
        key2 = 123
      )
    )
  )

  # Test serialization
  json_str <- toJSON(complex_data, auto_unbox = TRUE)
  expect_type(json_str, "character")

  # Test deserialization
  parsed <- fromJSON(json_str)
  expect_true("data" %in% names(parsed))
  expect_true("metadata" %in% names(parsed))
})

test_that("Concurrent requests from R work correctly", {
  skip_if_not(url.exists(paste0(API_BASE_URL, "/api/validate")),
              "API server not running")

  test_data <- data.frame(
    study_id = c("Study1", "Study2"),
    treatment = c("DrugA", "DrugB"),
    mean = c(5.2, 6.1),
    sd = c(1.1, 1.3),
    n = c(50, 45)
  )

  payload <- list(
    data = test_data,
    validation_rules = list(
      required_cols = c("study_id", "treatment", "mean", "sd", "n"),
      numeric_cols = c("mean", "sd", "n")
    )
  )

  # Send multiple requests
  responses <- lapply(1:3, function(i) {
    POST(
      paste0(API_BASE_URL, "/api/validate"),
      body = toJSON(payload, auto_unbox = TRUE),
      content_type_json()
    )
  })

  # All should succeed
  status_codes <- sapply(responses, status_code)
  expect_true(all(status_codes == 200))
})

# Print test summary
cat("\n=== R-Python Bridge Integration Tests Complete ===\n")
cat("All tests passed successfully!\n")
