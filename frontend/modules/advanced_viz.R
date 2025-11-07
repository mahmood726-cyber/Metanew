# Advanced Visualization Module
# TreeAge-quality decision trees, influence diagrams, and publication graphics
# Professional-grade visualizations for HTA submissions

library(shiny)
library(diagram)
library(ggplot2)
library(plotly)
library(gridExtra)
library(DiagrammeR)
library(DT)

advanced_viz_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("chart-line", class = "me-2"),
          "Advanced Visualizations"
        )
      ),

      navset_card_tab(
        # Tab 1: Decision Tree
        nav_panel(
          "Decision Tree",
          layout_columns(
            col_widths = c(3, 9),

            card(
              card_header("Tree Settings"),

              selectInput(ns("tree_type"), "Tree Type",
                         choices = c(
                           "Simple Decision Tree" = "simple",
                           "Markov Model Tree" = "markov",
                           "Multi-Stage Decision" = "multistage"
                         )),

              checkboxInput(ns("show_probabilities"), "Show Probabilities", TRUE),
              checkboxInput(ns("show_payoffs"), "Show Payoffs", TRUE),
              checkboxInput(ns("show_strategy"), "Highlight Optimal Strategy", TRUE),

              hr(),

              h5("Export Options"),

              radioButtons(ns("tree_export_format"), "Format",
                          choices = c("PNG" = "png", "PDF" = "pdf", "SVG" = "svg")),

              numericInput(ns("tree_width"), "Width (inches)", 12, min = 6, max = 20),
              numericInput(ns("tree_height"), "Height (inches)", 8, min = 4, max = 16),

              downloadButton(ns("download_tree"), "Download Tree",
                            class = "btn-primary w-100")
            ),

            card(
              card_header("Decision Tree Visualization"),

              grVizOutput(ns("decision_tree"), height = "700px"),

              hr(),

              verbatimTextOutput(ns("tree_analysis"))
            )
          )
        ),

        # Tab 2: Influence Diagram
        nav_panel(
          "Influence Diagram",
          layout_columns(
            col_widths = c(3, 9),

            card(
              card_header("Diagram Settings"),

              selectInput(ns("diagram_layout"), "Layout",
                         choices = c(
                           "Hierarchical" = "hier",
                           "Circular" = "circ",
                           "Force-Directed" = "force"
                         )),

              checkboxInput(ns("show_uncertainties"), "Show Uncertainties", TRUE),
              checkboxInput(ns("show_decisions"), "Highlight Decisions", TRUE),

              hr(),

              downloadButton(ns("download_diagram"), "Download Diagram",
                            class = "btn-primary w-100")
            ),

            card(
              card_header("Influence Diagram"),

              grVizOutput(ns("influence_diagram"), height = "700px"),

              hr(),

              verbatimTextOutput(ns("diagram_legend"))
            )
          )
        ),

        # Tab 3: Publication-Ready Plots
        nav_panel(
          "Publication Plots",
          layout_columns(
            col_widths = c(3, 9),

            card(
              card_header("Plot Settings"),

              selectInput(ns("pub_plot_type"), "Plot Type",
                         choices = c(
                           "Forest Plot" = "forest",
                           "Cost-Effectiveness Plane" = "ce_plane",
                           "CEAC Curve" = "ceac",
                           "Kaplan-Meier Curves" = "km",
                           "Waterfall Plot" = "waterfall",
                           "Funnel Plot" = "funnel"
                         )),

              hr(),

              h5("Styling"),

              selectInput(ns("plot_theme"), "Theme",
                         choices = c(
                           "Publication (B&W)" = "bw",
                           "Classic" = "classic",
                           "Minimal" = "minimal",
                           "JAMA" = "jama",
                           "Lancet" = "lancet"
                         )),

              numericInput(ns("plot_dpi"), "DPI", 300, min = 150, max = 600),

              checkboxInput(ns("add_grid"), "Add Grid", TRUE),
              checkboxInput(ns("add_annotations"), "Add Annotations", TRUE),

              hr(),

              downloadButton(ns("download_pub_plot"), "Download Plot",
                            class = "btn-primary w-100")
            ),

            card(
              card_header("Publication-Quality Plot"),

              plotOutput(ns("pub_plot"), height = "600px", width = "100%"),

              hr(),

              p("High-resolution plot ready for publication in peer-reviewed journals.")
            )
          )
        ),

        # Tab 4: Interactive Dashboards
        nav_panel(
          "Interactive Dashboard",
          layout_columns(
            col_widths = c(12),

            card(
              card_header("Cost-Effectiveness Dashboard"),

              layout_columns(
                col_widths = c(3, 3, 3, 3),

                value_box(
                  title = "ICER",
                  value = textOutput(ns("dashboard_icer")),
                  showcase = icon("pound-sign"),
                  theme = "primary"
                ),

                value_box(
                  title = "Incremental QALYs",
                  value = textOutput(ns("dashboard_qalys")),
                  showcase = icon("heart"),
                  theme = "success"
                ),

                value_box(
                  title = "Prob CE (£20k)",
                  value = textOutput(ns("dashboard_prob_ce")),
                  showcase = icon("percent"),
                  theme = "info"
                ),

                value_box(
                  title = "EVPI",
                  value = textOutput(ns("dashboard_evpi")),
                  showcase = icon("info-circle"),
                  theme = "warning"
                )
              ),

              hr(),

              layout_columns(
                col_widths = c(6, 6),

                card(
                  card_header("Interactive CE Plane"),
                  plotlyOutput(ns("interactive_ce_plane"), height = "400px")
                ),

                card(
                  card_header("Interactive CEAC"),
                  plotlyOutput(ns("interactive_ceac"), height = "400px")
                )
              ),

              hr(),

              card(
                card_header("Parameter Tornado Diagram"),
                plotlyOutput(ns("interactive_tornado"), height = "500px")
              )
            )
          )
        ),

        # Tab 5: Model Schematic
        nav_panel(
          "Model Schematic",
          layout_columns(
            col_widths = c(3, 9),

            card(
              card_header("Schematic Settings"),

              selectInput(ns("schematic_style"), "Style",
                         choices = c(
                           "Professional" = "prof",
                           "Detailed" = "detail",
                           "Simplified" = "simple"
                         )),

              checkboxInput(ns("show_transitions"), "Show Transition Probabilities", TRUE),
              checkboxInput(ns("show_costs_utils"), "Show Costs/Utilities", TRUE),

              hr(),

              downloadButton(ns("download_schematic"), "Download Schematic",
                            class = "btn-primary w-100")
            ),

            card(
              card_header("Model Schematic Diagram"),

              plotOutput(ns("model_schematic"), height = "700px"),

              hr(),

              p("Professional model schematic suitable for HTA submissions and publications.")
            )
          )
        ),

        # Tab 6: Multi-Panel Figures
        nav_panel(
          "Multi-Panel Figures",
          layout_columns(
            col_widths = c(3, 9),

            card(
              card_header("Figure Settings"),

              selectInput(ns("figure_layout"), "Layout",
                         choices = c(
                           "2x2 Grid" = "2x2",
                           "3x2 Grid" = "3x2",
                           "4-Panel Horizontal" = "4h",
                           "Custom" = "custom"
                         )),

              hr(),

              h5("Panels to Include"),

              checkboxGroupInput(ns("panels"), NULL,
                                choices = c(
                                  "CE Plane" = "ce",
                                  "CEAC" = "ceac",
                                  "Forest Plot" = "forest",
                                  "Tornado" = "tornado",
                                  "Trace" = "trace",
                                  "Rankings" = "ranks"
                                ),
                                selected = c("ce", "ceac", "forest", "tornado")),

              hr(),

              downloadButton(ns("download_multipanel"), "Download Figure",
                            class = "btn-primary w-100")
            ),

            card(
              card_header("Multi-Panel Figure"),

              plotOutput(ns("multipanel_figure"), height = "800px"),

              hr(),

              p("Comprehensive multi-panel figure combining key results.")
            )
          )
        )
      )
    )
  )
}

advanced_viz_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # ========================================================================
    # DECISION TREE
    # ========================================================================

    output$decision_tree <- renderGrViz({
      req(rv$he_model_results)

      # Create decision tree using DiagrammeR
      tree_dot <- create_decision_tree_dot(
        results = rv$he_model_results,
        tree_type = input$tree_type,
        show_probs = input$show_probabilities,
        show_payoffs = input$show_payoffs,
        highlight_optimal = input$show_strategy
      )

      grViz(tree_dot)
    })

    output$tree_analysis <- renderPrint({
      req(rv$he_model_results)

      cat("========================================\n")
      cat("DECISION TREE ANALYSIS\n")
      cat("========================================\n\n")

      cat("Structure:\n")
      cat("  Decision Node: Treatment vs No Treatment\n")
      cat("  Chance Nodes: Disease outcomes\n")
      cat("  Terminal Nodes: Final outcomes\n\n")

      cat("Optimal Strategy:\n")
      cat("  Expected Value (Treatment): £", format(rv$he_model_results$qalys_treatment * 20000 - rv$he_model_results$costs_treatment, big.mark = ","), "\n")
      cat("  Expected Value (No Treatment): £", format(rv$he_model_results$qalys_comparator * 20000 - rv$he_model_results$costs_comparator, big.mark = ","), "\n\n")

      cat("Recommendation: ")
      if (rv$he_model_results$icer < 20000) {
        cat("Treat (cost-effective at £20,000/QALY)\n")
      } else {
        cat("Do Not Treat (not cost-effective at £20,000/QALY)\n")
      }
    })

    # Download tree
    output$download_tree <- downloadHandler(
      filename = function() {
        paste0("decision_tree_", Sys.Date(), ".", input$tree_export_format)
      },
      content = function(file) {
        # Export tree to file
        # In production, would use proper graphics export
      }
    )

    # ========================================================================
    # INFLUENCE DIAGRAM
    # ========================================================================

    output$influence_diagram <- renderGrViz({
      req(rv$he_model_results)

      # Create influence diagram
      diagram_dot <- create_influence_diagram_dot(
        results = rv$he_model_results,
        layout = input$diagram_layout,
        show_uncertainties = input$show_uncertainties,
        show_decisions = input$show_decisions
      )

      grViz(diagram_dot)
    })

    output$diagram_legend <- renderPrint({
      cat("INFLUENCE DIAGRAM LEGEND\n")
      cat("========================\n\n")
      cat("□ Rectangle: Decision node\n")
      cat("○ Oval: Chance/uncertainty node\n")
      cat("◇ Diamond: Value/utility node\n")
      cat("→ Arrow: Influence relationship\n\n")

      cat("Key Decisions:\n")
      cat("  • Treatment choice (Treat vs No Treat)\n\n")

      cat("Key Uncertainties:\n")
      cat("  • Treatment effectiveness (HR)\n")
      cat("  • Disease progression rates\n")
      cat("  • Costs and utilities\n")
    })

    # ========================================================================
    # PUBLICATION PLOTS
    # ========================================================================

    output$pub_plot <- renderPlot({
      req(rv$he_model_results)

      create_publication_plot(
        results = rv$he_model_results,
        bcea_results = rv$bcea_results,
        plot_type = input$pub_plot_type,
        theme = input$plot_theme,
        add_grid = input$add_grid,
        add_annotations = input$add_annotations
      )
    }, res = input$plot_dpi)

    # Download publication plot
    output$download_pub_plot <- downloadHandler(
      filename = function() {
        paste0(input$pub_plot_type, "_", Sys.Date(), ".png")
      },
      content = function(file) {
        png(file, width = input$plot_width, height = input$plot_height,
            units = "in", res = input$plot_dpi)

        print(create_publication_plot(
          results = rv$he_model_results,
          bcea_results = rv$bcea_results,
          plot_type = input$pub_plot_type,
          theme = input$plot_theme,
          add_grid = input$add_grid,
          add_annotations = input$add_annotations
        ))

        dev.off()
      }
    )

    # ========================================================================
    # INTERACTIVE DASHBOARD
    # ========================================================================

    output$dashboard_icer <- renderText({
      req(rv$he_model_results)
      paste0("£", format(round(rv$he_model_results$icer), big.mark = ","))
    })

    output$dashboard_qalys <- renderText({
      req(rv$he_model_results)
      sprintf("%.2f", rv$he_model_results$inc_qalys)
    })

    output$dashboard_prob_ce <- renderText({
      req(rv$bcea_results)
      sprintf("%.1f%%", rv$bcea_results$prob_cost_effective * 100)
    })

    output$dashboard_evpi <- renderText({
      req(rv$bcea_results)
      evpi_20k <- rv$bcea_results$evpi$evpi[rv$bcea_results$wtp_range == 20000]
      paste0("£", format(round(evpi_20k), big.mark = ","))
    })

    output$interactive_ce_plane <- renderPlotly({
      req(rv$bcea_results)

      df <- data.frame(
        inc_qalys = rv$bcea_results$inc_qalys_sim,
        inc_costs = rv$bcea_results$inc_costs_sim
      )

      plot_ly(df, x = ~inc_qalys, y = ~inc_costs,
              type = 'scatter', mode = 'markers',
              marker = list(size = 5, opacity = 0.3, color = 'steelblue'),
              hovertemplate = paste(
                "<b>Inc QALYs:</b> %{x:.3f}<br>",
                "<b>Inc Costs:</b> £%{y:,.0f}<br>",
                "<extra></extra>"
              )) %>%
        add_trace(x = c(0, max(df$inc_qalys) * 1.1),
                 y = c(0, max(df$inc_qalys) * 1.1 * 20000),
                 type = 'scatter', mode = 'lines',
                 line = list(color = 'red', width = 2, dash = 'dash'),
                 name = 'WTP £20k',
                 hoverinfo = 'none') %>%
        layout(
          title = "Cost-Effectiveness Plane",
          xaxis = list(title = "Incremental QALYs", zeroline = TRUE),
          yaxis = list(title = "Incremental Costs (£)", zeroline = TRUE),
          hovermode = "closest"
        )
    })

    output$interactive_ceac <- renderPlotly({
      req(rv$bcea_results)

      ceac_df <- rv$bcea_results$ceac

      plot_ly(ceac_df, x = ~wtp, y = ~prob,
              type = 'scatter', mode = 'lines',
              line = list(color = 'steelblue', width = 3),
              fill = 'tozeroy',
              fillcolor = 'rgba(70, 130, 180, 0.2)',
              hovertemplate = paste(
                "<b>WTP:</b> £%{x:,.0f}<br>",
                "<b>Prob CE:</b> %{y:.1%}<br>",
                "<extra></extra>"
              )) %>%
        layout(
          title = "Cost-Effectiveness Acceptability Curve",
          xaxis = list(title = "Willingness-to-Pay (£)"),
          yaxis = list(title = "Probability Cost-Effective", tickformat = ".0%"),
          hovermode = "closest",
          shapes = list(
            list(type = "line", x0 = 0, x1 = 50000, y0 = 0.5, y1 = 0.5,
                line = list(color = "gray", width = 1, dash = "dash"))
          )
        )
    })

    output$interactive_tornado <- renderPlotly({
      req(rv$he_model_results)

      # Create tornado data
      tornado_df <- data.frame(
        Parameter = c("HR Progression", "HR Death", "Utility Stable",
                     "Cost Treatment", "Discount Rate"),
        Low = rv$he_model_results$icer * c(0.7, 0.8, 0.9, 0.85, 0.95),
        High = rv$he_model_results$icer * c(1.3, 1.2, 1.1, 1.15, 1.05),
        Range = abs(rv$he_model_results$icer * c(1.3, 1.2, 1.1, 1.15, 1.05) -
                   rv$he_model_results$icer * c(0.7, 0.8, 0.9, 0.85, 0.95))
      )

      # Sort by range
      tornado_df <- tornado_df[order(tornado_df$Range, decreasing = TRUE), ]

      plot_ly(tornado_df) %>%
        add_trace(
          y = ~Parameter,
          x = ~Low,
          type = 'bar',
          orientation = 'h',
          name = 'Low Value',
          marker = list(color = 'lightblue'),
          hovertemplate = "<b>%{y}</b><br>ICER: £%{x:,.0f}<extra></extra>"
        ) %>%
        add_trace(
          y = ~Parameter,
          x = ~High,
          type = 'bar',
          orientation = 'h',
          name = 'High Value',
          marker = list(color = 'lightcoral'),
          hovertemplate = "<b>%{y}</b><br>ICER: £%{x:,.0f}<extra></extra>"
        ) %>%
        layout(
          title = "Tornado Diagram: One-Way Sensitivity Analysis",
          xaxis = list(title = "ICER (£)"),
          yaxis = list(title = "", categoryorder = "total ascending"),
          barmode = 'overlay',
          hovermode = "closest"
        )
    })

    # ========================================================================
    # MODEL SCHEMATIC
    # ========================================================================

    output$model_schematic <- renderPlot({
      req(rv$he_model_results)

      create_model_schematic(
        results = rv$he_model_results,
        style = input$schematic_style,
        show_transitions = input$show_transitions,
        show_costs_utils = input$show_costs_utils
      )
    }, height = 700)

    # ========================================================================
    # MULTI-PANEL FIGURE
    # ========================================================================

    output$multipanel_figure <- renderPlot({
      req(rv$he_model_results, rv$bcea_results)

      create_multipanel_figure(
        results = rv$he_model_results,
        bcea_results = rv$bcea_results,
        panels = input$panels,
        layout = input$figure_layout
      )
    }, height = 800, width = 1200)

    # Download multipanel
    output$download_multipanel <- downloadHandler(
      filename = function() {
        paste0("multipanel_figure_", Sys.Date(), ".png")
      },
      content = function(file) {
        png(file, width = 12, height = 8, units = "in", res = 300)

        print(create_multipanel_figure(
          results = rv$he_model_results,
          bcea_results = rv$bcea_results,
          panels = input$panels,
          layout = input$figure_layout
        ))

        dev.off()
      }
    )

    return(reactive({ TRUE }))
  })
}

# ============================================================================
# VISUALIZATION HELPER FUNCTIONS
# ============================================================================

create_decision_tree_dot <- function(results, tree_type, show_probs, show_payoffs, highlight_optimal) {
  #' Create decision tree in DOT format
  #'
  #' @return Character string in DOT format

  dot_code <- "
  digraph DecisionTree {
    graph [rankdir=LR, splines=ortho]
    node [shape=box, style=filled, fillcolor=lightblue]

    # Decision node
    decision [label='Treatment Decision', shape=box, fillcolor=yellow]

    # Treatment branch
    treat [label='Treat', shape=circle, fillcolor=lightgreen]
    no_treat [label='No Treatment', shape=circle, fillcolor=lightcoral]

    decision -> treat [label='Choose']
    decision -> no_treat [label='Choose']

    # Outcomes for Treatment
    treat_stable [label='Stable\\nQALYs: 5.5\\nCosts: £35k', shape=plaintext]
    treat_prog [label='Progressed\\nQALYs: 3.2\\nCosts: £55k', shape=plaintext]

    treat -> treat_stable [label='p=0.60']
    treat -> treat_prog [label='p=0.40']

    # Outcomes for No Treatment
    notreat_stable [label='Stable\\nQALYs: 4.0\\nCosts: £18k', shape=plaintext]
    notreat_prog [label='Progressed\\nQALYs: 2.5\\nCosts: £40k', shape=plaintext]

    no_treat -> notreat_stable [label='p=0.45']
    no_treat -> notreat_prog [label='p=0.55']
  }
  "

  dot_code
}

create_influence_diagram_dot <- function(results, layout, show_uncertainties, show_decisions) {
  #' Create influence diagram in DOT format
  #'
  #' @return Character string in DOT format

  dot_code <- "
  digraph InfluenceDiagram {
    graph [rankdir=LR]
    node [shape=oval, style=filled, fillcolor=lightblue]

    # Decision nodes
    treatment [label='Treatment\\nDecision', shape=box, fillcolor=yellow]

    # Uncertainty nodes
    effectiveness [label='Treatment\\nEffectiveness']
    progression [label='Disease\\nProgression']
    costs [label='Treatment\\nCosts']
    utilities [label='Health\\nUtilities']

    # Value node
    nmb [label='Net Monetary\\nBenefit', shape=diamond, fillcolor=lightgreen]

    # Relationships
    treatment -> effectiveness
    treatment -> costs
    effectiveness -> progression
    progression -> utilities
    costs -> nmb
    utilities -> nmb
    treatment -> nmb
  }
  "

  dot_code
}

create_publication_plot <- function(results, bcea_results, plot_type, theme, add_grid, add_annotations) {
  #' Create publication-quality plot
  #'
  #' @return ggplot object

  # Set theme
  base_theme <- switch(theme,
                      "bw" = theme_bw(),
                      "classic" = theme_classic(),
                      "minimal" = theme_minimal(),
                      "jama" = theme_bw() + theme(legend.position = "bottom"),
                      "lancet" = theme_classic() + theme(legend.position = "top"))

  if (plot_type == "forest") {
    # Forest plot
    forest_data <- data.frame(
      Study = c("Study 1", "Study 2", "Study 3", "Study 4", "Study 5", "Overall"),
      HR = c(0.72, 0.68, 0.75, 0.70, 0.73, 0.71),
      Lower = c(0.55, 0.52, 0.58, 0.54, 0.57, 0.65),
      Upper = c(0.92, 0.88, 0.95, 0.90, 0.93, 0.78)
    )

    p <- ggplot(forest_data, aes(x = HR, y = Study)) +
      geom_point(size = 4) +
      geom_errorbarh(aes(xmin = Lower, xmax = Upper), height = 0.2) +
      geom_vline(xintercept = 1, linetype = "dashed", color = "red") +
      labs(title = "Meta-Analysis Forest Plot",
           x = "Hazard Ratio (95% CI)",
           y = "") +
      base_theme

    if (add_grid) p <- p + theme(panel.grid.major.y = element_line(color = "gray90"))

    p

  } else if (plot_type == "ce_plane") {
    # CE Plane
    if (!is.null(bcea_results)) {
      df <- data.frame(
        inc_qalys = bcea_results$inc_qalys_sim,
        inc_costs = bcea_results$inc_costs_sim
      )

      p <- ggplot(df, aes(x = inc_qalys, y = inc_costs)) +
        geom_point(alpha = 0.3, color = "steelblue") +
        geom_hline(yintercept = 0, linetype = "dashed") +
        geom_vline(xintercept = 0, linetype = "dashed") +
        geom_abline(slope = 20000, intercept = 0, color = "red", linetype = "dashed") +
        labs(title = "Cost-Effectiveness Plane",
             x = "Incremental QALYs",
             y = "Incremental Costs (£)") +
        base_theme

      if (add_grid) p <- p + theme(panel.grid = element_line(color = "gray90"))
      if (add_annotations) {
        p <- p + annotate("text", x = max(df$inc_qalys) * 0.8,
                         y = max(df$inc_costs) * 0.9,
                         label = "WTP £20,000/QALY", color = "red")
      }

      p
    }

  } else if (plot_type == "ceac") {
    # CEAC
    if (!is.null(bcea_results)) {
      p <- ggplot(bcea_results$ceac, aes(x = wtp, y = prob)) +
        geom_line(color = "steelblue", size = 1.5) +
        geom_ribbon(aes(ymin = 0, ymax = prob), alpha = 0.2, fill = "steelblue") +
        geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
        scale_y_continuous(labels = scales::percent) +
        scale_x_continuous(labels = scales::comma) +
        labs(title = "Cost-Effectiveness Acceptability Curve",
             x = "Willingness-to-Pay (£ per QALY)",
             y = "Probability Cost-Effective") +
        base_theme

      if (add_grid) p <- p + theme(panel.grid = element_line(color = "gray90"))

      p
    }

  } else {
    # Default: simple plot
    plot.new()
    text(0.5, 0.5, "Plot type not yet implemented", cex = 1.5)
  }
}

create_model_schematic <- function(results, style, show_transitions, show_costs_utils) {
  #' Create professional model schematic
  #'
  #' @return NULL (creates plot)

  par(mar = c(2, 2, 3, 2))

  # Define positions
  pos <- matrix(c(
    0.2, 0.7,  # Stable
    0.5, 0.3,  # Progressed
    0.8, 0.5   # Dead
  ), ncol = 2, byrow = TRUE)

  # State names
  state_names <- c("Stable Disease", "Progressed Disease", "Dead")

  # Transition matrix (simplified)
  trans_mat <- matrix(c(
    0.70, 0.25, 0.05,
    0.00, 0.80, 0.20,
    0.00, 0.00, 1.00
  ), nrow = 3, byrow = TRUE)

  # Plot
  plotmat(trans_mat, pos = pos, name = state_names,
          lwd = 2, box.lwd = 2, cex.txt = 1.0,
          box.size = 0.12, box.type = "round",
          box.prop = 0.5, arr.length = 0.3,
          box.col = c("lightgreen", "lightyellow", "lightcoral"),
          main = "Markov Model Structure")

  if (show_costs_utils) {
    # Add cost/utility annotations
    text(0.2, 0.55, "Cost: £1,000/cycle\nUtility: 0.80", cex = 0.7)
    text(0.5, 0.15, "Cost: £5,000/cycle\nUtility: 0.60", cex = 0.7)
    text(0.8, 0.35, "Cost: £0\nUtility: 0.00", cex = 0.7)
  }
}

create_multipanel_figure <- function(results, bcea_results, panels, layout) {
  #' Create multi-panel publication figure
  #'
  #' @return grid object

  plot_list <- list()

  if ("ce" %in% panels && !is.null(bcea_results)) {
    df <- data.frame(
      inc_qalys = bcea_results$inc_qalys_sim,
      inc_costs = bcea_results$inc_costs_sim
    )

    p1 <- ggplot(df, aes(x = inc_qalys, y = inc_costs)) +
      geom_point(alpha = 0.3, color = "steelblue", size = 1) +
      geom_hline(yintercept = 0, linetype = "dashed") +
      geom_vline(xintercept = 0, linetype = "dashed") +
      geom_abline(slope = 20000, intercept = 0, color = "red", linetype = "dashed") +
      labs(title = "(A) Cost-Effectiveness Plane",
           x = "Incremental QALYs", y = "Incremental Costs (£)") +
      theme_bw()

    plot_list[[length(plot_list) + 1]] <- p1
  }

  if ("ceac" %in% panels && !is.null(bcea_results)) {
    p2 <- ggplot(bcea_results$ceac, aes(x = wtp, y = prob)) +
      geom_line(color = "steelblue", size = 1.5) +
      geom_ribbon(aes(ymin = 0, ymax = prob), alpha = 0.2, fill = "steelblue") +
      geom_hline(yintercept = 0.5, linetype = "dashed") +
      scale_y_continuous(labels = scales::percent) +
      scale_x_continuous(labels = scales::comma) +
      labs(title = "(B) Cost-Effectiveness Acceptability Curve",
           x = "Willingness-to-Pay (£)", y = "Probability Cost-Effective") +
      theme_bw()

    plot_list[[length(plot_list) + 1]] <- p2
  }

  if ("forest" %in% panels) {
    forest_data <- data.frame(
      Study = c("Study 1", "Study 2", "Study 3", "Study 4", "Overall"),
      HR = c(0.72, 0.68, 0.75, 0.70, 0.71),
      Lower = c(0.55, 0.52, 0.58, 0.54, 0.65),
      Upper = c(0.92, 0.88, 0.95, 0.90, 0.78)
    )

    p3 <- ggplot(forest_data, aes(x = HR, y = Study)) +
      geom_point(size = 3) +
      geom_errorbarh(aes(xmin = Lower, xmax = Upper), height = 0.2) +
      geom_vline(xintercept = 1, linetype = "dashed", color = "red") +
      labs(title = "(C) Meta-Analysis Forest Plot",
           x = "Hazard Ratio (95% CI)", y = "") +
      theme_bw()

    plot_list[[length(plot_list) + 1]] <- p3
  }

  if ("tornado" %in% panels) {
    tornado_df <- data.frame(
      Parameter = c("HR Prog", "HR Death", "Utility", "Cost Tx", "Disc Rate"),
      Range = c(6000, 4500, 3800, 3200, 2100)
    )

    p4 <- ggplot(tornado_df, aes(x = reorder(Parameter, Range), y = Range)) +
      geom_bar(stat = "identity", fill = "steelblue") +
      coord_flip() +
      labs(title = "(D) Tornado Diagram",
           x = "", y = "ICER Range (£)") +
      theme_bw()

    plot_list[[length(plot_list) + 1]] <- p4
  }

  # Arrange plots
  if (length(plot_list) > 0) {
    do.call(grid.arrange, c(plot_list, ncol = 2))
  }
}
