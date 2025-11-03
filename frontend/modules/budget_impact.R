# Budget Impact Analysis (BIA) Module
# Part of Phase 2+v2 implementation - Health Economics extension

library(shiny)
library(bslib)
library(DT)
library(plotly)
library(ggplot2)

# UI
budget_impact_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # Header card
      card(
        card_header(
          tags$div(
            class = "d-flex justify-content-between align-items-center",
            tags$h4(class = "mb-0", icon("coins"), " Budget Impact Analysis"),
            actionButton(ns("btn_help"), icon("circle-question"),
                        class = "btn-sm btn-outline-secondary")
          )
        ),

        card_body(
          p(class = "text-muted",
            "Estimate the budget impact of implementing a new intervention in your healthcare system. ",
            "BIA differs from cost-effectiveness analysis by focusing on total budget requirements ",
            "rather than cost per QALY, helping decision-makers plan resource allocation."
          )
        )
      )
    ),

    # Input parameters
    layout_columns(
      col_widths = c(6, 6),

      # Population & Uptake
      card(
        card_header("Population & Uptake", class = "bg-primary text-white"),

        card_body(
          numericInput(ns("population_size"), "Eligible Population Size",
                      value = 10000, min = 1, step = 100),
          helpText("Total number of patients eligible for the intervention"),

          numericInput(ns("time_horizon"), "Time Horizon (years)",
                      value = 5, min = 1, max = 10, step = 1),

          selectInput(ns("uptake_model"), "Uptake Model",
                     choices = c(
                       "Linear Growth" = "linear",
                       "S-Curve (Sigmoid)" = "sigmoid",
                       "Step Function" = "step",
                       "Custom Year-by-Year" = "custom"
                     )),

          conditionalPanel(
            condition = "input.uptake_model == 'linear'",
            ns = ns,
            sliderInput(ns("uptake_linear_start"), "Year 1 Uptake (%)",
                       value = 5, min = 0, max = 100, step = 1),
            sliderInput(ns("uptake_linear_end"), "Final Year Uptake (%)",
                       value = 50, min = 0, max = 100, step = 1)
          ),

          conditionalPanel(
            condition = "input.uptake_model == 'sigmoid'",
            ns = ns,
            sliderInput(ns("uptake_sigmoid_max"), "Maximum Uptake (%)",
                       value = 80, min = 0, max = 100, step = 1),
            numericInput(ns("uptake_sigmoid_midpoint"), "Midpoint Year",
                        value = 3, min = 1, step = 0.5),
            numericInput(ns("uptake_sigmoid_rate"), "Growth Rate",
                        value = 1.5, min = 0.1, max = 5, step = 0.1)
          ),

          conditionalPanel(
            condition = "input.uptake_model == 'step'",
            ns = ns,
            sliderInput(ns("uptake_step_initial"), "Initial Uptake (%)",
                       value = 10, min = 0, max = 100, step = 1),
            numericInput(ns("uptake_step_year"), "Step Change Year",
                        value = 3, min = 1, step = 1),
            sliderInput(ns("uptake_step_final"), "Post-Step Uptake (%)",
                       value = 60, min = 0, max = 100, step = 1)
          ),

          conditionalPanel(
            condition = "input.uptake_model == 'custom'",
            ns = ns,
            uiOutput(ns("uptake_custom_inputs"))
          )
        )
      ),

      # Costs
      card(
        card_header("Costs", class = "bg-success text-white"),

        card_body(
          numericInput(ns("cost_intervention"), "Intervention Cost per Patient (£/$/€)",
                      value = 5000, min = 0, step = 100),
          helpText("Annual cost per patient on new intervention"),

          numericInput(ns("cost_comparator"), "Comparator Cost per Patient (£/$/€)",
                      value = 3000, min = 0, step = 100),
          helpText("Annual cost per patient on current/standard care"),

          numericInput(ns("cost_implementation"), "One-Time Implementation Cost (£/$/€)",
                      value = 50000, min = 0, step = 1000),
          helpText("Training, infrastructure, setup costs (Year 1 only)"),

          numericInput(ns("cost_admin"), "Annual Administrative Cost (£/$/€)",
                      value = 10000, min = 0, step = 1000),
          helpText("Ongoing program management costs per year")
        )
      )
    ),

    # Analysis controls
    layout_columns(
      col_widths = c(12),

      card(
        card_header("Analysis Settings"),

        card_body(
          layout_columns(
            col_widths = c(4, 4, 4),

            numericInput(ns("discount_rate"), "Discount Rate (%)",
                        value = 3.5, min = 0, max = 10, step = 0.5),

            selectInput(ns("perspective"), "Perspective",
                       choices = c("Healthcare System" = "healthcare",
                                 "Societal" = "societal",
                                 "Payer" = "payer")),

            selectInput(ns("currency"), "Currency",
                       choices = c("GBP (£)" = "GBP",
                                 "USD ($)" = "USD",
                                 "EUR (€)" = "EUR"))
          ),

          hr(),

          layout_columns(
            col_widths = c(6, 6),

            actionButton(ns("btn_run_bia"), "Run Budget Impact Analysis",
                        icon = icon("play-circle"),
                        class = "btn-primary btn-lg w-100"),

            actionButton(ns("btn_sensitivity"), "Sensitivity Analysis",
                        icon = icon("sliders"),
                        class = "btn-secondary btn-lg w-100")
          )
        )
      )
    ),

    # Results
    layout_columns(
      col_widths = c(12),

      uiOutput(ns("bia_results"))
    )
  )
}

# Server
budget_impact_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    bia_results <- reactiveVal(NULL)
    sensitivity_results <- reactiveVal(NULL)

    # Help modal
    observeEvent(input$btn_help, {
      showModal(modalDialog(
        title = tags$h4(icon("circle-question"), " Budget Impact Analysis Help"),
        size = "l",

        tags$div(
          tags$h5("What is Budget Impact Analysis (BIA)?"),
          tags$p("BIA estimates the financial consequences of adopting a new healthcare intervention. ",
                "Unlike cost-effectiveness analysis (which calculates cost per QALY), BIA focuses on ",
                "total budget requirements to help decision-makers plan resource allocation."),

          tags$hr(),

          tags$h5("Key Inputs:"),
          tags$ul(
            tags$li(tags$strong("Eligible Population:"), " Number of patients who could receive the intervention"),
            tags$li(tags$strong("Time Horizon:"), " Typically 1-5 years (3-5 years recommended)"),
            tags$li(tags$strong("Uptake Model:"), " How quickly the intervention is adopted:",
                   tags$ul(
                     tags$li(tags$em("Linear:"), " Steady growth from Year 1 to final year"),
                     tags$li(tags$em("S-Curve:"), " Slow start, rapid growth, plateau (realistic)"),
                     tags$li(tags$em("Step:"), " Sudden change (e.g., after policy implementation)"),
                     tags$li(tags$em("Custom:"), " Specify uptake for each year manually")
                   )),
            tags$li(tags$strong("Costs:"), " Include intervention costs, comparator costs, implementation, and admin")
          ),

          tags$hr(),

          tags$h5("Outputs:"),
          tags$ul(
            tags$li("Year-by-year budget impact table"),
            tags$li("Cumulative budget impact over time horizon"),
            tags$li("Budget impact per eligible patient"),
            tags$li("Visual uptake curve and cost trajectory"),
            tags$li("Sensitivity analysis on key parameters")
          ),

          tags$hr(),

          tags$h5("Interpretation:"),
          tags$ul(
            tags$li(tags$strong("Positive budget impact:"), " Intervention costs MORE than current care"),
            tags$li(tags$strong("Negative budget impact:"), " Intervention SAVES money (cost-saving)"),
            tags$li(tags$strong("Net budget impact:"), " Includes all costs minus displaced comparator costs")
          ),

          tags$hr(),

          tags$h5("Guidelines:"),
          tags$p("This module follows ISPOR Good Practices for Budget Impact Analysis. ",
                "Recommended perspective: Healthcare System. Recommended time horizon: 3-5 years.")
        ),

        footer = modalButton("Close")
      ))
    })

    # Custom uptake inputs
    output$uptake_custom_inputs <- renderUI({
      req(input$time_horizon)

      inputs <- lapply(1:input$time_horizon, function(year) {
        sliderInput(ns(paste0("uptake_year_", year)),
                   paste("Year", year, "Uptake (%)"),
                   value = min(10 * year, 100),
                   min = 0, max = 100, step = 1)
      })

      tagList(inputs)
    })

    # Run BIA
    observeEvent(input$btn_run_bia, {
      tryCatch({
        # Calculate uptake rates
        uptake_rates <- calculate_uptake_rates(
          model = input$uptake_model,
          time_horizon = input$time_horizon,
          linear_start = input$uptake_linear_start,
          linear_end = input$uptake_linear_end,
          sigmoid_max = input$uptake_sigmoid_max,
          sigmoid_midpoint = input$uptake_sigmoid_midpoint,
          sigmoid_rate = input$uptake_sigmoid_rate,
          step_initial = input$uptake_step_initial,
          step_year = input$uptake_step_year,
          step_final = input$uptake_step_final,
          custom_inputs = sapply(1:input$time_horizon, function(y) {
            input[[paste0("uptake_year_", y)]] %||% 0
          })
        )

        # Calculate BIA
        results <- calculate_bia(
          population_size = input$population_size,
          time_horizon = input$time_horizon,
          uptake_rates = uptake_rates,
          cost_intervention = input$cost_intervention,
          cost_comparator = input$cost_comparator,
          cost_implementation = input$cost_implementation,
          cost_admin = input$cost_admin,
          discount_rate = input$discount_rate / 100,
          currency = input$currency
        )

        bia_results(results)

        showNotification(
          "Budget Impact Analysis completed successfully",
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        showNotification(
          paste("Error running BIA:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Render results
    output$bia_results <- renderUI({
      req(bia_results())

      results <- bia_results()

      tagList(
        # Summary cards
        layout_columns(
          col_widths = c(3, 3, 3, 3),

          value_box(
            title = "Total Budget Impact",
            value = results$total_bi_formatted,
            showcase = icon("coins"),
            theme = if (results$total_bi >= 0) "warning" else "success"
          ),

          value_box(
            title = "Cumulative Patients",
            value = format(results$total_patients, big.mark = ","),
            showcase = icon("users"),
            theme = "primary"
          ),

          value_box(
            title = "Budget Impact per Patient",
            value = results$bi_per_patient_formatted,
            showcase = icon("user"),
            theme = "info"
          ),

          value_box(
            title = "Peak Annual Impact (Year)",
            value = paste0(results$peak_year_formatted, " (Yr ", results$peak_year, ")"),
            showcase = icon("chart-line"),
            theme = "secondary"
          )
        ),

        # Results table
        card(
          card_header(
            tags$h5(class = "mb-0", icon("table"), " Year-by-Year Budget Impact")
          ),

          card_body(
            DTOutput(ns("bia_table")),
            hr(),
            p(class = "text-muted small",
              icon("info-circle"),
              " Budget impact = (Intervention costs + Admin) - Displaced comparator costs. ",
              "Positive values indicate additional budget required; negative values indicate cost savings."
            )
          )
        ),

        # Plots
        card(
          card_header(
            tags$h5(class = "mb-0", icon("chart-area"), " Visual Analysis")
          ),

          navset_card_tab(
            nav_panel(
              "Budget Impact Over Time",
              plotlyOutput(ns("bi_plot"), height = "500px")
            ),
            nav_panel(
              "Uptake Curve",
              plotlyOutput(ns("uptake_plot"), height = "500px")
            ),
            nav_panel(
              "Cumulative Impact",
              plotlyOutput(ns("cumulative_plot"), height = "500px")
            )
          )
        ),

        # Export
        card(
          card_header("Export Results"),
          card_body(
            layout_columns(
              col_widths = c(4, 4, 4),
              downloadButton(ns("download_bia_csv"), "CSV Table",
                           class = "btn-primary w-100"),
              downloadButton(ns("download_bia_plot"), "Plot (PNG)",
                           class = "btn-secondary w-100"),
              downloadButton(ns("download_bia_report"), "Full Report (DOCX)",
                           class = "btn-info w-100")
            )
          )
        )
      )
    })

    # BIA table
    output$bia_table <- renderDT({
      req(bia_results())

      df <- bia_results()$table

      datatable(
        df,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 't'
        ),
        rownames = FALSE,
        class = "display stripe hover"
      ) %>%
        formatCurrency(columns = c("Intervention_Cost", "Comparator_Cost",
                                  "Implementation_Cost", "Admin_Cost",
                                  "Annual_BI", "Cumulative_BI"),
                      currency = bia_results()$currency_symbol) %>%
        formatRound(columns = "Uptake_Rate", digits = 1) %>%
        formatRound(columns = "Patients", digits = 0)
    })

    # Budget impact plot
    output$bi_plot <- renderPlotly({
      req(bia_results())

      df <- bia_results()$table

      fig <- plot_ly(
        data = df,
        x = ~Year,
        y = ~Annual_BI,
        type = "bar",
        marker = list(
          color = ~Annual_BI,
          colorscale = list(c(0, "green"), c(0.5, "yellow"), c(1, "red")),
          colorbar = list(title = "Budget Impact")
        ),
        text = ~paste0("Year ", Year, "<br>Impact: ",
                      bia_results()$currency_symbol,
                      format(round(Annual_BI, 0), big.mark = ",")),
        hoverinfo = "text"
      ) %>%
        layout(
          title = "Annual Budget Impact",
          xaxis = list(title = "Year"),
          yaxis = list(title = paste("Budget Impact (", bia_results()$currency_symbol, ")")),
          shapes = list(
            list(type = "line", x0 = 0, x1 = 1, xref = "paper",
                 y0 = 0, y1 = 0, line = list(dash = "dash", color = "black", width = 2))
          )
        )

      fig
    })

    # Uptake plot
    output$uptake_plot <- renderPlotly({
      req(bia_results())

      df <- bia_results()$table

      fig <- plot_ly(
        data = df,
        x = ~Year,
        y = ~Uptake_Rate,
        type = "scatter",
        mode = "lines+markers",
        line = list(color = "blue", width = 3),
        marker = list(size = 10, color = "darkblue"),
        text = ~paste0("Year ", Year, "<br>Uptake: ", round(Uptake_Rate, 1), "%<br>Patients: ",
                      format(round(Patients, 0), big.mark = ",")),
        hoverinfo = "text"
      ) %>%
        layout(
          title = "Intervention Uptake Over Time",
          xaxis = list(title = "Year"),
          yaxis = list(title = "Uptake Rate (%)", range = c(0, 100))
        )

      fig
    })

    # Cumulative plot
    output$cumulative_plot <- renderPlotly({
      req(bia_results())

      df <- bia_results()$table

      fig <- plot_ly(
        data = df,
        x = ~Year,
        y = ~Cumulative_BI,
        type = "scatter",
        mode = "lines+markers",
        fill = "tozeroy",
        fillcolor = "rgba(0, 100, 200, 0.2)",
        line = list(color = "darkblue", width = 3),
        marker = list(size = 10, color = "darkblue"),
        text = ~paste0("Year ", Year, "<br>Cumulative: ",
                      bia_results()$currency_symbol,
                      format(round(Cumulative_BI, 0), big.mark = ",")),
        hoverinfo = "text"
      ) %>%
        layout(
          title = "Cumulative Budget Impact",
          xaxis = list(title = "Year"),
          yaxis = list(title = paste("Cumulative Budget Impact (", bia_results()$currency_symbol, ")"))
        )

      fig
    })

    # Download handlers
    output$download_bia_csv <- downloadHandler(
      filename = function() {
        paste0("budget_impact_analysis_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(bia_results())
        write.csv(bia_results()$table, file, row.names = FALSE)
      }
    )

    output$download_bia_plot <- downloadHandler(
      filename = function() {
        paste0("budget_impact_plot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(bia_results())

        df <- bia_results()$table

        p <- ggplot(df, aes(x = Year, y = Annual_BI)) +
          geom_bar(stat = "identity", aes(fill = Annual_BI)) +
          scale_fill_gradient2(low = "green", mid = "yellow", high = "red", midpoint = 0) +
          geom_hline(yintercept = 0, linetype = "dashed", color = "black", size = 1) +
          labs(
            title = "Annual Budget Impact Over Time",
            x = "Year",
            y = paste("Budget Impact (", bia_results()$currency_symbol, ")"),
            fill = "Impact"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            axis.text = element_text(size = 11),
            axis.title = element_text(size = 12, face = "bold")
          )

        ggsave(file, p, width = 10, height = 6, dpi = 300)
      }
    )

    output$download_bia_report <- downloadHandler(
      filename = function() {
        paste0("budget_impact_report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
      },
      content = function(file) {
        req(bia_results())

        report <- generate_bia_report(bia_results(), input)
        writeLines(report, file)
      }
    )

    # Return reactive values
    return(reactive({
      list(
        bia_results = bia_results()
      )
    }))
  })
}

# Helper: Calculate uptake rates
calculate_uptake_rates <- function(model, time_horizon, linear_start, linear_end,
                                   sigmoid_max, sigmoid_midpoint, sigmoid_rate,
                                   step_initial, step_year, step_final,
                                   custom_inputs) {
  years <- 1:time_horizon

  if (model == "linear") {
    uptake <- seq(linear_start, linear_end, length.out = time_horizon)

  } else if (model == "sigmoid") {
    # Sigmoid: uptake = max / (1 + exp(-rate * (year - midpoint)))
    uptake <- sigmoid_max / (1 + exp(-sigmoid_rate * (years - sigmoid_midpoint)))

  } else if (model == "step") {
    uptake <- ifelse(years < step_year, step_initial, step_final)

  } else if (model == "custom") {
    uptake <- custom_inputs

  } else {
    uptake <- rep(0, time_horizon)
  }

  return(uptake / 100)  # Convert to proportion
}

# Helper: Calculate BIA
calculate_bia <- function(population_size, time_horizon, uptake_rates,
                         cost_intervention, cost_comparator,
                         cost_implementation, cost_admin,
                         discount_rate, currency) {

  # Build year-by-year table
  table <- data.frame(
    Year = 1:time_horizon,
    Uptake_Rate = uptake_rates * 100,
    Patients = round(population_size * uptake_rates, 0),
    Intervention_Cost = population_size * uptake_rates * cost_intervention,
    Comparator_Cost = population_size * uptake_rates * cost_comparator,
    Implementation_Cost = c(cost_implementation, rep(0, time_horizon - 1)),
    Admin_Cost = rep(cost_admin, time_horizon)
  )

  # Calculate annual budget impact
  table$Annual_BI <- (table$Intervention_Cost + table$Implementation_Cost + table$Admin_Cost) -
                     table$Comparator_Cost

  # Apply discounting
  discount_factors <- 1 / (1 + discount_rate)^(0:(time_horizon - 1))
  table$Discounted_BI <- table$Annual_BI * discount_factors

  # Cumulative budget impact
  table$Cumulative_BI <- cumsum(table$Annual_BI)

  # Summary statistics
  total_bi <- sum(table$Discounted_BI)
  total_patients <- sum(table$Patients)
  bi_per_patient <- if (total_patients > 0) total_bi / total_patients else 0

  peak_year <- which.max(abs(table$Annual_BI))
  peak_year_impact <- table$Annual_BI[peak_year]

  # Currency symbol
  currency_symbol <- switch(currency,
                           "GBP" = "£",
                           "USD" = "$",
                           "EUR" = "€",
                           "$")

  return(list(
    table = table,
    total_bi = total_bi,
    total_bi_formatted = paste0(currency_symbol, format(round(total_bi, 0), big.mark = ",")),
    total_patients = total_patients,
    bi_per_patient = bi_per_patient,
    bi_per_patient_formatted = paste0(currency_symbol, format(round(bi_per_patient, 0), big.mark = ",")),
    peak_year = peak_year,
    peak_year_formatted = paste0(currency_symbol, format(round(peak_year_impact, 0), big.mark = ",")),
    currency_symbol = currency_symbol
  ))
}

# Helper: Generate BIA report
generate_bia_report <- function(results, input) {
  report <- c(
    "BUDGET IMPACT ANALYSIS REPORT",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "=" %R% 60,
    "",
    "ANALYSIS PARAMETERS:",
    "",
    paste("Eligible Population:", format(input$population_size, big.mark = ",")),
    paste("Time Horizon:", input$time_horizon, "years"),
    paste("Uptake Model:", input$uptake_model),
    paste("Intervention Cost:", results$currency_symbol, format(input$cost_intervention, big.mark = ",")),
    paste("Comparator Cost:", results$currency_symbol, format(input$cost_comparator, big.mark = ",")),
    paste("Implementation Cost:", results$currency_symbol, format(input$cost_implementation, big.mark = ",")),
    paste("Admin Cost (annual):", results$currency_symbol, format(input$cost_admin, big.mark = ",")),
    paste("Discount Rate:", input$discount_rate, "%"),
    paste("Perspective:", input$perspective),
    paste("Currency:", input$currency),
    "",
    "=" %R% 60,
    "",
    "RESULTS SUMMARY:",
    "",
    paste("Total Budget Impact:", results$total_bi_formatted),
    paste("Total Patients Treated:", format(results$total_patients, big.mark = ",")),
    paste("Budget Impact per Patient:", results$bi_per_patient_formatted),
    paste("Peak Annual Impact:", results$peak_year_formatted, "(Year", results$peak_year, ")"),
    "",
    "=" %R% 60,
    "",
    "YEAR-BY-YEAR BREAKDOWN:",
    "",
    capture.output(print(results$table)),
    "",
    "=" %R% 60,
    "",
    "INTERPRETATION:",
    "",
    if (results$total_bi > 0) {
      c("The intervention results in a POSITIVE budget impact (additional costs).",
        paste("Healthcare system would need to allocate an additional", results$total_bi_formatted,
              "over", input$time_horizon, "years."))
    } else {
      c("The intervention results in a NEGATIVE budget impact (cost savings).",
        paste("Healthcare system would SAVE", results$total_bi_formatted,
              "over", input$time_horizon, "years."))
    },
    "",
    "=" %R% 60
  )

  return(report)
}

# Utility: Null coalescing operator
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

# Utility: String repetition
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
