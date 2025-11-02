# EvidenceOS PRIME - Multi-stage Dockerfile
# Combines R Shiny frontend and Python FastAPI backend

FROM rocker/shiny-verse:latest AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    libpq-dev \
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
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c( \
    'shiny', \
    'bslib', \
    'DT', \
    'plotly', \
    'shinyvalidate', \
    'metafor', \
    'netmeta', \
    'dosresmeta', \
    'rmarkdown', \
    'officer', \
    'readxl', \
    'httr', \
    'jsonlite', \
    'ggplot2', \
    'dplyr', \
    'tidyr' \
), repos='https://cloud.r-project.org/')"

# Install Python packages
WORKDIR /app/backend
COPY backend/requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application files
COPY backend /app/backend
COPY frontend /app/frontend
COPY data /app/data
COPY outputs /app/outputs

# Create startup script
RUN echo '#!/bin/bash\n\
cd /app/backend/api && python3 main.py &\n\
cd /app/frontend && R -e "shiny::runApp(host=\"0.0.0.0\", port=3838)"\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose ports
EXPOSE 3838 8000

# Set working directory
WORKDIR /app

# Start both services
CMD ["/app/start.sh"]
