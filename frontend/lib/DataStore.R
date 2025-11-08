# Data Store - Centralized State Management with Access Control
# MIT Legible Software Architecture Component
# Version: 2.0.0
#
# Purpose: Replace shared reactive values with explicit stores
# Benefits:
#   - Clear ownership (who can read/write)
#   - Immutability enforcement
#   - Schema validation on write
#   - Audit trail of all changes
#   - Version control for living MA

library(R6)
library(digest)
library(jsonlite)

#' DataStore Class
#'
#' Centralized storage with access control and validation.
#' Replaces the monolithic `rv` object with typed, validated stores.
#'
#' @export
DataStore <- R6Class("DataStore",
  public = list(

    #' @field stores List of named stores
    stores = NULL,

    #' @field schemas Schema definitions for each store
    schemas = NULL,

    #' @field access_control Who can read/write each store
    access_control = NULL,

    #' @field audit_log Log of all store operations
    audit_log = NULL,

    #' @description
    #' Initialize DataStore
    #' @param config_file Path to module_contracts.yaml (optional)
    initialize = function(config_file = NULL) {
      self$stores <- list()
      self$schemas <- list()
      self$access_control <- list()
      self$audit_log <- list()

      # Load configuration if provided
      if (!is.null(config_file) && file.exists(config_file)) {
        private$load_config(config_file)
      }

      message("DataStore initialized")
    },

    #' @description
    #' Create a new store
    #' @param store_name Name of store
    #' @param schema Schema definition (list)
    #' @param writers Module IDs allowed to write (character vector)
    #' @param readers Module IDs allowed to read (character vector)
    #' @param immutable Whether store is write-once (default FALSE)
    #' @param versioned Whether to keep version history (default FALSE)
    create_store = function(store_name,
                           schema = NULL,
                           writers = NULL,
                           readers = NULL,
                           immutable = FALSE,
                           versioned = FALSE) {

      if (store_name %in% names(self$stores)) {
        warning(sprintf("Store %s already exists, skipping creation", store_name))
        return(invisible(self))
      }

      self$stores[[store_name]] <- list(
        data = NULL,
        created_at = Sys.time(),
        updated_at = Sys.time(),
        version = 1,
        locked = FALSE
      )

      if (!is.null(schema)) {
        self$schemas[[store_name]] <- schema
      }

      self$access_control[[store_name]] <- list(
        writers = writers,
        readers = readers,
        immutable = immutable,
        versioned = versioned
      )

      # Version history if versioned
      if (versioned) {
        private$version_history[[store_name]] <- list()
      }

      message(sprintf("Store created: %s", store_name))
      invisible(self)
    },

    #' @description
    #' Write data to store
    #' @param store_name Name of store
    #' @param data Data to store
    #' @param writer_id ID of module writing (for access control)
    #' @param force_write Override immutability check (use with caution)
    write = function(store_name, data, writer_id = NULL, force_write = FALSE) {

      # Check store exists
      if (!store_name %in% names(self$stores)) {
        stop(sprintf("Store %s does not exist", store_name))
      }

      # Check write permission
      ac <- self$access_control[[store_name]]
      if (!is.null(ac$writers) && !is.null(writer_id)) {
        if (!writer_id %in% ac$writers) {
          stop(sprintf("Module %s not authorized to write to %s", writer_id, store_name))
        }
      }

      # Check immutability
      if (ac$immutable && !is.null(self$stores[[store_name]]$data) && !force_write) {
        stop(sprintf("Store %s is immutable and already has data", store_name))
      }

      # Check locked
      if (self$stores[[store_name]]$locked && !force_write) {
        stop(sprintf("Store %s is locked", store_name))
      }

      # Validate schema
      if (!is.null(self$schemas[[store_name]])) {
        private$validate_schema(store_name, data)
      }

      # Save version if versioned
      if (ac$versioned && !is.null(self$stores[[store_name]]$data)) {
        private$save_version(store_name)
      }

      # Write data
      old_hash <- if (!is.null(self$stores[[store_name]]$data)) {
        digest(self$stores[[store_name]]$data)
      } else {
        NULL
      }

      self$stores[[store_name]]$data <- data
      self$stores[[store_name]]$updated_at <- Sys.time()
      self$stores[[store_name]]$version <- self$stores[[store_name]]$version + 1

      new_hash <- digest(data)

      # Audit log
      private$add_audit_entry(
        store_name = store_name,
        action = "write",
        actor = writer_id,
        old_hash = old_hash,
        new_hash = new_hash
      )

      message(sprintf("Store written: %s (by: %s, version: %d)",
                     store_name,
                     writer_id %||% "anonymous",
                     self$stores[[store_name]]$version))

      invisible(self)
    },

    #' @description
    #' Read data from store
    #' @param store_name Name of store
    #' @param reader_id ID of module reading (for access control)
    #' @param version Version to read (NULL for latest)
    #' @return Stored data
    read = function(store_name, reader_id = NULL, version = NULL) {

      # Check store exists
      if (!store_name %in% names(self$stores)) {
        stop(sprintf("Store %s does not exist", store_name))
      }

      # Check read permission
      ac <- self$access_control[[store_name]]
      if (!is.null(ac$readers) && !is.null(reader_id)) {
        if (!reader_id %in% ac$readers && !reader_id %in% ac$writers) {
          stop(sprintf("Module %s not authorized to read from %s", reader_id, store_name))
        }
      }

      # Get version
      if (!is.null(version) && ac$versioned) {
        return(private$read_version(store_name, version))
      }

      # Audit log
      private$add_audit_entry(
        store_name = store_name,
        action = "read",
        actor = reader_id
      )

      return(self$stores[[store_name]]$data)
    },

    #' @description
    #' Check if store has data
    #' @param store_name Name of store
    #' @return Logical
    has_data = function(store_name) {
      if (!store_name %in% names(self$stores)) {
        return(FALSE)
      }
      return(!is.null(self$stores[[store_name]]$data))
    },

    #' @description
    #' Lock a store (prevent further writes)
    #' @param store_name Name of store
    #' @param locker_id ID of module locking
    lock = function(store_name, locker_id = NULL) {
      if (store_name %in% names(self$stores)) {
        self$stores[[store_name]]$locked <- TRUE
        self$stores[[store_name]]$locked_by <- locker_id
        self$stores[[store_name]]$locked_at <- Sys.time()

        private$add_audit_entry(
          store_name = store_name,
          action = "lock",
          actor = locker_id
        )

        message(sprintf("Store locked: %s", store_name))
      }
      invisible(self)
    },

    #' @description
    #' Unlock a store
    #' @param store_name Name of store
    unlock = function(store_name) {
      if (store_name %in% names(self$stores)) {
        self$stores[[store_name]]$locked <- FALSE
        message(sprintf("Store unlocked: %s", store_name))
      }
      invisible(self)
    },

    #' @description
    #' Clear a store
    #' @param store_name Name of store
    clear = function(store_name) {
      if (store_name %in% names(self$stores)) {
        self$stores[[store_name]]$data <- NULL
        message(sprintf("Store cleared: %s", store_name))
      }
      invisible(self)
    },

    #' @description
    #' Get store metadata
    #' @param store_name Name of store
    #' @return List with metadata
    get_metadata = function(store_name) {
      if (!store_name %in% names(self$stores)) {
        return(NULL)
      }

      list(
        created_at = self$stores[[store_name]]$created_at,
        updated_at = self$stores[[store_name]]$updated_at,
        version = self$stores[[store_name]]$version,
        locked = self$stores[[store_name]]$locked,
        has_data = !is.null(self$stores[[store_name]]$data),
        access_control = self$access_control[[store_name]]
      )
    },

    #' @description
    #' Get version history for a store
    #' @param store_name Name of store
    #' @return data.frame of versions
    get_versions = function(store_name) {
      if (!store_name %in% names(private$version_history)) {
        return(data.frame())
      }

      versions <- private$version_history[[store_name]]
      if (length(versions) == 0) {
        return(data.frame())
      }

      do.call(rbind, lapply(seq_along(versions), function(i) {
        data.frame(
          version = i,
          timestamp = as.character(versions[[i]]$timestamp),
          hash = versions[[i]]$hash,
          stringsAsFactors = FALSE
        )
      }))
    },

    #' @description
    #' Get audit log
    #' @param store_name Name of store (NULL for all stores)
    #' @param n Number of recent entries (NULL for all)
    #' @return data.frame of audit entries
    get_audit_log = function(store_name = NULL, n = NULL) {
      entries <- self$audit_log

      # Filter by store if specified
      if (!is.null(store_name)) {
        entries <- Filter(function(e) e$store_name == store_name, entries)
      }

      if (length(entries) == 0) {
        return(data.frame())
      }

      df <- do.call(rbind, lapply(entries, function(e) {
        data.frame(
          store_name = e$store_name,
          action = e$action,
          actor = e$actor %||% NA,
          timestamp = as.character(e$timestamp),
          old_hash = e$old_hash %||% NA,
          new_hash = e$new_hash %||% NA,
          stringsAsFactors = FALSE
        )
      }))

      if (!is.null(n) && nrow(df) > n) {
        df <- tail(df, n)
      }

      return(df)
    },

    #' @description
    #' Print store status
    print = function() {
      cat("DataStore Status\n")
      cat("================\n")
      cat(sprintf("Total stores: %d\n", length(self$stores)))
      cat(sprintf("Total audit entries: %d\n", length(self$audit_log)))

      if (length(self$stores) > 0) {
        cat("\nStores:\n")
        for (store_name in names(self$stores)) {
          meta <- self$get_metadata(store_name)
          cat(sprintf("  %s\n", store_name))
          cat(sprintf("    Has data: %s\n", meta$has_data))
          cat(sprintf("    Version: %d\n", meta$version))
          cat(sprintf("    Locked: %s\n", meta$locked))
          if (!is.null(meta$access_control$writers)) {
            cat(sprintf("    Writers: %s\n", paste(meta$access_control$writers, collapse = ", ")))
          }
        }
      }

      invisible(self)
    }
  ),

  private = list(

    version_history = list(),

    #' Load configuration from YAML
    #' @param config_file Path to module_contracts.yaml
    load_config = function(config_file) {
      tryCatch({
        config <- yaml::read_yaml(config_file)

        # Create stores from config
        if (!is.null(config$data_stores)) {
          for (store_name in names(config$data_stores)) {
            store_def <- config$data_stores[[store_name]]

            self$create_store(
              store_name = store_name,
              schema = config$schemas[[store_name]],
              writers = store_def$writers,
              readers = store_def$readers,
              immutable = store_def$immutability == "write-once per analysis",
              versioned = grepl("version", store_def$immutability, ignore.case = TRUE)
            )
          }
        }

        message(sprintf("Loaded configuration from %s", config_file))

      }, error = function(e) {
        warning(sprintf("Failed to load config: %s", e$message))
      })
    },

    #' Validate data against schema
    #' @param store_name Store name
    #' @param data Data to validate
    validate_schema = function(store_name, data) {
      schema <- self$schemas[[store_name]]

      # data.frame validation
      if (!is.null(schema$type) && schema$type == "data.frame") {
        if (!is.data.frame(data)) {
          stop(sprintf("Store %s expects data.frame, got %s", store_name, class(data)[1]))
        }

        # Check required columns
        if (!is.null(schema$required_columns)) {
          for (col in names(schema$required_columns)) {
            if (!col %in% names(data)) {
              stop(sprintf("Store %s missing required column: %s", store_name, col))
            }

            # Check column type
            expected_type <- schema$required_columns[[col]]
            actual_type <- class(data[[col]])[1]

            if (!private$types_compatible(actual_type, expected_type)) {
              stop(sprintf("Store %s column '%s' has wrong type (expected: %s, got: %s)",
                          store_name, col, expected_type, actual_type))
            }
          }
        }

        # Check constraints
        if (!is.null(schema$constraints)) {
          for (constraint in schema$constraints) {
            field <- constraint$field
            rule <- constraint$rule

            if (field %in% names(data)) {
              # Evaluate constraint
              # This is simplified - real implementation would parse rule properly
              if (grepl("> 0", rule)) {
                if (any(data[[field]] <= 0, na.rm = TRUE)) {
                  stop(sprintf("Store %s constraint violated: %s must be %s", store_name, field, rule))
                }
              }
            }
          }
        }
      }

      # list validation
      if (!is.null(schema$type) && schema$type == "list") {
        if (!is.list(data)) {
          stop(sprintf("Store %s expects list, got %s", store_name, class(data)[1]))
        }

        # Check required fields
        if (!is.null(schema$required_fields)) {
          for (field in names(schema$required_fields)) {
            if (!field %in% names(data)) {
              stop(sprintf("Store %s missing required field: %s", store_name, field))
            }
          }
        }
      }
    },

    #' Check if types are compatible
    #' @param actual Actual type
    #' @param expected Expected type
    #' @return Logical
    types_compatible = function(actual, expected) {
      if (actual == expected) return(TRUE)

      # Numeric compatibility
      if (expected == "numeric" && actual %in% c("numeric", "integer", "double")) return(TRUE)

      # Integer compatibility
      if (expected == "integer" && actual %in% c("integer", "numeric")) return(TRUE)

      return(FALSE)
    },

    #' Save current version to history
    #' @param store_name Store name
    save_version = function(store_name) {
      if (is.null(private$version_history[[store_name]])) {
        private$version_history[[store_name]] <- list()
      }

      version_entry <- list(
        data = self$stores[[store_name]]$data,
        timestamp = Sys.time(),
        hash = digest(self$stores[[store_name]]$data),
        version = self$stores[[store_name]]$version
      )

      private$version_history[[store_name]][[length(private$version_history[[store_name]]) + 1]] <- version_entry
    },

    #' Read specific version
    #' @param store_name Store name
    #' @param version Version number
    #' @return Version data
    read_version = function(store_name, version) {
      if (is.null(private$version_history[[store_name]])) {
        stop(sprintf("Store %s has no version history", store_name))
      }

      if (version > length(private$version_history[[store_name]])) {
        stop(sprintf("Version %d does not exist for store %s", version, store_name))
      }

      return(private$version_history[[store_name]][[version]]$data)
    },

    #' Add audit log entry
    #' @param store_name Store name
    #' @param action Action performed
    #' @param actor Module ID
    #' @param old_hash Hash before change
    #' @param new_hash Hash after change
    add_audit_entry = function(store_name, action, actor = NULL, old_hash = NULL, new_hash = NULL) {
      entry <- list(
        store_name = store_name,
        action = action,
        actor = actor,
        timestamp = Sys.time(),
        old_hash = old_hash,
        new_hash = new_hash
      )

      self$audit_log[[length(self$audit_log) + 1]] <- entry
    }
  )
)


# ==============================================================================
# FACTORY FUNCTION
# ==============================================================================

#' Create a new DataStore instance
#'
#' @param config_file Path to module_contracts.yaml (optional)
#' @return DataStore instance
#' @export
create_data_store <- function(config_file = "config/module_contracts.yaml") {
  DataStore$new(config_file = config_file)
}


# ==============================================================================
# USAGE EXAMPLES
# ==============================================================================

if (FALSE) {
  # Example 1: Basic usage
  ds <- create_data_store()

  ds$create_store(
    "data_store",
    schema = list(
      type = "data.frame",
      required_columns = list(
        study_id = "character",
        yi = "numeric",
        sei = "numeric"
      )
    ),
    writers = c("data_import"),
    readers = c("meta_pairwise", "nma", "sensitivity")
  )

  # Write data
  ds$write("data_store",
          data.frame(study_id = c("A", "B"), yi = c(0.5, 0.6), sei = c(0.1, 0.2)),
          writer_id = "data_import")

  # Read data
  data <- ds$read("data_store", reader_id = "meta_pairwise")
  print(data)

  # Check audit log
  print(ds$get_audit_log())


  # Example 2: Immutable store
  ds$create_store(
    "protocol_store",
    immutable = TRUE,
    writers = c("protocol"),
    readers = c("reporting")
  )

  ds$write("protocol_store", list(population = "Adults with diabetes"), writer_id = "protocol")

  # This will fail:
  # ds$write("protocol_store", list(population = "Children"), writer_id = "protocol")


  # Example 3: Versioned store (for living MA)
  ds$create_store(
    "living_ma_store",
    versioned = TRUE,
    writers = c("living_ma"),
    readers = c("living_ma", "reporting")
  )

  # Multiple writes create versions
  ds$write("living_ma_store", data.frame(study_id = "A", yi = 0.5), writer_id = "living_ma")
  ds$write("living_ma_store", data.frame(study_id = c("A", "B"), yi = c(0.5, 0.6)), writer_id = "living_ma")

  # View versions
  print(ds$get_versions("living_ma_store"))

  # Read specific version
  v1_data <- ds$read("living_ma_store", version = 1)
}
