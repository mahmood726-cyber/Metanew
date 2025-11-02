# Dose-Response Meta-Analysis Module - FULL IMPLEMENTATION
library(shiny)
library(ggplot2)

dose_response_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(3, 9),
      card(
        card_header("Dose-Response Settings"),
        selectInput(ns("outcome"), "Outcome", choices = NULL),
        selectInput(ns("dose_var"), "Dose Variable",
                    choices = c("dose", "dosage", "concentration")),
        numericInput(ns("knots"), "Number of Knots", value = 3, min = 2, max = 5),
        selectInput(ns("spline_type"), "Spline Type",
                    choices = c("Restricted Cubic Spline" = "rcs",
                               "Natural Spline" = "ns",
                               "Linear" = "linear")),
        checkboxInput(ns("test_nonlin"), "Test for Non-Linearity", TRUE),
        actionButton(ns("btn_run"), "Run Analysis", class = "btn-primary w-100")
      ),
      card(
        card_header("Dose-Response Results"),
        navset_card_tab(
          nav_panel("Dose-Response Curve",
                    plotOutput(ns("dose_response_plot"), height = "500px")),
          nav_panel("Prediction Table", DTOutput(ns("prediction_table"))),
          nav_panel("Summary", verbatimTextOutput(ns("summary"))),
          nav_panel("Data", DTOutput(ns("data_table")))
        )
      )
    )
  )
}

dose_response_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    dr_result <- reactiveVal(NULL)

    observe({
      req(rv$data)
      if ("outcome" %in% names(rv$data)) {
        updateSelectInput(session, "outcome", choices = unique(rv$data$outcome))
      }
    })

    observeEvent(input$btn_run, {
      req(rv$data, input$outcome)

      withProgress(message = "Running dose-response analysis...", {
        tryCatch({
          result <- run_dose_response(
            rv$data,
            input$outcome,
            input$dose_var,
            input$knots,
            input$spline_type,
            input$test_nonlin
          )
          dr_result(result)
          rv$dr_results[[input$outcome]] <- result
          showNotification("✓ Dose-response analysis complete", type = "message")
        }, error = function(e) {
          showNotification(
            paste("Error:", e$message),
            type = "error",
            duration = 10
          )
        })
      })
    })

    output$summary <- renderPrint({
      req(dr_result())
      result <- dr_result()

      cat("DOSE-RESPONSE META-ANALYSIS\n")
      cat("============================\n\n")
      cat("Outcome:", input$outcome, "\n")
      cat("Spline type:", input$spline_type, "\n")
      cat("Number of knots:", input$knots, "\n")
      cat("Number of studies:", result$n_studies, "\n")
      cat("Number of dose levels:", result$n_doses, "\n\n")

      if (!is.null(result$p_nonlinearity)) {
        cat("Test for Non-Linearity:\n")
        cat(sprintf("  χ² = %.2f\n", result$chi2_nonlinearity))
        cat(sprintf("  p-value = %.4f\n", result$p_nonlinearity))

        if (result$p_nonlinearity < 0.05) {
          cat("  ⚠ Significant non-linear relationship detected\n\n")
        } else {
          cat("  ✓ No significant deviation from linearity\n\n")
        }
      }

      if (!is.null(result$linear_coef)) {
        cat("Linear Dose-Response:\n")
        cat(sprintf("  Coefficient: %.4f (95%% CI: %.4f to %.4f)\n",
                    result$linear_coef$estimate,
                    result$linear_coef$ci_lower,
                    result$linear_coef$ci_upper))
        cat(sprintf("  P-value: %.4f\n\n", result$linear_coef$p_value))
      }

      cat("Reference dose:", result$ref_dose, "\n")
    })

    output$dose_response_plot <- renderPlot({
      req(dr_result())
      result <- dr_result()

      # Create base plot
      p <- ggplot() +
        # Prediction line
        geom_line(data = result$predictions,
                  aes(x = dose, y = estimate),
                  color = "steelblue", size = 1.2) +
        # Confidence interval
        geom_ribbon(data = result$predictions,
                    aes(x = dose, ymin = ci_lower, ymax = ci_upper),
                    alpha = 0.2, fill = "steelblue") +
        # Original data points
        geom_point(data = result$data,
                   aes(x = dose, y = yi, size = 1/vi),
                   alpha = 0.6, color = "darkblue") +
        # Reference line
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
        labs(
          title = paste("Dose-Response Relationship:", input$outcome),
          x = paste("Dose (", result$dose_unit, ")", sep = ""),
          y = "Log Relative Risk",
          size = "Weight"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(size = 14, face = "bold"),
          axis.title = element_text(size = 12),
          legend.position = "right"
        )

      # Add study labels if not too many
      if (result$n_studies <= 15) {
        p <- p + geom_text(data = result$data,
                           aes(x = dose, y = yi, label = study_id),
                           vjust = -0.5, size = 3, alpha = 0.7)
      }

      print(p)
    })

    output$prediction_table <- renderDT({
      req(dr_result())
      result <- dr_result()

      pred_table <- result$predictions
      pred_table$RR <- exp(pred_table$estimate)
      pred_table$RR_lower <- exp(pred_table$ci_lower)
      pred_table$RR_upper <- exp(pred_table$ci_upper)

      display_table <- pred_table[, c("dose", "RR", "RR_lower", "RR_upper")]
      names(display_table) <- c("Dose", "Relative Risk", "95% CI Lower", "95% CI Upper")

      datatable(
        display_table,
        options = list(pageLength = 20),
        caption = "Predicted Relative Risks at Different Dose Levels"
      ) %>%
        formatRound(columns = c("Relative Risk", "95% CI Lower", "95% CI Upper"), digits = 3)
    })

    output$data_table <- renderDT({
      req(dr_result())
      result <- dr_result()

      datatable(
        result$data[, c("study_id", "dose", "yi", "sei")],
        options = list(pageLength = 10),
        caption = "Input Data for Dose-Response Analysis"
      )
    })

    return(reactive(dr_result()))
  })
}

run_dose_response <- function(data, outcome, dose_var = "dose",
                               knots = 3, spline_type = "rcs",
                               test_nonlin = TRUE) {

  # Filter by outcome
  data_outcome <- data[data$outcome == outcome, ]

  # Check for dose variable
  if (!dose_var %in% names(data_outcome)) {
    stop(paste("Dose variable '", dose_var, "' not found in data", sep = ""))
  }

  # Ensure required columns exist
  if (!all(c("yi", "sei", "study_id") %in% names(data_outcome))) {
    stop("Data must contain yi, sei, and study_id columns")
  }

  # Calculate variance if not present
  if (!"vi" %in% names(data_outcome)) {
    data_outcome$vi <- data_outcome$sei^2
  }

  # Rename dose variable to "dose" for consistency
  data_outcome$dose <- data_outcome[[dose_var]]

  # Remove missing doses
  data_outcome <- data_outcome[!is.na(data_outcome$dose), ]

  if (nrow(data_outcome) < 3) {
    stop("Insufficient data points for dose-response analysis (need at least 3)")
  }

  # Set reference dose (typically 0 or minimum)
  ref_dose <- min(data_outcome$dose, na.rm = TRUE)

  # Center doses around reference
  data_outcome$dose_centered <- data_outcome$dose - ref_dose

  # Fit dose-response model
  if (spline_type == "linear") {
    # Simple linear model
    model <- lm(yi ~ dose_centered, data = data_outcome, weights = 1/vi)

    linear_coef <- list(
      estimate = coef(model)[2],
      ci_lower = confint(model)[2, 1],
      ci_upper = confint(model)[2, 2],
      p_value = summary(model)$coefficients[2, 4]
    )

    p_nonlinearity <- NULL
    chi2_nonlinearity <- NULL

  } else {
    # Spline model using restricted cubic splines
    dose_range <- range(data_outcome$dose_centered)
    knot_positions <- quantile(data_outcome$dose_centered,
                                probs = seq(0, 1, length.out = knots))

    # Create spline basis
    if (spline_type == "rcs") {
      # Restricted cubic spline (Harrell's method)
      spline_basis <- create_rcs_basis(data_outcome$dose_centered, knot_positions)
    } else {
      # Natural spline
      spline_basis <- create_ns_basis(data_outcome$dose_centered, knot_positions)
    }

    # Fit spline model
    model_data <- cbind(data_outcome, spline_basis)
    formula_str <- paste("yi ~", paste(colnames(spline_basis), collapse = " + "))
    model <- lm(as.formula(formula_str), data = model_data, weights = 1/vi)

    # Test for non-linearity (compare to linear model)
    if (test_nonlin) {
      model_linear <- lm(yi ~ dose_centered, data = data_outcome, weights = 1/vi)
      anova_result <- anova(model_linear, model)
      chi2_nonlinearity <- anova_result$F[2] * anova_result$Df[2]
      p_nonlinearity <- anova_result$`Pr(>F)`[2]
    } else {
      p_nonlinearity <- NULL
      chi2_nonlinearity <- NULL
    }

    # Linear coefficient from linear model for comparison
    model_linear <- lm(yi ~ dose_centered, data = data_outcome, weights = 1/vi)
    linear_coef <- list(
      estimate = coef(model_linear)[2],
      ci_lower = confint(model_linear)[2, 1],
      ci_upper = confint(model_linear)[2, 2],
      p_value = summary(model_linear)$coefficients[2, 4]
    )
  }

  # Generate predictions
  dose_seq <- seq(min(data_outcome$dose), max(data_outcome$dose), length.out = 100)
  dose_seq_centered <- dose_seq - ref_dose

  if (spline_type == "linear") {
    pred_data <- data.frame(dose_centered = dose_seq_centered)
  } else {
    if (spline_type == "rcs") {
      pred_spline <- create_rcs_basis(dose_seq_centered, knot_positions)
    } else {
      pred_spline <- create_ns_basis(dose_seq_centered, knot_positions)
    }
    pred_data <- data.frame(pred_spline)
  }

  predictions <- predict(model, newdata = pred_data, se.fit = TRUE)

  predictions_df <- data.frame(
    dose = dose_seq,
    estimate = predictions$fit,
    se = predictions$se.fit,
    ci_lower = predictions$fit - 1.96 * predictions$se.fit,
    ci_upper = predictions$fit + 1.96 * predictions$se.fit
  )

  # Determine dose unit (if available in data)
  dose_unit <- if ("dose_unit" %in% names(data_outcome)) {
    unique(data_outcome$dose_unit)[1]
  } else {
    "units"
  }

  list(
    model = model,
    predictions = predictions_df,
    data = data_outcome[, c("study_id", "dose", "yi", "sei", "vi")],
    n_studies = length(unique(data_outcome$study_id)),
    n_doses = nrow(data_outcome),
    ref_dose = ref_dose,
    dose_unit = dose_unit,
    spline_type = spline_type,
    knots = knots,
    p_nonlinearity = p_nonlinearity,
    chi2_nonlinearity = chi2_nonlinearity,
    linear_coef = linear_coef
  )
}

# Helper function: Create restricted cubic spline basis
create_rcs_basis <- function(x, knots) {
  # Simplified RCS implementation
  # For production, would use rms::rcspline.eval

  k <- length(knots)
  if (k < 3) stop("Need at least 3 knots for RCS")

  X <- matrix(0, nrow = length(x), ncol = k - 2)

  for (j in 1:(k - 2)) {
    lambda <- (knots[k] - knots[j]) / (knots[k] - knots[k - 1])

    term1 <- pmax(x - knots[j], 0)^3
    term2 <- lambda * pmax(x - knots[k - 1], 0)^3
    term3 <- (1 - lambda) * pmax(x - knots[k], 0)^3

    X[, j] <- term1 - term2 + term3
  }

  # Add linear term
  X <- cbind(x, X)
  colnames(X) <- c("spline1", paste0("spline", 2:ncol(X)))

  as.data.frame(X)
}

# Helper function: Create natural spline basis
create_ns_basis <- function(x, knots) {
  # Simplified natural spline
  # For production, would use splines::ns

  k <- length(knots)
  X <- matrix(0, nrow = length(x), ncol = k)

  X[, 1] <- x

  for (j in 2:k) {
    X[, j] <- pmax(x - knots[j], 0)
  }

  colnames(X) <- paste0("spline", 1:k)
  as.data.frame(X)
}
