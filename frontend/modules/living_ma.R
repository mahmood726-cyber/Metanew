# Living Meta-Analysis Module - Incremental Updates
library(shiny)

living_ma_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Living Meta-Analysis: Incremental Updates"),
      layout_columns(
        col_widths = c(4, 8),
        card(
          h5("Current Version"),
          verbatimTextOutput(ns("current_version_info")),
          hr(),
          h5("Add New Studies"),
          fileInput(ns("new_studies_file"), "Upload New Studies (CSV/Excel)",
                    accept = c(".csv", ".xlsx", ".xls")),
          textAreaInput(ns("update_notes"), "Update Notes", rows = 3,
                        placeholder = "Describe what changed in this update..."),
          actionButton(ns("btn_add_studies"), "Add & Re-run", class = "btn-success w-100 mt-2"),
          hr(),
          h5("Version History"),
          DTOutput(ns("version_history"))
        ),
        card(
          navset_card_tab(
            nav_panel("Change Summary", uiOutput(ns("change_summary"))),
            nav_panel("Updated Forest Plot", plotlyOutput(ns("updated_forest"))),
            nav_panel("Comparison", DTOutput(ns("comparison_table"))),
            nav_panel("Delta Report", verbatimTextOutput(ns("delta_report")))
          )
        )
      )
    )
  )
}

living_ma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Version tracking
    versions <- reactiveVal(list())

    # Initialize with current data if available
    observe({
      if (!is.null(rv$data) && length(versions()) == 0) {
        initial_version <- list(
          version = 1,
          timestamp = Sys.time(),
          n_studies = length(unique(rv$data$study_id)),
          n_observations = nrow(rv$data),
          data = rv$data,
          results = rv$pairwise_results,
          notes = "Initial version"
        )
        versions(list(initial_version))
      }
    })

    output$current_version_info <- renderPrint({
      if (length(versions()) == 0) {
        cat("No meta-analysis loaded yet.\n")
        cat("Please run a meta-analysis first from the Analysis tab.")
      } else {
        current <- versions()[[length(versions())]]
        cat("Current Version Information\n")
        cat("===========================\n\n")
        cat(sprintf("Version: %d\n", current$version))
        cat(sprintf("Last Updated: %s\n", format(current$timestamp, "%Y-%m-%d %H:%M")))
        cat(sprintf("Number of Studies: %d\n", current$n_studies))
        cat(sprintf("Total Observations: %d\n", current$n_observations))
        if (!is.null(current$notes)) {
          cat(sprintf("\nNotes: %s\n", current$notes))
        }
      }
    })

    observeEvent(input$btn_add_studies, {
      req(input$new_studies_file, length(versions()) > 0)

      withProgress(message = "Adding new studies and updating...", {
        tryCatch({
          # Read new studies
          ext <- tools::file_ext(input$new_studies_file$name)
          if (ext == "csv") {
            new_data <- read.csv(input$new_studies_file$datapath, stringsAsFactors = FALSE)
          } else {
            new_data <- readxl::read_excel(input$new_studies_file$datapath)
          }

          # Get current version
          current_version <- versions()[[length(versions())]]
          old_data <- current_version$data

          # Combine with existing data
          combined_data <- rbind(old_data, new_data)

          # Remove duplicates by study_id
          combined_data <- combined_data[!duplicated(combined_data$study_id), ]

          # Calculate changes
          n_new <- length(setdiff(combined_data$study_id, old_data$study_id))
          n_removed <- length(setdiff(old_data$study_id, combined_data$study_id))

          # Re-run meta-analyses for all outcomes
          # Use incremental meta-analysis for faster updates (from extreme_optimizations.R)
          new_results <- list()
          for (outcome in names(current_version$results)) {
            previous_ma <- current_version$results[[outcome]]

            # Filter data by outcome
            outcome_data <- combined_data[combined_data$outcome == outcome, ]
            new_study_data <- new_data[new_data$outcome == outcome, ]

            if (nrow(new_study_data) > 0 && !is.null(previous_ma)) {
              # Use incremental update (10-16x faster!)
              cat(sprintf("⚡ Using incremental update for outcome: %s\n", outcome))
              new_results[[outcome]] <- incremental_meta_analysis(previous_ma, new_study_data)
            } else {
              # Full recomputation (no previous results or no new studies for this outcome)
              new_results[[outcome]] <- run_pairwise_ma(
                data = combined_data,
                outcome = outcome,
                method = "REML"
              )
            }
          }

          # Create new version
          new_version <- list(
            version = current_version$version + 1,
            timestamp = Sys.time(),
            n_studies = length(unique(combined_data$study_id)),
            n_observations = nrow(combined_data),
            data = combined_data,
            results = new_results,
            notes = input$update_notes,
            changes = list(
              n_new = n_new,
              n_removed = n_removed,
              new_study_ids = setdiff(combined_data$study_id, old_data$study_id)
            )
          )

          # Add to version history
          all_versions <- versions()
          all_versions[[length(all_versions) + 1]] <- new_version
          versions(all_versions)

          # Update main reactive values
          rv$data <- combined_data
          rv$pairwise_results <- new_results

          showNotification(
            paste("✓ Added", n_new, "new studies. Version", new_version$version, "created."),
            type = "message",
            duration = 5
          )

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    output$version_history <- renderDT({
      if (length(versions()) == 0) return(NULL)

      history_df <- do.call(rbind, lapply(versions(), function(v) {
        data.frame(
          Version = v$version,
          Date = format(v$timestamp, "%Y-%m-%d %H:%M"),
          Studies = v$n_studies,
          Observations = v$n_observations,
          Notes = substr(v$notes, 1, 50),
          stringsAsFactors = FALSE
        )
      }))

      datatable(history_df, selection = "single", options = list(pageLength = 10))
    })

    output$change_summary <- renderUI({
      if (length(versions()) < 2) {
        return(div(class = "alert alert-info",
                   icon("info-circle"), " No updates yet. Upload new studies to create version 2."))
      }

      current <- versions()[[length(versions())]]
      previous <- versions()[[length(versions()) - 1]]

      changes <- current$changes

      tagList(
        div(class = "alert alert-success",
            icon("check-circle"),
            sprintf(" Version %d created successfully", current$version)),
        hr(),
        h5("Changes in This Update:"),
        tags$ul(
          tags$li(sprintf("New studies added: %d", changes$n_new)),
          tags$li(sprintf("Studies removed: %d", changes$n_removed)),
          tags$li(sprintf("Total studies now: %d (was %d)",
                          current$n_studies, previous$n_studies))
        ),
        if (changes$n_new > 0) {
          tagList(
            hr(),
            h5("Newly Added Studies:"),
            tags$ul(
              lapply(changes$new_study_ids, function(id) tags$li(id))
            )
          )
        },
        hr(),
        h5("Impact on Results:"),
        create_results_comparison_ui(current$results, previous$results)
      )
    })

    output$comparison_table <- renderDT({
      if (length(versions()) < 2) return(NULL)

      current <- versions()[[length(versions())]]
      previous <- versions()[[length(versions()) - 1]]

      comparison_list <- list()

      for (outcome in names(current$results)) {
        if (outcome %in% names(previous$results)) {
          curr_res <- current$results[[outcome]]
          prev_res <- previous$results[[outcome]]

          comparison_list[[length(comparison_list) + 1]] <- data.frame(
            Outcome = outcome,
            Version = c(previous$version, current$version),
            N_Studies = c(prev_res$n_studies, curr_res$n_studies),
            Pooled_Effect = c(prev_res$pooled_effect, curr_res$pooled_effect),
            CI_Lower = c(prev_res$ci_lower, curr_res$ci_lower),
            CI_Upper = c(prev_res$ci_upper, curr_res$ci_upper),
            I_Squared = c(prev_res$i_squared, curr_res$i_squared),
            P_Value = c(prev_res$p_value, curr_res$p_value),
            stringsAsFactors = FALSE
          )
        }
      }

      comparison_df <- do.call(rbind, comparison_list)

      datatable(comparison_df, options = list(pageLength = 20)) %>%
        formatRound(columns = c("Pooled_Effect", "CI_Lower", "CI_Upper"), digits = 3) %>%
        formatRound(columns = c("I_Squared"), digits = 1) %>%
        formatSignif(columns = c("P_Value"), digits = 3)
    })

    output$delta_report <- renderPrint({
      if (length(versions()) < 2) {
        cat("No previous version to compare.\n")
        return()
      }

      current <- versions()[[length(versions())]]
      previous <- versions()[[length(versions()) - 1]]

      cat("LIVING META-ANALYSIS: DELTA REPORT\n")
      cat("===================================\n\n")

      cat(sprintf("Update from Version %d to Version %d\n", previous$version, current$version))
      cat(sprintf("Date: %s\n\n", format(current$timestamp, "%Y-%m-%d %H:%M")))

      cat("Data Changes:\n")
      cat(sprintf("  Studies: %d → %d (%+d)\n",
                  previous$n_studies, current$n_studies,
                  current$n_studies - previous$n_studies))
      cat(sprintf("  Observations: %d → %d (%+d)\n\n",
                  previous$n_observations, current$n_observations,
                  current$n_observations - previous$n_observations))

      cat("Results Changes:\n")
      for (outcome in names(current$results)) {
        if (outcome %in% names(previous$results)) {
          curr <- current$results[[outcome]]
          prev <- previous$results[[outcome]]

          cat(sprintf("\n%s:\n", outcome))
          cat(sprintf("  Pooled effect: %.3f → %.3f (Δ = %+.3f)\n",
                      prev$pooled_effect, curr$pooled_effect,
                      curr$pooled_effect - prev$pooled_effect))
          cat(sprintf("  95%% CI: [%.3f, %.3f] → [%.3f, %.3f]\n",
                      prev$ci_lower, prev$ci_upper, curr$ci_lower, curr$ci_upper))
          cat(sprintf("  I²: %.1f%% → %.1f%% (Δ = %+.1f%%)\n",
                      prev$i_squared, curr$i_squared, curr$i_squared - prev$i_squared))
          cat(sprintf("  p-value: %.4f → %.4f\n", prev$p_value, curr$p_value))

          # Interpretation
          if (abs(curr$pooled_effect - prev$pooled_effect) > 0.1) {
            cat("  ⚠ Substantial change in pooled estimate\n")
          } else {
            cat("  ✓ Pooled estimate remains stable\n")
          }
        }
      }

      cat("\nUpdate Notes:\n")
      cat(sprintf("  %s\n", current$notes))
    })

    output$updated_forest <- renderPlotly({
      if (length(versions()) == 0) return(NULL)

      current <- versions()[[length(versions())]]

      if (length(current$results) == 0) return(NULL)

      # Show forest plot for first outcome
      outcome <- names(current$results)[1]
      result <- current$results[[outcome]]

      create_forest_plot(result, outcome)
    })

    return(reactive(versions()))
  })
}

create_results_comparison_ui <- function(current_results, previous_results) {
  comparison_items <- list()

  for (outcome in names(current_results)) {
    if (outcome %in% names(previous_results)) {
      curr <- current_results[[outcome]]
      prev <- previous_results[[outcome]]

      delta <- curr$pooled_effect - prev$pooled_effect
      pct_change <- 100 * abs(delta) / abs(prev$pooled_effect)

      color_class <- if (abs(delta) > 0.1) "alert-warning" else "alert-success"

      comparison_items[[length(comparison_items) + 1]] <- div(
        class = paste("alert", color_class, "py-2 mb-2"),
        tags$strong(outcome, ":"),
        sprintf(" %.3f → %.3f (Δ = %+.3f, %+.1f%%)",
                prev$pooled_effect, curr$pooled_effect, delta, pct_change)
      )
    }
  }

  tagList(comparison_items)
}
