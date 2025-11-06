#!/bin/bash
set -e

echo "🚀 Setting up EvidenceOS PRIME in Codespaces..."

# Update package lists
echo "📦 Updating package lists..."
sudo apt-get update -qq

# Install R and required system dependencies
echo "📊 Installing R and system dependencies..."
sudo apt-get install -y -qq \
    r-base \
    r-base-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    pandoc \
    pandoc-citeproc \
    git \
    curl

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
cd /workspace
pip install --upgrade pip
pip install -r backend/requirements.txt
pip install -r backend/api/requirements.txt

# Install R packages
echo "📈 Installing R packages (this may take a few minutes)..."
sudo Rscript -e "
options(repos = c(CRAN = 'https://cloud.r-project.org'))
install.packages(c(
  'shiny',
  'bslib',
  'DT',
  'plotly',
  'shinyvalidate',
  'metafor',
  'netmeta',
  'dosresmeta',
  'rmarkdown',
  'officer',
  'readxl',
  'httr',
  'jsonlite',
  'tidyverse',
  'ggplot2'
), quiet = TRUE, verbose = FALSE)
"

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p outputs
mkdir -p data/uploads
mkdir -p logs
mkdir -p cache/parquet

# Set permissions
echo "🔒 Setting permissions..."
chmod -R 777 outputs data logs cache

# Copy environment template if .env doesn't exist
if [ ! -f .env ]; then
    echo "⚙️  Creating .env file from template..."
    cp .env.example .env
    # Update ALLOWED_ORIGINS for Codespaces
    sed -i 's|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://*.github.dev,https://*.preview.app.github.dev,http://localhost:3838,http://localhost:8000,http://localhost:8001|' .env
fi

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x scripts/*.sh 2>/dev/null || true

echo ""
echo "✅ Setup complete!"
echo ""
echo "📖 Quick Start:"
echo "   1. Run: ./scripts/start-codespaces.sh"
echo "   2. Open forwarded port 3838 to access Shiny UI"
echo "   3. Open forwarded port 8000 for API docs"
echo ""
echo "📚 Read CODESPACES_QUICKSTART.md for detailed instructions"
echo ""
