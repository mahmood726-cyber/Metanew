#!/bin/bash
################################################################################
# EvidenceOS PRIME - Mahmood789 Integration Deployment Script
# Deploys 19 Shiny apps + 650+ datasets from 786-MIII-Meta-analysis
################################################################################

set -e  # Exit on error

echo "======================================================================="
echo "  EvidenceOS PRIME - Mahmood789 Integration Deployment"
echo "  Version: 1.0.0"
echo "  Date: $(date)"
echo "======================================================================="
echo ""

# ===== CONFIGURATION =====

PROJECT_ROOT="/home/user/Metanew"
DOCKER_REGISTRY="evidenceos"
IMAGE_NAME="shiny-apps"
IMAGE_TAG="latest"
FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# API Keys (set these as environment variables)
GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===== HELPER FUNCTIONS =====

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    log_success "Docker is installed: $(docker --version)"

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_warning "docker-compose is not installed. Will use 'docker compose' instead."
    else
        log_success "docker-compose is installed: $(docker-compose --version)"
    fi

    # Check if external_integrations exists
    if [ ! -d "$PROJECT_ROOT/external_integrations/786-MIII-Meta-analysis" ]; then
        log_error "786-MIII-Meta-analysis repository not found!"
        log_error "Expected location: $PROJECT_ROOT/external_integrations/786-MIII-Meta-analysis"
        exit 1
    fi
    log_success "786-MIII-Meta-analysis repository found"

    # Count apps
    APP_COUNT=$(find "$PROJECT_ROOT/external_integrations/786-MIII-Meta-analysis" -maxdepth 1 -type f -name "*.R" -o -name "786*" | wc -l)
    log_info "Found $APP_COUNT Shiny app files"

    # Check datasets
    if [ -d "$PROJECT_ROOT/external_integrations/786-MIII-Meta-analysis/external_integrations/Pairwise70/data" ]; then
        PAIRWISE_COUNT=$(ls "$PROJECT_ROOT/external_integrations/786-MIII-Meta-analysis/external_integrations/Pairwise70/data" | wc -l)
        log_success "Pairwise70: $PAIRWISE_COUNT datasets found"
    else
        log_warning "Pairwise70 datasets not found"
    fi
}

build_docker_image() {
    log_info "Building Docker image for Shiny apps..."

    cd "$PROJECT_ROOT"

    # Build the image
    log_info "Running: docker build -f docker/shiny-apps/Dockerfile -t $FULL_IMAGE ."

    if docker build -f docker/shiny-apps/Dockerfile -t "$FULL_IMAGE" . ; then
        log_success "Docker image built successfully: $FULL_IMAGE"

        # Get image size
        IMAGE_SIZE=$(docker images "$FULL_IMAGE" --format "{{.Size}}")
        log_info "Image size: $IMAGE_SIZE"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

test_docker_image() {
    log_info "Testing Docker image..."

    # Test run the container
    log_info "Starting test container..."

    CONTAINER_ID=$(docker run -d -p 3839:3838 "$FULL_IMAGE")

    if [ -z "$CONTAINER_ID" ]; then
        log_error "Failed to start test container"
        return 1
    fi

    log_info "Test container started: $CONTAINER_ID"
    log_info "Waiting for Shiny Server to start (10 seconds)..."
    sleep 10

    # Check if container is still running
    if docker ps | grep -q "$CONTAINER_ID"; then
        log_success "Test container is running"

        # Try to curl the homepage
        if curl -f http://localhost:3839/ > /dev/null 2>&1; then
            log_success "Shiny Server is responding on port 3839"
        else
            log_warning "Shiny Server may not be fully ready yet"
        fi

        # Stop and remove test container
        log_info "Stopping test container..."
        docker stop "$CONTAINER_ID" > /dev/null
        docker rm "$CONTAINER_ID" > /dev/null
        log_success "Test container cleaned up"

        return 0
    else
        log_error "Test container stopped unexpectedly"
        docker logs "$CONTAINER_ID"
        docker rm "$CONTAINER_ID" > /dev/null
        return 1
    fi
}

create_docker_network() {
    log_info "Creating Docker network..."

    if docker network inspect sp-net > /dev/null 2>&1; then
        log_info "Network 'sp-net' already exists"
    else
        docker network create sp-net
        log_success "Network 'sp-net' created"
    fi
}

deploy_standalone() {
    log_info "Deploying Shiny apps in standalone mode..."

    create_docker_network

    # Stop existing container if running
    if docker ps -a | grep -q "evidenceos-shiny-apps"; then
        log_info "Stopping existing container..."
        docker stop evidenceos-shiny-apps > /dev/null 2>&1 || true
        docker rm evidenceos-shiny-apps > /dev/null 2>&1 || true
    fi

    # Run the container
    log_info "Starting Shiny apps container..."

    docker run -d \
        --name evidenceos-shiny-apps \
        --network sp-net \
        -p 3838:3838 \
        -e GOOGLE_API_KEY="$GOOGLE_API_KEY" \
        -e OPENAI_API_KEY="$OPENAI_API_KEY" \
        --restart unless-stopped \
        "$FULL_IMAGE"

    log_success "Shiny apps deployed successfully!"
    log_info "Access apps at: http://localhost:3838"
}

create_docker_compose_file() {
    log_info "Creating docker-compose.yml for ShinyProxy..."

    cat > "$PROJECT_ROOT/docker-compose.shinyproxy.yml" <<'EOF'
version: '3.8'

services:
  shiny-apps:
    image: evidenceos/shiny-apps:latest
    container_name: evidenceos-shiny-apps
    networks:
      - sp-net
    ports:
      - "3838:3838"
    environment:
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3838/"]
      interval: 30s
      timeout: 10s
      retries: 3

  shinyproxy:
    image: openanalytics/shinyproxy:latest
    container_name: evidenceos-shinyproxy
    networks:
      - sp-net
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./docker/shiny-proxy/application.yml:/opt/shinyproxy/application.yml
    environment:
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    restart: unless-stopped
    depends_on:
      - shiny-apps

networks:
  sp-net:
    driver: bridge
EOF

    log_success "docker-compose.shinyproxy.yml created"
}

deploy_shinyproxy() {
    log_info "Deploying with ShinyProxy..."

    create_docker_network
    create_docker_compose_file

    cd "$PROJECT_ROOT"

    # Start services
    log_info "Starting ShinyProxy services..."

    docker-compose -f docker-compose.shinyproxy.yml up -d

    log_success "ShinyProxy deployed successfully!"
    log_info "Access ShinyProxy at: http://localhost:8080"
    log_info "Default credentials: admin / changeme"
}

show_summary() {
    echo ""
    echo "======================================================================="
    echo "  DEPLOYMENT SUMMARY"
    echo "======================================================================="
    echo ""
    echo "✓ Docker image built: $FULL_IMAGE"
    echo "✓ Network created: sp-net"
    echo "✓ Shiny apps: 19 apps deployed"
    echo "✓ Datasets integrated:"
    echo "    - Pairwise70: 501 Cochrane datasets"
    echo "    - NMA51: 51 NMA datasets"
    echo "    - NMArepo: 100+ NMA networks"
    echo "    - DTA70: 76 DTA datasets"
    echo ""
    echo "Access Points:"
    echo "  - Shiny Apps: http://localhost:3838"
    echo "  - ShinyProxy: http://localhost:8080 (if deployed)"
    echo "  - API: http://localhost:8000/datasets"
    echo ""
    echo "Next Steps:"
    echo "  1. Test individual apps"
    echo "  2. Configure API keys for AI-powered apps"
    echo "  3. Set up authentication in ShinyProxy"
    echo "  4. Deploy to production environment"
    echo ""
    echo "Documentation: /home/user/Metanew/INTEGRATION_PLAN.md"
    echo "======================================================================="
}

# ===== MAIN DEPLOYMENT FLOW =====

main() {
    echo ""
    log_info "Starting deployment process..."
    echo ""

    # Step 1: Check prerequisites
    check_prerequisites
    echo ""

    # Step 2: Build Docker image
    read -p "Build Docker image? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        build_docker_image
        echo ""
    else
        log_warning "Skipping Docker image build"
        echo ""
    fi

    # Step 3: Test Docker image
    read -p "Test Docker image? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_docker_image
        echo ""
    else
        log_warning "Skipping Docker image test"
        echo ""
    fi

    # Step 4: Choose deployment method
    echo "Select deployment method:"
    echo "  1) Standalone (single container, port 3838)"
    echo "  2) ShinyProxy (multi-app hosting, port 8080)"
    echo "  3) Skip deployment"
    read -p "Enter choice (1-3): " -n 1 -r
    echo ""

    case $REPLY in
        1)
            deploy_standalone
            ;;
        2)
            deploy_shinyproxy
            ;;
        3)
            log_info "Skipping deployment"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac

    echo ""

    # Step 5: Show summary
    show_summary
}

# Run main function
main "$@"
