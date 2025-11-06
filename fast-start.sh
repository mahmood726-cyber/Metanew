#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║       EvidenceOS PRIME - INSTANT START MODE            ║${NC}"
echo -e "${MAGENTA}║          Using Pre-Built Docker Images                 ║${NC}"
echo -e "${MAGENTA}║         Target: 30-60 Second Startup! 🚀               ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
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

# Record start time
START_TIME=$(date +%s)

echo -e "${CYAN}⏱️  Timer started - let's see how fast this is!${NC}"
echo ""

# Pull pre-built images (much faster than building!)
echo -e "${BLUE}📦 Pulling pre-built images from GitHub Container Registry...${NC}"
echo -e "${YELLOW}   This replaces the 5-7 minute build with a 10-30 second pull!${NC}"
docker-compose -f docker-compose.prod.yml pull 2>&1 | grep -E "Pulling|Digest|Status|Downloaded" || {
    echo -e "${YELLOW}⚠️  Could not pull pre-built images. Falling back to local build...${NC}"
    echo -e "${YELLOW}   To use pre-built images, ensure the CI/CD workflow has run.${NC}"
    echo -e "${YELLOW}   Using docker-compose.yml instead...${NC}"

    # Fallback to building locally
    docker-compose build --parallel 2>&1 | grep -E "Step|Successfully|Building|CACHED" || true
    docker-compose up -d
}

# Start services with pre-built images
echo ""
echo -e "${BLUE}🚀 Starting services with pre-built images...${NC}"
docker-compose -f docker-compose.prod.yml up -d 2>&1 | grep -E "Creating|Starting|Started|Created" || docker-compose -f docker-compose.prod.yml up -d

# Calculate elapsed time for pull + start
PULL_END_TIME=$(date +%s)
PULL_ELAPSED=$((PULL_END_TIME - START_TIME))
echo ""
echo -e "${GREEN}✅ Images pulled and services started in ${PULL_ELAPSED} seconds!${NC}"

# Function to check service health
check_service_health() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1

    echo ""
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

echo ""
echo -e "${YELLOW}⏳ Waiting for services to initialize (~30 seconds)...${NC}"
sleep 30

# Check backend health
if check_service_health "Backend API" "http://localhost:8001/health"; then
    BACKEND_STATUS="${GREEN}✅ Online${NC}"
else
    BACKEND_STATUS="${RED}❌ Check logs${NC}"
fi

# Check frontend health
if check_service_health "Frontend" "http://localhost:3838"; then
    FRONTEND_STATUS="${GREEN}✅ Online${NC}"
else
    FRONTEND_STATUS="${RED}❌ Check logs${NC}"
fi

# Calculate total elapsed time
END_TIME=$(date +%s)
TOTAL_ELAPSED=$((END_TIME - START_TIME))

# Display final status
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║           🎉 INSTANT STARTUP COMPLETE! 🎉              ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}⏱️  Total Startup Time: ${TOTAL_ELAPSED} seconds${NC}"
echo -e "${CYAN}    (Compare to 5-7 minutes with local build!)${NC}"
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
echo -e "  ${BLUE}docker-compose -f docker-compose.prod.yml logs -f${NC}     View live logs"
echo -e "  ${BLUE}docker-compose -f docker-compose.prod.yml ps${NC}          Service status"
echo -e "  ${BLUE}docker-compose -f docker-compose.prod.yml down${NC}        Stop services"
echo -e "  ${BLUE}docker-compose -f docker-compose.prod.yml restart${NC}     Restart services"
echo ""
echo -e "${GREEN}💡 Performance Boost:${NC}"
echo -e "  🚀 Pre-built images: ${TOTAL_ELAPSED}s startup"
echo -e "  🐌 Local build: ~300-420s startup"
echo -e "  ⚡ Speed improvement: ${CYAN}$(( (400 - TOTAL_ELAPSED) * 100 / 400 ))% faster!${NC}"
echo ""

# Open browser automatically if in Codespaces
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "${BLUE}🌐 GitHub Codespaces detected! URLs will auto-forward.${NC}"
    echo -e "${YELLOW}   Click the 'Ports' tab and open port 3838 for the frontend.${NC}"
    echo ""
fi

echo -e "${GREEN}✨ Ready to analyze! Open ${BLUE}http://localhost:3838${GREEN} to get started.${NC}"
echo ""
