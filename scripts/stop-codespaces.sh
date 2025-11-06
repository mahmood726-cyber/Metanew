#!/bin/bash
set -e

echo "🛑 Stopping EvidenceOS PRIME services..."
echo ""

# Create .pids directory if it doesn't exist
mkdir -p /workspace/.pids

# Function to stop process by PID file
stop_by_pid_file() {
    local pid_file=$1
    local service_name=$2

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null 2>&1; then
            echo "🛑 Stopping $service_name (PID: $pid)..."
            kill $pid 2>/dev/null || true
            sleep 1
            # Force kill if still running
            if ps -p $pid > /dev/null 2>&1; then
                kill -9 $pid 2>/dev/null || true
            fi
            echo "   ✅ Stopped"
        else
            echo "   ℹ️  $service_name was not running"
        fi
        rm -f "$pid_file"
    fi
}

# Stop services by PID files
stop_by_pid_file "/workspace/.pids/api-main.pid" "Main API"
stop_by_pid_file "/workspace/.pids/api-ai.pid" "AI Copilot"
stop_by_pid_file "/workspace/.pids/shiny.pid" "Shiny Frontend"

# Fallback: kill by process name
echo ""
echo "🧹 Cleaning up any remaining processes..."
pkill -f "uvicorn" 2>/dev/null && echo "   ✅ Killed remaining uvicorn processes" || true
pkill -f "R.*shiny" 2>/dev/null && echo "   ✅ Killed remaining R/Shiny processes" || true

echo ""
echo "✅ All services stopped"
echo ""
echo "💡 To restart, run: ./scripts/start-codespaces.sh"
echo ""
