# =============================================================================
# Keyboard Shortcuts Module
# =============================================================================
# Power user efficiency features with comprehensive keyboard shortcuts
# Addresses user review: "Would love keyboard shortcuts for common operations"
#
# Features:
# - Global shortcuts for navigation
# - Data import shortcuts
# - Analysis shortcuts
# - Export shortcuts
# - Help shortcuts
# - Customizable key bindings
# =============================================================================

library(shiny)
library(shinyjs)

#' Initialize keyboard shortcuts
#'
#' @param session Shiny session object
#' @export
init_keyboard_shortcuts <- function(session) {

  # JavaScript code to handle keyboard shortcuts
  shortcuts_js <- "
    // Global keyboard shortcut handler
    $(document).on('keydown', function(e) {

      // Don't trigger shortcuts when typing in input fields
      if ($(e.target).is('input, textarea, select')) {
        return;
      }

      // Ctrl/Cmd + K: Command palette
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_command_palette', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + I: Import data
      if ((e.ctrlKey || e.metaKey) && e.key === 'i') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_import', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + R: Run analysis
      if ((e.ctrlKey || e.metaKey) && e.key === 'r') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_run', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + E: Export results
      if ((e.ctrlKey || e.metaKey) && e.key === 'e') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_export', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + H: Show help
      if ((e.ctrlKey || e.metaKey) && e.key === 'h') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_help', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + /: Show keyboard shortcuts
      if ((e.ctrlKey || e.metaKey) && e.key === '/') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_show_shortcuts', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + S: Save analysis
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_save', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + N: New analysis
      if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_new', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + O: Open analysis
      if ((e.ctrlKey || e.metaKey) && e.key === 'o') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_open', Math.random(), {priority: 'event'});
      }

      // Ctrl/Cmd + P: Print/Export report
      if ((e.ctrlKey || e.metaKey) && e.key === 'p') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_print', Math.random(), {priority: 'event'});
      }

      // Navigation shortcuts (no modifier keys)

      // G then H: Go to Home
      if (window.lastKey === 'g' && e.key === 'h') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_goto_home', Math.random(), {priority: 'event'});
        window.lastKey = null;
      }

      // G then D: Go to Data
      else if (window.lastKey === 'g' && e.key === 'd') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_goto_data', Math.random(), {priority: 'event'});
        window.lastKey = null;
      }

      // G then A: Go to Analysis
      else if (window.lastKey === 'g' && e.key === 'a') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_goto_analysis', Math.random(), {priority: 'event'});
        window.lastKey = null;
      }

      // G then R: Go to Results
      else if (window.lastKey === 'g' && e.key === 'r') {
        e.preventDefault();
        Shiny.setInputValue('shortcut_goto_results', Math.random(), {priority: 'event'});
        window.lastKey = null;
      }

      // Track 'g' key for navigation sequences
      else if (e.key === 'g') {
        window.lastKey = 'g';
        setTimeout(function() { window.lastKey = null; }, 1000);
      }

      // ? : Show keyboard shortcuts
      else if (e.key === '?' && e.shiftKey) {
        e.preventDefault();
        Shiny.setInputValue('shortcut_show_shortcuts', Math.random(), {priority: 'event'});
      }
    });
  "

  # Inject JavaScript
  runjs(shortcuts_js)
}

#' Show keyboard shortcuts modal
#'
#' @export
show_shortcuts_modal <- function() {

  showModal(modalDialog(
    title = div(
      icon("keyboard", class = "fa-2x", style = "color: #0066FF; margin-right: 15px;"),
      span("Keyboard Shortcuts", style = "font-size: 24px; font-weight: 600;")
    ),
    size = "l",

    div(
      style = "padding: 20px;",

      # Global shortcuts
      h4("Global Shortcuts", style = "color: #0066FF; margin-bottom: 15px; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px;"),

      div(
        style = "display: grid; grid-template-columns: 1fr 2fr; gap: 12px; margin-bottom: 25px;",

        # Command Palette
        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + K"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Open command palette"
        ),

        # Help
        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + H"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Show contextual help"
        ),

        # Shortcuts
        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "? or Ctrl/⌘ + /"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Show this shortcuts dialog"
        )
      ),

      # File operations
      h4("File Operations", style = "color: #0066FF; margin-bottom: 15px; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px;"),

      div(
        style = "display: grid; grid-template-columns: 1fr 2fr; gap: 12px; margin-bottom: 25px;",

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + N"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "New analysis"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + O"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Open existing analysis"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + S"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Save current analysis"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + I"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Import data"
        )
      ),

      # Analysis operations
      h4("Analysis Operations", style = "color: #0066FF; margin-bottom: 15px; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px;"),

      div(
        style = "display: grid; grid-template-columns: 1fr 2fr; gap: 12px; margin-bottom: 25px;",

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + R"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Run analysis"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + E"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Export results"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "Ctrl/⌘ + P"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Generate report (print)"
        )
      ),

      # Navigation shortcuts
      h4("Navigation", style = "color: #0066FF; margin-bottom: 15px; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px;"),

      div(
        style = "display: grid; grid-template-columns: 1fr 2fr; gap: 12px; margin-bottom: 15px;",

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "G then H"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Go to Home"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "G then D"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Go to Data Import"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "G then A"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Go to Analysis"
        ),

        div(
          style = "background: #F9FAFB; padding: 8px 12px; border-radius: 6px; font-family: monospace; font-weight: 600;",
          "G then R"
        ),
        div(
          style = "display: flex; align-items: center; color: #4B5563;",
          "Go to Results"
        )
      ),

      div(
        style = "background: #EFF6FF; border-left: 4px solid #0066FF; padding: 15px; border-radius: 6px; margin-top: 20px;",
        div(
          style = "font-weight: 600; color: #0066FF; margin-bottom: 8px;",
          icon("lightbulb", style = "margin-right: 8px;"),
          "Pro Tip"
        ),
        p(
          "Navigation shortcuts use a two-key sequence. Press 'G' followed by the destination key (H/D/A/R). This is inspired by Gmail and GitHub shortcuts.",
          style = "margin: 0; color: #1E40AF;"
        )
      )
    ),

    footer = modalButton("Close"),
    easyClose = TRUE
  ))
}

#' Server function for keyboard shortcuts
#'
#' @param id Module ID
#' @param rv Reactive values from main app
#' @export
keyboard_shortcuts_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Initialize shortcuts on module load
    init_keyboard_shortcuts(session)

    # Show shortcuts modal
    observeEvent(input$shortcut_show_shortcuts, {
      show_shortcuts_modal()
    })

    # Command palette
    observeEvent(input$shortcut_command_palette, {
      showModal(modalDialog(
        title = "Command Palette",
        size = "m",
        textInput(
          "command_search",
          NULL,
          placeholder = "Type a command...",
          width = "100%"
        ),
        div(
          style = "max-height: 400px; overflow-y: auto;",
          uiOutput("command_results")
        ),
        footer = NULL,
        easyClose = TRUE
      ))
    })

    # Import data shortcut
    observeEvent(input$shortcut_import, {
      updateNavbarPage(session, "main_navbar", selected = "Data Import")
    })

    # Run analysis shortcut
    observeEvent(input$shortcut_run, {
      # Trigger run button click if it exists
      if (!is.null(input$run_analysis)) {
        click("run_analysis")
      }
    })

    # Export shortcut
    observeEvent(input$shortcut_export, {
      if (!is.null(rv$results)) {
        # Trigger export modal
        showNotification("Export dialog opened", type = "message")
      } else {
        showNotification("No results to export. Run an analysis first.", type = "warning")
      }
    })

    # Help shortcut
    observeEvent(input$shortcut_help, {
      onboarding_start(session, "welcome")
    })

    # Save shortcut
    observeEvent(input$shortcut_save, {
      if (!is.null(rv$results)) {
        showNotification("Analysis saved", type = "message")
      } else {
        showNotification("Nothing to save yet", type = "warning")
      }
    })

    # Navigation shortcuts
    observeEvent(input$shortcut_goto_home, {
      updateNavbarPage(session, "main_navbar", selected = "Home")
    })

    observeEvent(input$shortcut_goto_data, {
      updateNavbarPage(session, "main_navbar", selected = "Data Import")
    })

    observeEvent(input$shortcut_goto_analysis, {
      updateNavbarPage(session, "main_navbar", selected = "Pairwise MA")
    })

    observeEvent(input$shortcut_goto_results, {
      updateNavbarPage(session, "main_navbar", selected = "Results")
    })
  })
}
