# MODULE TEMPLATE - Legible Software Architecture
# Version: 2.0.0
#
# This template shows how to write modules that follow MIT "Legible Software" principles
#
# KEY PRINCIPLES:
#   1. No shared state (rv) - use EventBus and DataStore
#   2. Explicit contracts - declare what you consume/produce
#   3. Event-driven - publish events when work completes
#   4. Schema validation - validate all inputs/outputs
#   5. LLM-safe - changes won't break other modules

library(shiny)

# ==============================================================================
# MODULE CONTRACT (matches config/module_contracts.yaml)
# ==============================================================================

# This module's contract from module_contracts.yaml:
#
# example_module:
#   description: "What this module does"
#   user_value: "Why users care about this"
#
#   consumes:
#     input_data:
#       source: "data_store"           # Which store to read from
#       required: true                 # Is this required?
#       validation: "must have x, y, z columns"
#
#   produces:
#     output_results:
#       type: "list"
#       schema:
#         required_fields: ["field1", "field2"]
#       destination: "results_store"   # Which store to write to
#
#   api_calls:
#     - endpoint: "/example"
#       purpose: "Do something"
#
#   can_fail: true
#   failure_modes:
#     - "Not enough data"

# ==============================================================================
# UI FUNCTION (Unchanged from old pattern)
# ==============================================================================

example_module_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Your UI definition here
    # This is unchanged from the old architecture

    card(
      card_header("Example Module"),

      # Inputs
      selectInput(ns("input_option"), "Option", choices = c("A", "B", "C")),

      # Action button
      actionButton(ns("btn_run"), "Run Analysis", class = "btn-primary"),

      # Outputs
      verbatimTextOutput(ns("results"))
    )
  )
}

# ==============================================================================
# SERVER FUNCTION (NEW PATTERN - Event-driven, no shared rv)
# ==============================================================================

example_module_server <- function(id, rv = NULL, event_bus = NULL, data_store = NULL) {
  moduleServer(id, function(input, output, session) {

    # ========================================================================
    # MODULE ID (for event publishing and store access)
    # ========================================================================

    MODULE_ID <- "example_module"

    # ========================================================================
    # BACKWARDS COMPATIBILITY
    # ========================================================================
    #
    # During migration, modules receive both rv and event_bus/data_store
    # Eventually, rv will be removed and only event_bus/data_store used
    #

    use_new_architecture <- !is.null(event_bus) && !is.null(data_store)

    if (use_new_architecture) {
      message(sprintf("Module %s using new architecture", MODULE_ID))
    } else {
      message(sprintf("Module %s using legacy rv architecture", MODULE_ID))
    }

    # ========================================================================
    # CONSUME DATA (from DataStore or rv)
    # ========================================================================

    # NEW PATTERN: Read from DataStore
    input_data <- reactive({
      if (use_new_architecture) {
        # Check if data available
        if (!data_store$has_data("data_store")) {
          return(NULL)
        }

        # Read from store (access control enforced)
        data <- data_store$read("data_store", reader_id = MODULE_ID)

        # Validate schema (optional but recommended)
        # validate_data_schema(data)

        return(data)

      } else {
        # OLD PATTERN: Read from rv
        return(rv$data)
      }
    })

    # ========================================================================
    # SUBSCRIBE TO EVENTS (only if using new architecture)
    # ========================================================================

    if (use_new_architecture) {

      # Subscribe to events this module cares about
      # Example: When data is validated, enable UI
      event_bus$subscribe(EVENTS$DATA_VALIDATED, function(event_data) {
        message(sprintf("%s received DATA_VALIDATED event", MODULE_ID))

        # Update UI or trigger re-computation
        # shinyjs::enable("btn_run")

      }, subscriber_id = MODULE_ID)

      # Example: When parameters change, invalidate results
      event_bus$subscribe(EVENTS$HE_PARAMS_DEFINED, function(event_data) {
        message(sprintf("%s received HE_PARAMS_DEFINED event", MODULE_ID))

        # Clear old results
        # results_storage$clear()

      }, subscriber_id = MODULE_ID)
    }

    # ========================================================================
    # MAIN COMPUTATION
    # ========================================================================

    # Store results locally in reactive
    results_storage <- reactiveVal(NULL)

    observeEvent(input$btn_run, {

      # --------------------------------------------------------------------
      # 1. VALIDATE DEPENDENCIES
      # --------------------------------------------------------------------

      data <- input_data()

      if (is.null(data)) {
        showNotification("No data available", type = "warning")
        return(NULL)
      }

      # Additional validation
      if (nrow(data) < 2) {
        showNotification("Need at least 2 rows", type = "error")
        return(NULL)
      }

      # --------------------------------------------------------------------
      # 2. PERFORM COMPUTATION
      # --------------------------------------------------------------------

      tryCatch({

        # Show progress
        withProgress(message = "Computing...", {

          # Your analysis code here
          results <- list(
            summary = "Example results",
            estimate = 0.5,
            se = 0.2,
            ci_lower = 0.1,
            ci_upper = 0.9,
            k = nrow(data),
            computed_at = Sys.time()
          )

          # Store locally
          results_storage(results)

          # --------------------------------------------------------------------
          # 3. VALIDATE OUTPUT (against contract)
          # --------------------------------------------------------------------

          # Check required fields present
          required_fields <- c("estimate", "se", "ci_lower", "ci_upper")
          for (field in required_fields) {
            if (is.null(results[[field]])) {
              stop(sprintf("Missing required field: %s", field))
            }
          }

          # --------------------------------------------------------------------
          # 4. WRITE TO DATASTORE (if using new architecture)
          # --------------------------------------------------------------------

          if (use_new_architecture) {

            # Write to designated store
            data_store$write(
              store_name = "analysis_results_store",
              data = list(
                example_module = results
              ),
              writer_id = MODULE_ID
            )

            message(sprintf("%s wrote results to analysis_results_store", MODULE_ID))

          } else {
            # OLD PATTERN: Write to rv
            rv$example_results <- results
          }

          # --------------------------------------------------------------------
          # 5. PUBLISH EVENT (if using new architecture)
          # --------------------------------------------------------------------

          if (use_new_architecture) {

            # Publish completion event
            event_bus$publish(
              event_name = "example_module_complete",
              event_data = results,
              publisher_id = MODULE_ID
            )

            message(sprintf("%s published example_module_complete event", MODULE_ID))

            # Also publish standard completion events
            # event_bus$publish(EVENTS$PAIRWISE_COMPLETE, results, MODULE_ID)
          }

          # --------------------------------------------------------------------
          # 6. ADD AUDIT ENTRY
          # --------------------------------------------------------------------

          if (use_new_architecture) {
            # Audit is automatic in DataStore
          } else {
            # OLD PATTERN: Manual audit entry
            add_audit_entry(rv, "example_analysis_run", list(
              n_rows = nrow(data),
              estimate = results$estimate
            ))
          }

          # Show success notification
          showNotification(
            "Analysis complete!",
            type = "message",
            duration = 3
          )
        })

      }, error = function(e) {
        showNotification(
          paste("Error:", e$message),
          type = "error",
          duration = 10
        )

        # Publish error event
        if (use_new_architecture) {
          event_bus$publish(EVENTS$ERROR_OCCURRED, list(
            module_id = MODULE_ID,
            error = e$message,
            timestamp = Sys.time()
          ), publisher_id = MODULE_ID)
        }
      })
    })

    # ========================================================================
    # OUTPUT RENDERING
    # ========================================================================

    output$results <- renderText({
      res <- results_storage()

      if (is.null(res)) {
        return("No results yet. Click 'Run Analysis'.")
      }

      sprintf(
        "Results:\n  Estimate: %.3f (95%% CI: %.3f to %.3f)\n  SE: %.3f\n  k: %d\n  Computed: %s",
        res$estimate,
        res$ci_lower,
        res$ci_upper,
        res$se,
        res$k,
        format(res$computed_at, "%Y-%m-%d %H:%M:%S")
      )
    })

    # ========================================================================
    # RETURN VALUE
    # ========================================================================
    #
    # NEW PATTERN: Return reactive that exposes results
    # Consumers should subscribe to events, not read return value directly
    #

    return(reactive({
      list(
        results = results_storage(),
        status = if (is.null(results_storage())) "not_run" else "complete",
        module_id = MODULE_ID
      )
    }))
  })
}

# ==============================================================================
# VALIDATION HELPERS (Optional but recommended)
# ==============================================================================

#' Validate data schema
#' @param data Data to validate
validate_data_schema <- function(data) {
  # Check type
  if (!is.data.frame(data)) {
    stop("Expected data.frame")
  }

  # Check required columns
  required_cols <- c("study_id", "yi", "sei")
  for (col in required_cols) {
    if (!col %in% names(data)) {
      stop(sprintf("Missing required column: %s", col))
    }
  }

  # Check column types
  if (!is.numeric(data$yi)) {
    stop("Column 'yi' must be numeric")
  }

  if (!is.numeric(data$sei)) {
    stop("Column 'sei' must be numeric")
  }

  # Check constraints
  if (any(data$sei <= 0, na.rm = TRUE)) {
    stop("Column 'sei' must be > 0")
  }

  invisible(TRUE)
}

# ==============================================================================
# USAGE NOTES
# ==============================================================================

# 1. To create a new module:
#    - Copy this template
#    - Update MODULE_ID
#    - Define your UI
#    - Implement computation logic
#    - Add entry to config/module_contracts.yaml
#
# 2. To consume data:
#    - Use data_store$read(store_name, reader_id = MODULE_ID)
#    - Don't access rv directly (unless in compat mode)
#
# 3. To produce data:
#    - Use data_store$write(store_name, data, writer_id = MODULE_ID)
#    - Publish event when done
#
# 4. To depend on other modules:
#    - Subscribe to their completion events
#    - Read their data from DataStore
#    - Don't access their rv fields directly
#
# 5. LLM Safety:
#    - When LLM modifies this module, it will:
#      * Read module_contracts.yaml to understand dependencies
#      * See explicit read/write operations
#      * Know which events to publish
#      * Validate against schemas
#    - This makes breaking changes much less likely!

# ==============================================================================
# MIGRATION STRATEGY
# ==============================================================================

# Phase 1: Dual mode (current)
#   - Module accepts both rv and event_bus/data_store
#   - Reads from rv if event_bus is NULL
#   - Writes to both rv and event_bus/data_store
#
# Phase 2: Event_bus primary
#   - Module prefers event_bus/data_store
#   - rv is only for backwards compat
#
# Phase 3: Pure event-driven
#   - Remove rv parameter entirely
#   - All communication via EventBus
#   - All state in DataStore
