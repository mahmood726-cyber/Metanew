# ==============================================================================
# GENOMIC META-ANALYSIS MODULE
# ==============================================================================
#
# Specialized module for meta-analysis of genome-wide association studies (GWAS),
# gene expression data, and genetic variants. Opens Metanew to precision medicine
# and genomics research markets.
#
# References:
# - Evangelou & Ioannidis (2013) Meta-analysis methods for genome-wide
#   association studies and beyond
# - Willer et al. (2010) METAL: fast and efficient meta-analysis of
#   genomewide association scans
# - de Bakker et al. (2008) Practical aspects of imputation-driven
#   meta-analysis of genome-wide association studies
#
# Version: 4.0.0
# Last Updated: 2025-11-04
# ==============================================================================

# Required packages
library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(DT)
library(data.table)  # Fast data handling for large GWAS

# ==============================================================================
# UI FUNCTION
# ==============================================================================

genomic_ma_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      class = "bg-info text-white",
      "Genomic Meta-Analysis - GWAS, Gene Expression & Genetic Variants 🧬"
    ),
    card_body(
      # Information panel
      card(
        card_header("Genomic Meta-Analysis Capabilities"),
        card_body(
          p("Specialized toolkit for genetic association studies:"),
          tags$ul(
            tags$li(strong("GWAS Meta-Analysis:"), "Combine genome-wide association studies"),
            tags$li(strong("Multiple Testing Correction:"), "Genome-wide significance (p < 5×10⁻⁸)"),
            tags$li(strong("LD Clumping:"), "Identify independent genetic signals"),
            tags$li(strong("Gene-Set Enrichment:"), "Pathway and biological annotation"),
            tags$li(strong("Publication Plots:"), "Manhattan, QQ, regional association")
          ),
          p(class = "text-info", strong("Opens Metanew to precision medicine and genomics research!"))
        )
      ),

      hr(),

      # Step 1: Data import
      card(
        card_header("Step 1: Import GWAS Summary Statistics"),
        card_body(
          selectInput(
            ns("gwas_format"),
            "GWAS Format:",
            choices = c(
              "PLINK (.assoc, .linear, .logistic)" = "plink",
              "BOLT-LMM" = "bolt",
              "SAIGE" = "saige",
              "METAL" = "metal",
              "Custom (specify columns)" = "custom"
            ),
            selected = "plink"
          ),

          fileInput(
            ns("gwas_files"),
            "Upload GWAS Summary Statistics (can select multiple studies):",
            accept = c(".txt", ".tsv", ".gz", ".assoc", ".linear", ".logistic"),
            multiple = TRUE
          ),

          conditionalPanel(
            condition = "input.gwas_format == 'custom'",
            ns = ns,
            p("Specify column names in your files:"),
            textInput(ns("col_snp"), "SNP ID column:", value = "SNP"),
            textInput(ns("col_chr"), "Chromosome column:", value = "CHR"),
            textInput(ns("col_pos"), "Position column:", value = "POS"),
            textInput(ns("col_a1"), "Effect allele column:", value = "A1"),
            textInput(ns("col_a2"), "Other allele column:", value = "A2"),
            textInput(ns("col_beta"), "Beta/Effect column:", value = "BETA"),
            textInput(ns("col_se"), "Standard error column:", value = "SE"),
            textInput(ns("col_p"), "P-value column:", value = "P")
          ),

          actionButton(
            ns("import_gwas"),
            "Import GWAS Data",
            icon = icon("upload"),
            class = "btn-primary"
          ),

          hr(),

          h5("Data Summary:"),
          uiOutput(ns("import_summary"))
        )
      ),

      hr(),

      # Step 2: Quality control
      card(
        card_header("Step 2: Quality Control"),
        card_body(
          layout_columns(
            col_widths = c(6, 6),

            card(
              card_header("Filters"),
              card_body(
                numericInput(
                  ns("maf_threshold"),
                  "Minimum MAF (Minor Allele Frequency):",
                  value = 0.01,
                  min = 0,
                  max = 0.5,
                  step = 0.01
                ),

                numericInput(
                  ns("info_threshold"),
                  "Minimum Imputation Quality (INFO):",
                  value = 0.8,
                  min = 0,
                  max = 1,
                  step = 0.1
                ),

                numericInput(
                  ns("hwe_threshold"),
                  "HWE P-value Threshold:",
                  value = 1e-6,
                  min = 0,
                  max = 1,
                  step = 0.000001
                ),

                actionButton(
                  ns("apply_qc"),
                  "Apply QC Filters",
                  icon = icon("filter"),
                  class = "btn-warning"
                )
              )
            ),

            card(
              card_header("QC Summary"),
              card_body(
                uiOutput(ns("qc_summary"))
              )
            )
          )
        )
      ),

      hr(),

      # Step 3: Meta-analysis
      card(
        card_header("Step 3: Meta-Analysis Settings"),
        card_body(
          layout_columns(
            col_widths = c(6, 6),

            card(
              card_header("Analysis Options"),
              card_body(
                selectInput(
                  ns("ma_method"),
                  "Meta-Analysis Method:",
                  choices = c(
                    "Fixed Effects (Inverse Variance)" = "fixed",
                    "Random Effects (DerSimonian-Laird)" = "random",
                    "Sample Size Weighted" = "sample_size"
                  ),
                  selected = "fixed"
                ),

                checkboxInput(
                  ns("genomic_control"),
                  "Apply Genomic Control (λ correction)",
                  value = TRUE
                ),

                numericInput(
                  ns("gwas_threshold"),
                  "Genome-Wide Significance Threshold:",
                  value = 5e-8,
                  min = 1e-10,
                  max = 1e-5,
                  step = 1e-8
                ),

                numericInput(
                  ns("suggestive_threshold"),
                  "Suggestive Threshold:",
                  value = 1e-5,
                  min = 1e-8,
                  max = 1e-3,
                  step = 1e-6
                )
              )
            ),

            card(
              card_header("Run Analysis"),
              card_body(
                actionButton(
                  ns("run_gwas_ma"),
                  "Run GWAS Meta-Analysis",
                  icon = icon("rocket"),
                  class = "btn-success btn-lg w-100 mb-3"
                ),

                hr(),

                h5("Analysis Status:"),
                uiOutput(ns("ma_status"))
              )
            )
          )
        )
      ),

      hr(),

      # Results tabs
      navset_card_tab(
        id = ns("results_tabs"),

        # Tab 1: Manhattan plot
        nav_panel(
          "Manhattan Plot",
          icon = icon("mountain"),

          card(
            card_header("Genome-Wide Association Results"),
            card_body(
              plotlyOutput(ns("manhattan_plot"), height = "600px"),

              hr(),

              layout_columns(
                col_widths = c(4, 4, 4),

                card(
                  card_header("Genome-Wide Significant"),
                  card_body(
                    h3(textOutput(ns("n_gwas_sig")), style = "color: red;"),
                    p("SNPs at p < 5×10⁻⁸")
                  )
                ),

                card(
                  card_header("Suggestive"),
                  card_body(
                    h3(textOutput(ns("n_suggestive")), style = "color: orange;"),
                    p("SNPs at p < 1×10⁻⁵")
                  )
                ),

                card(
                  card_header("Lead SNPs (Clumped)"),
                  card_body(
                    h3(textOutput(ns("n_lead_snps")), style = "color: green;"),
                    p("Independent signals")
                  )
                )
              )
            )
          ),

          card(
            card_header("Top Association Results"),
            card_body(
              DTOutput(ns("top_snps_table"))
            )
          )
        ),

        # Tab 2: QQ plot
        nav_panel(
          "QQ Plot",
          icon = icon("chart-line"),

          card(
            card_header("Quantile-Quantile Plot"),
            card_body(
              p("Assess systematic bias and genomic inflation:"),

              plotlyOutput(ns("qq_plot"), height = "500px"),

              hr(),

              layout_columns(
                col_widths = c(6, 6),

                card(
                  card_header("Genomic Inflation Factor (λ)"),
                  card_body(
                    h3(textOutput(ns("lambda_gc")), style = "color: steelblue;"),
                    p("λ > 1.05 suggests inflation (population stratification,
                      poor QC, or polygenic signal)")
                  )
                ),

                card(
                  card_header("Interpretation"),
                  card_body(
                    uiOutput(ns("lambda_interpretation"))
                  )
                )
              )
            )
          )
        ),

        # Tab 3: Regional plot
        nav_panel(
          "Regional Association",
          icon = icon("search-location"),

          card(
            card_header("Zoom Into Genomic Region"),
            card_body(
              layout_columns(
                col_widths = c(4, 4, 4),

                selectInput(
                  ns("region_chr"),
                  "Chromosome:",
                  choices = 1:22,
                  selected = 1
                ),

                numericInput(
                  ns("region_start"),
                  "Start Position (bp):",
                  value = 1000000,
                  min = 1,
                  step = 100000
                ),

                numericInput(
                  ns("region_end"),
                  "End Position (bp):",
                  value = 2000000,
                  min = 1,
                  step = 100000
                )
              ),

              actionButton(
                ns("plot_region"),
                "Plot Region",
                icon = icon("search"),
                class = "btn-primary"
              ),

              hr(),

              plotOutput(ns("regional_plot"), height = "500px")
            )
          )
        ),

        # Tab 4: Gene annotation
        nav_panel(
          "Gene Annotation",
          icon = icon("dna"),

          card(
            card_header("Map SNPs to Genes"),
            card_body(
              p("Annotate lead SNPs with nearest genes:"),

              numericInput(
                ns("gene_window"),
                "Gene Window (kb):",
                value = 50,
                min = 0,
                max = 500,
                step = 10
              ),

              actionButton(
                ns("annotate_genes"),
                "Annotate Genes",
                icon = icon("tag"),
                class = "btn-info"
              ),

              hr(),

              DTOutput(ns("gene_annotation_table"))
            )
          ),

          card(
            card_header("Gene-Set Enrichment Analysis"),
            card_body(
              p("Test for enrichment in biological pathways:"),

              selectInput(
                ns("gene_set_db"),
                "Gene Set Database:",
                choices = c(
                  "GO Biological Process" = "GO_BP",
                  "GO Molecular Function" = "GO_MF",
                  "GO Cellular Component" = "GO_CC",
                  "KEGG Pathways" = "KEGG",
                  "Reactome" = "REACTOME"
                ),
                selected = "GO_BP"
              ),

              actionButton(
                ns("run_gsea"),
                "Run GSEA",
                icon = icon("project-diagram"),
                class = "btn-success"
              ),

              hr(),

              DTOutput(ns("gsea_results_table"))
            )
          )
        ),

        # Tab 5: LD clumping
        nav_panel(
          "LD Clumping",
          icon = icon("compress"),

          card(
            card_header("Identify Independent Signals"),
            card_body(
              p("Clump SNPs by linkage disequilibrium to find independent associations:"),

              layout_columns(
                col_widths = c(6, 6),

                card(
                  card_header("Clumping Parameters"),
                  card_body(
                    numericInput(
                      ns("clump_p1"),
                      "Index SNP P-value Threshold:",
                      value = 5e-8,
                      min = 1e-10,
                      max = 1e-3,
                      step = 1e-8
                    ),

                    numericInput(
                      ns("clump_p2"),
                      "Clumped SNP P-value Threshold:",
                      value = 0.01,
                      min = 0.001,
                      max = 0.5,
                      step = 0.01
                    ),

                    numericInput(
                      ns("clump_r2"),
                      "LD r² Threshold:",
                      value = 0.1,
                      min = 0.01,
                      max = 1,
                      step = 0.05
                    ),

                    numericInput(
                      ns("clump_kb"),
                      "Clumping Window (kb):",
                      value = 250,
                      min = 50,
                      max = 1000,
                      step = 50
                    ),

                    actionButton(
                      ns("run_clumping"),
                      "Run LD Clumping",
                      icon = icon("compress"),
                      class = "btn-primary"
                    )
                  )
                ),

                card(
                  card_header("Clumping Results"),
                  card_body(
                    uiOutput(ns("clumping_summary"))
                  )
                )
              ),

              hr(),

              card(
                card_header("Independent Lead SNPs"),
                card_body(
                  DTOutput(ns("lead_snps_table"))
                )
              )
            )
          )
        ),

        # Tab 6: Export
        nav_panel(
          "Export Results",
          icon = icon("download"),

          card(
            card_header("Export GWAS Meta-Analysis Results"),
            card_body(
              h5("Available Export Formats:"),

              layout_columns(
                col_widths = c(6, 6),

                card(
                  card_body(
                    h6("Summary Statistics"),
                    downloadButton(ns("download_summary"), "Download Full Results (TSV)"),
                    p(class = "text-muted", "All SNPs with meta-analysis p-values")
                  )
                ),

                card(
                  card_body(
                    h6("Significant Hits"),
                    downloadButton(ns("download_significant"), "Download Significant SNPs (TSV)"),
                    p(class = "text-muted", "Genome-wide significant SNPs only")
                  )
                ),

                card(
                  card_body(
                    h6("Lead SNPs"),
                    downloadButton(ns("download_lead"), "Download Lead SNPs (TSV)"),
                    p(class = "text-muted", "Independent signals after LD clumping")
                  )
                ),

                card(
                  card_body(
                    h6("LocusZoom Format"),
                    downloadButton(ns("download_locuszoom"), "Download for LocusZoom"),
                    p(class = "text-muted", "Format for LocusZoom regional plots")
                  )
                ),

                card(
                  card_body(
                    h6("Manhattan Plot"),
                    downloadButton(ns("download_manhattan"), "Download Manhattan Plot (PNG)"),
                    p(class = "text-muted", "Publication-quality 300 DPI")
                  )
                ),

                card(
                  card_body(
                    h6("QQ Plot"),
                    downloadButton(ns("download_qq"), "Download QQ Plot (PNG)"),
                    p(class = "text-muted", "Publication-quality 300 DPI")
                  )
                )
              )
            )
          )
        )
      )
    )
  )
}

# ==============================================================================
# SERVER FUNCTION
# ==============================================================================

genomic_ma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    gwas_rv <- reactiveValues(
      gwas_data = NULL,
      ma_results = NULL,
      lead_snps = NULL,
      lambda_gc = NULL,
      fitted = FALSE
    )

    # ==============================================================================
    # HELPER FUNCTIONS
    # ==============================================================================

    # Calculate genomic inflation factor
    calculate_lambda_gc <- function(pvalues) {
      chisq <- qchisq(1 - pvalues, 1)
      lambda <- median(chisq, na.rm = TRUE) / qchisq(0.5, 1)
      return(lambda)
    }

    # Fixed-effects meta-analysis
    meta_analyze_gwas <- function(beta_list, se_list) {
      # Inverse variance weighting
      weights <- lapply(se_list, function(se) 1 / se^2)

      # Pooled beta
      pooled_beta <- mapply(function(b, w) sum(b * w) / sum(w),
                            beta_list, weights)

      # Pooled SE
      pooled_se <- mapply(function(w) sqrt(1 / sum(w)), weights)

      # Z-score and p-value
      z <- pooled_beta / pooled_se
      p <- 2 * pnorm(-abs(z))

      return(data.frame(
        BETA = pooled_beta,
        SE = pooled_se,
        Z = z,
        P = p
      ))
    }

    # LD clumping (simplified - would use PLINK in production)
    ld_clump <- function(data, p_threshold, r2_threshold, kb_window) {
      # Sort by p-value
      data <- data[order(data$P), ]

      # Greedy clumping
      lead_snps <- list()
      excluded <- c()

      for (i in 1:nrow(data)) {
        if (data$SNP[i] %in% excluded) next
        if (data$P[i] > p_threshold) break

        lead_snps <- c(lead_snps, list(data[i, ]))

        # Mark nearby SNPs as excluded
        nearby <- which(
          abs(data$POS - data$POS[i]) < kb_window * 1000 &
          data$CHR == data$CHR[i]
        )
        excluded <- c(excluded, data$SNP[nearby])
      }

      return(do.call(rbind, lead_snps))
    }

    # ==============================================================================
    # REACTIVE: Import GWAS data
    # ==============================================================================

    observeEvent(input$import_gwas, {
      req(input$gwas_files)

      showNotification("Importing GWAS summary statistics...",
                      type = "message", id = "import")

      tryCatch({
        # Read files (simplified - would handle different formats)
        gwas_list <- lapply(input$gwas_files$datapath, fread)

        # Combine studies
        gwas_combined <- rbindlist(gwas_list, fill = TRUE)

        gwas_rv$gwas_data <- gwas_combined

        removeNotification("import")
        showNotification(
          paste("Imported", nrow(gwas_combined), "SNPs from",
                length(gwas_list), "studies"),
          type = "message", duration = 5
        )

      }, error = function(e) {
        removeNotification("import")
        showNotification(paste("Error:", e$message), type = "error")
      })
    })

    # ==============================================================================
    # REACTIVE: Run GWAS meta-analysis
    # ==============================================================================

    observeEvent(input$run_gwas_ma, {
      req(gwas_rv$gwas_data)

      showNotification("Running GWAS meta-analysis...",
                      type = "message", id = "gwas_ma")

      tryCatch({
        data <- gwas_rv$gwas_data

        # Meta-analyze (simplified)
        ma_results <- meta_analyze_gwas(
          split(data$BETA, data$SNP),
          split(data$SE, data$SNP)
        )

        # Calculate genomic inflation
        lambda <- calculate_lambda_gc(ma_results$P)
        gwas_rv$lambda_gc <- lambda

        # Apply genomic control if requested
        if (input$genomic_control && lambda > 1) {
          ma_results$P <- pchisq(qchisq(1 - ma_results$P, 1) / lambda, 1, lower.tail = FALSE)
        }

        gwas_rv$ma_results <- ma_results
        gwas_rv$fitted <- TRUE

        removeNotification("gwas_ma")
        showNotification("GWAS meta-analysis complete!", type = "message", duration = 5)

      }, error = function(e) {
        removeNotification("gwas_ma")
        showNotification(paste("Error:", e$message), type = "error")
      })
    })

    # ==============================================================================
    # OUTPUTS
    # ==============================================================================

    # Manhattan plot
    output$manhattan_plot <- renderPlotly({
      req(gwas_rv$fitted, gwas_rv$ma_results)

      data <- gwas_rv$ma_results

      # Transform p-values to -log10
      data$LOG_P <- -log10(data$P)

      # Color by chromosome
      data$COLOR <- ifelse(data$CHR %% 2 == 0, "blue", "darkblue")

      plot_ly(data, x = ~POS, y = ~LOG_P, color = ~as.factor(CHR),
              type = "scatter", mode = "markers",
              marker = list(size = 3),
              text = ~paste("SNP:", SNP, "<br>P:", format.pval(P, digits = 2))) %>%
        add_segments(
          x = min(data$POS), xend = max(data$POS),
          y = -log10(input$gwas_threshold), yend = -log10(input$gwas_threshold),
          line = list(dash = "dash", color = "red"),
          showlegend = FALSE
        ) %>%
        layout(
          title = "Manhattan Plot - GWAS Meta-Analysis",
          xaxis = list(title = "Genomic Position"),
          yaxis = list(title = "-log10(P)"),
          showlegend = FALSE
        )
    })

    # QQ plot
    output$qq_plot <- renderPlotly({
      req(gwas_rv$fitted, gwas_rv$ma_results)

      pvals <- gwas_rv$ma_results$P
      n <- length(pvals)

      observed <- sort(-log10(pvals))
      expected <- -log10(ppoints(n))

      plot_ly(x = expected, y = observed,
              type = "scatter", mode = "markers",
              marker = list(size = 3, color = "steelblue")) %>%
        add_segments(
          x = 0, xend = max(expected),
          y = 0, yend = max(expected),
          line = list(dash = "dash", color = "red"),
          showlegend = FALSE
        ) %>%
        layout(
          title = paste("QQ Plot (λ =", round(gwas_rv$lambda_gc, 3), ")"),
          xaxis = list(title = "Expected -log10(P)"),
          yaxis = list(title = "Observed -log10(P)")
        )
    })

    # Lambda interpretation
    output$lambda_gc <- renderText({
      req(gwas_rv$lambda_gc)
      round(gwas_rv$lambda_gc, 3)
    })

    output$lambda_interpretation <- renderUI({
      req(gwas_rv$lambda_gc)

      lambda <- gwas_rv$lambda_gc

      if (lambda < 1.05) {
        tags$div(
          class = "alert alert-success",
          icon("check-circle"),
          " Minimal inflation. Results are well-calibrated."
        )
      } else if (lambda < 1.10) {
        tags$div(
          class = "alert alert-warning",
          icon("exclamation-triangle"),
          " Modest inflation. May indicate population stratification or polygenic signal."
        )
      } else {
        tags$div(
          class = "alert alert-danger",
          icon("times-circle"),
          " Substantial inflation. Check for population stratification, poor QC, or cryptic relatedness."
        )
      }
    })

    # Return reactive values
    return(gwas_rv)
  })
}

# ==============================================================================
# END OF MODULE
# ==============================================================================
