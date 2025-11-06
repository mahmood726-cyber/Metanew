# ==============================================================================
# THEME CUSTOMIZER MODULE
# ==============================================================================
#
# Visual theme customizer allowing users to:
# - Choose from 6 beautiful pre-built themes
# - Toggle dark mode
# - Customize colors and fonts
# - Preview changes in real-time
#
# Inspired by modern journal themes (OJS) but adapted for meta-analysis platform
#
# AUTHOR: EvidenceOS Development Team
# LAST UPDATED: 2025-11-06
# ==============================================================================
# Dependencies: shiny, bslib (loaded in app.R)

#' Theme Customizer UI
#'
#' Creates a sidebar panel with theme customization options
#'
#' @param id Module namespace ID
#' @return Shiny UI elements
theme_customizer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Theme customizer button in navbar (will be added via JS)
    tags$div(
      id = ns("theme_button_container"),
      style = "position: fixed; top: 10px; right: 10px; z-index: 9999;",
      actionButton(
        ns("open_customizer"),
        "",
        icon = icon("palette"),
        class = "btn-sm btn-light shadow-sm",
        title = "Theme Customizer",
        style = "border-radius: 50%; width: 40px; height: 40px;"
      )
    ),

    # Theme customizer panel (slides in from right)
    tags$div(
      id = ns("customizer_panel"),
      class = "theme-customizer-panel",
      style = "position: fixed; top: 0; right: -400px; width: 400px; height: 100vh;
               background: white; box-shadow: -2px 0 10px rgba(0,0,0,0.1);
               z-index: 9998; transition: right 0.3s ease; overflow-y: auto;
               border-left: 1px solid #dee2e6;",

      # Header
      tags$div(
        class = "p-3 border-bottom bg-light",
        tags$div(
          class = "d-flex justify-content-between align-items-center",
          tags$h5(
            class = "mb-0",
            icon("palette"), " Theme Customizer"
          ),
          actionButton(
            ns("close_customizer"),
            "",
            icon = icon("times"),
            class = "btn-sm btn-light",
            style = "border-radius: 50%;"
          )
        )
      ),

      # Content
      tags$div(
        class = "p-3",

        # Pre-built Themes
        tags$h6(class = "mb-3", icon("swatchbook"), " Pre-built Themes"),
        tags$div(
          class = "row g-2 mb-4",

          # Theme 1: Professional Blue (Default)
          tags$div(
            class = "col-6",
            actionButton(
              ns("theme_professional"),
              tags$div(
                style = "text-align: left;",
                tags$div(
                  class = "mb-2",
                  style = "height: 60px; border-radius: 8px; background: linear-gradient(135deg, #0066CC 0%, #004d99 100%); border: 2px solid #0066CC;"
                ),
                tags$small("Professional Blue", class = "d-block fw-bold"),
                tags$small("Clean & trustworthy", class = "text-muted d-block", style = "font-size: 0.75rem;")
              ),
              class = "w-100 btn-light text-start p-2",
              style = "height: auto;"
            )
          ),

          # Theme 2: Academic Green
          tags$div(
            class = "col-6",
            actionButton(
              ns("theme_academic"),
              tags$div(
                style = "text-align: left;",
                tags$div(
                  class = "mb-2",
                  style = "height: 60px; border-radius: 8px; background: linear-gradient(135deg, #2d6a4f 0%, #1b4332 100%); border: 2px solid #2d6a4f;"
                ),
                tags$small("Academic Green", class = "d-block fw-bold"),
                tags$small("Scholarly & focused", class = "text-muted d-block", style = "font-size: 0.75rem;")
              ),
              class = "w-100 btn-light text-start p-2",
              style = "height: auto;"
            )
          ),

          # Theme 3: Medical Red
          tags$div(
            class = "col-6",
            actionButton(
              ns("theme_medical"),
              tags$div(
                style = "text-align: left;",
                tags$div(
                  class = "mb-2",
                  style = "height: 60px; border-radius: 8px; background: linear-gradient(135deg, #c1121f 0%, #780000 100%); border: 2px solid #c1121f;"
                ),
                tags$small("Medical Red", class = "d-block fw-bold"),
                tags$small("Healthcare focus", class = "text-muted d-block", style = "font-size: 0.75rem;")
              ),
              class = "w-100 btn-light text-start p-2",
              style = "height: auto;"
            )
          ),

          # Theme 4: Modern Purple
          tags$div(
            class = "col-6",
            actionButton(
              ns("theme_modern"),
              tags$div(
                style = "text-align: left;",
                tags$div(
                  class = "mb-2",
                  style = "height: 60px; border-radius: 8px; background: linear-gradient(135deg, #7209b7 0%, #560bad 100%); border: 2px solid #7209b7;"
                ),
                tags$small("Modern Purple", class = "d-block fw-bold"),
                tags$small("Contemporary", class = "text-muted d-block", style = "font-size: 0.75rem;")
              ),
              class = "w-100 btn-light text-start p-2",
              style = "height: auto;"
            )
          ),

          # Theme 5: Minimalist Gray
          tags$div(
            class = "col-6",
            actionButton(
              ns("theme_minimalist"),
              tags$div(
                style = "text-align: left;",
                tags$div(
                  class = "mb-2",
                  style = "height: 60px; border-radius: 8px; background: linear-gradient(135deg, #495057 0%, #212529 100%); border: 2px solid #495057;"
                ),
                tags$small("Minimalist Gray", class = "d-block fw-bold"),
                tags$small("Content-focused", class = "text-muted d-block", style = "font-size: 0.75rem;")
              ),
              class = "w-100 btn-light text-start p-2",
              style = "height: auto;"
            )
          ),

          # Theme 6: Vibrant Orange
          tags$div(
            class = "col-6",
            actionButton(
              ns("theme_vibrant"),
              tags$div(
                style = "text-align: left;",
                tags$div(
                  class = "mb-2",
                  style = "height: 60px; border-radius: 8px; background: linear-gradient(135deg, #f77f00 0%, #d62828 100%); border: 2px solid #f77f00;"
                ),
                tags$small("Vibrant Orange", class = "d-block fw-bold"),
                tags$small("Bold & energetic", class = "text-muted d-block", style = "font-size: 0.75rem;")
              ),
              class = "w-100 btn-light text-start p-2",
              style = "height: auto;"
            )
          )
        ),

        tags$hr(),

        # Dark Mode Toggle
        tags$h6(class = "mb-3", icon("moon"), " Appearance"),
        tags$div(
          class = "form-check form-switch mb-4",
          tags$input(
            type = "checkbox",
            class = "form-check-input",
            id = ns("dark_mode_toggle"),
            role = "switch"
          ),
          tags$label(
            class = "form-check-label",
            `for` = ns("dark_mode_toggle"),
            "Dark Mode"
          )
        ),

        tags$hr(),

        # Typography
        tags$h6(class = "mb-3", icon("font"), " Typography"),
        selectInput(
          ns("font_pairing"),
          "Font Pairing",
          choices = c(
            "Inter (Default)" = "inter",
            "Roboto + Lora" = "roboto_lora",
            "Open Sans + Merriweather" = "opensans_merriweather",
            "Montserrat + Source Serif" = "montserrat_sourceserif",
            "Poppins + Crimson Text" = "poppins_crimson",
            "Work Sans + Spectral" = "worksans_spectral"
          ),
          selected = "inter"
        ),

        tags$hr(),

        # Custom Colors (Advanced)
        tags$h6(class = "mb-3", icon("palette"), " Custom Colors"),
        colourpicker::colourInput(
          ns("custom_primary"),
          "Primary Color",
          value = "#0066CC",
          showColour = "background",
          palette = "limited",
          allowedCols = c(
            "#0066CC", "#2d6a4f", "#c1121f", "#7209b7",
            "#495057", "#f77f00", "#0077b6", "#e63946"
          )
        ),

        tags$div(
          class = "mt-3",
          actionButton(
            ns("apply_custom"),
            "Apply Custom Theme",
            class = "btn-primary w-100",
            icon = icon("check")
          )
        ),

        tags$hr(),

        # Reset
        tags$div(
          class = "text-center",
          actionButton(
            ns("reset_theme"),
            "Reset to Default",
            class = "btn-sm btn-outline-secondary",
            icon = icon("rotate-left")
          )
        ),

        # Info
        tags$div(
          class = "alert alert-info mt-3",
          style = "font-size: 0.85rem;",
          icon("info-circle"), " Theme preferences are saved in your browser"
        )
      )
    ),

    # CSS for animations and effects
    tags$head(
      tags$style(HTML("
        /* Theme customizer animations */
        .theme-customizer-panel.open {
          right: 0 !important;
        }

        /* Smooth transitions */
        * {
          transition: background-color 0.3s ease, color 0.3s ease;
        }

        /* Glassmorphism effect for cards */
        .card {
          backdrop-filter: blur(10px);
          background: rgba(255, 255, 255, 0.95) !important;
          border: 1px solid rgba(255, 255, 255, 0.2);
        }

        /* Dark mode styles */
        body.dark-mode {
          background-color: #1a1a1a !important;
          color: #e0e0e0 !important;
        }

        body.dark-mode .card {
          background: rgba(30, 30, 30, 0.95) !important;
          border-color: rgba(255, 255, 255, 0.1);
          color: #e0e0e0;
        }

        body.dark-mode .theme-customizer-panel {
          background: #2d2d2d !important;
          color: #e0e0e0 !important;
          border-left-color: #404040 !important;
        }

        body.dark-mode .bg-light {
          background: #1f1f1f !important;
          color: #e0e0e0 !important;
        }

        /* Hover effects */
        .nav-link:hover {
          transform: translateY(-2px);
          transition: transform 0.2s ease;
        }

        /* Button hover effects */
        .btn:hover {
          transform: scale(1.02);
          box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
        }
      "))
    ),

    # JavaScript for panel toggle
    tags$script(HTML(sprintf("
      $(document).ready(function() {
        // Open customizer
        $('#%s').click(function() {
          $('#%s').addClass('open');
        });

        // Close customizer
        $('#%s').click(function() {
          $('#%s').removeClass('open');
        });
      });
    ", ns("open_customizer"), ns("customizer_panel"),
       ns("close_customizer"), ns("customizer_panel"))))
  )
}

#' Theme Customizer Server
#'
#' Handles theme switching and customization logic
#'
#' @param id Module namespace ID
#' @param session Shiny session object
theme_customizer_server <- function(id, session = getDefaultReactiveDomain()) {
  moduleServer(id, function(input, output, session) {

    # Reactive value to store current theme
    current_theme <- reactiveVal("professional")

    # Pre-built theme configurations
    themes <- list(
      professional = list(
        bootswatch = "flatly",
        primary = "#0066CC",
        font_base = "Inter",
        font_heading = "Inter"
      ),
      academic = list(
        bootswatch = "journal",
        primary = "#2d6a4f",
        font_base = "Merriweather",
        font_heading = "Lora"
      ),
      medical = list(
        bootswatch = "pulse",
        primary = "#c1121f",
        font_base = "Roboto",
        font_heading = "Roboto Slab"
      ),
      modern = list(
        bootswatch = "united",
        primary = "#7209b7",
        font_base = "Poppins",
        font_heading = "Poppins"
      ),
      minimalist = list(
        bootswatch = "minty",
        primary = "#495057",
        font_base = "Work Sans",
        font_heading = "Work Sans"
      ),
      vibrant = list(
        bootswatch = "superhero",
        primary = "#f77f00",
        font_base = "Montserrat",
        font_heading = "Montserrat"
      )
    )

    # Function to apply theme
    apply_theme <- function(theme_name) {
      theme_config <- themes[[theme_name]]
      current_theme(theme_name)

      # Update bslib theme
      session$sendCustomMessage("update_theme", list(
        bootswatch = theme_config$bootswatch,
        primary = theme_config$primary,
        font_base = theme_config$font_base
      ))

      showNotification(
        paste("✓ Applied", tools::toTitleCase(theme_name), "theme"),
        type = "message",
        duration = 2
      )
    }

    # Theme button observers
    observeEvent(input$theme_professional, { apply_theme("professional") })
    observeEvent(input$theme_academic, { apply_theme("academic") })
    observeEvent(input$theme_medical, { apply_theme("medical") })
    observeEvent(input$theme_modern, { apply_theme("modern") })
    observeEvent(input$theme_minimalist, { apply_theme("minimalist") })
    observeEvent(input$theme_vibrant, { apply_theme("vibrant") })

    # Dark mode toggle
    observeEvent(input$dark_mode_toggle, {
      session$sendCustomMessage("toggle_dark_mode", list(enabled = input$dark_mode_toggle))

      if (input$dark_mode_toggle) {
        showNotification("🌙 Dark mode enabled", type = "message", duration = 2)
      } else {
        showNotification("☀️ Light mode enabled", type = "message", duration = 2)
      }
    })

    # Font pairing change
    observeEvent(input$font_pairing, {
      session$sendCustomMessage("update_fonts", list(pairing = input$font_pairing))
      showNotification("✓ Font updated", type = "message", duration = 2)
    })

    # Custom color apply
    observeEvent(input$apply_custom, {
      session$sendCustomMessage("update_theme", list(
        primary = input$custom_primary,
        custom = TRUE
      ))
      showNotification("✓ Custom theme applied", type = "message", duration = 2)
    })

    # Reset to default
    observeEvent(input$reset_theme, {
      apply_theme("professional")
      updateCheckboxInput(session, "dark_mode_toggle", value = FALSE)
      updateSelectInput(session, "font_pairing", selected = "inter")
      session$sendCustomMessage("toggle_dark_mode", list(enabled = FALSE))
    })

    return(reactive({ current_theme() }))
  })
}
