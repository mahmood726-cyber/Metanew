# Network Meta-Analysis Module - FIXED VERSION
library(shiny)
library(netmeta)

nma_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(3, 9),
      card(
        card_header("NMA Settings"),
        selectInput(ns("outcome"), "Outcome", choices = NULL),
        selectInput(
          ns("reference"),
          tags$span(
            "Reference Treatment",
            bslib::tooltip(
              icon("circle-question"),
              "The reference treatment serves as the comparator. All other treatments will be compared to this. Typically use placebo or standard care."
            )
          ),
          choices = NULL
        ),
        selectInput(
          ns("method"),
          tags$span(
            "Method",
            bslib::tooltip(
              icon("circle-question"),
              "Random Effects accounts for between-study heterogeneity (recommended for most NMA). Fixed Effect assumes all studies estimate the same treatment effects."
            )
          ),
          choices = c("Random Effects (Recommended)" = "random", "Fixed Effect" = "fixed"),
          selected = "random"
        ),
        checkboxInput(
          ns("check_inconsistency"),
          tags$span(
            "Check Inconsistency",
            bslib::tooltip(
              icon("circle-question"),
              "Inconsistency occurs when direct and indirect evidence disagree. This tests whether the network assumption holds (design-by-treatment interaction test)."
            )
          ),
          TRUE
        ),
        hr(),
        div(
          class = "alert alert-info p-2",
          icon("info-circle"),
          tags$small(" NMA requires studies with multiple treatment arms. Each study should compare ≥2 treatments.")
        ),
        actionButton(ns("btn_run"), "Run NMA", class = "btn-primary w-100", icon = icon("play-circle"))
      ),
      card(
        card_header("NMA Results"),
        navset_card_tab(
          nav_panel(
            "Network Plot",
            p(class = "text-muted",
              icon("info-circle"),
              " Visual representation of the evidence network. Node size = number of studies, line thickness = number of direct comparisons."),
            plotOutput(ns("network_plot"), height = "500px")
          ),
          nav_panel(
            "League Table",
            p(class = "text-muted",
              icon("info-circle"),
              " All pairwise treatment comparisons with effect estimates and 95% confidence intervals. Upper triangle shows effect sizes, lower triangle shows opposite direction."),
            DTOutput(ns("league_table"))
          ),
          nav_panel(
            "Rankings",
            p(class = "text-muted",
              icon("info-circle"),
              " Treatment rankings based on P-scores (0-1 scale). Higher P-score = better treatment. P-score ≈ probability that treatment is best."),
            DTOutput(ns("rankings"))
          ),
          nav_panel(
            "Inconsistency",
            p(class = "text-muted",
              icon("info-circle"),
              " Tests whether direct and indirect evidence agree. p > 0.05 suggests consistency (good). p < 0.05 suggests inconsistency (investigate sources)."),
            verbatimTextOutput(ns("inconsistency"))
          ),
          nav_panel(
            "Summary",
            p(class = "text-muted",
              icon("info-circle"),
              " Overall model statistics including number of studies, treatments, heterogeneity (τ², I²), and model fit."),
            verbatimTextOutput(ns("summary"))
          )
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
          result <- run_nma(rv$data, input$outcome, input$reference,
                           input$method, input$check_inconsistency)
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
      cat("Number of studies:", result$n_studies, "\n")
      cat("Number of treatments:", result$n_treatments, "\n")
      cat("Reference treatment:", result$reference, "\n")
      cat("Method:", result$method, "\n\n")

      if (!is.null(result$heterogeneity)) {
        cat("Heterogeneity:\n")
        cat(sprintf("  τ² = %.3f\n", result$heterogeneity$tau2))
        cat(sprintf("  I² = %.1f%%\n", result$heterogeneity$I2))
      }

      cat("\nModel Summary:\n")
      print(summary(result$model))
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

      netgraph(result$model,
               cex = 1.5,
               col = "steelblue",
               thickness = "number.of.studies",
               number.of.studies = TRUE,
               labels = result$treatments,
               main = "Evidence Network")
    })

    output$inconsistency <- renderPrint({
      req(nma_result())
      result <- nma_result()

      cat("INCONSISTENCY ASSESSMENT\n")
      cat("========================\n\n")

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
