#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         EvidenceOS PRIME - Quick Start                 ║${NC}"
echo -e "${BLUE}║    Meta-Analysis & Health Technology Assessment        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose not found. Please install docker-compose first.${NC}"
    exit 1
fi

# Function to check service health
check_service_health() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}⏳ Waiting for ${service_name} to be ready...${NC}"

    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302\|404"; then
            echo -e "${GREEN}✅ ${service_name} is ready!${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo -e "${RED}❌ ${service_name} failed to start${NC}"
    return 1
}

# Build images with cache (much faster after first build)
echo -e "${BLUE}🔨 Building Docker images (this may take a few minutes on first run)...${NC}"
docker-compose build --parallel 2>&1 | grep -E "Step|Successfully|Building|CACHED" || true

# Start services
echo -e "${BLUE}🚀 Starting services...${NC}"
docker-compose up -d

echo ""
echo -e "${YELLOW}⏳ Waiting for services to initialize (60 seconds)...${NC}"
sleep 60

# Check backend health
echo ""
if check_service_health "Backend API" "http://localhost:8001/health"; then
    BACKEND_STATUS="${GREEN}✅ Online${NC}"
else
    BACKEND_STATUS="${RED}❌ Check logs${NC}"
fi

# Check frontend health
echo ""
if check_service_health "Frontend" "http://localhost:3838"; then
    FRONTEND_STATUS="${GREEN}✅ Online${NC}"
else
    FRONTEND_STATUS="${RED}❌ Check logs${NC}"
fi

# Display final status
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 🎉 STARTUP COMPLETE                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📊 Service Status:${NC}"
echo -e "  Frontend (Shiny):  ${FRONTEND_STATUS}"
echo -e "  Backend (API):     ${BACKEND_STATUS}"
echo ""
echo -e "${GREEN}🌐 Access URLs:${NC}"
echo -e "  ${BLUE}Frontend:${NC}      http://localhost:3838"
echo -e "  ${BLUE}Backend API:${NC}   http://localhost:8001"
echo -e "  ${BLUE}API Docs:${NC}      http://localhost:8001/docs"
echo ""
echo -e "${GREEN}📋 Key Features Available:${NC}"
echo -e "  ✓ Pairwise Meta-Analysis (forest plots, funnel plots)"
echo -e "  ✓ Network Meta-Analysis (league tables, P-scores)"
echo -e "  ✓ Dose-Response Meta-Analysis (spline modeling)"
echo -e "  ✓ Health Economics Analysis (ICER, CEAC, EVPI)"
echo -e "  ✓ Interactive Sensitivity Explorer"
echo -e "  ✓ AI Copilot for natural language queries"
echo -e "  ✓ Report Generation (Word, PDF, PowerPoint)"
echo -e "  ✓ Scenario Presets Library (17 templates)"
echo ""
echo -e "${YELLOW}🔧 Useful Commands:${NC}"
echo -e "  ${BLUE}docker-compose logs -f${NC}            View live logs"
echo -e "  ${BLUE}docker-compose logs -f shiny-frontend${NC}  Frontend logs only"
echo -e "  ${BLUE}docker-compose logs -f ai-backend${NC}      Backend logs only"
echo -e "  ${BLUE}docker-compose ps${NC}                  Service status"
echo -e "  ${BLUE}docker-compose down${NC}                Stop all services"
echo -e "  ${BLUE}docker-compose restart${NC}             Restart services"
echo ""
echo -e "${GREEN}🎯 Next Steps:${NC}"
echo -e "  1. Open ${BLUE}http://localhost:3838${NC} in your browser"
echo -e "  2. Upload your study data or use example datasets"
echo -e "  3. Create a protocol using the PICO framework"
echo -e "  4. Run meta-analysis (pairwise, network, or dose-response)"
echo -e "  5. Generate publication-ready reports"
echo ""
echo -e "${GREEN}💡 Pro Tips:${NC}"
echo -e "  • Use Scenario Presets for quick analysis setup"
echo -e "  • Try the AI Copilot for natural language queries"
echo -e "  • Enable Parquet caching for 10-100x faster re-analysis"
echo -e "  • Check the Audit Trail tab for full reproducibility"
echo ""

# Open browser automatically if in Codespaces
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "${BLUE}🌐 GitHub Codespaces detected! URLs will auto-forward.${NC}"
    echo -e "${YELLOW}   Click the 'Ports' tab and open port 3838 for the frontend.${NC}"
fi

echo ""
