# =============================================================================
# SUCRA Rankings Module for Network Meta-Analysis
# =============================================================================
# ✅ STANDARD - Widely accepted by Cochrane, NICE, and ISPOR for NMA
#
# Features:
# - SUCRA (Surface Under the Cumulative RAnking) scores
# - Probabilistic ranking of treatments
# - Rankograms (probability of each rank)
# - Cumulative ranking curves
# - Treatment hierarchy visualization
# - Mean ranks with uncertainty
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(netmeta)
library(dplyr)
library(tidyr)

#' Calculate SUCRA scores from network meta-analysis
#'
#' @param nma_result netmeta object from network meta-analysis
#' @param small_values Character indicating if small values are good ("desirable") or bad ("undesirable")
#' @return List with SUCRA scores, rankograms, and mean ranks
#' @export
calculate_sucra <- function(nma_result, small_values = "undesirable") {

  # Get ranking probabilities from netmeta
  rank_probs <- netrank(nma_result, small.values = small_values)

  # Extract SUCRA scores
  sucra_scores <- if (small_values == "desirable") {
    rank_probs$ranking.random  # Use random effects if available
  } else {
    rank_probs$ranking.random
  }

  # Get probability matrix (treatments x ranks)
  # Rows = treatments, Columns = ranks (1st, 2nd, 3rd, etc.)
  prob_matrix <- rank_probs$ranking.matrix.random

  # Calculate SUCRA manually if not provided
  n_treatments <- nrow(prob_matrix)
  sucra_manual <- numeric(n_treatments)

  for (i in 1:n_treatments) {
    # SUCRA = sum of probabilities of being better than average
    # Formula: SUCRA = 1/(n-1) * sum(cumulative probabilities - 1/2)
    cum_probs <- cumsum(prob_matrix[i, ])
    sucra_manual[i] <- sum(cum_probs[1:(n_treatments-1)]) / (n_treatments - 1)
  }

  # Mean rank for each treatment
  mean_ranks <- numeric(n_treatments)
  for (i in 1:n_treatments) {
    mean_ranks[i] <- sum((1:n_treatments) * prob_matrix[i, ])
  }

  # Median rank
  median_ranks <- apply(prob_matrix, 1, function(probs) {
    cum_probs <- cumsum(probs)
    which(cum_probs >= 0.5)[1]
  })

  # Create data frame with results
  treatment_names <- rownames(prob_matrix)

  sucra_df <- data.frame(
    treatment = treatment_names,
    sucra_score = sucra_manual * 100,  # Convert to percentage
    mean_rank = mean_ranks,
    median_rank = median_ranks,
    prob_best = prob_matrix[, 1] * 100,  # Probability of being best
    prob_worst = prob_matrix[, n_treatments] * 100,  # Probability of being worst
    stringsAsFactors = FALSE
  ) %>%
    arrange(desc(sucra_score))

  # Create long format for rankogram plotting
  rankogram_long <- as.data.frame(prob_matrix) %>%
    mutate(treatment = treatment_names) %>%
    pivot_longer(
      cols = -treatment,
      names_to = "rank",
      values_to = "probability"
    ) %>%
    mutate(
      rank = as.numeric(gsub("V", "", rank)),
      probability = probability * 100  # Convert to percentage
    )

  # Create cumulative ranking curves
  cumulative_curves <- rankogram_long %>%
    group_by(treatment) %>%
    arrange(rank) %>%
    mutate(cumulative_prob = cumsum(probability)) %>%
    ungroup()

  list(
    sucra_df = sucra_df,
    prob_matrix = prob_matrix,
    rankogram_long = rankogram_long,
    cumulative_curves = cumulative_curves,
    n_treatments = n_treatments,
    small_values = small_values
  )
}

#' UI for SUCRA rankings
#'
#' @param id Module ID
#' @export
sucra_rankings_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      div(
        "SUCRA Rankings for Network Meta-Analysis",
        span("✅ STANDARD",
             style = "background: #10B981; color: white; padding: 3px 8px;
                      border-radius: 4px; font-size: 11px; margin-left: 10px;")
      )
    ),

    p(
      "Surface Under the Cumulative RAnking (SUCRA) provides a single number summarizing treatment ranking. SUCRA = 100% means always best, 0% means always worst.",
      style = "color: #6B7280; margin-bottom: 20px;"
    ),

    layout_columns(
      col_widths = c(3, 9),

      # Controls
      div(
        h5("Settings", style = "color: #EC4899; margin-bottom: 15px;"),

        radioButtons(
          ns("small_values"),
          "Small Values Are:",
          choices = c(
            "Undesirable (e.g., mortality, adverse events)" = "undesirable",
            "Desirable (e.g., cure rate, response rate)" = "desirable"
          ),
          selected = "undesirable"
        ),

        radioButtons(
          ns("model_type"),
          "Use Model:",
          choices = c(
            "Random Effects" = "random",
            "Fixed Effect" = "fixed"
          ),
          selected = "random"
        ),

        hr(),

        actionButton(
          ns("calculate_sucra"),
          "Calculate SUCRA",
          class = "btn-primary",
          icon = icon("chart-bar"),
          style = "width: 100%;"
        ),

        br(), br(),

        div(
          style = "background: #EFF6FF; border-left: 4px solid #3B82F6;
                   padding: 12px; border-radius: 6px;",
          div(
            strong(icon("graduation-cap", style = "color: #3B82F6; margin-right: 5px;"),
                   "What is SUCRA?"),
            style = "color: #1E40AF; margin-bottom: 8px;"
          ),
          tags$ul(
            style = "margin: 0; color: #1E40AF; font-size: 13px;",
            tags$li("Single number ranking (0-100%)"),
            tags$li("100% = always ranks 1st"),
            tags$li("0% = always ranks last"),
            tags$li("50% = average ranking"),
            tags$li("Combines all ranking probabilities")
          )
        ),

        br(),

        div(
          style = "background: #FEF3C7; border-left: 4px solid #F59E0B;
                   padding: 12px; border-radius: 6px;",
          div(
            strong(icon("exclamation-triangle", style = "color: #F59E0B; margin-right: 5px;"),
                   "Important Note"),
            style = "color: #92400E; margin-bottom: 8px; font-size: 13px;"
          ),
          p(
            "SUCRA ranks treatments but doesn't tell you if differences are clinically meaningful.
            Always consider effect sizes and confidence intervals.",
            style = "margin: 0; color: #92400E; font-size: 12px; line-height: 1.5;"
          )
        )
      ),

      # Results
      div(
        h5("SUCRA Results", style = "color: #EC4899; margin-bottom: 15px;"),

        uiOutput(ns("sucra_summary")),

        br(),

        tabsetPanel(
          id = ns("results_tabs"),

          tabPanel(
            "SUCRA Scores",
            br(),
            plotlyOutput(ns("sucra_barplot"), height = "400px"),
            br(),
            DT::DTOutput(ns("sucra_table"))
          ),

          tabPanel(
            "Rankograms",
            br(),
            plotlyOutput(ns("rankogram_plot"), height = "500px"),
            br(),
            p("Shows probability of each treatment achieving each rank position.",
              style = "color: #6B7280; font-size: 13px;")
          ),

          tabPanel(
            "Cumulative Ranking",
            br(),
            plotlyOutput(ns("cumulative_plot"), height = "500px"),
            br(),
            p("Cumulative probability curves - steeper curves indicate more certainty about ranking.",
              style = "color: #6B7280; font-size: 13px;")
          ),

          tabPanel(
            "League Table",
            br(),
            p("SUCRA-based treatment hierarchy (highest to lowest):",
              style = "color: #6B7280; font-size: 13px; margin-bottom: 15px;"),
            uiOutput(ns("league_table"))
          ),

          tabPanel(
            "Interpretation",
            br(),
            uiOutput(ns("interpretation_guide"))
          )
        )
      )
    ),

    hr(),

    div(
      style = "background: #DBEAFE; border-left: 4px solid #3B82F6;
               padding: 15px; border-radius: 6px;",

      div(
        strong(icon("book", style = "color: #3B82F6; margin-right: 5px;"),
               "About SUCRA"),
        style = "color: #1E3A8A; margin-bottom: 8px;"
      ),

      tags$ul(
        style = "margin: 0; color: #1E3A8A; font-size: 14px;",
        tags$li("SUCRA = Surface Under the Cumulative RAnking curve"),
        tags$li("Developed by Salanti et al. (2011) for NMA treatment ranking"),
        tags$li("Widely accepted by NICE, Cochrane, ISPOR for HTA"),
        tags$li("Complements P-scores and mean ranks"),
        tags$li("Accounts for both position and uncertainty in rankings"),
        tags$li("Reference: Salanti et al. J Clin Epidemiol 2011;64:1283-92")
      )
    )
  )
}

#' Server for SUCRA rankings
#'
#' @param id Module ID
#' @param rv Reactive values with NMA results
#' @export
sucra_rankings_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    sucra_results <- reactiveVal(NULL)

    # Calculate SUCRA
    observeEvent(input$calculate_sucra, {

      req(rv$nma_result)

      withProgress(message = 'Calculating SUCRA rankings...', value = 0, {

        setProgress(0.3, detail = "Computing ranking probabilities...")

        # Calculate SUCRA
        results <- calculate_sucra(
          nma_result = rv$nma_result,
          small_values = input$small_values
        )

        sucra_results(results)

        setProgress(1)
      })
    })

    # Summary display
    output$sucra_summary <- renderUI({
      req(sucra_results())

      results <- sucra_results()
      sucra_df <- results$sucra_df

      # Top 3 treatments
      top3 <- head(sucra_df, 3)

      tagList(
        div(
          style = "background: linear-gradient(135deg, #F59E0B 0%, #EC4899 100%);
                   color: white; padding: 25px; border-radius: 12px;",

          div(
            style = "text-align: center;",

            div(
              style = "font-size: 14px; margin-bottom: 8px; opacity: 0.9;",
              "Best Treatment (Highest SUCRA)"
            ),

            div(
              style = "font-size: 36px; font-weight: 700; margin-bottom: 5px;",
              top3$treatment[1]
            ),

            div(
              style = "font-size: 24px; font-weight: 600; margin-bottom: 15px;",
              sprintf("SUCRA: %.1f%%", top3$sucra_score[1])
            ),

            div(
              style = "font-size: 14px; opacity: 0.9;",
              sprintf("%.1f%% probability of being best | Mean rank: %.1f",
                      top3$prob_best[1], top3$mean_rank[1])
            )
          )
        ),

        br(),

        div(
          style = "display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px;",

          # 2nd best
          div(
            style = "background: white; border: 2px solid #F59E0B; border-radius: 8px; padding: 15px;",
            div(
              style = "text-align: center;",
              div(style = "color: #6B7280; font-size: 12px; margin-bottom: 3px;", "2nd: SUCRA"),
              div(style = "color: #F59E0B; font-size: 20px; font-weight: 700; margin-bottom: 3px;",
                  top3$treatment[2]),
              div(style = "color: #1F2937; font-size: 18px; font-weight: 600;",
                  sprintf("%.1f%%", top3$sucra_score[2]))
            )
          ),

          # 3rd best
          div(
            style = "background: white; border: 2px solid #8B5CF6; border-radius: 8px; padding: 15px;",
            div(
              style = "text-align: center;",
              div(style = "color: #6B7280; font-size: 12px; margin-bottom: 3px;", "3rd: SUCRA"),
              div(style = "color: #8B5CF6; font-size: 20px; font-weight: 700; margin-bottom: 3px;",
                  top3$treatment[3]),
              div(style = "color: #1F2937; font-size: 18px; font-weight: 600;",
                  sprintf("%.1f%%", top3$sucra_score[3]))
            )
          )
        ),

        br(),

        div(
          style = "background: #F9FAFB; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px;",
          div(
            style = "text-align: center; color: #6B7280; font-size: 13px;",
            sprintf("%d treatments ranked | %s outcome",
                    results$n_treatments,
                    if (results$small_values == "desirable") "Higher is better" else "Lower is better")
          )
        )
      )
    })

    # SUCRA bar plot
    output$sucra_barplot <- renderPlotly({
      req(sucra_results())

      sucra_df <- sucra_results()$sucra_df

      # Create gradient colors based on SUCRA score
      colors <- colorRampPalette(c("#EF4444", "#FFF", "#10B981"))(100)
      sucra_colors <- colors[round(sucra_df$sucra_score) + 1]

      p <- plot_ly(
        data = sucra_df,
        x = ~sucra_score,
        y = ~reorder(treatment, sucra_score),
        type = 'bar',
        orientation = 'h',
        marker = list(
          color = sucra_colors,
          line = list(color = '#E5E7EB', width = 1)
        ),
        text = ~sprintf("SUCRA: %.1f%%<br>Mean Rank: %.1f<br>Prob Best: %.1f%%",
                        sucra_score, mean_rank, prob_best),
        hoverinfo = 'text'
      ) %>%
        layout(
          title = "SUCRA Scores by Treatment",
          xaxis = list(title = "SUCRA (%)", range = c(0, 100)),
          yaxis = list(title = ""),
          margin = list(l = 150),
          showlegend = FALSE
        ) %>%
        add_segments(
          x = 50, xend = 50,
          y = 0, yend = nrow(sucra_df) + 1,
          line = list(color = "#6B7280", width = 2, dash = "dash"),
          showlegend = FALSE,
          hoverinfo = 'none'
        ) %>%
        add_annotations(
          x = 50,
          y = -0.5,
          text = "Average",
          showarrow = FALSE,
          font = list(size = 10, color = "#6B7280")
        )

      p
    })

    # SUCRA table
    output$sucra_table <- DT::renderDT({
      req(sucra_results())

      sucra_df <- sucra_results()$sucra_df

      display_df <- sucra_df %>%
        mutate(
          sucra_score = round(sucra_score, 1),
          mean_rank = round(mean_rank, 1),
          prob_best = round(prob_best, 1),
          prob_worst = round(prob_worst, 1)
        ) %>%
        select(
          Treatment = treatment,
          `SUCRA (%)` = sucra_score,
          `Mean Rank` = mean_rank,
          `Median Rank` = median_rank,
          `Prob Best (%)` = prob_best,
          `Prob Worst (%)` = prob_worst
        )

      DT::datatable(
        display_df,
        options = list(
          pageLength = 15,
          dom = 't',
          ordering = FALSE
        ),
        rownames = FALSE,
        class = 'cell-border stripe'
      ) %>%
        DT::formatStyle(
          'SUCRA (%)',
          background = DT::styleColorBar(c(0, 100), '#10B981'),
          backgroundSize = '98% 88%',
          backgroundRepeat = 'no-repeat',
          backgroundPosition = 'center'
        ) %>%
        DT::formatStyle(
          'Treatment',
          target = 'row',
          backgroundColor = DT::styleInterval(
            c(1, 2, 3),
            c('#FEF3C7', '#FEF3C7', '#FEF3C7', 'white')
          )
        )
    })

    # Rankogram plot
    output$rankogram_plot <- renderPlotly({
      req(sucra_results())

      rankogram_data <- sucra_results()$rankogram_long

      # Create heatmap
      plot_ly(
        data = rankogram_data,
        x = ~rank,
        y = ~treatment,
        z = ~probability,
        type = "heatmap",
        colors = colorRamp(c("#FFF", "#EC4899", "#7C3AED")),
        colorbar = list(title = "Probability (%)")
      ) %>%
        layout(
          title = "Rankogram - Probability of Each Rank",
          xaxis = list(title = "Rank Position", dtick = 1),
          yaxis = list(title = "Treatment"),
          margin = list(l = 150)
        )
    })

    # Cumulative ranking curves
    output$cumulative_plot <- renderPlotly({
      req(sucra_results())

      cumulative_data <- sucra_results()$cumulative_curves

      # Create line plot with multiple traces (one per treatment)
      treatments <- unique(cumulative_data$treatment)

      p <- plot_ly()

      # Color palette
      colors <- c("#EF4444", "#F59E0B", "#10B981", "#3B82F6", "#8B5CF6",
                  "#EC4899", "#14B8A6", "#F97316")

      for (i in seq_along(treatments)) {
        trt <- treatments[i]
        trt_data <- cumulative_data %>% filter(treatment == trt)

        p <- p %>%
          add_lines(
            data = trt_data,
            x = ~rank,
            y = ~cumulative_prob,
            name = trt,
            line = list(color = colors[(i - 1) %% length(colors) + 1], width = 2)
          )
      }

      p %>%
        layout(
          title = "Cumulative Ranking Curves",
          xaxis = list(title = "Rank Position", dtick = 1),
          yaxis = list(title = "Cumulative Probability (%)", range = c(0, 100)),
          hovermode = "closest",
          legend = list(x = 1.05, y = 1)
        )
    })

    # League table
    output$league_table <- renderUI({
      req(sucra_results())

      sucra_df <- sucra_results()$sucra_df

      # Create visual league table
      league_items <- lapply(1:nrow(sucra_df), function(i) {
        row <- sucra_df[i, ]

        # Color based on rank
        bg_color <- if (i == 1) "#FEF3C7"
                    else if (i == 2) "#DBEAFE"
                    else if (i == 3) "#E9D5FF"
                    else "white"

        border_color <- if (i == 1) "#F59E0B"
                        else if (i == 2) "#3B82F6"
                        else if (i == 3) "#8B5CF6"
                        else "#E5E7EB"

        div(
          style = sprintf("background: %s; border-left: 4px solid %s;
                           padding: 15px; margin-bottom: 10px; border-radius: 6px;
                           display: flex; justify-content: space-between; align-items: center;",
                          bg_color, border_color),

          div(
            style = "flex: 1;",
            div(
              style = "font-size: 18px; font-weight: 600; color: #1F2937; margin-bottom: 3px;",
              sprintf("%d. %s", i, row$treatment)
            ),
            div(
              style = "font-size: 13px; color: #6B7280;",
              sprintf("Mean Rank: %.1f | Median Rank: %d", row$mean_rank, row$median_rank)
            )
          ),

          div(
            style = "text-align: right;",
            div(
              style = "font-size: 24px; font-weight: 700; color: #EC4899; margin-bottom: 3px;",
              sprintf("%.1f%%", row$sucra_score)
            ),
            div(
              style = "font-size: 12px; color: #6B7280;",
              "SUCRA"
            )
          )
        )
      })

      tagList(league_items)
    })

    # Interpretation guide
    output$interpretation_guide <- renderUI({
      req(sucra_results())

      sucra_df <- sucra_results()$sucra_df

      # Calculate spread of SUCRA scores
      sucra_range <- diff(range(sucra_df$sucra_score))
      clarity <- if (sucra_range > 50) "HIGH"
                 else if (sucra_range > 30) "MODERATE"
                 else "LOW"

      tagList(
        div(
          style = "background: white; padding: 20px; border-radius: 8px; border: 1px solid #E5E7EB;",

          h5("Interpretation Guide:", style = "color: #1F2937; margin-bottom: 15px;"),

          h6("1. Understanding SUCRA Scores:", style = "color: #374151; margin-top: 15px;"),
          tags$ul(
            style = "color: #6B7280; line-height: 1.8;",
            tags$li(strong("SUCRA = 100%:"), " Treatment always ranks first (perfect)"),
            tags$li(strong("SUCRA = 75%:"), " Treatment ranks in top quartile on average"),
            tags$li(strong("SUCRA = 50%:"), " Treatment has average ranking"),
            tags$li(strong("SUCRA = 25%:"), " Treatment ranks in bottom quartile on average"),
            tags$li(strong("SUCRA = 0%:"), " Treatment always ranks last")
          ),

          h6("2. Your Network Clarity:", style = "color: #374151; margin-top: 15px;"),
          p(
            sprintf("Ranking Clarity: %s (SUCRA range = %.1f%%)", clarity, sucra_range),
            style = "color: #374151; font-weight: 600;"
          ),
          p(
            if (clarity == "HIGH") {
              "Your network shows clear separation between treatments. Rankings are well-defined
              with substantial differences in SUCRA scores. Confidence in treatment hierarchy is high."
            } else if (clarity == "MODERATE") {
              "Your network shows moderate separation. Some treatments have similar SUCRA scores,
              indicating overlapping rankings. Consider clinical significance of small SUCRA differences."
            } else {
              "Your network shows low separation between treatments. Many treatments have similar
              SUCRA scores, suggesting uncertainty in ranking. Effect sizes may be small or
              inconsistency may be present. Interpret rankings cautiously."
            },
            style = "color: #6B7280; line-height: 1.6;"
          ),

          h6("3. Practical Recommendations:", style = "color: #374151; margin-top: 15px;"),
          tags$ul(
            style = "color: #6B7280; line-height: 1.8;",
            tags$li("Don't over-interpret small SUCRA differences (<10%)"),
            tags$li("Check rankograms for uncertainty (flat distributions = high uncertainty)"),
            tags$li("Combine SUCRA with effect sizes and clinical importance"),
            tags$li("Consider cost-effectiveness alongside SUCRA rankings"),
            tags$li("SUCRA ranks treatments but doesn't prove one is 'best' - use alongside CI"),
            tags$li("Report both SUCRA and probability of being best for transparency")
          ),

          hr(),

          div(
            style = "background: #F9FAFB; padding: 15px; border-radius: 6px;",
            h6("Statistical Note:", style = "color: #1F2937; margin-bottom: 10px;"),
            p(
              "SUCRA integrates the cumulative ranking probabilities, giving equal weight to
              each rank position. A treatment with SUCRA = 80% is not necessarily '80% effective'
              - rather, it ranks in the top 20% of the distribution on average. Always consider
              absolute effect sizes and clinical context.",
              style = "color: #6B7280; margin: 0; font-size: 14px; line-height: 1.6;"
            )
          )
        )
      )
    })
  })
}
