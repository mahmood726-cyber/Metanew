# Plotting Utilities - PRODUCTION QUALITY
library(plotly)
library(ggplot2)
library(grid)
library(gridExtra)

# Publication-quality forest plot with weights
create_forest_plot <- function(ma_result, outcome_name = "Outcome", save_path = NULL) {

  data <- ma_result$data
  data$ci_lower <- data$yi - 1.96 * data$sei
  data$ci_upper <- data$yi + 1.96 * data$sei

  # Calculate weights (inverse variance)
  data$weight <- 1 / data$vi
  data$weight_pct <- 100 * data$weight / sum(data$weight)

  # Sort by year if available, otherwise by effect size
  if ("year" %in% names(data)) {
    data <- data[order(data$year, data$study_id), ]
  } else {
    data <- data[order(data$yi), ]
  }
  data$study_order <- 1:nrow(data)

  # Create study labels with author and year
  data$study_label <- if ("author" %in% names(data) && "year" %in% names(data)) {
    paste0(data$author, " (", data$year, ")")
  } else {
    data$study_id
  }

  # Calculate box sizes for weights (scale to reasonable plotly sizes)
  data$box_size <- sqrt(data$weight_pct) * 3 + 5

  # Create interactive forest plot
  p <- plot_ly()

  # Add confidence intervals - OPTIMIZED: Vectorized instead of loop
  p <- p %>%
    add_segments(
      data = data,
      x = ~ci_lower, xend = ~ci_upper,
      y = ~study_order, yend = ~study_order,
      line = list(color = 'steelblue', width = 2),
      showlegend = FALSE,
      hoverinfo = "none"
    )

  # Add point estimates (box size proportional to weight)
  p <- p %>%
    add_markers(
      data = data,
      x = ~yi, y = ~study_order,
      marker = list(
        color = 'steelblue',
        size = ~box_size,
        symbol = 'square',
        line = list(color = 'darkblue', width = 1)
      ),
      text = ~paste0(
        "<b>", study_label, "</b><br>",
        "Effect: ", round(yi, 3), " (", round(ci_lower, 3), " to ", round(ci_upper, 3), ")<br>",
        "Weight: ", round(weight_pct, 1), "%<br>",
        "SE: ", round(sei, 3)
      ),
      hovertemplate = '%{text}<extra></extra>',
      showlegend = FALSE
    )

  # Add pooled estimate diamond
  diamond_y <- 0
  diamond_x <- ma_result$pooled_effect
  diamond_width <- ma_result$ci_upper - ma_result$ci_lower

  p <- p %>%
    add_trace(
      type = "scatter",
      x = c(ma_result$ci_lower, diamond_x, ma_result$ci_upper, diamond_x, ma_result$ci_lower),
      y = c(diamond_y, diamond_y + 0.3, diamond_y, diamond_y - 0.3, diamond_y),
      fill = "toself",
      fillcolor = 'rgba(255, 0, 0, 0.3)',
      line = list(color = 'red', width = 2),
      text = paste0(
        "<b>Pooled Effect (Random Effects)</b><br>",
        "Effect: ", round(ma_result$pooled_effect, 3),
        " (", round(ma_result$ci_lower, 3), " to ", round(ma_result$ci_upper, 3), ")<br>",
        "p = ", format.pval(ma_result$p_value, digits = 3), "<br>",
        "I² = ", round(ma_result$i_squared, 1), "%<br>",
        "τ² = ", round(ma_result$tau_squared, 3)
      ),
      hovertemplate = '%{text}<extra></extra>',
      showlegend = FALSE
    )

  # Add null line
  p <- p %>%
    add_segments(
      x = 0, xend = 0,
      y = -0.5, yend = nrow(data) + 0.5,
      line = list(color = 'gray', width = 1, dash = 'dash'),
      showlegend = FALSE,
      hoverinfo = "none"
    )

  # Layout
  p <- p %>%
    layout(
      title = list(
        text = paste("<b>Forest Plot:", outcome_name, "</b>"),
        font = list(size = 16)
      ),
      xaxis = list(
        title = "Effect Size (95% CI)",
        titlefont = list(size = 14),
        zeroline = FALSE,
        showgrid = TRUE,
        gridcolor = 'rgba(0,0,0,0.1)'
      ),
      yaxis = list(
        title = "",
        ticktext = c("Pooled", data$study_label),
        tickvals = c(0, data$study_order),
        showgrid = FALSE,
        zeroline = FALSE
      ),
      hovermode = 'closest',
      margin = list(l = 200, r = 50, t = 80, b = 50),
      annotations = list(
        list(
          x = 1, y = -0.1,
          xref = "paper", yref = "paper",
          text = paste0("Heterogeneity: I² = ", round(ma_result$i_squared, 1),
                       "%, τ² = ", round(ma_result$tau_squared, 3),
                       ", p ", ifelse(ma_result$q_p_value < 0.001, "< 0.001",
                                     paste("=", round(ma_result$q_p_value, 3)))),
          showarrow = FALSE,
          xanchor = "right",
          font = list(size = 10, color = "gray")
        )
      )
    )

  # Save if path provided
  if (!is.null(save_path)) {
    # For high-res export, use ggplot2 version
    save_forest_plot_static(ma_result, outcome_name, save_path)
  }

  return(p)
}

# Static forest plot for export (ggplot2 version)
save_forest_plot_static <- function(ma_result, outcome_name, save_path) {

  data <- ma_result$data
  data$ci_lower <- data$yi - 1.96 * data$sei
  data$ci_upper <- data$yi + 1.96 * data$sei
  data$weight <- 1 / data$vi
  data$weight_pct <- 100 * data$weight / sum(data$weight)

  if ("year" %in% names(data)) {
    data <- data[order(data$year, data$study_id), ]
  } else {
    data <- data[order(data$yi), ]
  }
  data$study_order <- 1:nrow(data)

  data$study_label <- if ("author" %in% names(data) && "year" %in% names(data)) {
    paste0(data$author, " (", data$year, ")")
  } else {
    data$study_id
  }

  # Add pooled row
  pooled_row <- data.frame(
    study_label = "Pooled (RE Model)",
    yi = ma_result$pooled_effect,
    ci_lower = ma_result$ci_lower,
    ci_upper = ma_result$ci_upper,
    weight_pct = 100,
    study_order = 0,
    stringsAsFactors = FALSE
  )

  plot_data <- rbind(
    data[, c("study_label", "yi", "ci_lower", "ci_upper", "weight_pct", "study_order")],
    pooled_row
  )

  p <- ggplot(plot_data, aes(y = study_order, x = yi)) +
    # CI lines
    geom_segment(aes(x = ci_lower, xend = ci_upper, yend = study_order),
                 color = "steelblue", size = 0.5) +
    # Point estimates (size by weight)
    geom_point(data = plot_data[plot_data$study_order > 0, ],
               aes(size = weight_pct), shape = 15, color = "steelblue") +
    # Pooled diamond
    geom_polygon(data = data.frame(
      x = c(pooled_row$ci_lower, pooled_row$yi, pooled_row$ci_upper, pooled_row$yi),
      y = c(0, 0.3, 0, -0.3)
    ), aes(x = x, y = y), fill = "red", alpha = 0.5, color = "darkred", size = 0.8) +
    # Null line
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    # Labels
    scale_y_continuous(
      breaks = plot_data$study_order,
      labels = plot_data$study_label,
      expand = c(0.02, 0.02)
    ) +
    scale_size_continuous(range = c(2, 6), guide = "none") +
    labs(
      title = paste("Forest Plot:", outcome_name),
      subtitle = sprintf("I² = %.1f%%, τ² = %.3f, p %s",
                        ma_result$i_squared, ma_result$tau_squared,
                        ifelse(ma_result$q_p_value < 0.001, "< 0.001",
                              paste("=", round(ma_result$q_p_value, 3)))),
      x = "Effect Size (95% CI)",
      y = NULL
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 10, color = "gray40"),
      axis.text.y = element_text(hjust = 1),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )

  ggsave(save_path, p, width = 10, height = max(6, nrow(data) * 0.3), dpi = 300)

  return(p)
}

# Enhanced funnel plot with trim-and-fill
create_funnel_plot <- function(ma_result, show_trim_fill = TRUE) {

  data <- ma_result$data

  # Create funnel plot
  p <- plot_ly()

  # Add studies
  p <- p %>%
    add_markers(
      data = data,
      x = ~yi, y = ~sei,
      marker = list(color = 'steelblue', size = 10, opacity = 0.7),
      text = ~paste0(
        "<b>", study_id, "</b><br>",
        "Effect: ", round(yi, 3), "<br>",
        "SE: ", round(sei, 3)
      ),
      hovertemplate = '%{text}<extra></extra>',
      name = "Studies",
      showlegend = TRUE
    )

  # Add pooled estimate line
  p <- p %>%
    add_segments(
      x = ma_result$pooled_effect, xend = ma_result$pooled_effect,
      y = 0, yend = max(data$sei) * 1.1,
      line = list(color = 'red', width = 2, dash = 'solid'),
      name = "Pooled Effect",
      showlegend = TRUE
    )

  # Add funnel (pseudo-confidence limits)
  max_se <- max(data$sei) * 1.1
  se_seq <- seq(0, max_se, length.out = 50)

  # 95% CI funnel
  ci_lower <- ma_result$pooled_effect - 1.96 * se_seq
  ci_upper <- ma_result$pooled_effect + 1.96 * se_seq

  p <- p %>%
    add_trace(
      x = c(ci_lower, rev(ci_upper)),
      y = c(se_seq, rev(se_seq)),
      type = "scatter",
      mode = "lines",
      fill = "toself",
      fillcolor = 'rgba(200, 200, 200, 0.2)',
      line = list(color = 'gray', width = 1, dash = 'dash'),
      name = "95% CI",
      showlegend = TRUE,
      hoverinfo = "none"
    )

  # Trim-and-fill if requested and enough studies
  if (show_trim_fill && nrow(data) >= 3 && !is.null(ma_result$trim_fill)) {
    tf <- ma_result$trim_fill
    if (!is.null(tf$filled_studies)) {
      p <- p %>%
        add_markers(
          data = tf$filled_studies,
          x = ~yi, y = ~sei,
          marker = list(color = 'orange', size = 10, opacity = 0.7, symbol = 'diamond'),
          text = ~paste0(
            "<b>Imputed Study</b><br>",
            "Effect: ", round(yi, 3), "<br>",
            "SE: ", round(sei, 3)
          ),
          hovertemplate = '%{text}<extra></extra>',
          name = "Trim & Fill",
          showlegend = TRUE
        )
    }
  }

  p <- p %>%
    layout(
      title = list(text = "<b>Funnel Plot</b>", font = list(size = 16)),
      xaxis = list(
        title = "Effect Size",
        zeroline = TRUE,
        zerolinewidth = 1,
        zerolinecolor = 'gray'
      ),
      yaxis = list(
        title = "Standard Error",
        autorange = "reversed",
        zeroline = FALSE
      ),
      hovermode = 'closest',
      legend = list(x = 0.02, y = 0.98)
    )

  # Add Egger test annotation if available
  if (!is.null(ma_result$egger_test)) {
    egger <- ma_result$egger_test
    p <- p %>%
      layout(
        annotations = list(
          list(
            x = 0.98, y = 0.02,
            xref = "paper", yref = "paper",
            text = paste0("Egger's test: p ",
                         ifelse(egger$p_value < 0.001, "< 0.001",
                               paste("=", round(egger$p_value, 3)))),
            showarrow = FALSE,
            xanchor = "right",
            yanchor = "bottom",
            font = list(size = 10, color = ifelse(egger$p_value < 0.05, "red", "gray"))
          )
        )
      )
  }

  return(p)
}

# Save plot to file
save_plot <- function(plot_obj, filename, width = 10, height = 6, dpi = 300) {
  if (inherits(plot_obj, "plotly")) {
    # Save plotly as HTML or use orca for static
    htmlwidgets::saveWidget(plot_obj, filename)
  } else if (inherits(plot_obj, "gg")) {
    # Save ggplot2
    ggsave(filename, plot_obj, width = width, height = height, dpi = dpi)
  } else {
    # Base plot - use png device
    png(filename, width = width * dpi, height = height * dpi, res = dpi)
    print(plot_obj)
    dev.off()
  }

  return(filename)
}

# Create all plots for a meta-analysis
create_all_ma_plots <- function(ma_result, outcome_name, output_dir = "outputs/plots") {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  base_name <- paste0(gsub(" ", "_", outcome_name), "_", timestamp)

  # Forest plot
  forest_file <- file.path(output_dir, paste0(base_name, "_forest.png"))
  forest_plot <- create_forest_plot(ma_result, outcome_name, save_path = forest_file)

  # Funnel plot
  funnel_plot <- create_funnel_plot(ma_result, show_trim_fill = TRUE)
  funnel_file <- file.path(output_dir, paste0(base_name, "_funnel.html"))
  htmlwidgets::saveWidget(funnel_plot, funnel_file)

  list(
    forest_plot = forest_plot,
    forest_file = forest_file,
    funnel_plot = funnel_plot,
    funnel_file = funnel_file
  )
}

# Wrapper functions for consistent API with reporting module

#' Save forest plot to file
#'
#' @param ma_result Meta-analysis result object
#' @param outcome_name Name of the outcome
#' @param save_path Path to save the plot
#' @param width Plot width in inches (default: 10)
#' @param height Plot height in inches (default: 8)
#' @return ggplot object
save_forest_plot <- function(ma_result, outcome_name, save_path,
                             width = 10, height = 8) {
  # Use the static version for saving
  save_forest_plot_static(ma_result, outcome_name, save_path)
}

#' Save funnel plot to file
#'
#' @param ma_result Meta-analysis result object
#' @param outcome_name Name of the outcome
#' @param save_path Path to save the plot (must end in .png)
#' @param width Plot width in inches (default: 8)
#' @param height Plot height in inches (default: 8)
#' @return ggplot object
save_funnel_plot <- function(ma_result, outcome_name, save_path,
                             width = 8, height = 8) {

  data <- ma_result$data

  # Create static funnel plot using ggplot2 (for PNG export)
  p <- ggplot(data, aes(x = yi, y = sei)) +
    geom_point(color = "steelblue", size = 3, alpha = 0.6) +
    geom_vline(xintercept = ma_result$pooled_effect,
               linetype = "dashed", color = "red", size = 1) +
    # Add funnel (pseudo confidence interval)
    geom_abline(intercept = 0, slope = 1.96, linetype = "dotted", color = "gray50") +
    geom_abline(intercept = 0, slope = -1.96, linetype = "dotted", color = "gray50") +
    scale_y_reverse() +
    labs(
      title = paste("Funnel Plot:", outcome_name),
      subtitle = if (!is.null(ma_result$egger_test)) {
        sprintf("Egger's test: p = %.3f", ma_result$egger_test$p_value)
      } else {
        "Funnel plot for publication bias assessment"
      },
      x = "Effect Size",
      y = "Standard Error"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 10, color = "gray40")
    )

  # Save the plot
  ggsave(save_path, p, width = width, height = height, dpi = 300)

  return(p)
}
