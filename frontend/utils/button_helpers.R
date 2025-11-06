# Button Helper Functions for Consistent Styling Across EvidenceOS PRIME
# Provides standardized button components with proper sizing, icons, and spacing
#
# Author: EvidenceOS PRIME
# Created: 2025-11-06

#' Primary action button (Run Analysis, Generate, Submit)
#'
#' Large, prominent button for main actions
#' Min height: 50px
#'
#' @param id Button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name (without "icon()" wrapper)
#' @return actionButton with primary styling
#' @export
primary_action_button <- function(id, label, icon_name = "play-circle") {
  actionButton(
    id,
    label,
    class = "btn-primary btn-lg w-100 mt-3 mb-2",
    icon = icon(icon_name),
    style = "min-height: 50px; font-size: 16px; font-weight: 600;"
  )
}

#' Download button (styled for exports)
#'
#' Download action button with proper sizing
#' Min height: 45px
#'
#' @param id Download button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name
#' @param type Button color theme: "success", "info", or "secondary"
#' @return downloadButton with styled appearance
#' @export
download_action_button <- function(id, label, icon_name = "download",
                                   type = c("success", "info", "secondary")) {
  type <- match.arg(type)

  downloadButton(
    id,
    label,
    class = paste0("btn-", type, " w-100 mb-3"),
    icon = icon(icon_name),
    style = "min-height: 45px; font-size: 15px;"
  )
}

#' Secondary action button (View, Filter, Options)
#'
#' Outline style button for secondary actions
#' Min height: 42px
#'
#' @param id Button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name
#' @return actionButton with outline styling
#' @export
secondary_action_button <- function(id, label, icon_name = "cog") {
  actionButton(
    id,
    label,
    class = "btn-outline-primary w-100 mb-2",
    icon = icon(icon_name),
    style = "min-height: 42px; font-size: 14px;"
  )
}

#' Tertiary/utility button (Reset, Clear, View)
#'
#' Minimal button for utility actions
#' Min height: 40px
#'
#' @param id Button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name
#' @return actionButton with secondary outline styling
#' @export
utility_action_button <- function(id, label, icon_name = "refresh") {
  actionButton(
    id,
    label,
    class = "btn-outline-secondary w-100 mb-2",
    icon = icon(icon_name),
    style = "min-height: 40px; font-size: 14px;"
  )
}

#' Danger button with confirmation (Delete, Remove, Exclude)
#'
#' Red button for destructive actions with confirmation dialog
#' Min height: 45px
#'
#' @param id Button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name
#' @param confirm_message Confirmation dialog message
#' @return actionButton with danger styling and confirmation
#' @export
danger_action_button <- function(id, label, icon_name = "trash",
                                confirm_message = "Are you sure? This action cannot be undone.") {
  actionButton(
    id,
    label,
    class = "btn-danger w-100 mb-2",
    icon = icon(icon_name),
    style = "min-height: 45px; font-size: 15px; font-weight: 600;",
    onclick = sprintf("return confirm('%s');", confirm_message)
  )
}

#' Success button (Complete, Approve, Publish)
#'
#' Green button for positive confirmation actions
#' Min height: 45px
#'
#' @param id Button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name
#' @return actionButton with success styling
#' @export
success_action_button <- function(id, label, icon_name = "check-circle") {
  actionButton(
    id,
    label,
    class = "btn-success w-100 mb-2",
    icon = icon(icon_name),
    style = "min-height: 45px; font-size: 15px; font-weight: 600;"
  )
}

#' Info button (Help, Guide, Documentation)
#'
#' Blue info button for help and documentation
#' Min height: 40px
#'
#' @param id Button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name
#' @return actionButton with info styling
#' @export
info_action_button <- function(id, label, icon_name = "circle-info") {
  actionButton(
    id,
    label,
    class = "btn-info w-100 mb-2",
    icon = icon(icon_name),
    style = "min-height: 40px; font-size: 14px;"
  )
}

#' Warning button (Caution, Review Required)
#'
#' Yellow/orange button for cautionary actions
#' Min height: 42px
#'
#' @param id Button ID
#' @param label Button label text
#' @param icon_name Font Awesome icon name
#' @return actionButton with warning styling
#' @export
warning_action_button <- function(id, label, icon_name = "exclamation-triangle") {
  actionButton(
    id,
    label,
    class = "btn-warning w-100 mb-2",
    icon = icon(icon_name),
    style = "min-height: 42px; font-size: 14px;"
  )
}

#' Button group separator
#'
#' Creates visual separation between button groups with optional title
#'
#' @param title Optional section title (default: NULL)
#' @return HTML tagList with hr and optional heading
#' @export
button_group_separator <- function(title = NULL) {
  tagList(
    hr(class = "my-3"),
    if (!is.null(title)) {
      h5(title, class = "text-muted mb-2")
    }
  )
}

#' Disabled button state wrapper
#'
#' Wraps a button in a disabled state with tooltip
#'
#' @param button Button element to disable
#' @param reason Tooltip text explaining why button is disabled
#' @return Disabled button with tooltip
#' @export
disabled_button <- function(button, reason = "Not available") {
  tags$div(
    title = reason,
    `data-toggle` = "tooltip",
    shinyjs::disabled(button)
  )
}

# Button Usage Examples
# ======================
#
# Primary Action:
#   primary_action_button("btn_run", "Run Meta-Analysis", "chart-line")
#
# Download:
#   download_action_button("download_forest", "Download Forest Plot", "file-image", "success")
#
# Secondary:
#   secondary_action_button("btn_options", "Analysis Options", "cog")
#
# Danger:
#   danger_action_button("btn_delete", "Delete Analysis", "trash", "Delete this analysis?")
#
# With Separator:
#   button_group_separator("Export Options")
#   download_action_button("download_pdf", "Download PDF", "file-pdf", "info")
#   download_action_button("download_html", "Download HTML", "file-code", "success")
