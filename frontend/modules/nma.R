# Network Meta-Analysis Module - WITH MULTI-LEVEL SUPPORT
library(shiny)
library(netmeta)
library(metafor)

# Source utilities
source("utils/plot_downloads.R", local = TRUE)
source("utils/multilevel_nma.R", local = TRUE)

nma_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(3, 9),
      card(
        card_header("NMA Settings"),
        selectInput(ns("outcome"), "Outcome", choices = NULL),
        selectInput(ns("reference"), "Reference Treatment", choices = NULL),
        selectInput(ns("nma_type"), "NMA Type",
                    choices = c("Standard NMA (netmeta)" = "standard",
                               "Multi-Level NMA (rma.mv)" = "multilevel"),
                    selected = "standard"),
        selectInput(ns("method"), "Method",
                    choices = c("Random Effects" = "random", "Fixed Effect" = "fixed")),
        conditionalPanel(
          condition = "input.nma_type == 'multilevel'",
          ns = ns,
          numericInput(ns("correlation"), "Within-Study Correlation",
                      value = 0.5, min = 0, max = 1, step = 0.1),
          selectInput(ns("vcov_structure"), "Variance Structure",
                     choices = c("Unstructured" = "UN",
                                "Compound Symmetry" = "CS",
                                "Autoregressive" = "AR")),
          helpText("Multi-level NMA properly handles multi-arm trials and within-study correlations.")
        ),
        checkboxInput(ns("check_inconsistency"), "Check Inconsistency", TRUE),
        hr(),
        helpText("Note: For NMA, data should have multiple treatments per study."),
        actionButton(ns("btn_run"), "Run NMA", class = "btn-primary w-100")
      ),
      card(
        card_header("NMA Results"),
        navset_card_tab(
          nav_panel(
            "Network Plot",
            plotOutput(ns("network_plot"), height = "500px"),
            hr(),
            plot_download_ui(
              ns("network_download"),
              plot_name = "Network Plot",
              default_width = 2400,
              default_height = 2400
            )
          ),
          nav_panel("League Table", DTOutput(ns("league_table"))),
          nav_panel("Rankings", DTOutput(ns("rankings"))),
          nav_panel("Inconsistency", verbatimTextOutput(ns("inconsistency"))),
          nav_panel("Summary", verbatimTextOutput(ns("summary")))
        )
      )
    )
  )
}

nma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    nma_result <- reactiveVal(NULL)

    observe({
      req(rv$data)
      if ("outcome" %in% names(rv$data)) {
        updateSelectInput(session, "outcome", choices = unique(rv$data$outcome))
      }
      if ("treatment" %in% names(rv$data)) {
        updateSelectInput(session, "reference", choices = unique(rv$data$treatment))
      }
    })

    observeEvent(input$btn_run, {
      req(rv$data, input$outcome, input$reference)

      withProgress(message = "Running NMA...", {
        tryCatch({
          if (input$nma_type == "multilevel") {
            # Multi-level NMA using rma.mv
            result <- run_multilevel_nma(
              data = rv$data,
              outcome = input$outcome,
              reference = input$reference,
              correlation = input$correlation,
              struct = input$vcov_structure,
              method = ifelse(input$method == "random", "REML", "ML")
            )
            # Convert to standard format for display
            result$is_multilevel <- TRUE
            result$league_table <- generate_league_table_multilevel(
              result$pairwise_comparisons,
              result$treatments
            )
          } else {
            # Standard NMA using netmeta
            result <- run_nma(rv$data, input$outcome, input$reference,
                            input$method, input$check_inconsistency)
            result$is_multilevel <- FALSE
          }

          nma_result(result)
          rv$nma_results[[input$outcome]] <- result
          showNotification("✓ NMA complete", type = "message")
        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    output$summary <- renderPrint({
      req(nma_result())
      result <- nma_result()

      cat("NETWORK META-ANALYSIS RESULTS\n")
      cat("==============================\n\n")

      if (isTRUE(result$is_multilevel)) {
        cat("Method: Multi-Level NMA (rma.mv)\n")
      } else {
        cat("Method: Standard NMA (netmeta)\n")
      }

      cat("Number of studies:", result$n_studies, "\n")
      cat("Number of treatments:", result$n_treatments, "\n")
      cat("Reference treatment:", result$reference, "\n\n")

      if (isTRUE(result$is_multilevel)) {
        # Multi-level results
        cat("Diagnostics:\n")
        cat(sprintf("  τ² = %.3f\n", result$diagnostics$tau2[1]))
        cat(sprintf("  I² = %.1f%%\n", result$diagnostics$I2))
        cat(sprintf("  Q = %.2f (p = %.4f)\n", result$diagnostics$QE, result$diagnostics$QEp))
        cat(sprintf("  AIC = %.1f, BIC = %.1f\n", result$diagnostics$AIC, result$diagnostics$BIC))
        cat(sprintf("  Within-study correlation: %.2f\n", result$correlation_assumed))
        cat(sprintf("  Variance structure: %s\n\n", result$structure))

        cat("Treatment Effects (vs", result$reference, "):\n")
        print(result$treatment_effects)

      } else {
        # Standard NMA results
        if (!is.null(result$heterogeneity)) {
          cat("Heterogeneity:\n")
          cat(sprintf("  τ² = %.3f\n", result$heterogeneity$tau2))
          cat(sprintf("  I² = %.1f%%\n", result$heterogeneity$I2))
        }

        cat("\nModel Summary:\n")
        print(summary(result$model))
      }
    })

    output$league_table <- renderDT({
      req(nma_result())
      result <- nma_result()

      datatable(
        result$league_table,
        options = list(
          dom = 't',
          pageLength = 20,
          scrollX = TRUE
        ),
        caption = "League Table: Effect estimates (95% CI) for all pairwise comparisons"
      )
    })

    output$rankings <- renderDT({
      req(nma_result())
      result <- nma_result()

      datatable(
        result$rankings,
        options = list(
          pageLength = 10,
          order = list(list(1, 'asc'))  # Sort by rank
        ),
        caption = "Treatment Rankings (P-scores)"
      )
    })

    output$network_plot <- renderPlot({
      req(nma_result())
      result <- nma_result()

      if (isTRUE(result$is_multilevel)) {
        # Forest plot for multi-level NMA
        plot_multilevel_nma_forest(result$treatment_effects, result$reference)
      } else {
        # Network graph for standard NMA
        netgraph(result$model,
                 cex = 1.5,
                 col = "steelblue",
                 thickness = "number.of.studies",
                 number.of.studies = TRUE,
                 labels = result$treatments,
                 main = "Evidence Network")
      }
    })

    output$inconsistency <- renderPrint({
      req(nma_result())
      result <- nma_result()

      cat("INCONSISTENCY ASSESSMENT\n")
      cat("========================\n\n")

      if (isTRUE(result$is_multilevel)) {
        # Multi-level inconsistency check
        if (!is.null(result$inconsistency)) {
          cat("Method:", result$inconsistency$method, "\n\n")
          cat(sprintf("Q = %.2f (df = %d, p = %.4f)\n",
                     result$inconsistency$Q,
                     result$inconsistency$df,
                     result$inconsistency$p_value))
          cat("\n", result$inconsistency$interpretation, "\n")
        }
      } else {
        # Standard NMA inconsistency
        if (!is.null(result$inconsistency)) {
          cat("Design-by-treatment interaction model:\n\n")
          print(result$inconsistency)

          if (result$inconsistency$p.value > 0.05) {
            cat("\n✓ No significant inconsistency detected (p > 0.05)\n")
          } else {
            cat("\n⚠ Significant inconsistency detected (p < 0.05)\n")
            cat("  Consider fixed-effects model or investigate sources of inconsistency.\n")
          }
        } else {
          cat("Inconsistency check not performed.\n")
        }
      }
    })

    # Network plot download handler
    moduleServer("network_download", function(input_dl, output_dl, session) {
      output_dl$download <- downloadHandler(
        filename = function() {
          format <- tolower(input_dl$format)
          timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
          paste0("network_plot_", input$outcome, "_", timestamp, ".", format)
        },

        content = function(file) {
          req(nma_result())

          format <- tolower(input_dl$format)
          result <- nma_result()

          # Get dimensions
          if (format == "pdf") {
            width <- input_dl$width_pdf
            height <- input_dl$height_pdf
          } else {
            width <- input_dl$width
            height <- input_dl$height
          }

          # Open graphics device
          if (format == "png") {
            png(file, width = width, height = height, res = input_dl$dpi, type = "cairo")
          } else if (format == "jpg") {
            jpeg(file, width = width, height = height, res = input_dl$dpi,
                 quality = input_dl$quality, type = "cairo")
          } else if (format == "pdf") {
            pdf(file, width = width, height = height, useDingbats = FALSE)
          } else if (format == "svg") {
            svg(file, width = width / 96, height = height / 96)
          }

          # Generate network plot
          netgraph(result$model,
                   cex = 1.5,
                   col = "steelblue",
                   thickness = "number.of.studies",
                   number.of.studies = TRUE,
                   labels = result$treatments,
                   main = "Evidence Network")

          dev.off()
        }
      )
    })

    return(reactive(nma_result()))
  })
}

run_nma <- function(data, outcome, reference, method = "random", check_inconsistency = TRUE) {

  # Filter by outcome
  data_outcome <- data[data$outcome == outcome, ]

  # Check data structure and convert to pairwise format if needed
  data_pairwise <- prepare_nma_data(data_outcome)

  if (nrow(data_pairwise) == 0) {
    stop("No valid comparisons found for NMA. Ensure data has multiple treatments per study.")
  }

  # Run network meta-analysis
  nma <- netmeta(
    TE = yi,
    seTE = sei,
    treat1 = treat1,
    treat2 = treat2,
    studlab = study_id,
    data = data_pairwise,
    reference.group = reference,
    comb.fixed = (method == "fixed"),
    comb.random = (method == "random"),
    sm = "SMD"  # Can be adjusted based on data type
  )

  # Generate league table
  league <- netleague(nma, digits = 2)
  league_table <- if (method == "random") league$random else league$fixed

  # Calculate rankings (P-scores)
  rankings <- netrank(nma)
  ranking_df <- if (method == "random") {
    data.frame(
      Treatment = names(rankings$ranking.random),
      Rank = rankings$ranking.random,
      P_score = rankings$Pscore.random,
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      Treatment = names(rankings$ranking.fixed),
      Rank = rankings$ranking.fixed,
      P_score = rankings$Pscore.fixed,
      stringsAsFactors = FALSE
    )
  }
  ranking_df <- ranking_df[order(ranking_df$Rank), ]

  # Check for inconsistency (if sufficient data)
  inconsistency_result <- NULL
  if (check_inconsistency && nma$k >= 3) {
    tryCatch({
      # Design-by-treatment interaction model
      decomp <- decomp.design(nma)
      inconsistency_result <- list(
        p.value = decomp$Q.inconsistency.p,
        Q = decomp$Q.inconsistency,
        df = decomp$df.Q.inconsistency
      )
    }, error = function(e) {
      # Inconsistency check may fail if network too simple
      NULL
    })
  }

  # Extract heterogeneity
  heterogeneity <- list(
    tau2 = nma$tau^2,
    I2 = nma$I2
  )

  list(
    model = nma,
    league_table = league_table,
    rankings = ranking_df,
    n_studies = nma$k,
    n_treatments = length(nma$trts),
    treatments = nma$trts,
    reference = reference,
    method = method,
    heterogeneity = heterogeneity,
    inconsistency = inconsistency_result
  )
}

# Helper function to prepare data for NMA
prepare_nma_data <- function(data) {

  # Check if data already has treat1/treat2 structure
  if (all(c("treat1", "treat2") %in% names(data))) {
    return(data)
  }

  # Otherwise, create pairwise comparisons within each study
  # Group by study and create all pairwise comparisons

  studies <- unique(data$study_id)
  pairwise_list <- list()

  for (study in studies) {
    study_data <- data[data$study_id == study, ]

    # Get treatments in this study
    treatments <- unique(study_data$treatment)

    if (length(treatments) < 2) {
      # Skip studies with only one arm
      next
    }

    # Create all pairwise comparisons
    for (i in 1:(length(treatments) - 1)) {
      for (j in (i + 1):length(treatments)) {
        treat1_data <- study_data[study_data$treatment == treatments[i], ]
        treat2_data <- study_data[study_data$treatment == treatments[j], ]

        if (nrow(treat1_data) > 0 && nrow(treat2_data) > 0) {
          # Calculate pairwise effect
          yi_pair <- treat1_data$yi[1] - treat2_data$yi[1]
          sei_pair <- sqrt(treat1_data$vi[1] + treat2_data$vi[1])

          pairwise_list[[length(pairwise_list) + 1]] <- data.frame(
            study_id = study,
            treat1 = treatments[i],
            treat2 = treatments[j],
            yi = yi_pair,
            sei = sei_pair,
            outcome = treat1_data$outcome[1],
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  if (length(pairwise_list) == 0) {
    return(data.frame())
  }

  do.call(rbind, pairwise_list)
}
