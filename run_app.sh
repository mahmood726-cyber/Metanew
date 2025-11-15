#!/bin/bash
# EvidenceOS PRIME Quick Start Script for Codespaces

echo "🚀 EvidenceOS PRIME - Starting Application..."
echo ""

# Check if Python dependencies are installed
if ! python -c "import fastapi" 2>/dev/null; then
    echo "📦 Installing Python dependencies..."
    pip install -r backend/api/requirements.txt
    echo ""
fi

# Start backend in background
echo "⚡ Starting FastAPI backend on port 8000..."
cd /home/user/Metanew/backend/api
uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
echo "   Backend PID: $BACKEND_PID"

# Wait for backend to start
sleep 3

# Check backend health
echo ""
echo "🏥 Checking backend health..."
if curl -s http://localhost:8000/health > /dev/null; then
    echo "   ✅ Backend is healthy!"
else
    echo "   ⚠️  Backend may not be ready yet"
fi

echo ""
echo "================================"
echo "✅ Application is running!"
echo "================================"
echo ""
echo "📍 Access points:"
echo "   Backend API: http://localhost:8000"
echo "   API Docs:    http://localhost:8000/docs"
echo ""
echo "💡 To start the frontend (in a new terminal):"
echo "   cd /home/user/Metanew/frontend"
echo "   R -e \"shiny::runApp(port=3838, host='0.0.0.0')\""
echo ""
echo "⏹️  To stop backend: kill $BACKEND_PID"
echo "   Or press Ctrl+C to stop this script"
echo ""

# Keep script running
wait $BACKEND_PID
