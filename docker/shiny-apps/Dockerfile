# EvidenceOS PRIME - Shiny Apps Container
# Mahmood789 786-MIII Meta-analysis Apps Integration

FROM rocker/shiny:4.3.2

LABEL maintainer="EvidenceOS PRIME Team"
LABEL description="Shiny apps for comprehensive meta-analysis (786-MIII integration)"
LABEL version="1.0.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libcairo2-dev \
    libxt-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set CRAN mirror
RUN echo 'options(repos = c(CRAN = "https://cloud.r-project.org/"))' >> /usr/local/lib/R/etc/Rprofile.site

# Install core R packages
RUN R -e "install.packages('remotes', dependencies=TRUE)"

# Install meta-analysis packages
RUN R -e "install.packages(c( \
    'metafor', \
    'meta', \
    'netmeta', \
    'dosresmeta', \
    'metaplus', \
    'metasens', \
    'mada' \
), dependencies=TRUE)"

# Install Bayesian NMA packages
RUN R -e "install.packages(c( \
    'rjags', \
    'R2jags', \
    'coda', \
    'gemtc' \
), dependencies=TRUE)"

# Install Shiny and UI packages
RUN R -e "install.packages(c( \
    'shiny', \
    'shinydashboard', \
    'shinyWidgets', \
    'shinycssloaders', \
    'bslib', \
    'DT', \
    'plotly', \
    'ggplot2', \
    'gridExtra', \
    'Cairo' \
), dependencies=TRUE)"

# Install data manipulation packages
RUN R -e "install.packages(c( \
    'dplyr', \
    'tidyr', \
    'readr', \
    'readxl', \
    'writexl', \
    'jsonlite', \
    'httr' \
), dependencies=TRUE)"

# Install statistical packages
RUN R -e "install.packages(c( \
    'survival', \
    'survminer', \
    'lme4', \
    'nlme', \
    'mvmeta' \
), dependencies=TRUE)"

# Install reporting packages
RUN R -e "install.packages(c( \
    'rmarkdown', \
    'knitr', \
    'officer', \
    'flextable' \
), dependencies=TRUE)"

# Install dataset packages from GitHub
RUN R -e "remotes::install_github('Mahmood789/Pairwise70', dependencies=FALSE)" || true
RUN R -e "remotes::install_github('Mahmood789/NMA51', dependencies=FALSE)" || true

# Create app directories (AI/LLM apps excluded - rules-based only)
RUN mkdir -p /srv/shiny-server/MIII786MasroorPairwiseRROR
RUN mkdir -p /srv/shiny-server/PairwiseSMD
RUN mkdir -p /srv/shiny-server/HazardRatioMeta
RUN mkdir -p /srv/shiny-server/PropApp
RUN mkdir -p /srv/shiny-server/786MIIIRRORNMA
RUN mkdir -p /srv/shiny-server/786MIIIHRNMA
RUN mkdir -p /srv/shiny-server/786MIIINMAmetaregression
RUN mkdir -p /srv/shiny-server/NMABayesianSMD
RUN mkdir -p /srv/shiny-server/NMASMDMDFreqadvanced
RUN mkdir -p /srv/shiny-server/DTA
RUN mkdir -p /srv/shiny-server/DoseResponseApp
RUN mkdir -p /srv/shiny-server/KMCurveProject
RUN mkdir -p /srv/shiny-server/MultilevelMetaAnalysis
RUN mkdir -p /srv/shiny-server/786MIIIAnnualisedPlot
RUN mkdir -p /srv/shiny-server/786MIIIConversion
RUN mkdir -p /srv/shiny-server/DataConversionMeta
RUN mkdir -p /srv/shiny-server/786MIIIROB
RUN mkdir -p /srv/shiny-server/MedianIQRconversion

# Copy Shiny apps from 786-MIII repository (AI/LLM apps excluded)
COPY external_integrations/786-MIII-Meta-analysis/MIII786MasroorPairwiseRROR /srv/shiny-server/MIII786MasroorPairwiseRROR/app.R
COPY external_integrations/786-MIII-Meta-analysis/PairwiseSMD /srv/shiny-server/PairwiseSMD/app.R
COPY "external_integrations/786-MIII-Meta-analysis/Hazard ratio meta app" /srv/shiny-server/HazardRatioMeta/app.R
COPY "external_integrations/786-MIII-Meta-analysis/Prop app" /srv/shiny-server/PropApp/app.R
COPY external_integrations/786-MIII-Meta-analysis/786-MIIIRRORNMA /srv/shiny-server/786MIIIRRORNMA/app.R
COPY external_integrations/786-MIII-Meta-analysis/786MIIIHRNMA /srv/shiny-server/786MIIIHRNMA/app.R
COPY external_integrations/786-MIII-Meta-analysis/786MIIINMAmetaregression /srv/shiny-server/786MIIINMAmetaregression/app.R
COPY "external_integrations/786-MIII-Meta-analysis/NMA Bayseian SMD" /srv/shiny-server/NMABayesianSMD/app.R
COPY external_integrations/786-MIII-Meta-analysis/NMASMDMDFreqadvanced /srv/shiny-server/NMASMDMDFreqadvanced/app.R
COPY external_integrations/786-MIII-Meta-analysis/DTA /srv/shiny-server/DTA/app.R
COPY "external_integrations/786-MIII-Meta-analysis/Dose response app" /srv/shiny-server/DoseResponseApp/app.R
COPY "external_integrations/786-MIII-Meta-analysis/KM curve project" /srv/shiny-server/KMCurveProject/app.R
COPY "external_integrations/786-MIII-Meta-analysis/Multilevel meta-analysis" /srv/shiny-server/MultilevelMetaAnalysis/app.R
COPY external_integrations/786-MIII-Meta-analysis/786MIIIAnnualisedPlot /srv/shiny-server/786MIIIAnnualisedPlot/app.R
COPY external_integrations/786-MIII-Meta-analysis/786MIIIConversion /srv/shiny-server/786MIIIConversion/app.R
COPY external_integrations/786-MIII-Meta-analysis/Dataconversionmeta /srv/shiny-server/DataConversionMeta/app.R
COPY external_integrations/786-MIII-Meta-analysis/786MIIIROB /srv/shiny-server/786MIIIROB/app.R
COPY external_integrations/786-MIII-Meta-analysis/MedianIQRconversion /srv/shiny-server/MedianIQRconversion/app.R

# Set permissions
RUN chmod -R 755 /srv/shiny-server/

# Configure Shiny Server
RUN echo "run_as shiny;" > /etc/shiny-server/shiny-server.conf && \
    echo "server {" >> /etc/shiny-server/shiny-server.conf && \
    echo "  listen 3838;" >> /etc/shiny-server/shiny-server.conf && \
    echo "  location / {" >> /etc/shiny-server/shiny-server.conf && \
    echo "    site_dir /srv/shiny-server;" >> /etc/shiny-server/shiny-server.conf && \
    echo "    log_dir /var/log/shiny-server;" >> /etc/shiny-server/shiny-server.conf && \
    echo "    directory_index on;" >> /etc/shiny-server/shiny-server.conf && \
    echo "  }" >> /etc/shiny-server/shiny-server.conf && \
    echo "}" >> /etc/shiny-server/shiny-server.conf

# Expose port
EXPOSE 3838

# Health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost:3838/ || exit 1

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]
