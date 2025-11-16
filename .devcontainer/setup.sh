#!/bin/bash
set -e

echo "🚀 Setting up EvidenceOS PRIME development environment..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update

# Install system dependencies for R packages
echo "📦 Installing system dependencies for R..."
sudo apt-get install -y \
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
    curl \
    wget

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
cd backend
pip install --upgrade pip
pip install -r requirements.txt
cd ..

cd backend/api
pip install -r requirements.txt
cd ../..

# Install R packages
echo "📊 Installing R packages (this may take 5-10 minutes)..."
Rscript -e "install.packages(c(
    'shiny',
    'bslib',
    'DT',
    'plotly',
    'shinyvalidate',
    'metafor',
    'netmeta',
    'dosresmeta',
    'readr',
    'readxl',
    'dplyr',
    'tidyr',
    'ggplot2',
    'officer',
    'flextable',
    'DiagrammeR',
    'httr',
    'jsonlite',
    'digest',
    'yaml',
    'BCEA'
), repos='https://cloud.r-project.org/', Ncpus = 4)"

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p outputs
mkdir -p data/uploads
mkdir -p frontend/outputs
mkdir -p frontend/data/uploads

# Set permissions
chmod -R 777 outputs
chmod -R 777 data
chmod -R 777 frontend/outputs
chmod -R 777 frontend/data

echo "✅ Setup complete! You can now run the application."
echo ""
echo "Quick start:"
echo "  1. Run: bash .devcontainer/start.sh"
echo "  2. Open http://localhost:3838 for Shiny App"
echo "  3. Open http://localhost:8001/docs for API docs"
