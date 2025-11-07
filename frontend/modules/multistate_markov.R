# Multi-State Markov Model Module
# Flexible Markov models with user-defined states and transitions
# Matches TreeAge Pro and heemod capabilities
# Supports 3-10 states with custom transition structures

library(shiny)
library(DT)
library(plotly)
library(diagram)  # For state diagram visualization

multistate_markov_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("project-diagram", class = "me-2"),
          "Multi-State Markov Model"
        )
      ),

      layout_columns(
        col_widths = c(4, 8),

        # Model Configuration Panel
        card(
          card_header("Model Structure"),

          numericInput(ns("n_states"), "Number of States",
                      value = 3, min = 2, max = 10, step = 1),

          uiOutput(ns("state_names_ui")),

          hr(),

          h5("Model Settings"),

          numericInput(ns("time_horizon"), "Time Horizon (years)",
                      value = 10, min = 1, max = 100),

          numericInput(ns("cycle_length"), "Cycle Length (years)",
                      value = 1, min = 0.08, max = 5, step = 0.25),

          checkboxInput(ns("half_cycle"), "Half-Cycle Correction", TRUE),

          numericInput(ns("discount_rate_costs"), "Discount Rate - Costs",
                      value = 0.035, min = 0, max = 0.2, step = 0.005),

          numericInput(ns("discount_rate_qalys"), "Discount Rate - QALYs",
                      value = 0.035, min = 0, max = 0.2, step = 0.005),

          hr(),

          h5("Initial Distribution"),

          uiOutput(ns("initial_dist_ui")),

          hr(),

          actionButton(ns("btn_configure"), "Configure Model",
                      class = "btn-primary w-100 mb-2"),

          actionButton(ns("btn_run"), "Run Analysis",
                      class = "btn-success w-100",
                      icon = icon("play"))
        ),

        # Main Results Panel
        card(
          card_header("Results & Visualization"),

          navset_card_tab(
            nav_panel(
              "State Diagram",
              plotOutput(ns("state_diagram_plot"), height = "400px"),
              verbatimTextOutput(ns("model_summary"))
            ),

            nav_panel(
              "Transition Matrix",
              h5("Treatment Arm"),
              DTOutput(ns("transition_matrix_trt")),
              hr(),
              h5("Comparator Arm"),
              DTOutput(ns("transition_matrix_comp"))
            ),

            nav_panel(
              "State Occupancy",
              plotlyOutput(ns("state_occupancy_plot"), height = "500px"),
              DTOutput(ns("state_occupancy_table"))
            ),

            nav_panel(
              "Costs & QALYs",
              h5("State-Specific Values"),
              DTOutput(ns("state_values_table")),
              hr(),
              h5("Economic Results"),
              verbatimTextOutput(ns("economic_results"))
            ),

            nav_panel(
              "Trace Results",
              DTOutput(ns("trace_table")),
              downloadButton(ns("download_trace"), "Download Trace")
            )
          )
        )
      ),

      # Transition Probabilities Configuration (appears after Configure)
      uiOutput(ns("transition_config_ui"))
    )
  )
}

multistate_markov_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values for model
    model_rv <- reactiveValues(
      configured = FALSE,
      state_names = NULL,
      n_states = 3,
      transition_matrix_trt = NULL,
      transition_matrix_comp = NULL,
      state_costs = NULL,
      state_utilities = NULL,
      results = NULL
    )

    # Dynamic UI for state names
    output$state_names_ui <- renderUI({
      n <- input$n_states
      if (is.null(n) || n < 2) return(NULL)

      lapply(1:n, function(i) {
        default_name <- switch(i,
          "1" = "Healthy",
          "2" = "Sick",
          if (i == n) "Dead" else paste0("State_", i)
        )

        textInput(ns(paste0("state_name_", i)),
                 paste("State", i, "Name:"),
                 value = default_name)
      })
    })

    # Dynamic UI for initial distribution
    output$initial_dist_ui <- renderUI({
      n <- input$n_states
      if (is.null(n) || n < 2) return(NULL)

      state_names <- sapply(1:n, function(i) {
        input[[paste0("state_name_", i)]]
      })

      if (any(is.null(state_names))) {
        state_names <- paste0("State_", 1:n)
      }

      lapply(1:n, function(i) {
        default_val <- if (i == 1) 1.0 else 0.0

        numericInput(ns(paste0("init_dist_", i)),
                    paste0(state_names[i], ":"),
                    value = default_val,
                    min = 0, max = 1, step = 0.1)
      })
    })

    # Configure model
    observeEvent(input$btn_configure, {
      n <- input$n_states

      # Get state names
      state_names <- sapply(1:n, function(i) {
        name <- input[[paste0("state_name_", i)]]
        if (is.null(name) || name == "") paste0("State_", i) else name
      })

      model_rv$n_states <- n
      model_rv$state_names <- state_names
      model_rv$configured <- TRUE

      # Initialize transition matrices (will be filled by user)
      model_rv$transition_matrix_trt <- matrix(0, nrow = n, ncol = n,
                                                dimnames = list(state_names, state_names))
      model_rv$transition_matrix_comp <- matrix(0, nrow = n, ncol = n,
                                                 dimnames = list(state_names, state_names))

      # Initialize state values
      model_rv$state_costs <- setNames(rep(0, n), state_names)
      model_rv$state_utilities <- setNames(rep(0.8, n), state_names)

      # If last state is "Dead", set utility to 0
      if (grepl("dead|death", state_names[n], ignore.case = TRUE)) {
        model_rv$state_utilities[n] <- 0
      }

      showNotification("Model configured! Please set transition probabilities and state values.",
                      type = "message", duration = 5)
    })

    # Dynamic UI for transition probabilities configuration
    output$transition_config_ui <- renderUI({
      if (!model_rv$configured) return(NULL)

      n <- model_rv$n_states
      state_names <- model_rv$state_names

      card(
        card_header("Transition Probabilities & State Values"),

        layout_columns(
          col_widths = c(6, 6),

          # Treatment arm transitions
          card(
            card_header("Treatment Arm Transitions"),

            lapply(1:n, function(from_state) {
              div(
                h6(paste("From:", state_names[from_state])),
                lapply(1:n, function(to_state) {
                  if (from_state != to_state) {
                    numericInput(
                      ns(paste0("trans_trt_", from_state, "_", to_state)),
                      paste("To", state_names[to_state], ":"),
                      value = 0,
                      min = 0, max = 1, step = 0.01
                    )
                  }
                }),
                hr()
              )
            })
          ),

          # Comparator arm transitions
          card(
            card_header("Comparator Arm Transitions"),

            lapply(1:n, function(from_state) {
              div(
                h6(paste("From:", state_names[from_state])),
                lapply(1:n, function(to_state) {
                  if (from_state != to_state) {
                    numericInput(
                      ns(paste0("trans_comp_", from_state, "_", to_state)),
                      paste("To", state_names[to_state], ":"),
                      value = 0,
                      min = 0, max = 1, step = 0.01
                    )
                  }
                }),
                hr()
              )
            })
          )
        ),

        hr(),

        # State values
        card(
          card_header("State-Specific Costs and Utilities"),

          layout_columns(
            col_widths = c(6, 6),

            div(
              h6("State Costs (per cycle)"),
              lapply(1:n, function(i) {
                numericInput(
                  ns(paste0("cost_state_", i)),
                  paste(state_names[i], ":"),
                  value = if (i == n && grepl("dead", state_names[i], ignore.case = TRUE)) 0 else 1000,
                  min = 0, step = 100
                )
              })
            ),

            div(
              h6("State Utilities (QALY weight)"),
              lapply(1:n, function(i) {
                numericInput(
                  ns(paste0("utility_state_", i)),
                  paste(state_names[i], ":"),
                  value = if (i == n && grepl("dead", state_names[i], ignore.case = TRUE)) 0 else 0.8,
                  min = 0, max = 1, step = 0.05
                )
              })
            )
          )
        )
      )
    })

    # Run analysis
    observeEvent(input$btn_run, {
      req(model_rv$configured)

      tryCatch({
        n <- model_rv$n_states
        state_names <- model_rv$state_names

        # Collect transition matrices
        trans_trt <- matrix(0, nrow = n, ncol = n)
        trans_comp <- matrix(0, nrow = n, ncol = n)

        for (i in 1:n) {
          for (j in 1:n) {
            if (i != j) {
              trans_trt[i, j] <- input[[paste0("trans_trt_", i, "_", j)]]
              trans_comp[i, j] <- input[[paste0("trans_comp_", i, "_", j)]]
            }
          }
        }

        # Calculate stay probabilities (diagonal)
        for (i in 1:n) {
          trans_trt[i, i] <- 1 - sum(trans_trt[i, -i])
          trans_comp[i, i] <- 1 - sum(trans_comp[i, -i])
        }

        # Validate transition matrices
        row_sums_trt <- rowSums(trans_trt)
        row_sums_comp <- rowSums(trans_comp)

        if (any(abs(row_sums_trt - 1) > 0.001) || any(abs(row_sums_comp - 1) > 0.001)) {
          showNotification("Error: Transition probabilities must sum to 1 for each state",
                          type = "error", duration = 10)
          return(NULL)
        }

        if (any(trans_trt < 0) || any(trans_comp < 0)) {
          showNotification("Error: Negative transition probabilities detected",
                          type = "error", duration = 10)
          return(NULL)
        }

        dimnames(trans_trt) <- list(state_names, state_names)
        dimnames(trans_comp) <- list(state_names, state_names)

        # Collect state values
        state_costs <- sapply(1:n, function(i) {
          input[[paste0("cost_state_", i)]]
        })
        names(state_costs) <- state_names

        state_utilities <- sapply(1:n, function(i) {
          input[[paste0("utility_state_", i)]]
        })
        names(state_utilities) <- state_names

        # Get initial distribution
        init_dist <- sapply(1:n, function(i) {
          input[[paste0("init_dist_", i)]]
        })

        if (abs(sum(init_dist) - 1) > 0.001) {
          showNotification("Warning: Initial distribution normalized to sum to 1",
                          type = "warning", duration = 5)
          init_dist <- init_dist / sum(init_dist)
        }

        # Run Markov model
        results <- run_multistate_markov(
          transition_matrix_trt = trans_trt,
          transition_matrix_comp = trans_comp,
          state_costs = state_costs,
          state_utilities = state_utilities,
          initial_distribution = init_dist,
          time_horizon = input$time_horizon,
          cycle_length = input$cycle_length,
          discount_rate_costs = input$discount_rate_costs,
          discount_rate_qalys = input$discount_rate_qalys,
          half_cycle_correction = input$half_cycle
        )

        # Store results
        model_rv$transition_matrix_trt <- trans_trt
        model_rv$transition_matrix_comp <- trans_comp
        model_rv$state_costs <- state_costs
        model_rv$state_utilities <- state_utilities
        model_rv$results <- results

        # Update rv for other modules
        rv$multistate_results <- results

        showNotification("Analysis complete!", type = "message", duration = 3)

      }, error = function(e) {
        showNotification(paste("Error:", e$message),
                        type = "error", duration = 10)
      })
    })

    # Render state diagram
    output$state_diagram_plot <- renderPlot({
      req(model_rv$configured)

      n <- model_rv$n_states
      state_names <- model_rv$state_names
      trans_mat <- model_rv$transition_matrix_trt

      if (is.null(trans_mat)) {
        plot.new()
        text(0.5, 0.5, "Configure transition probabilities and run analysis",
             cex = 1.5, col = "gray50")
        return(NULL)
      }

      # Create state transition diagram
      par(mar = c(1, 1, 3, 1))

      # Arrange states in a circle or line depending on number
      if (n <= 4) {
        # Linear arrangement for simple models
        pos <- matrix(ncol = 2, nrow = n)
        for (i in 1:n) {
          pos[i, ] <- c(i / (n + 1), 0.5)
        }
      } else {
        # Circular arrangement for complex models
        angles <- seq(0, 2 * pi, length.out = n + 1)[1:n]
        pos <- matrix(ncol = 2, nrow = n)
        for (i in 1:n) {
          pos[i, ] <- c(0.5 + 0.35 * cos(angles[i]),
                       0.5 + 0.35 * sin(angles[i]))
        }
      }

      # Plot transitions with thickness based on probability
      plotmat(trans_mat, pos = pos, name = state_names,
              lwd = 1, box.lwd = 2, cex.txt = 0.8,
              box.size = 0.08, box.type = "circle",
              box.prop = 0.5, arr.length = 0.3,
              arr.width = 0.2, self.cex = 0.6,
              self.shifty = -0.05,
              main = "State Transition Diagram (Treatment Arm)")
    })

    # Model summary
    output$model_summary <- renderPrint({
      req(model_rv$configured)

      cat("========================================\n")
      cat("MULTI-STATE MARKOV MODEL SUMMARY\n")
      cat("========================================\n\n")

      cat("Number of States:", model_rv$n_states, "\n")
      cat("State Names:", paste(model_rv$state_names, collapse = ", "), "\n")
      cat("Time Horizon:", input$time_horizon, "years\n")
      cat("Cycle Length:", input$cycle_length, "years\n")
      cat("Number of Cycles:", ceiling(input$time_horizon / input$cycle_length), "\n")
      cat("Half-Cycle Correction:", ifelse(input$half_cycle, "Yes", "No"), "\n")
      cat("Discount Rate (Costs):", input$discount_rate_costs * 100, "%\n")
      cat("Discount Rate (QALYs):", input$discount_rate_qalys * 100, "%\n\n")

      if (!is.null(model_rv$results)) {
        cat("========================================\n")
        cat("ECONOMIC RESULTS\n")
        cat("========================================\n\n")

        res <- model_rv$results
        cat(sprintf("Treatment: %.2f QALYs, £%.0f costs\n",
                   res$qalys_treatment, res$costs_treatment))
        cat(sprintf("Comparator: %.2f QALYs, £%.0f costs\n",
                   res$qalys_comparator, res$costs_comparator))
        cat(sprintf("\nIncremental: %.2f QALYs, £%.0f costs\n",
                   res$inc_qalys, res$inc_costs))
        cat(sprintf("ICER: £%.0f per QALY\n", res$icer))
      }
    })

    # Transition matrix tables
    output$transition_matrix_trt <- renderDT({
      req(model_rv$transition_matrix_trt)

      datatable(
        round(model_rv$transition_matrix_trt, 4),
        options = list(
          dom = 't',
          pageLength = 20,
          scrollX = TRUE
        ),
        caption = "Treatment Arm Transition Matrix"
      ) %>%
        formatStyle(columns = 1:ncol(model_rv$transition_matrix_trt),
                   backgroundColor = styleInterval(c(0.01, 0.5), c('white', '#fff3cd', '#f8d7da')))
    })

    output$transition_matrix_comp <- renderDT({
      req(model_rv$transition_matrix_comp)

      datatable(
        round(model_rv$transition_matrix_comp, 4),
        options = list(
          dom = 't',
          pageLength = 20,
          scrollX = TRUE
        ),
        caption = "Comparator Arm Transition Matrix"
      ) %>%
        formatStyle(columns = 1:ncol(model_rv$transition_matrix_comp),
                   backgroundColor = styleInterval(c(0.01, 0.5), c('white', '#fff3cd', '#f8d7da')))
    })

    # State occupancy visualization
    output$state_occupancy_plot <- renderPlotly({
      req(model_rv$results)

      trace_trt <- model_rv$results$trace_treatment
      trace_comp <- model_rv$results$trace_comparator
      state_names <- model_rv$state_names

      # Create plot for treatment arm
      p <- plot_ly()

      for (i in 1:ncol(trace_trt)) {
        p <- p %>%
          add_trace(
            x = 0:(nrow(trace_trt) - 1) * input$cycle_length,
            y = trace_trt[, i],
            name = paste("Trt:", state_names[i]),
            type = 'scatter',
            mode = 'lines',
            line = list(width = 2),
            hovertemplate = paste0(
              "<b>", state_names[i], " (Treatment)</b><br>",
              "Time: %{x:.1f} years<br>",
              "Proportion: %{y:.3f}<extra></extra>"
            )
          )
      }

      for (i in 1:ncol(trace_comp)) {
        p <- p %>%
          add_trace(
            x = 0:(nrow(trace_comp) - 1) * input$cycle_length,
            y = trace_comp[, i],
            name = paste("Comp:", state_names[i]),
            type = 'scatter',
            mode = 'lines',
            line = list(width = 2, dash = 'dash'),
            hovertemplate = paste0(
              "<b>", state_names[i], " (Comparator)</b><br>",
              "Time: %{x:.1f} years<br>",
              "Proportion: %{y:.3f}<extra></extra>"
            )
          )
      }

      p <- p %>%
        layout(
          title = "State Occupancy Over Time",
          xaxis = list(title = "Time (years)"),
          yaxis = list(title = "Proportion in State", range = c(0, 1)),
          hovermode = "closest",
          legend = list(orientation = "v", x = 1.05, y = 1)
        )

      p
    })

    # State occupancy table
    output$state_occupancy_table <- renderDT({
      req(model_rv$results)

      trace_trt <- model_rv$results$trace_treatment
      trace_comp <- model_rv$results$trace_comparator
      state_names <- model_rv$state_names

      # Create summary table
      time_points <- 0:(nrow(trace_trt) - 1) * input$cycle_length

      df <- data.frame(
        Cycle = 0:(nrow(trace_trt) - 1),
        Time = time_points
      )

      for (i in 1:ncol(trace_trt)) {
        df[[paste0("Trt_", state_names[i])]] <- trace_trt[, i]
        df[[paste0("Comp_", state_names[i])]] <- trace_comp[, i]
      }

      datatable(
        df,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 'Bfrtip'
        ),
        caption = "State Occupancy by Cycle"
      ) %>%
        formatRound(columns = 3:ncol(df), digits = 4)
    })

    # State values table
    output$state_values_table <- renderDT({
      req(model_rv$state_costs, model_rv$state_utilities)

      df <- data.frame(
        State = model_rv$state_names,
        Cost_per_Cycle = model_rv$state_costs,
        Utility = model_rv$state_utilities,
        stringsAsFactors = FALSE
      )

      datatable(
        df,
        options = list(
          dom = 't',
          pageLength = 20
        ),
        caption = "State-Specific Costs and Utilities",
        rownames = FALSE
      ) %>%
        formatCurrency(columns = "Cost_per_Cycle", currency = "£") %>%
        formatRound(columns = "Utility", digits = 3)
    })

    # Economic results
    output$economic_results <- renderPrint({
      req(model_rv$results)

      res <- model_rv$results

      cat("========================================\n")
      cat("COST-EFFECTIVENESS RESULTS\n")
      cat("========================================\n\n")

      cat("TREATMENT ARM:\n")
      cat(sprintf("  Total QALYs: %.3f\n", res$qalys_treatment))
      cat(sprintf("  Total Costs: £%.2f\n", res$costs_treatment))
      cat(sprintf("  Life Years: %.3f\n", res$ly_treatment))

      cat("\nCOMPARATOR ARM:\n")
      cat(sprintf("  Total QALYs: %.3f\n", res$qalys_comparator))
      cat(sprintf("  Total Costs: £%.2f\n", res$costs_comparator))
      cat(sprintf("  Life Years: %.3f\n", res$ly_comparator))

      cat("\n========================================\n")
      cat("INCREMENTAL ANALYSIS:\n")
      cat("========================================\n\n")

      cat(sprintf("Incremental QALYs: %.3f\n", res$inc_qalys))
      cat(sprintf("Incremental Costs: £%.2f\n", res$inc_costs))
      cat(sprintf("Incremental LYs: %.3f\n", res$inc_ly))

      cat("\n")
      if (res$inc_qalys > 0.001) {
        cat(sprintf("ICER: £%.2f per QALY gained\n", res$icer))
        cat(sprintf("Cost per Life Year: £%.2f\n", res$inc_costs / res$inc_ly))

        # WTP thresholds
        wtp_thresholds <- c(20000, 30000, 50000)
        cat("\nCost-Effectiveness at Common Thresholds:\n")
        for (wtp in wtp_thresholds) {
          ce <- if (res$icer < wtp) "COST-EFFECTIVE" else "NOT cost-effective"
          cat(sprintf("  £%s/QALY: %s\n", format(wtp, big.mark = ","), ce))
        }
      } else if (res$inc_qalys < -0.001) {
        cat("Treatment is DOMINATED (fewer QALYs, higher costs)\n")
      } else {
        cat("Treatment and comparator have similar QALY outcomes\n")
      }

      cat("\n========================================\n")
    })

    # Trace table
    output$trace_table <- renderDT({
      req(model_rv$results)

      # Combine treatment and comparator traces
      trace_trt <- model_rv$results$trace_treatment
      state_names <- model_rv$state_names

      df <- data.frame(
        Cycle = 0:(nrow(trace_trt) - 1),
        Time = 0:(nrow(trace_trt) - 1) * input$cycle_length
      )

      for (i in 1:ncol(trace_trt)) {
        df[[paste0("Trt_", state_names[i])]] <- trace_trt[, i]
      }

      datatable(
        df,
        extensions = 'Buttons',
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel')
        ),
        caption = "Markov Trace (Treatment Arm)"
      ) %>%
        formatRound(columns = 3:ncol(df), digits = 4)
    })

    # Download trace
    output$download_trace <- downloadHandler(
      filename = function() {
        paste0("markov_trace_", Sys.Date(), ".csv")
      },
      content = function(file) {
        req(model_rv$results)

        trace_trt <- model_rv$results$trace_treatment
        trace_comp <- model_rv$results$trace_comparator
        state_names <- model_rv$state_names

        df <- data.frame(
          Cycle = 0:(nrow(trace_trt) - 1),
          Time = 0:(nrow(trace_trt) - 1) * input$cycle_length
        )

        for (i in 1:ncol(trace_trt)) {
          df[[paste0("Trt_", state_names[i])]] <- trace_trt[, i]
          df[[paste0("Comp_", state_names[i])]] <- trace_comp[, i]
        }

        write.csv(df, file, row.names = FALSE)
      }
    )

    # Return results
    return(reactive({ model_rv$results }))
  })
}

# ============================================================================
# CORE MULTI-STATE MARKOV MODEL ENGINE
# ============================================================================

run_multistate_markov <- function(transition_matrix_trt,
                                   transition_matrix_comp,
                                   state_costs,
                                   state_utilities,
                                   initial_distribution,
                                   time_horizon = 10,
                                   cycle_length = 1,
                                   discount_rate_costs = 0.035,
                                   discount_rate_qalys = 0.035,
                                   half_cycle_correction = TRUE) {

  n_states <- nrow(transition_matrix_trt)
  n_cycles <- ceiling(time_horizon / cycle_length)

  # Initialize trace matrices
  trace_trt <- matrix(0, nrow = n_cycles + 1, ncol = n_states)
  trace_comp <- matrix(0, nrow = n_cycles + 1, ncol = n_states)

  # Set initial distribution
  trace_trt[1, ] <- initial_distribution
  trace_comp[1, ] <- initial_distribution

  # Run Markov trace
  for (t in 1:n_cycles) {
    trace_trt[t + 1, ] <- trace_trt[t, ] %*% transition_matrix_trt
    trace_comp[t + 1, ] <- trace_comp[t, ] %*% transition_matrix_comp
  }

  # Calculate discount weights
  discount_weights_costs <- exp(-discount_rate_costs * cycle_length * (0:n_cycles))
  discount_weights_qalys <- exp(-discount_rate_qalys * cycle_length * (0:n_cycles))

  # Half-cycle correction
  if (half_cycle_correction) {
    hcc_weights <- c(0.5, rep(1, n_cycles - 1), 0.5)
  } else {
    hcc_weights <- rep(1, n_cycles + 1)
  }

  # Calculate costs and QALYs
  costs_trt <- 0
  qalys_trt <- 0
  ly_trt <- 0

  costs_comp <- 0
  qalys_comp <- 0
  ly_comp <- 0

  for (t in 1:(n_cycles + 1)) {
    # Treatment arm
    state_dist_trt <- trace_trt[t, ]
    costs_trt <- costs_trt + sum(state_dist_trt * state_costs) *
                 cycle_length * discount_weights_costs[t] * hcc_weights[t]
    qalys_trt <- qalys_trt + sum(state_dist_trt * state_utilities) *
                 cycle_length * discount_weights_qalys[t] * hcc_weights[t]
    ly_trt <- ly_trt + sum(state_dist_trt * (state_utilities > 0)) *
              cycle_length * discount_weights_qalys[t] * hcc_weights[t]

    # Comparator arm
    state_dist_comp <- trace_comp[t, ]
    costs_comp <- costs_comp + sum(state_dist_comp * state_costs) *
                  cycle_length * discount_weights_costs[t] * hcc_weights[t]
    qalys_comp <- qalys_comp + sum(state_dist_comp * state_utilities) *
                  cycle_length * discount_weights_qalys[t] * hcc_weights[t]
    ly_comp <- ly_comp + sum(state_dist_comp * (state_utilities > 0)) *
               cycle_length * discount_weights_qalys[t] * hcc_weights[t]
  }

  # Calculate incremental values
  inc_costs <- costs_trt - costs_comp
  inc_qalys <- qalys_trt - qalys_comp
  inc_ly <- ly_trt - ly_comp

  # Calculate ICER
  icer <- if (abs(inc_qalys) > 0.0001) inc_costs / inc_qalys else NA

  # Return results
  list(
    trace_treatment = trace_trt,
    trace_comparator = trace_comp,
    costs_treatment = costs_trt,
    qalys_treatment = qalys_trt,
    ly_treatment = ly_trt,
    costs_comparator = costs_comp,
    qalys_comparator = qalys_comp,
    ly_comparator = ly_comp,
    inc_costs = inc_costs,
    inc_qalys = inc_qalys,
    inc_ly = inc_ly,
    icer = icer,
    n_states = n_states,
    n_cycles = n_cycles,
    state_names = names(state_costs)
  )
}
