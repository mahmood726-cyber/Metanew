# Network Meta-Analysis Module
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
        selectInput(ns("reference"), "Reference Treatment", choices = NULL),
        selectInput(ns("method"), "Method",
                    choices = c("Random Effects" = "random", "Fixed Effect" = "fixed")),
        checkboxInput(ns("check_inconsistency"), "Check Inconsistency", TRUE),
        actionButton(ns("btn_run"), "Run NMA", class = "btn-primary w-100")
      ),
      card(
        card_header("NMA Results"),
        navset_card_tab(
          nav_panel("League Table", DTOutput(ns("league_table"))),
          nav_panel("Network Plot", plotOutput(ns("network_plot"))),
          nav_panel("Rankings", DTOutput(ns("rankings"))),
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
          result <- run_nma(rv$data, input$outcome, input$reference, input$method)
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
      print(nma_result()$model)
    })

    output$league_table <- renderDT({
      req(nma_result())
      datatable(nma_result()$league_table, options = list(dom = 't'))
    })

    output$rankings <- renderDT({
      req(nma_result())
      datatable(nma_result()$rankings)
    })

    output$network_plot <- renderPlot({
      req(nma_result())
      netgraph(nma_result()$model, cex = 1.5, col = "steelblue")
    })

    return(reactive(nma_result()))
  })
}

run_nma <- function(data, outcome, reference, method = "random") {
  data_outcome <- data[data$outcome == outcome, ]

  nma <- netmeta(TE = yi, seTE = sei, treat1 = treatment, treat2 = comparator,
                 studlab = study_id, data = data_outcome,
                 reference.group = reference, comb.random = (method == "random"))

  league <- netleague(nma)
  rankings <- netrank(nma)

  list(model = nma, league_table = league$random, rankings = rankings$ranking.random)
}
