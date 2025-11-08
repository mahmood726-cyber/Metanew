# Event Bus - Decoupled Inter-Module Communication
# MIT Legible Software Architecture Component
# Version: 2.0.0
#
# Purpose: Replace shared reactive values (rv) with explicit event-driven communication
# Benefits:
#   - Modules don't share mutable state
#   - Dependencies are explicit (subscribe to events)
#   - Easy to trace data flow
#   - LLM-safe (can't accidentally break other modules)

library(R6)
library(digest)
library(jsonlite)

#' EventBus Class
#'
#' Implements publish-subscribe pattern for module communication.
#' Modules publish events when they complete work, other modules subscribe to those events.
#'
#' @export
EventBus <- R6Class("EventBus",
  public = list(

    #' @field subscribers List of subscriptions (event -> list of callbacks)
    subscribers = NULL,

    #' @field event_history Log of all events published
    event_history = NULL,

    #' @field event_schemas Expected schema for each event type
    event_schemas = NULL,

    #' @description
    #' Initialize EventBus
    #' @param log_events Whether to log events to history (default TRUE)
    initialize = function(log_events = TRUE) {
      self$subscribers <- list()
      self$event_history <- list()
      self$event_schemas <- list()
      private$log_events <- log_events

      message("EventBus initialized")
    },

    #' @description
    #' Register event schema for validation
    #' @param event_name Name of event type
    #' @param schema List defining expected data structure
    #' @examples
    #' bus$register_schema("data_validated", list(
    #'   required_fields = c("data", "validation_result"),
    #'   types = list(data = "data.frame", validation_result = "list")
    #' ))
    register_schema = function(event_name, schema) {
      self$event_schemas[[event_name]] <- schema
      message(sprintf("Schema registered for event: %s", event_name))
    },

    #' @description
    #' Subscribe to an event
    #' @param event_name Name of event to listen for
    #' @param callback Function to call when event occurs (receives event_data)
    #' @param subscriber_id Unique ID for this subscriber (for debugging)
    #' @return subscription_id (use to unsubscribe later)
    #' @examples
    #' bus$subscribe("data_validated", function(data) {
    #'   print("Data is ready!")
    #'   # Use data$validated_data
    #' }, subscriber_id = "meta_pairwise")
    subscribe = function(event_name, callback, subscriber_id = NULL) {
      if (!is.function(callback)) {
        stop("Callback must be a function")
      }

      # Initialize subscriber list for this event if needed
      if (is.null(self$subscribers[[event_name]])) {
        self$subscribers[[event_name]] <- list()
      }

      # Generate subscription ID
      sub_id <- digest(paste0(event_name, Sys.time(), runif(1)))

      # Store subscription
      self$subscribers[[event_name]][[sub_id]] <- list(
        callback = callback,
        subscriber_id = subscriber_id,
        subscribed_at = Sys.time()
      )

      message(sprintf("Subscribed: %s -> %s (sub_id: %s)",
                     subscriber_id %||% "anonymous",
                     event_name,
                     substr(sub_id, 1, 8)))

      return(sub_id)
    },

    #' @description
    #' Unsubscribe from an event
    #' @param event_name Event name
    #' @param subscription_id ID returned from subscribe()
    unsubscribe = function(event_name, subscription_id) {
      if (!is.null(self$subscribers[[event_name]])) {
        self$subscribers[[event_name]][[subscription_id]] <- NULL

        # Clean up if no more subscribers
        if (length(self$subscribers[[event_name]]) == 0) {
          self$subscribers[[event_name]] <- NULL
        }
      }
    },

    #' @description
    #' Publish an event (notify all subscribers)
    #' @param event_name Name of event
    #' @param event_data Data to pass to subscribers
    #' @param publisher_id ID of publishing module (for debugging)
    #' @examples
    #' bus$publish("data_validated", list(
    #'   validated_data = my_data,
    #'   validation_result = result
    #' ), publisher_id = "data_import")
    publish = function(event_name, event_data = NULL, publisher_id = NULL) {

      # Validate event data against schema if registered
      if (!is.null(self$event_schemas[[event_name]])) {
        private$validate_event_data(event_name, event_data)
      }

      # Log event
      if (private$log_events) {
        event_entry <- list(
          event_name = event_name,
          publisher_id = publisher_id,
          timestamp = Sys.time(),
          data_hash = digest(event_data)
        )
        self$event_history[[length(self$event_history) + 1]] <- event_entry
      }

      message(sprintf("Event published: %s (from: %s)",
                     event_name,
                     publisher_id %||% "anonymous"))

      # Notify all subscribers
      if (!is.null(self$subscribers[[event_name]])) {
        for (sub_id in names(self$subscribers[[event_name]])) {
          subscription <- self$subscribers[[event_name]][[sub_id]]

          tryCatch({
            # Call subscriber callback with event data
            subscription$callback(event_data)

            message(sprintf("  -> Notified: %s",
                           subscription$subscriber_id %||% "anonymous"))

          }, error = function(e) {
            warning(sprintf("Subscriber error in %s: %s",
                           subscription$subscriber_id %||% "unknown",
                           e$message))
          })
        }
      } else {
        message(sprintf("  (no subscribers for %s)", event_name))
      }

      invisible(self)
    },

    #' @description
    #' Wait for an event (blocking, for testing)
    #' @param event_name Event to wait for
    #' @param timeout_seconds Timeout in seconds (default 30)
    #' @return event_data or NULL if timeout
    wait_for = function(event_name, timeout_seconds = 30) {
      result <- NULL
      received <- FALSE

      # Temporary subscription
      sub_id <- self$subscribe(event_name, function(data) {
        result <<- data
        received <<- TRUE
      }, subscriber_id = "wait_for_temp")

      # Wait loop
      start_time <- Sys.time()
      while (!received && difftime(Sys.time(), start_time, units = "secs") < timeout_seconds) {
        Sys.sleep(0.1)
      }

      # Cleanup
      self$unsubscribe(event_name, sub_id)

      return(result)
    },

    #' @description
    #' Get event history
    #' @param n Number of recent events to return (default: all)
    #' @return data.frame of events
    get_history = function(n = NULL) {
      if (length(self$event_history) == 0) {
        return(data.frame())
      }

      df <- do.call(rbind, lapply(self$event_history, function(e) {
        data.frame(
          event_name = e$event_name,
          publisher_id = e$publisher_id %||% NA,
          timestamp = as.character(e$timestamp),
          data_hash = e$data_hash,
          stringsAsFactors = FALSE
        )
      }))

      if (!is.null(n) && nrow(df) > n) {
        df <- tail(df, n)
      }

      return(df)
    },

    #' @description
    #' Clear event history
    clear_history = function() {
      self$event_history <- list()
      message("Event history cleared")
    },

    #' @description
    #' Get current subscribers for an event
    #' @param event_name Event name (NULL for all events)
    get_subscribers = function(event_name = NULL) {
      if (is.null(event_name)) {
        # Return all subscriptions
        result <- list()
        for (event in names(self$subscribers)) {
          result[[event]] <- sapply(self$subscribers[[event]], function(s) {
            s$subscriber_id %||% "anonymous"
          })
        }
        return(result)
      } else {
        # Return subscribers for specific event
        if (is.null(self$subscribers[[event_name]])) {
          return(character(0))
        }
        return(sapply(self$subscribers[[event_name]], function(s) {
          s$subscriber_id %||% "anonymous"
        }))
      }
    },

    #' @description
    #' Print event bus status
    print = function() {
      cat("EventBus Status\n")
      cat("===============\n")
      cat(sprintf("Total events published: %d\n", length(self$event_history)))
      cat(sprintf("Active event types: %d\n", length(self$subscribers)))

      if (length(self$subscribers) > 0) {
        cat("\nSubscriptions:\n")
        for (event_name in names(self$subscribers)) {
          subs <- self$get_subscribers(event_name)
          cat(sprintf("  %s (%d subscribers)\n", event_name, length(subs)))
          for (sub in subs) {
            cat(sprintf("    - %s\n", sub))
          }
        }
      }

      if (length(self$event_schemas) > 0) {
        cat(sprintf("\nRegistered schemas: %d\n", length(self$event_schemas)))
      }

      invisible(self)
    }
  ),

  private = list(
    log_events = TRUE,

    #' Validate event data against schema
    #' @param event_name Event name
    #' @param event_data Data to validate
    validate_event_data = function(event_name, event_data) {
      schema <- self$event_schemas[[event_name]]

      # Check required fields
      if (!is.null(schema$required_fields)) {
        for (field in schema$required_fields) {
          if (is.null(event_data[[field]])) {
            stop(sprintf("Event %s missing required field: %s", event_name, field))
          }
        }
      }

      # Check types
      if (!is.null(schema$types)) {
        for (field in names(schema$types)) {
          expected_type <- schema$types[[field]]
          actual_value <- event_data[[field]]

          if (!is.null(actual_value)) {
            valid <- switch(expected_type,
              "data.frame" = is.data.frame(actual_value),
              "list" = is.list(actual_value),
              "numeric" = is.numeric(actual_value),
              "character" = is.character(actual_value),
              "integer" = is.integer(actual_value),
              "logical" = is.logical(actual_value),
              TRUE  # Unknown type, skip validation
            )

            if (!valid) {
              stop(sprintf("Event %s field '%s' has wrong type (expected: %s)",
                          event_name, field, expected_type))
            }
          }
        }
      }
    }
  )
)


# ==============================================================================
# HELPER OPERATORS
# ==============================================================================

#' Null coalescing operator
#' @param a First value
#' @param b Default value if a is NULL
`%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# FACTORY FUNCTION
# ==============================================================================

#' Create a new EventBus instance
#'
#' @param log_events Whether to log events to history (default TRUE)
#' @return EventBus instance
#' @export
#' @examples
#' bus <- create_event_bus()
#' bus$subscribe("data_ready", function(data) { print("Got data!") })
#' bus$publish("data_ready", list(data = mtcars))
create_event_bus <- function(log_events = TRUE) {
  EventBus$new(log_events = log_events)
}


# ==============================================================================
# STANDARD EVENT TYPES (from module_contracts.yaml)
# ==============================================================================

#' Standard event type constants
#' @export
EVENTS <- list(
  # Data events
  DATA_VALIDATED = "data_validated",
  DATA_UPDATED = "data_updated",

  # Protocol events
  PROTOCOL_DEFINED = "protocol_defined",
  PROTOCOL_LOCKED = "protocol_locked",

  # Analysis events
  PAIRWISE_COMPLETE = "pairwise_complete",
  NMA_COMPLETE = "nma_complete",
  DR_COMPLETE = "dr_complete",
  SENSITIVITY_COMPLETE = "sensitivity_complete",

  # Health economics events
  HE_PARAMS_DEFINED = "he_params_defined",
  HE_MODEL_COMPLETE = "he_model_complete",
  BCEA_COMPLETE = "bcea_complete",
  BIA_COMPLETE = "bia_complete",

  # Output events
  REPORT_GENERATED = "report_generated",
  PORTAL_GENERATED = "portal_generated",

  # Living MA events
  LIVING_MA_UPDATED = "living_ma_updated",

  # System events
  SESSION_SAVED = "session_saved",
  SESSION_LOADED = "session_loaded",
  ERROR_OCCURRED = "error_occurred"
)


# ==============================================================================
# USAGE EXAMPLES
# ==============================================================================

if (FALSE) {
  # Example 1: Basic publish-subscribe
  bus <- create_event_bus()

  bus$subscribe("data_validated", function(data) {
    print("Meta-analysis module received data!")
    print(head(data$validated_data))
  }, subscriber_id = "meta_pairwise")

  bus$publish("data_validated", list(
    validated_data = mtcars,
    validation_result = list(valid = TRUE)
  ), publisher_id = "data_import")


  # Example 2: With schema validation
  bus$register_schema("pairwise_complete", list(
    required_fields = c("estimate", "se", "ci_lower", "ci_upper"),
    types = list(
      estimate = "numeric",
      se = "numeric",
      ci_lower = "numeric",
      ci_upper = "numeric"
    )
  ))

  bus$publish("pairwise_complete", list(
    estimate = 0.5,
    se = 0.2,
    ci_lower = 0.1,
    ci_upper = 0.9
  ), publisher_id = "meta_pairwise")


  # Example 3: Multiple subscribers
  bus$subscribe("pairwise_complete", function(data) {
    print("Sensitivity module updating...")
  }, subscriber_id = "sensitivity")

  bus$subscribe("pairwise_complete", function(data) {
    print("HE model integrating results...")
  }, subscriber_id = "he_model")

  bus$subscribe("pairwise_complete", function(data) {
    print("Reporting module preparing...")
  }, subscriber_id = "reporting")

  # One publish notifies all 3 subscribers
  bus$publish("pairwise_complete", list(estimate = 0.5, se = 0.2, ci_lower = 0.1, ci_upper = 0.9))


  # Example 4: Check status
  bus$print()
  history <- bus$get_history()
  print(history)
}
