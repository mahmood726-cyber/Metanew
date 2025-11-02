# Plotting Utilities
library(plotly)
library(ggplot2)

# Forest plot
create_forest_plot <- function(ma_result, outcome_name = "Outcome") {
  req(ma_result$data)

  data <- ma_result$data
  data$ci_lower <- data$yi - 1.96 * data$sei
  data$ci_upper <- data$yi + 1.96 * data$sei

  # Sort by effect size
  data <- data[order(data$yi), ]
  data$study_order <- 1:nrow(data)

  # Create plot
  p <- plot_ly() %>%
    add_segments(
      data = data,
      x = ~ci_lower, xend = ~ci_upper,
      y = ~study_order, yend = ~study_order,
      line = list(color = 'steelblue', width = 2),
      showlegend = FALSE
    ) %>%
    add_markers(
      data = data,
      x = ~yi, y = ~study_order,
      marker = list(color = 'steelblue', size = 8),
      text = ~study_id,
      hovertemplate = paste(
        '<b>%{text}</b><br>',
        'Effect: %{x:.3f}<br>',
        '<extra></extra>'
      ),
      showlegend = FALSE
    ) %>%
    # Add pooled estimate
    add_segments(
      x = ma_result$ci_lower, xend = ma_result$ci_upper,
      y = 0, yend = 0,
      line = list(color = 'red', width = 4),
      showlegend = FALSE
    ) %>%
    add_markers(
      x = ma_result$pooled_effect, y = 0,
      marker = list(color = 'red', size = 12, symbol = 'diamond'),
      name = 'Pooled',
      hovertemplate = paste(
        '<b>Pooled Effect</b><br>',
        'Effect: %{x:.3f}<br>',
        '<extra></extra>'
      )
    ) %>%
    # Add null line
    add_segments(
      x = 0, xend = 0,
      y = -0.5, yend = nrow(data) + 0.5,
      line = list(color = 'gray', width = 1, dash = 'dash'),
      showlegend = FALSE
    ) %>%
    layout(
      title = paste("Forest Plot:", outcome_name),
      xaxis = list(title = "Effect Size"),
      yaxis = list(
        title = "",
        ticktext = c("Pooled", data$study_id),
        tickvals = c(0, data$study_order),
        showgrid = FALSE
      ),
      hovermode = 'closest'
    )

  return(p)
}

# Funnel plot
create_funnel_plot <- function(ma_result) {
  data <- ma_result$data

  # Create funnel plot
  p <- plot_ly() %>%
    add_markers(
      data = data,
      x = ~yi, y = ~sei,
      marker = list(color = 'steelblue', size = 8),
      text = ~study_id,
      hovertemplate = paste(
        '<b>%{text}</b><br>',
        'Effect: %{x:.3f}<br>',
        'SE: %{y:.3f}<br>',
        '<extra></extra>'
      )
    ) %>%
    # Add pooled estimate line
    add_segments(
      x = ma_result$pooled_effect, xend = ma_result$pooled_effect,
      y = 0, yend = max(data$sei) * 1.1,
      line = list(color = 'red', width = 2, dash = 'dash')
    ) %>%
    layout(
      title = "Funnel Plot",
      xaxis = list(title = "Effect Size"),
      yaxis = list(title = "Standard Error", autorange = "reversed"),
      hovermode = 'closest'
    )

  return(p)
}

# Network plot for NMA
create_network_plot <- function(nma_data) {
  # Placeholder for network visualization
  # In production, would create interactive network graph
  plot(1, type = "n", xlab = "", ylab = "", main = "Network Plot")
  text(1, 1, "Network plot placeholder")
}

# Dose-response curve
create_dose_response_plot <- function(dr_result) {
  # Placeholder for dose-response visualization
  plot(1, type = "n", xlab = "Dose", ylab = "Effect", main = "Dose-Response Curve")
  text(1, 1, "Dose-response plot placeholder")
}
