# Dockerfile for EvidenceOS PRIME Shiny Frontend
# Based on rocker/shiny with additional R packages

FROM rocker/shiny:4.3.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
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
RUN R -e "install.packages(c(\
    'shiny', \
    'bslib', \
    'DT', \
    'plotly', \
    'shinyvalidate', \
    'metafor', \
    'netmeta', \
    'dosresmeta', \
    'readr', \
    'readxl', \
    'dplyr', \
    'tidyr', \
    'ggplot2', \
    'officer', \
    'flextable', \
    'DiagrammeR', \
    'httr', \
    'jsonlite', \
    'digest', \
    'yaml', \
    'BCEA' \
    ), repos='https://cloud.r-project.org/')"

# Create app directory
RUN mkdir -p /srv/shiny-server/evidenceos

# Copy application files
COPY app.R /srv/shiny-server/evidenceos/
COPY modules/ /srv/shiny-server/evidenceos/modules/
COPY utils/ /srv/shiny-server/evidenceos/utils/
COPY config/ /srv/shiny-server/evidenceos/config/

# Create outputs directory with proper permissions
RUN mkdir -p /srv/shiny-server/evidenceos/outputs && \
    mkdir -p /srv/shiny-server/evidenceos/data/uploads && \
    chown -R shiny:shiny /srv/shiny-server/evidenceos

# Copy Shiny server configuration
RUN echo "run_as shiny;" > /etc/shiny-server/shiny-server.conf && \
    echo "server {" >> /etc/shiny-server/shiny-server.conf && \
    echo "  listen 3838;" >> /etc/shiny-server/shiny-server.conf && \
    echo "  location /evidenceos {" >> /etc/shiny-server/shiny-server.conf && \
    echo "    app_dir /srv/shiny-server/evidenceos;" >> /etc/shiny-server/shiny-server.conf && \
    echo "    log_dir /var/log/shiny-server;" >> /etc/shiny-server/shiny-server.conf && \
    echo "    directory_index on;" >> /etc/shiny-server/shiny-server.conf && \
    echo "  }" >> /etc/shiny-server/shiny-server.conf && \
    echo "}" >> /etc/shiny-server/shiny-server.conf

# Expose port
EXPOSE 3838

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3838/evidenceos/ || exit 1

# Run Shiny Server
CMD ["/usr/bin/shiny-server"]
