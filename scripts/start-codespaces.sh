#!/bin/bash
set -e

echo "🚀 Starting EvidenceOS PRIME in Codespaces..."
echo ""

# Function to check if a port is in use
port_in_use() {
    lsof -i:$1 >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_wait=60
    local waited=0

    echo "⏳ Waiting for $service_name (port $port) to start..."

    while ! nc -z localhost $port; do
        sleep 1
        waited=$((waited + 1))
        if [ $waited -ge $max_wait ]; then
            echo "❌ $service_name failed to start after ${max_wait}s"
            return 1
        fi
    done

    echo "✅ $service_name is ready!"
    return 0
}

# Stop any existing processes
echo "🛑 Stopping any existing services..."
pkill -f "uvicorn" 2>/dev/null || true
pkill -f "R.*shiny" 2>/dev/null || true
sleep 2

# Start FastAPI Main Backend (port 8000)
echo ""
echo "🔧 Starting FastAPI Main Backend (port 8000)..."
cd /workspace/backend/api
nohup python main.py > /workspace/logs/api-main.log 2>&1 &
API_MAIN_PID=$!
echo "   PID: $API_MAIN_PID"

# Start AI Copilot Backend (port 8001)
echo ""
echo "🤖 Starting AI Copilot Backend (port 8001)..."
nohup python nlq.py > /workspace/logs/api-ai.log 2>&1 &
API_AI_PID=$!
echo "   PID: $API_AI_PID"

# Wait for backends to be ready
sleep 5
wait_for_service 8000 "Main API" || exit 1
wait_for_service 8001 "AI Copilot API" || exit 1

# Start Shiny Frontend (port 3838)
echo ""
echo "🎨 Starting Shiny Frontend (port 3838)..."
cd /workspace/frontend
nohup Rscript -e "shiny::runApp(host='0.0.0.0', port=3838)" > /workspace/logs/shiny.log 2>&1 &
SHINY_PID=$!
echo "   PID: $SHINY_PID"

# Wait for Shiny to be ready
sleep 10
wait_for_service 3838 "Shiny Frontend" || exit 1

# Get Codespace URL
CODESPACE_NAME=${CODESPACE_NAME:-"your-codespace"}

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ EvidenceOS PRIME is running!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📊 Access Points:"
echo ""
echo "   🎨 Shiny UI:"
echo "      https://${CODESPACE_NAME}-3838.preview.app.github.dev"
echo "      (Or click the 'Ports' tab and open port 3838)"
echo ""
echo "   📡 Main API Docs:"
echo "      https://${CODESPACE_NAME}-8000.preview.app.github.dev/docs"
echo ""
echo "   🤖 AI Copilot API:"
echo "      https://${CODESPACE_NAME}-8001.preview.app.github.dev/health"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📝 Process IDs:"
echo "   Main API: $API_MAIN_PID"
echo "   AI Copilot: $API_AI_PID"
echo "   Shiny Frontend: $SHINY_PID"
echo ""
echo "📋 Useful Commands:"
echo "   📊 View logs:"
echo "      tail -f logs/api-main.log"
echo "      tail -f logs/api-ai.log"
echo "      tail -f logs/shiny.log"
echo ""
echo "   🛑 Stop all services:"
echo "      ./scripts/stop-codespaces.sh"
echo ""
echo "   🔄 Restart services:"
echo "      ./scripts/stop-codespaces.sh && ./scripts/start-codespaces.sh"
echo ""
echo "   🧪 Run tests:"
echo "      cd tests/integration && pytest -v"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "💡 Tip: Click the 'Ports' tab in VS Code to see all forwarded ports"
echo "        and click the globe icon to open in browser"
echo ""

# Save PIDs for stop script
echo "$API_MAIN_PID" > /workspace/.pids/api-main.pid
echo "$API_AI_PID" > /workspace/.pids/api-ai.pid
echo "$SHINY_PID" > /workspace/.pids/shiny.pid

# Keep script running and show logs
echo "📡 Monitoring services (Ctrl+C to stop viewing logs, services will continue)..."
echo ""
tail -f /workspace/logs/*.log
