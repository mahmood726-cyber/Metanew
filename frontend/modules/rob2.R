# Risk of Bias 2.0 (RoB 2) Assessment Module
# Reference: Sterne et al. (2019) RoB 2: a revised tool for assessing risk of bias in randomised trials
# BMJ 2019;366:l4898

library(shiny)
library(bslib)
library(DT)
library(ggplot2)

rob2_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(4, 8),

      # Left panel: Assessment entry
      card(
        card_header("RoB 2.0 Assessment"),
        helpText("Assess risk of bias for each included study using the Cochrane RoB 2.0 tool"),

        selectInput(ns("study_select"), "Select Study", choices = NULL),

        hr(),
        h5("Domain 1: Randomization Process"),
        selectInput(ns("d1_rating"), "Rating",
                    choices = c("", "Low", "Some concerns", "High")),
        textAreaInput(ns("d1_rationale"), "Rationale", rows = 2),

        hr(),
        h5("Domain 2: Deviations from Intended Interventions"),
        selectInput(ns("d2_rating"), "Rating",
                    choices = c("", "Low", "Some concerns", "High")),
        textAreaInput(ns("d2_rationale"), "Rationale", rows = 2),

        hr(),
        h5("Domain 3: Missing Outcome Data"),
        selectInput(ns("d3_rating"), "Rating",
                    choices = c("", "Low", "Some concerns", "High")),
        textAreaInput(ns("d3_rationale"), "Rationale", rows = 2),

        hr(),
        h5("Domain 4: Measurement of the Outcome"),
        selectInput(ns("d4_rating"), "Rating",
                    choices = c("", "Low", "Some concerns", "High")),
        textAreaInput(ns("d4_rationale"), "Rationale", rows = 2),

        hr(),
        h5("Domain 5: Selection of the Reported Result"),
        selectInput(ns("d5_rating"), "Rating",
                    choices = c("", "Low", "Some concerns", "High")),
        textAreaInput(ns("d5_rationale"), "Rationale", rows = 2),

        hr(),
        div(
          class = "d-flex gap-2",
          actionButton(ns("btn_save"), "Save Assessment",
                       class = "btn-success flex-fill", icon = icon("save")),
          actionButton(ns("btn_clear"), "Clear",
                       class = "btn-secondary flex-fill", icon = icon("eraser"))
        )
      ),

      # Right panel: Summary and visualization
      card(
        card_header("RoB 2.0 Summary"),
        navset_card_tab(
          nav_panel(
            "Traffic Light Plot",
            icon = icon("traffic-light"),
            plotOutput(ns("traffic_light_plot"), height = "500px"),
            hr(),
            helpText("Traffic light plot showing risk of bias across studies and domains.",
                     "Green = Low risk | Yellow = Some concerns | Red = High risk")
          ),
          nav_panel(
            "Summary Table",
            icon = icon("table"),
            DTOutput(ns("rob_table")),
            hr(),
            downloadButton(ns("download_rob"), "Download RoB Table", class = "btn-sm btn-primary")
          ),
          nav_panel(
            "Domain Summary",
            icon = icon("chart-bar"),
            plotOutput(ns("domain_summary_plot"), height = "400px"),
            hr(),
            verbatimTextOutput(ns("domain_summary_text"))
          ),
          nav_panel(
            "Overall Summary",
            icon = icon("pie-chart"),
            plotOutput(ns("overall_summary_plot"), height = "400px"),
            hr(),
            uiOutput(ns("overall_summary_stats"))
          )
        )
      )
    )
  )
}

rob2_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values for RoB assessments
    rob_assessments <- reactiveVal(list())

    # Update study choices when data is loaded
    observe({
      req(rv$data)
      if ("study_id" %in% names(rv$data)) {
        studies <- unique(rv$data$study_id)
        updateSelectInput(session, "study_select", choices = studies)
      }
    })

    # Load existing assessment when study is selected
    observeEvent(input$study_select, {
      req(input$study_select)
      assessments <- rob_assessments()

      if (input$study_select %in% names(assessments)) {
        # Load existing assessment
        rob <- assessments[[input$study_select]]
        updateSelectInput(session, "d1_rating", selected = rob$d1_rating)
        updateTextAreaInput(session, "d1_rationale", value = rob$d1_rationale)
        updateSelectInput(session, "d2_rating", selected = rob$d2_rating)
        updateTextAreaInput(session, "d2_rationale", value = rob$d2_rationale)
        updateSelectInput(session, "d3_rating", selected = rob$d3_rating)
        updateTextAreaInput(session, "d3_rationale", value = rob$d3_rationale)
        updateSelectInput(session, "d4_rating", selected = rob$d4_rating)
        updateTextAreaInput(session, "d4_rationale", value = rob$d4_rationale)
        updateSelectInput(session, "d5_rating", selected = rob$d5_rating)
        updateTextAreaInput(session, "d5_rationale", value = rob$d5_rationale)
      } else {
        # Clear form for new assessment
        observeEvent(input$btn_clear, {}, ignoreInit = FALSE, once = TRUE)
      }
    })

    # Save assessment
    observeEvent(input$btn_save, {
      req(input$study_select)

      # Calculate overall RoB using RoB 2.0 algorithm
      # Overall = High if any domain is High
      # Overall = Some concerns if no High but at least one Some concerns
      # Overall = Low if all domains are Low
      overall <- calculate_overall_rob(
        c(input$d1_rating, input$d2_rating, input$d3_rating,
          input$d4_rating, input$d5_rating)
      )

      assessment <- list(
        study_id = input$study_select,
        d1_rating = input$d1_rating,
        d1_rationale = input$d1_rationale,
        d2_rating = input$d2_rating,
        d2_rationale = input$d2_rationale,
        d3_rating = input$d3_rating,
        d3_rationale = input$d3_rationale,
        d4_rating = input$d4_rating,
        d4_rationale = input$d4_rationale,
        d5_rating = input$d5_rating,
        d5_rationale = input$d5_rationale,
        overall = overall,
        timestamp = Sys.time()
      )

      # Save to assessments
      assessments <- rob_assessments()
      assessments[[input$study_select]] <- assessment
      rob_assessments(assessments)

      # Also save to rv for use in other modules
      if (is.null(rv$rob2_assessments)) {
        rv$rob2_assessments <- list()
      }
      rv$rob2_assessments[[input$study_select]] <- assessment

      showNotification(
        sprintf("✓ RoB 2.0 assessment saved for %s (Overall: %s)",
                input$study_select, overall),
        type = "message",
        duration = 3
      )
    })

    # Clear form
    observeEvent(input$btn_clear, {
      updateSelectInput(session, "d1_rating", selected = "")
      updateTextAreaInput(session, "d1_rationale", value = "")
      updateSelectInput(session, "d2_rating", selected = "")
      updateTextAreaInput(session, "d2_rationale", value = "")
      updateSelectInput(session, "d3_rating", selected = "")
      updateTextAreaInput(session, "d3_rationale", value = "")
      updateSelectInput(session, "d4_rating", selected = "")
      updateTextAreaInput(session, "d4_rationale", value = "")
      updateSelectInput(session, "d5_rating", selected = "")
      updateTextAreaInput(session, "d5_rationale", value = "")
    })

    # Traffic light plot
    output$traffic_light_plot <- renderPlot({
      assessments <- rob_assessments()
      req(length(assessments) > 0)

      create_traffic_light_plot(assessments)
    })

    # RoB summary table
    output$rob_table <- renderDT({
      assessments <- rob_assessments()
      req(length(assessments) > 0)

      # Convert to data frame
      rob_df <- do.call(rbind, lapply(names(assessments), function(study) {
        rob <- assessments[[study]]
        data.frame(
          Study = study,
          D1_Randomization = rob$d1_rating,
          D2_Deviations = rob$d2_rating,
          D3_Missing_Data = rob$d3_rating,
          D4_Measurement = rob$d4_rating,
          D5_Selection = rob$d5_rating,
          Overall = rob$overall,
          stringsAsFactors = FALSE
        )
      }))

      datatable(
        rob_df,
        options = list(
          pageLength = 20,
          dom = 'tp'
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          columns = 2:7,
          backgroundColor = styleEqual(
            c("Low", "Some concerns", "High"),
            c("#90EE90", "#FFD700", "#FF6B6B")
          )
        )
    })

    # Domain summary plot
    output$domain_summary_plot <- renderPlot({
      assessments <- rob_assessments()
      req(length(assessments) > 0)

      create_domain_summary_plot(assessments)
    })

    # Domain summary text
    output$domain_summary_text <- renderPrint({
      assessments <- rob_assessments()
      req(length(assessments) > 0)

      domains <- c("D1: Randomization", "D2: Deviations", "D3: Missing Data",
                   "D4: Measurement", "D5: Selection")
      ratings <- c("d1_rating", "d2_rating", "d3_rating", "d4_rating", "d5_rating")

      cat("DOMAIN-LEVEL SUMMARY\n")
      cat("===================\n\n")

      for (i in 1:length(domains)) {
        values <- sapply(assessments, function(x) x[[ratings[i]]])
        values <- values[values != ""]

        if (length(values) > 0) {
          cat(sprintf("%s:\n", domains[i]))
          cat(sprintf("  Low risk: %d (%.0f%%)\n",
                      sum(values == "Low"), 100 * mean(values == "Low")))
          cat(sprintf("  Some concerns: %d (%.0f%%)\n",
                      sum(values == "Some concerns"), 100 * mean(values == "Some concerns")))
          cat(sprintf("  High risk: %d (%.0f%%)\n",
                      sum(values == "High"), 100 * mean(values == "High")))
          cat("\n")
        }
      }
    })

    # Overall summary plot
    output$overall_summary_plot <- renderPlot({
      assessments <- rob_assessments()
      req(length(assessments) > 0)

      # Extract overall ratings
      overall_ratings <- sapply(assessments, function(x) x$overall)
      overall_ratings <- overall_ratings[overall_ratings != ""]

      if (length(overall_ratings) > 0) {
        # Create pie chart
        counts <- table(factor(overall_ratings,
                               levels = c("Low", "Some concerns", "High")))

        df <- data.frame(
          Rating = names(counts),
          Count = as.numeric(counts),
          Percentage = as.numeric(counts) / sum(counts) * 100
        )

        ggplot(df, aes(x = "", y = Count, fill = Rating)) +
          geom_bar(stat = "identity", width = 1) +
          coord_polar("y") +
          scale_fill_manual(values = c("Low" = "#90EE90",
                                       "Some concerns" = "#FFD700",
                                       "High" = "#FF6B6B")) +
          labs(title = "Overall Risk of Bias Summary",
               subtitle = sprintf("n = %d studies assessed", length(overall_ratings))) +
          theme_void() +
          theme(
            plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
            plot.subtitle = element_text(size = 12, hjust = 0.5),
            legend.position = "right"
          ) +
          geom_text(aes(label = sprintf("%d\n(%.0f%%)", Count, Percentage)),
                    position = position_stack(vjust = 0.5),
                    size = 5, fontface = "bold")
      }
    })

    # Overall summary stats
    output$overall_summary_stats <- renderUI({
      assessments <- rob_assessments()
      req(length(assessments) > 0)

      overall_ratings <- sapply(assessments, function(x) x$overall)
      overall_ratings <- overall_ratings[overall_ratings != ""]

      if (length(overall_ratings) > 0) {
        n_low <- sum(overall_ratings == "Low")
        n_some <- sum(overall_ratings == "Some concerns")
        n_high <- sum(overall_ratings == "High")
        n_total <- length(overall_ratings)

        tagList(
          div(
            class = "p-3",
            h5("Overall Risk of Bias Across Studies"),
            tags$table(
              class = "table table-sm",
              tags$tr(
                tags$td(strong("Total studies assessed:")),
                tags$td(n_total)
              ),
              tags$tr(
                tags$td(strong("Low risk of bias:")),
                tags$td(sprintf("%d (%.0f%%)", n_low, 100 * n_low / n_total)),
                tags$td(style = "background-color: #90EE90;", "")
              ),
              tags$tr(
                tags$td(strong("Some concerns:")),
                tags$td(sprintf("%d (%.0f%%)", n_some, 100 * n_some / n_total)),
                tags$td(style = "background-color: #FFD700;", "")
              ),
              tags$tr(
                tags$td(strong("High risk of bias:")),
                tags$td(sprintf("%d (%.0f%%)", n_high, 100 * n_high / n_total)),
                tags$td(style = "background-color: #FF6B6B;", "")
              )
            ),
            hr(),
            if (n_high / n_total > 0.5) {
              div(
                class = "alert alert-danger",
                icon("exclamation-triangle"),
                sprintf(" Warning: More than 50%% of studies at high risk of bias (%d/%d)",
                        n_high, n_total)
              )
            } else if (n_low / n_total > 0.7) {
              div(
                class = "alert alert-success",
                icon("check-circle"),
                sprintf(" Good: Most studies at low risk of bias (%d/%d)", n_low, n_total)
              )
            } else {
              div(
                class = "alert alert-warning",
                icon("info-circle"),
                " Mixed risk of bias across included studies"
              )
            }
          )
        )
      }
    })

    # Download RoB table
    output$download_rob <- downloadHandler(
      filename = function() {
        paste0("rob2_assessment_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        assessments <- rob_assessments()
        rob_df <- do.call(rbind, lapply(names(assessments), function(study) {
          rob <- assessments[[study]]
          data.frame(
            Study = study,
            D1_Randomization = rob$d1_rating,
            D1_Rationale = rob$d1_rationale,
            D2_Deviations = rob$d2_rating,
            D2_Rationale = rob$d2_rationale,
            D3_Missing_Data = rob$d3_rating,
            D3_Rationale = rob$d3_rationale,
            D4_Measurement = rob$d4_rating,
            D4_Rationale = rob$d4_rationale,
            D5_Selection = rob$d5_rating,
            D5_Rationale = rob$d5_rationale,
            Overall = rob$overall,
            stringsAsFactors = FALSE
          )
        }))
        write.csv(rob_df, file, row.names = FALSE)
      }
    )

    return(reactive(rob_assessments()))
  })
}

# Helper function: Calculate overall RoB using RoB 2.0 algorithm
# Reference: Sterne et al. (2019) Algorithm for determining overall risk of bias
calculate_overall_rob <- function(domain_ratings) {
  # Remove empty ratings
  ratings <- domain_ratings[domain_ratings != ""]

  if (length(ratings) == 0) {
    return("")
  }

  # Algorithm: Overall = High if any domain is High
  if (any(ratings == "High")) {
    return("High")
  }

  # Overall = Some concerns if no High but at least one Some concerns
  if (any(ratings == "Some concerns")) {
    return("Some concerns")
  }

  # Overall = Low if all domains are Low
  if (all(ratings == "Low")) {
    return("Low")
  }

  return("Some concerns")  # Default
}

# Helper function: Create traffic light plot
# Reference: McGuinness & Higgins (2020) Risk-of-bias VISualization (robvis)
create_traffic_light_plot <- function(assessments) {
  # Convert to data frame
  rob_df <- do.call(rbind, lapply(names(assessments), function(study) {
    rob <- assessments[[study]]
    data.frame(
      Study = study,
      D1 = rob$d1_rating,
      D2 = rob$d2_rating,
      D3 = rob$d3_rating,
      D4 = rob$d4_rating,
      D5 = rob$d5_rating,
      Overall = rob$overall,
      stringsAsFactors = FALSE
    )
  }))

  # Reshape to long format
  rob_long <- reshape2::melt(rob_df, id.vars = "Study",
                              variable.name = "Domain", value.name = "Rating")

  # Filter out empty ratings
  rob_long <- rob_long[rob_long$Rating != "", ]

  # Create traffic light plot
  domain_labels <- c(
    "D1" = "D1: Randomization",
    "D2" = "D2: Deviations",
    "D3" = "D3: Missing Data",
    "D4" = "D4: Measurement",
    "D5" = "D5: Selection",
    "Overall" = "Overall"
  )

  ggplot(rob_long, aes(x = Domain, y = Study, fill = Rating)) +
    geom_tile(color = "white", size = 1.5) +
    scale_fill_manual(
      values = c("Low" = "#90EE90",
                 "Some concerns" = "#FFD700",
                 "High" = "#FF6B6B"),
      na.value = "gray90"
    ) +
    scale_x_discrete(labels = domain_labels) +
    labs(
      title = "Risk of Bias Assessment: Traffic Light Plot",
      subtitle = "Cochrane RoB 2.0 tool",
      x = "",
      y = "",
      fill = "Risk of Bias"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 10, color = "gray40"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
      axis.text.y = element_text(size = 9),
      legend.position = "bottom",
      panel.grid = element_blank()
    ) +
    guides(fill = guide_legend(nrow = 1))
}

# Helper function: Create domain summary plot
create_domain_summary_plot <- function(assessments) {
  domains <- c("D1: Randomization", "D2: Deviations", "D3: Missing Data",
               "D4: Measurement", "D5: Selection")
  ratings_vars <- c("d1_rating", "d2_rating", "d3_rating", "d4_rating", "d5_rating")

  # Count ratings for each domain
  domain_data <- do.call(rbind, lapply(1:length(domains), function(i) {
    values <- sapply(assessments, function(x) x[[ratings_vars[i]]])
    values <- values[values != ""]

    if (length(values) > 0) {
      data.frame(
        Domain = domains[i],
        Low = sum(values == "Low"),
        Some_concerns = sum(values == "Some concerns"),
        High = sum(values == "High"),
        stringsAsFactors = FALSE
      )
    } else {
      NULL
    }
  }))

  if (nrow(domain_data) > 0) {
    # Reshape to long format
    domain_long <- reshape2::melt(domain_data, id.vars = "Domain",
                                   variable.name = "Rating", value.name = "Count")

    # Reorder rating levels
    domain_long$Rating <- factor(domain_long$Rating,
                                   levels = c("Low", "Some_concerns", "High"),
                                   labels = c("Low", "Some concerns", "High"))

    # Create stacked bar chart
    ggplot(domain_long, aes(x = Domain, y = Count, fill = Rating)) +
      geom_bar(stat = "identity", position = "stack") +
      scale_fill_manual(values = c("Low" = "#90EE90",
                                    "Some concerns" = "#FFD700",
                                    "High" = "#FF6B6B")) +
      labs(
        title = "Risk of Bias by Domain",
        subtitle = sprintf("Across %d assessed studies", length(assessments)),
        x = "",
        y = "Number of Studies",
        fill = "Risk of Bias"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 14, face = "bold"),
        plot.subtitle = element_text(size = 10, color = "gray40"),
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom"
      ) +
      geom_text(aes(label = ifelse(Count > 0, Count, "")),
                position = position_stack(vjust = 0.5),
                size = 4, fontface = "bold")
  }
}
