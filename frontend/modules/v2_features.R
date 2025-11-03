# V2 Features Module
# Integrates scenario presets, caching, protocol diff, advanced HE, and living MA

# Source utility functions
source("utils/scenario_presets.R")
source("utils/cache_bridge.R", local = TRUE)
source("utils/protocol_diff.R")
source("utils/advanced_he.R")
source("utils/living_ma_tracker.R")

#' V2 Features UI
v2_features_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("Version 2.0 Features"),

    # Tab layout for different V2 features
    tabsetPanel(
      id = ns("v2_tabs"),

      # ====================================================================
      # SCENARIO PRESETS TAB
      # ====================================================================
      tabPanel(
        "Scenario Presets",
        icon = icon("bookmark"),
        value = "presets",

        fluidRow(
          column(
            width = 6,
            h4("Load Preset Scenario"),
            selectInput(
              ns("preset_selector"),
              "Select Preset:",
              choices = NULL  # Will be populated in server
            ),
            actionButton(ns("load_preset"), "Load Preset", class = "btn-primary"),
            hr(),
            uiOutput(ns("preset_summary"))
          ),
          column(
            width = 6,
            h4("Save Custom Preset"),
            textInput(ns("custom_preset_name"), "Preset Name:"),
            textAreaInput(ns("custom_preset_desc"), "Description:", rows = 3),
            actionButton(ns("save_custom_preset"), "Save Current Configuration", class = "btn-success")
          )
        )
      ),

      # ====================================================================
      # CACHE MANAGEMENT TAB
      # ====================================================================
      tabPanel(
        "Cache Management",
        icon = icon("database"),
        value = "cache",

        h4("Analysis Cache Statistics"),

        fluidRow(
          column(
            width = 8,
            uiOutput(ns("cache_stats_display"))
          ),
          column(
            width = 4,
            actionButton(ns("refresh_cache_stats"), "Refresh Stats", class = "btn-info"),
            br(), br(),
            numericInput(ns("cache_clear_days"), "Clear cache older than (days):", value = 30, min = 1),
            actionButton(ns("clear_old_cache"), "Clear Old Cache", class = "btn-warning"),
            br(), br(),
            checkboxInput(ns("enable_caching"), "Enable caching for analyses", value = TRUE)
          )
        ),

        hr(),

        h5("Cached Analyses"),
        DT::dataTableOutput(ns("cached_analyses_table"))
      ),

      # ====================================================================
      # PROTOCOL DIFF TAB
      # ====================================================================
      tabPanel(
        "Protocol Diff",
        icon = icon("code-compare"),
        value = "protocol_diff",

        h4("Protocol Version Comparison"),

        fluidRow(
          column(
            width = 4,
            h5("Manage Versions"),
            textInput(ns("protocol_version_name"), "Version Name:"),
            actionButton(ns("save_protocol_version"), "Save Current Protocol", class = "btn-primary"),
            hr(),
            selectInput(ns("protocol_versions_list"), "Saved Versions:", choices = NULL, multiple = FALSE)
          ),
          column(
            width = 8,
            h5("Compare Versions"),
            fluidRow(
              column(
                width = 6,
                selectInput(ns("protocol_version_1"), "Version 1:", choices = NULL)
              ),
              column(
                width = 6,
                selectInput(ns("protocol_version_2"), "Version 2:", choices = NULL)
              )
            ),
            actionButton(ns("compare_protocols"), "Compare", class = "btn-info"),
            br(), br(),
            uiOutput(ns("protocol_diff_display"))
          )
        )
      ),

      # ====================================================================
      # ADVANCED HEALTH ECONOMICS TAB
      # ====================================================================
      tabPanel(
        "Advanced HE",
        icon = icon("chart-line"),
        value = "advanced_he",

        h4("Advanced Health Economics Analysis"),

        tabsetPanel(
          # VOI Analysis
          tabPanel(
            "Value of Information",
            h5("Expected Value of Perfect Information (EVPI)"),
            fluidRow(
              column(
                width = 4,
                numericInput(ns("evpi_wtp"), "WTP Threshold (£/QALY):", value = 30000, min = 0),
                numericInput(ns("evpi_n_patients"), "Population Size:", value = 10000, min = 1),
                actionButton(ns("calculate_evpi"), "Calculate EVPI", class = "btn-primary")
              ),
              column(
                width = 8,
                uiOutput(ns("evpi_results_display")),
                plotlyOutput(ns("evpi_curve_plot"))
              )
            )
          ),

          # Budget Impact Model
          tabPanel(
            "Budget Impact",
            h5("Budget Impact Model"),
            fluidRow(
              column(
                width = 4,
                numericInput(ns("bim_intervention_cost"), "Intervention Cost per Patient (£):", value = 10000),
                numericInput(ns("bim_comparator_cost"), "Comparator Cost per Patient (£):", value = 5000),
                numericInput(ns("bim_n_patients_yr1"), "Patients Year 1:", value = 1000),
                numericInput(ns("bim_market_share_yr1"), "Market Share Year 1 (%):", value = 10, min = 0, max = 100),
                numericInput(ns("bim_market_share_yr5"), "Market Share Year 5 (%):", value = 50, min = 0, max = 100),
                numericInput(ns("bim_n_years"), "Number of Years:", value = 5, min = 1, max = 10),
                actionButton(ns("calculate_bim"), "Calculate Budget Impact", class = "btn-primary")
              ),
              column(
                width = 8,
                uiOutput(ns("bim_results_display")),
                plotlyOutput(ns("bim_plot"))
              )
            )
          )
        )
      ),

      # ====================================================================
      # LIVING MA TRACKER TAB
      # ====================================================================
      tabPanel(
        "Living MA Tracker",
        icon = icon("rotate"),
        value = "living_ma",

        h4("Living Meta-Analysis Update Tracker"),

        fluidRow(
          column(
            width = 4,
            h5("Register MA for Living Updates"),
            textInput(ns("living_ma_name"), "MA Name:"),
            textInput(ns("living_ma_outcome"), "Outcome:"),
            numericInput(ns("living_ma_n_studies"), "Number of Studies:", value = 10, min = 1),
            numericInput(ns("living_ma_effect"), "Effect Size:", value = 0.5),
            numericInput(ns("living_ma_i2"), "I² (%):", value = 50, min = 0, max = 100),
            selectInput(ns("living_ma_trigger"), "Update Trigger:",
                       choices = c("New study" = "new_study",
                                  "Quarterly" = "quarterly",
                                  "Signal detected" = "signal")),
            actionButton(ns("register_living_ma"), "Register", class = "btn-success")
          ),
          column(
            width = 8,
            h5("Update Dashboard"),
            uiOutput(ns("living_ma_dashboard")),
            hr(),
            h5("Check for Updates"),
            selectInput(ns("living_ma_select"), "Select MA:", choices = NULL),
            numericInput(ns("living_ma_new_n"), "New # Studies:", value = 0),
            actionButton(ns("check_update_signal"), "Check for Update Signal", class = "btn-info"),
            br(), br(),
            uiOutput(ns("update_signal_display"))
          )
        )
      )
    )
  )
}

#' V2 Features Server
v2_features_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Initialize cache manager
    cache_manager <- reactive({
      init_cache_manager()
    })

    # Load scenario presets
    presets_data <- reactive({
      load_scenario_presets()
    })

    # ====================================================================
    # SCENARIO PRESETS
    # ====================================================================

    # Populate preset selector
    observe({
      presets <- presets_data()
      choices <- create_preset_choices(presets)
      updateSelectInput(session, "preset_selector", choices = choices)
    })

    # Display preset summary
    output$preset_summary <- renderUI({
      req(input$preset_selector, input$preset_selector != "")

      preset <- get_preset_by_id(input$preset_selector, presets_data())
      generate_preset_summary(preset)
    })

    # Load preset
    observeEvent(input$load_preset, {
      req(input$preset_selector, input$preset_selector != "")

      preset <- get_preset_by_id(input$preset_selector, presets_data())

      if (!is.null(preset)) {
        rv <- apply_preset_to_rv(preset, rv, session)

        showNotification(
          sprintf("✓ Loaded preset: %s", preset$name),
          type = "message",
          duration = 3
        )
      }
    })

    # Save custom preset
    observeEvent(input$save_custom_preset, {
      req(input$custom_preset_name)

      # Handle null/empty description
      desc <- if (is.null(input$custom_preset_desc) || input$custom_preset_desc == "") {
        ""
      } else {
        input$custom_preset_desc
      }

      success <- save_custom_preset(
        rv = rv,
        preset_name = input$custom_preset_name,
        preset_description = desc
      )

      if (success) {
        showNotification(
          sprintf("✓ Saved custom preset: %s", input$custom_preset_name),
          type = "message",
          duration = 3
        )
      }
    })

    # ====================================================================
    # CACHE MANAGEMENT
    # ====================================================================

    # Display cache stats
    output$cache_stats_display <- renderUI({
      input$refresh_cache_stats  # Trigger on refresh

      stats <- get_cache_stats(cache_manager())
      format_cache_stats(stats)
    })

    # Clear old cache
    observeEvent(input$clear_old_cache, {
      req(input$cache_clear_days)

      count <- clear_old_cache(cache_manager(), days = input$cache_clear_days)

      showNotification(
        sprintf("✓ Cleared %d cache entries", count),
        type = "message",
        duration = 3
      )
    })

    # ====================================================================
    # PROTOCOL DIFF
    # ====================================================================

    # Refresh protocol versions list
    protocol_versions <- reactive({
      input$save_protocol_version  # Trigger on save
      list_protocol_versions()
    })

    observe({
      versions <- protocol_versions()

      if (nrow(versions) > 0) {
        choices <- setNames(versions$version_id, versions$version_name)
        updateSelectInput(session, "protocol_versions_list", choices = choices)
        updateSelectInput(session, "protocol_version_1", choices = choices)
        updateSelectInput(session, "protocol_version_2", choices = choices)
      }
    })

    # Save protocol version
    observeEvent(input$save_protocol_version, {
      req(input$protocol_version_name)

      version_id <- save_protocol_version(
        protocol = rv$protocol,
        version_name = input$protocol_version_name
      )

      showNotification(
        sprintf("✓ Saved protocol version: %s", input$protocol_version_name),
        type = "message",
        duration = 3
      )
    })

    # Compare protocols
    output$protocol_diff_display <- renderUI({
      req(input$compare_protocols > 0)
      req(input$protocol_version_1, input$protocol_version_2)

      diff_result <- compare_protocol_versions(
        input$protocol_version_1,
        input$protocol_version_2
      )

      generate_diff_report_html(diff_result)
    })

    # ====================================================================
    # ADVANCED HE
    # ====================================================================

    # Calculate EVPI
    evpi_result <- eventReactive(input$calculate_evpi, {
      req(rv$psa_results)

      calculate_evpi(
        psa_results = rv$psa_results,
        wtp_threshold = input$evpi_wtp,
        n_patients = input$evpi_n_patients
      )
    })

    output$evpi_results_display <- renderUI({
      format_evpi_display(evpi_result())
    })

    output$evpi_curve_plot <- renderPlotly({
      req(rv$psa_results)

      plot <- plot_evpi_curve(
        rv$psa_results,
        wtp_range = seq(0, 50000, by = 5000),
        n_patients = input$evpi_n_patients
      )

      ggplotly(plot)
    })

    # Calculate budget impact
    bim_result <- eventReactive(input$calculate_bim, {
      calculate_budget_impact(
        intervention_cost = input$bim_intervention_cost,
        comparator_cost = input$bim_comparator_cost,
        n_patients_yr1 = input$bim_n_patients_yr1,
        market_share_yr1 = input$bim_market_share_yr1 / 100,
        market_share_yr5 = input$bim_market_share_yr5 / 100,
        n_years = input$bim_n_years
      )
    })

    output$bim_results_display <- renderUI({
      format_bim_display(bim_result())
    })

    output$bim_plot <- renderPlotly({
      plot <- plot_budget_impact(bim_result())
      if (!is.null(plot)) {
        ggplotly(plot)
      }
    })

    # ====================================================================
    # LIVING MA TRACKER
    # ====================================================================

    # Register living MA
    observeEvent(input$register_living_ma, {
      req(input$living_ma_name, input$living_ma_outcome)

      ma_id <- paste0("ma_", digest::digest(input$living_ma_name, algo = "sha256") %>% substr(1, 8))

      register_living_ma(
        ma_id = ma_id,
        ma_name = input$living_ma_name,
        outcome = input$living_ma_outcome,
        n_studies = input$living_ma_n_studies,
        effect_size = input$living_ma_effect,
        i2 = input$living_ma_i2,
        update_trigger = input$living_ma_trigger
      )

      showNotification(
        sprintf("✓ Registered living MA: %s", input$living_ma_name),
        type = "message",
        duration = 3
      )
    })

    # Living MA dashboard
    output$living_ma_dashboard <- renderUI({
      input$register_living_ma  # Trigger on registration
      input$check_update_signal  # Trigger on check

      create_living_ma_dashboard()
    })

    # Check for update signal
    output$update_signal_display <- renderUI({
      req(input$check_update_signal > 0)
      req(input$living_ma_select, input$living_ma_new_n)

      signal_result <- check_update_signal(
        ma_id = input$living_ma_select,
        new_n_studies = input$living_ma_new_n
      )

      generate_update_alert(signal_result)
    })
  })
}
