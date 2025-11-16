#!/bin/bash

echo "🚀 Starting EvidenceOS PRIME services..."

# Function to check if port is in use
port_in_use() {
    lsof -i:$1 > /dev/null 2>&1
}

# Kill any existing processes on the ports
echo "🧹 Cleaning up any existing processes..."
if port_in_use 8001; then
    echo "Stopping existing process on port 8001..."
    kill $(lsof -t -i:8001) 2>/dev/null || true
fi

if port_in_use 8000; then
    echo "Stopping existing process on port 8000..."
    kill $(lsof -t -i:8000) 2>/dev/null || true
fi

if port_in_use 3838; then
    echo "Stopping existing process on port 3838..."
    kill $(lsof -t -i:3838) 2>/dev/null || true
fi

sleep 2

# Start AI Copilot Backend (FastAPI on port 8001)
echo "🤖 Starting AI Copilot Backend on port 8001..."
cd backend/api
nohup uvicorn nlq:app --host 0.0.0.0 --port 8001 --reload > ../../outputs/ai-backend.log 2>&1 &
AI_BACKEND_PID=$!
echo "AI Backend PID: $AI_BACKEND_PID"
cd ../..

# Wait for backend to start
echo "⏳ Waiting for AI backend to start..."
sleep 3

# Check if backend is running
if curl -s http://localhost:8001/health > /dev/null; then
    echo "✅ AI Backend is running on http://localhost:8001"
else
    echo "⚠️  AI Backend may not have started properly. Check outputs/ai-backend.log"
fi

# Start Legacy Backend (FastAPI on port 8000) - Optional
echo "🐍 Starting Legacy Backend on port 8000..."
cd backend/api
nohup uvicorn main:app --host 0.0.0.0 --port 8000 --reload > ../../outputs/backend.log 2>&1 &
BACKEND_PID=$!
echo "Legacy Backend PID: $BACKEND_PID"
cd ../..

sleep 2

# Start Shiny Frontend
echo "📊 Starting Shiny Frontend on port 3838..."
cd frontend
nohup R -e "shiny::runApp(port=3838, host='0.0.0.0', launch.browser=FALSE)" > ../outputs/shiny.log 2>&1 &
SHINY_PID=$!
echo "Shiny PID: $SHINY_PID"
cd ..

# Wait for services to be ready
echo "⏳ Waiting for all services to start..."
sleep 5

echo ""
echo "✅ All services started!"
echo ""
echo "📊 Shiny App:     http://localhost:3838"
echo "🤖 AI Copilot:    http://localhost:8001/docs"
echo "🐍 Legacy API:    http://localhost:8000/docs"
echo ""
echo "📝 Logs:"
echo "   AI Backend:    tail -f outputs/ai-backend.log"
echo "   Legacy API:    tail -f outputs/backend.log"
echo "   Shiny:         tail -f outputs/shiny.log"
echo ""
echo "🛑 To stop all services: pkill -f uvicorn && pkill -f shiny"
