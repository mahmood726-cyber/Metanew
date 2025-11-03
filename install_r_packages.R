#!/usr/bin/env Rscript
# ============================================================================
# EvidenceOS PRIME - R Package Installation Script
# ============================================================================
# This script installs all required R packages for the Shiny frontend
# Run this script once before launching the application
#
# Usage:
#   Rscript install_r_packages.R
#   or from R console: source("install_r_packages.R")
# ============================================================================

cat("\n")
cat("========================================================================\n")
cat("  EvidenceOS PRIME - R Package Installation\n")
cat("========================================================================\n")
cat("\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# ============================================================================
# Helper Functions
# ============================================================================

#' Install a package if not already installed
install_if_missing <- function(pkg, source = "CRAN", version = NULL) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("Installing %s from %s...\n", pkg, source))
    if (source == "CRAN") {
      install.packages(pkg, dependencies = TRUE)
    } else if (source == "GitHub") {
      if (!requireNamespace("remotes", quietly = TRUE)) {
        install.packages("remotes")
      }
      remotes::install_github(pkg)
    } else if (source == "Bioconductor") {
      if (!requireNamespace("BiocManager", quietly = TRUE)) {
        install.packages("BiocManager")
      }
      BiocManager::install(pkg)
    }
    cat(sprintf("✓ %s installed successfully\n", pkg))
  } else {
    cat(sprintf("✓ %s already installed\n", pkg))
  }
}

#' Check if package is available (for optional packages)
check_availability <- function(pkg) {
  available <- nchar(system(sprintf("Rscript -e 'packageDescription(\"%s\")' 2>&1 | grep -c 'Warning'", pkg), intern = TRUE)) == 0
  return(available)
}

# ============================================================================
# Core Shiny & UI Packages (REQUIRED)
# ============================================================================
cat("\n--- Core Shiny & UI Packages ---\n")

core_packages <- c(
  "shiny",           # Web application framework
  "bslib",           # Bootstrap 5 theming
  "bsicons",         # Bootstrap icons
  "DT",              # Interactive data tables
  "shinyjs",         # JavaScript operations
  "shinyWidgets",    # Extended input widgets
  "shinycssloaders", # Loading animations
  "fresh"            # Custom themes
)

for (pkg in core_packages) {
  install_if_missing(pkg)
}

# ============================================================================
# Data Processing & Manipulation (REQUIRED)
# ============================================================================
cat("\n--- Data Processing & Manipulation ---\n")

data_packages <- c(
  "dplyr",           # Data manipulation
  "tidyr",           # Data tidying
  "purrr",           # Functional programming
  "readr",           # Reading data files
  "readxl",          # Excel file reading
  "haven",           # SPSS/Stata file reading
  "jsonlite",        # JSON processing
  "data.table"       # Fast data manipulation
)

for (pkg in data_packages) {
  install_if_missing(pkg)
}

# ============================================================================
# Meta-Analysis Core Packages (REQUIRED)
# ============================================================================
cat("\n--- Meta-Analysis Core Packages ---\n")

meta_packages <- c(
  "meta",            # Standard meta-analysis
  "metafor",         # Comprehensive meta-analysis
  "netmeta"          # Network meta-analysis
)

for (pkg in meta_packages) {
  install_if_missing(pkg)
}

# ============================================================================
# Visualization & Plotting (REQUIRED)
# ============================================================================
cat("\n--- Visualization & Plotting ---\n")

viz_packages <- c(
  "ggplot2",         # Grammar of graphics
  "plotly",          # Interactive plots
  "scales",          # Scale functions for ggplot2
  "RColorBrewer",    # Color palettes
  "viridis",         # Color-blind friendly palettes
  "ggraph",          # Network visualization
  "igraph",          # Graph/network analysis
  "visNetwork",      # Interactive network visualization
  "DiagrammeR"       # Diagrams and flowcharts
)

for (pkg in viz_packages) {
  install_if_missing(pkg)
}

# ============================================================================
# Statistics & Modeling (REQUIRED)
# ============================================================================
cat("\n--- Statistics & Modeling ---\n")

stats_packages <- c(
  "nlme",            # Linear and nonlinear mixed effects
  "lme4",            # Linear mixed effects models
  "survival",        # Survival analysis
  "coda"             # MCMC diagnostics
)

for (pkg in stats_packages) {
  install_if_missing(pkg)
}

# ============================================================================
# Report Generation (REQUIRED)
# ============================================================================
cat("\n--- Report Generation ---\n")

report_packages <- c(
  "officer",         # Word document generation
  "flextable",       # Formatted tables for reports
  "rmarkdown",       # R Markdown documents
  "knitr"            # Dynamic report generation
)

for (pkg in report_packages) {
  install_if_missing(pkg)
}

# ============================================================================
# Phase 3.4: Advanced Publication Bias (OPTIONAL - Recommended)
# ============================================================================
cat("\n--- Phase 3.4: Advanced Publication Bias (Optional) ---\n")

# puniform - p-uniform and p-uniform* methods
cat("\nChecking for 'puniform' package...\n")
if (!requireNamespace("puniform", quietly = TRUE)) {
  cat("⚠ 'puniform' package not found\n")
  cat("  Phase 3.4 (Advanced Publication Bias) will have limited functionality\n")
  cat("  To install: install.packages('puniform')\n")
  cat("  Note: May require compilation tools on some systems\n")
} else {
  cat("✓ puniform package available\n")
}

# weightr - Selection models (Vevea-Hedges)
cat("\nChecking for 'weightr' package...\n")
if (!requireNamespace("weightr", quietly = TRUE)) {
  cat("⚠ 'weightr' package not found\n")
  cat("  Selection models (3PSM/4PSM) will not be available\n")
  cat("  To install: install.packages('weightr')\n")
} else {
  cat("✓ weightr package available\n")
}

# ============================================================================
# Phase 3.5: Enhanced UI Widgets (OPTIONAL - Recommended)
# ============================================================================
cat("\n--- Phase 3.5: Enhanced UI Widgets (Optional) ---\n")

# colourpicker - Color picker widget
cat("\nChecking for 'colourpicker' package...\n")
if (!requireNamespace("colourpicker", quietly = TRUE)) {
  cat("⚠ 'colourpicker' package not found\n")
  cat("  Custom branding color selection will be disabled\n")
  cat("  To install: install.packages('colourpicker')\n")
} else {
  cat("✓ colourpicker package available\n")
}

# ============================================================================
# Phase 4.2: Bayesian NMA (OPTIONAL - Framework Only)
# ============================================================================
cat("\n--- Phase 4.2: Bayesian NMA (Optional - Framework Only) ---\n")

# brms - Bayesian regression models using Stan
cat("\nChecking for 'brms' package...\n")
if (!requireNamespace("brms", quietly = TRUE)) {
  cat("⚠ 'brms' package not found\n")
  cat("  Note: Bayesian NMA currently uses SIMULATION only\n")
  cat("  Full implementation requires: install.packages('brms')\n")
  cat("  Warning: brms requires Stan and can take 30+ minutes to install\n")
} else {
  cat("✓ brms package available (required for full Bayesian NMA)\n")
}

# ============================================================================
# Phase 4.4: Partitioned Survival (OPTIONAL - Framework Only)
# ============================================================================
cat("\n--- Phase 4.4: Partitioned Survival (Optional - Framework Only) ---\n")

# flexsurv - Flexible parametric survival models
cat("\nChecking for 'flexsurv' package...\n")
if (!requireNamespace("flexsurv", quietly = TRUE)) {
  cat("⚠ 'flexsurv' package not found\n")
  cat("  Note: Partitioned Survival currently uses SIMULATION only\n")
  cat("  Full implementation requires: install.packages('flexsurv')\n")
} else {
  cat("✓ flexsurv package available (required for full survival modeling)\n")
}

# ============================================================================
# Authentication (OPTIONAL - Recommended for Production)
# ============================================================================
cat("\n--- Authentication (Optional - Recommended for Production) ---\n")

# shinymanager - Simple authentication
cat("\nChecking for 'shinymanager' package...\n")
if (!requireNamespace("shinymanager", quietly = TRUE)) {
  cat("⚠ 'shinymanager' package not found\n")
  cat("  No authentication will be available\n")
  cat("  For production deployment, install: install.packages('shinymanager')\n")
} else {
  cat("✓ shinymanager package available\n")
}

# ============================================================================
# Summary
# ============================================================================
cat("\n")
cat("========================================================================\n")
cat("  Installation Summary\n")
cat("========================================================================\n")
cat("\n")

# Count installed packages
required_pkgs <- c(core_packages, data_packages, meta_packages, viz_packages,
                  stats_packages, report_packages)
installed_count <- sum(sapply(required_pkgs, function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}))

cat(sprintf("Required packages: %d / %d installed\n", installed_count, length(required_pkgs)))

if (installed_count == length(required_pkgs)) {
  cat("\n✓ All required packages are installed!\n")
  cat("  You can now run the application with:\n")
  cat("    Rscript frontend/app.R\n")
} else {
  cat("\n⚠ Some required packages failed to install\n")
  cat("  Please check error messages above and try installing failed packages manually\n")
}

# Optional packages summary
optional_pkgs <- c("puniform", "weightr", "colourpicker", "brms", "flexsurv", "shinymanager")
optional_installed <- sum(sapply(optional_pkgs, function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}))

cat(sprintf("\nOptional packages: %d / %d installed\n", optional_installed, length(optional_pkgs)))

if (optional_installed < length(optional_pkgs)) {
  cat("\n  Missing optional packages will limit some advanced features:\n")
  if (!requireNamespace("puniform", quietly = TRUE)) {
    cat("    - puniform: p-uniform/p-uniform* publication bias methods\n")
  }
  if (!requireNamespace("weightr", quietly = TRUE)) {
    cat("    - weightr: Selection models for publication bias\n")
  }
  if (!requireNamespace("colourpicker", quietly = TRUE)) {
    cat("    - colourpicker: Custom color picker for report branding\n")
  }
  if (!requireNamespace("brms", quietly = TRUE)) {
    cat("    - brms: Full Bayesian NMA (currently simulation only)\n")
  }
  if (!requireNamespace("flexsurv", quietly = TRUE)) {
    cat("    - flexsurv: Full partitioned survival (currently simulation only)\n")
  }
  if (!requireNamespace("shinymanager", quietly = TRUE)) {
    cat("    - shinymanager: User authentication for production deployment\n")
  }
}

cat("\n")
cat("========================================================================\n")
cat("  Installation Complete!\n")
cat("========================================================================\n")
cat("\n")
