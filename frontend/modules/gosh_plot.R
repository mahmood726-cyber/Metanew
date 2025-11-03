# GOSH Plot Module
# Graphical Display of Study Heterogeneity for outlier detection
# Part of Phase 3.3: Advanced Analytics

library(shiny)
library(bslib)
library(plotly)
library(ggplot2)
library(metafor)

# UI
gosh_plot_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # Header
      card(
        card_header(
          tags$div(
            class = "d-flex justify-content-between align-items-center",
            tags$h4(class = "mb-0", icon("project-diagram"), " GOSH Plot - Outlier Detection"),
            actionButton(ns("btn_help"), icon("circle-question"),
                        class = "btn-sm btn-outline-secondary")
          )
        ),

        card_body(
          p(class = "text-muted",
            "Graphical Display of Study Heterogeneity (GOSH) plots all possible combinations of studies ",
            "to identify outliers and influential studies. More sophisticated than simple leave-one-out analysis."
          ),

          layout_columns(
            col_widths = c(4, 4, 4),

            numericInput(ns("n_subsets"), "Number of Subsets",
                        value = 1000, min = 100, max = 10000, step = 100),

            selectInput(ns("cluster_method"), "Clustering Method",
                       choices = c("K-means" = "kmeans",
                                 "None (just plot)" = "none")),

            conditionalPanel(
              condition = "input.cluster_method == 'kmeans'",
              ns = ns,
              numericInput(ns("n_clusters"), "Number of Clusters",
                          value = 2, min = 2, max = 5, step = 1)
            )
          ),

          hr(),

          actionButton(ns("btn_run_gosh"), "Run GOSH Analysis",
                      icon = icon("play-circle"),
                      class = "btn-primary btn-lg w-100"),

          uiOutput(ns("progress_ui"))
        )
      )
    ),

    # Results
    layout_columns(
      col_widths = c(12),

      uiOutput(ns("gosh_output"))
    )
  )
}

# Server
gosh_plot_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    gosh_results <- reactiveVal(NULL)
    progress <- reactiveVal(NULL)

    # Help modal
    observeEvent(input$btn_help, {
      showModal(modalDialog(
        title = tags$h4(icon("circle-question"), " GOSH Plot Help"),
        size = "l",

        tags$div(
          tags$h5("What is GOSH?"),
          tags$p("GOSH (Graphical Display of Study Heterogeneity) generates all possible (or a random ",
                "sample of) combinations of studies and plots the pooled effect against heterogeneity (I²). ",
                "This reveals patterns and outliers that simple leave-one-out analysis might miss."),

          tags$hr(),

          tags$h5("How it Works:"),
          tags$ol(
            tags$li("Generate combinations of k studies (all subsets or random sample)"),
            tags$li("For each subset, fit a meta-analysis model"),
            tags$li("Extract pooled effect and I² statistic"),
            tags$li("Plot I² vs. pooled effect (scatter plot)"),
            tags$li("Apply clustering to identify groups"),
            tags$li("Single-study clusters often indicate outliers")
          ),

          tags$hr(),

          tags$h5("Computational Limits:"),
          tags$ul(
            tags$li(tags$strong("k ≤ 15:"), " All possible subsets (combinatorial)"),
            tags$li(tags$strong("k > 15:"), " Random sampling (specify number of subsets)"),
            tags$li(tags$strong("Recommended:"), " 1000-5000 subsets for k > 15"),
            tags$li(tags$strong("Processing time:"), " 1-5 minutes depending on k and subsets")
          ),

          tags$hr(),

          tags$h5("Interpretation:"),
          tags$ul(
            tags$li(tags$strong("Tight cluster:"), " Homogeneous studies, low heterogeneity"),
            tags$li(tags$strong("Multiple clusters:"), " Subgroups or outliers present"),
            tags$li(tags$strong("Isolated points:"), " Potential outliers or influential studies"),
            tags$li(tags$strong("Wide spread:"), " High heterogeneity across different combinations")
          ),

          tags$hr(),

          tags$h5("References:"),
          tags$p(tags$em("Olkin I, Dahabreh IJ, Trikalinos TA. GOSH - a graphical display of study heterogeneity. Research Synthesis Methods. 2012;3(3):214-223."))
        ),

        footer = modalButton("Close")
      ))
    })

    # Run GOSH analysis
    observeEvent(input$btn_run_gosh, {
      req(rv$data)

      # Check if we have effect sizes
      if (!"effect_size" %in% names(rv$data) || !"se" %in% names(rv$data)) {
        showNotification(
          "Please run a meta-analysis first to generate effect sizes",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Show progress
      progress(list(message = "Initializing GOSH analysis...", value = 0))

      # Run in background
      future::future({
        run_gosh_analysis(
          effect_size = rv$data$effect_size,
          se = rv$data$se,
          study_ids = rv$data$study_id %||% paste0("Study ", 1:nrow(rv$data)),
          n_subsets = input$n_subsets,
          cluster_method = input$cluster_method,
          n_clusters = input$n_clusters
        )
      }) %...>% {
        result <- .
        gosh_results(result)
        progress(NULL)

        showNotification(
          paste("GOSH analysis complete:", result$n_subsets, "subsets analyzed"),
          type = "message",
          duration = 5
        )
      }
    })

    # Progress UI
    output$progress_ui <- renderUI({
      req(progress())

      p <- progress()

      tags$div(
        class = "mt-3",
        tags$div(
          class = "progress",
          tags$div(
            class = "progress-bar progress-bar-striped progress-bar-animated",
            role = "progressbar",
            style = paste0("width: ", p$value, "%"),
            p$message
          )
        )
      )
    })

    # Render GOSH output
    output$gosh_output <- renderUI({
      req(gosh_results())

      results <- gosh_results()

      tagList(
        # Summary
        layout_columns(
          col_widths = c(3, 3, 3, 3),

          value_box(
            title = "Subsets Analyzed",
            value = format(results$n_subsets, big.mark = ","),
            showcase = icon("cubes"),
            theme = "primary"
          ),

          value_box(
            title = "Outliers Detected",
            value = results$n_outliers,
            showcase = icon("exclamation-triangle"),
            theme = if (results$n_outliers > 0) "warning" else "success"
          ),

          value_box(
            title = "Effect Range",
            value = sprintf("%.2f to %.2f", results$effect_min, results$effect_max),
            showcase = icon("arrows-alt-h"),
            theme = "info"
          ),

          value_box(
            title = "I² Range",
            value = sprintf("%.1f%% to %.1f%%", results$i2_min, results$i2_max),
            showcase = icon("chart-area"),
            theme = "secondary"
          )
        ),

        # GOSH plot
        card(
          card_header(
            tags$h5(class = "mb-0", icon("project-diagram"), " GOSH Plot (I² vs. Pooled Effect)")
          ),
          card_body(
            plotlyOutput(ns("gosh_plot"), height = "600px"),
            hr(),
            p(class = "text-muted small",
              icon("info-circle"),
              " Each point represents one combination of studies. Isolated points or clusters ",
              "suggest outliers or subgroups."
            )
          )
        ),

        # Outlier studies
        if (results$n_outliers > 0) {
          card(
            card_header("Suspected Outlier Studies"),
            card_body(
              DT::DTOutput(ns("outliers_table")),
              p(class = "text-muted small mt-3",
                "Studies that frequently appear in isolated clusters or extreme subsets."
              )
            )
          )
        },

        # Export
        card(
          card_header("Export"),
          card_body(
            layout_columns(
              col_widths = c(4, 4, 4),
              downloadButton(ns("download_plot"), "Plot (PNG)",
                           class = "btn-primary w-100"),
              downloadButton(ns("download_data"), "GOSH Data (CSV)",
                           class = "btn-secondary w-100"),
              downloadButton(ns("download_report"), "Report (TXT)",
                           class = "btn-info w-100")
            )
          )
        )
      )
    })

    # GOSH plot
    output$gosh_plot <- renderPlotly({
      req(gosh_results())
      results <- gosh_results()

      # Create plotly figure
      if (results$cluster_method == "kmeans") {
        # Color by cluster
        fig <- plot_ly(
          data = results$gosh_data,
          x = ~pooled_effect,
          y = ~i2,
          color = ~as.factor(cluster),
          colors = "Set1",
          type = "scatter",
          mode = "markers",
          marker = list(size = 5, opacity = 0.6),
          text = ~paste0("Effect: ", round(pooled_effect, 3), "<br>",
                        "I²: ", round(i2, 1), "%<br>",
                        "Cluster: ", cluster),
          hoverinfo = "text"
        ) %>%
          layout(
            title = "GOSH Plot with K-means Clustering",
            xaxis = list(title = "Pooled Effect", zeroline = TRUE),
            yaxis = list(title = "I² (%)", range = c(0, 100)),
            hovermode = "closest"
          )
      } else {
        # No clustering - color by I²
        fig <- plot_ly(
          data = results$gosh_data,
          x = ~pooled_effect,
          y = ~i2,
          type = "scatter",
          mode = "markers",
          marker = list(
            size = 5,
            opacity = 0.6,
            color = ~i2,
            colorscale = "Viridis",
            showscale = TRUE,
            colorbar = list(title = "I² (%)")
          ),
          text = ~paste0("Effect: ", round(pooled_effect, 3), "<br>",
                        "I²: ", round(i2, 1), "%"),
          hoverinfo = "text"
        ) %>%
          layout(
            title = "GOSH Plot",
            xaxis = list(title = "Pooled Effect", zeroline = TRUE),
            yaxis = list(title = "I² (%)", range = c(0, 100)),
            hovermode = "closest"
          )
      }

      fig
    })

    # Outliers table
    output$outliers_table <- DT::renderDT({
      req(gosh_results())
      results <- gosh_results()

      outliers_df <- results$outliers_df

      DT::datatable(
        outliers_df,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 't'
        ),
        rownames = FALSE,
        class = "display stripe hover"
      ) %>%
        DT::formatRound(columns = c("Frequency_in_Extreme_Subsets"), digits = 1)
    })

    # Download handlers
    output$download_plot <- downloadHandler(
      filename = function() {
        paste0("gosh_plot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(gosh_results())
        results <- gosh_results()

        p <- create_gosh_ggplot(results)
        ggsave(file, p, width = 10, height = 7, dpi = 300)
      }
    )

    output$download_data <- downloadHandler(
      filename = function() {
        paste0("gosh_data_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(gosh_results())
        write.csv(gosh_results()$gosh_data, file, row.names = FALSE)
      }
    )

    output$download_report <- downloadHandler(
      filename = function() {
        paste0("gosh_report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
      },
      content = function(file) {
        req(gosh_results())
        results <- gosh_results()

        report <- c(
          "GOSH ANALYSIS REPORT",
          paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
          "",
          "=" %R% 60,
          "",
          "SUMMARY:",
          paste("Subsets analyzed:", format(results$n_subsets, big.mark = ",")),
          paste("Outliers detected:", results$n_outliers),
          paste("Pooled effect range:", sprintf("[%.3f, %.3f]", results$effect_min, results$effect_max)),
          paste("I² range:", sprintf("[%.1f%%, %.1f%%]", results$i2_min, results$i2_max)),
          "",
          if (results$n_outliers > 0) {
            c("SUSPECTED OUTLIER STUDIES:",
              "",
              capture.output(print(results$outliers_df)))
          },
          "",
          "=" %R% 60
        )

        writeLines(report, file)
      }
    )

    # Return reactive values
    return(reactive({
      list(
        gosh_results = gosh_results()
      )
    }))
  })
}

# Helper: Run GOSH analysis
run_gosh_analysis <- function(effect_size, se, study_ids, n_subsets, cluster_method, n_clusters) {
  n_studies <- length(effect_size)

  # Generate subsets
  if (n_studies <= 15) {
    # All possible subsets
    subsets <- generate_all_subsets(n_studies, min_size = 3)
  } else {
    # Random sampling
    subsets <- generate_random_subsets(n_studies, n_subsets, min_size = 3)
  }

  # Limit to requested number
  if (length(subsets) > n_subsets) {
    subsets <- sample(subsets, n_subsets)
  }

  # Run meta-analysis for each subset
  gosh_data <- lapply(subsets, function(idx) {
    if (length(idx) < 2) return(NULL)

    tryCatch({
      fit <- metafor::rma(yi = effect_size[idx], sei = se[idx], method = "REML")

      data.frame(
        pooled_effect = coef(fit),
        i2 = max(0, 100 * fit$I2),
        tau2 = fit$tau2,
        n_studies_in_subset = length(idx)
      )
    }, error = function(e) NULL)
  })

  # Remove NULLs and combine
  gosh_data <- do.call(rbind, Filter(Negate(is.null), gosh_data))

  # Clustering
  if (cluster_method == "kmeans" && nrow(gosh_data) > n_clusters) {
    km <- kmeans(gosh_data[, c("pooled_effect", "i2")], centers = n_clusters, nstart = 25)
    gosh_data$cluster <- km$cluster
  } else {
    gosh_data$cluster <- 1
  }

  # Identify outlier studies (studies that frequently appear in extreme subsets)
  # Define "extreme" as subsets in bottom/top 5% of pooled effect distribution
  effect_q05 <- quantile(gosh_data$pooled_effect, 0.05)
  effect_q95 <- quantile(gosh_data$pooled_effect, 0.95)

  study_frequencies <- sapply(1:n_studies, function(i) {
    # Count how often study i appears in extreme subsets
    extreme_count <- sum(sapply(subsets, function(idx) {
      if (i %in% idx) {
        subset_effect <- gosh_data$pooled_effect[which(sapply(subsets, function(x) setequal(x, idx)))[1]]
        return(subset_effect < effect_q05 || subset_effect > effect_q95)
      }
      return(FALSE)
    }))

    return(extreme_count)
  })

  # Studies with high frequency in extreme subsets are outliers
  outlier_threshold <- quantile(study_frequencies, 0.90)
  outlier_indices <- which(study_frequencies > outlier_threshold)

  outliers_df <- if (length(outlier_indices) > 0) {
    data.frame(
      Study_ID = study_ids[outlier_indices],
      Effect_Size = effect_size[outlier_indices],
      SE = se[outlier_indices],
      Frequency_in_Extreme_Subsets = study_frequencies[outlier_indices],
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      Study_ID = character(0),
      Effect_Size = numeric(0),
      SE = numeric(0),
      Frequency_in_Extreme_Subsets = numeric(0)
    )
  }

  return(list(
    gosh_data = gosh_data,
    n_subsets = nrow(gosh_data),
    n_outliers = nrow(outliers_df),
    outliers_df = outliers_df,
    effect_min = min(gosh_data$pooled_effect),
    effect_max = max(gosh_data$pooled_effect),
    i2_min = min(gosh_data$i2),
    i2_max = max(gosh_data$i2),
    cluster_method = cluster_method
  ))
}

# Helper: Generate all subsets
generate_all_subsets <- function(n, min_size = 2) {
  all_subsets <- list()

  for (size in min_size:n) {
    combs <- combn(n, size, simplify = FALSE)
    all_subsets <- c(all_subsets, combs)
  }

  return(all_subsets)
}

# Helper: Generate random subsets
generate_random_subsets <- function(n, n_subsets, min_size = 2) {
  subsets <- list()

  for (i in 1:n_subsets) {
    size <- sample(min_size:n, 1)
    subset <- sample(n, size)
    subsets[[i]] <- subset
  }

  return(subsets)
}

# Helper: Create ggplot version
create_gosh_ggplot <- function(results) {
  p <- ggplot(results$gosh_data, aes(x = pooled_effect, y = i2))

  if (results$cluster_method == "kmeans") {
    p <- p +
      geom_point(aes(color = as.factor(cluster)), alpha = 0.6, size = 2) +
      scale_color_brewer(palette = "Set1", name = "Cluster")
  } else {
    p <- p +
      geom_point(aes(color = i2), alpha = 0.6, size = 2) +
      scale_color_viridis_c(name = "I² (%)")
  }

  p <- p +
    labs(
      title = "GOSH Plot",
      x = "Pooled Effect",
      y = "I² (%)"
    ) +
    ylim(0, 100) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
      axis.text = element_text(size = 11),
      axis.title = element_text(size = 12, face = "bold")
    )

  return(p)
}

# Utility: String repetition
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}

# Utility: Null coalescing operator
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}
