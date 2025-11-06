#!/bin/bash
set -e

echo "🚀 Setting up EvidenceOS PRIME in Codespaces..."

# Create workspace symlink if needed
if [ ! -L /workspace ]; then
  ln -s /workspaces/$(basename $PWD) /workspace 2>/dev/null || true
fi

# Make start scripts executable
chmod +x /workspaces/$(basename $PWD)/quick-start.sh 2>/dev/null || true
chmod +x /workspaces/$(basename $PWD)/fast-start.sh 2>/dev/null || true

echo "✅ Setup complete!"
echo ""
echo "📋 Quick Start Commands:"
echo "  ./fast-start.sh           - INSTANT START (30-60 seconds!) - Uses pre-built images"
echo "  ./quick-start.sh          - Build and start (5-7 minutes) - Builds from source"
echo "  docker-compose up -d      - Manual start with local build"
echo "  docker-compose logs -f    - View live logs"
echo ""
echo "🌐 Service URLs (will be available after startup):"
echo "  Frontend: http://localhost:3838"
echo "  Backend:  http://localhost:8001"
echo "  API Docs: http://localhost:8001/docs"
echo ""
