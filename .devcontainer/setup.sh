#!/bin/bash
set -e

echo "⚡ Setting up EvidenceOS PRIME (OPTIMIZED for speed)..."
echo ""

# Function to show progress
show_progress() {
    echo "▶ $1..."
}

# Update package lists (silent)
show_progress "Updating system packages"
sudo apt-get update -qq > /dev/null 2>&1

# Install system dependencies in parallel
show_progress "Installing system dependencies"
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
    git \
    curl \
    netcat \
    > /dev/null 2>&1 &
SYS_PID=$!

# Install Python dependencies in parallel
show_progress "Installing Python dependencies (in parallel)"
cd /workspace
(
    pip install --upgrade pip -q > /dev/null 2>&1
    # Install critical packages first
    pip install -q fastapi uvicorn pydantic pandas numpy > /dev/null 2>&1
    # Install remaining packages
    pip install -q -r backend/api/requirements.txt > /dev/null 2>&1
    echo "  ✓ Python packages installed"
) &
PY_PID=$!

# Wait for system dependencies
wait $SYS_PID
echo "  ✓ System dependencies installed"

# Install R packages using BINARY packages from Posit PPM (10x faster!)
show_progress "Installing R packages (using binary packages - FAST!)"
sudo Rscript -e "
# Use Posit Public Package Manager for BINARY packages (much faster!)
options(repos = c(PPM = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest'))

# Install packages quietly with progress
cat('  Installing core packages...\n')
install.packages(c('shiny', 'bslib', 'DT', 'plotly'), quiet = TRUE)

cat('  Installing meta-analysis packages...\n')
install.packages(c('metafor', 'netmeta', 'dosresmeta'), quiet = TRUE)

cat('  Installing utility packages...\n')
install.packages(c('rmarkdown', 'officer', 'readxl', 'httr', 'jsonlite', 'shinyvalidate'), quiet = TRUE)

cat('  ✓ R packages installed\n')
" 2>&1 | grep -v "^trying URL" | grep -v "^Content type" | grep -v "^downloaded"

# Wait for Python installation
wait $PY_PID

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
