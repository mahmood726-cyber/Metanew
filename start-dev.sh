#!/bin/bash
# Quick start script for local development
# Use this if you're not using Docker Compose

echo "🚀 Starting EvidenceOS PRIME in development mode..."
echo ""

# Check if we're in Codespaces
if [ -n "$CODESPACES" ]; then
    echo "✅ Running in GitHub Codespaces"
    bash .devcontainer/start.sh
else
    echo "💻 Running in local environment"

    # Check for required commands
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python 3 not found. Please install Python 3.9+"
        exit 1
    fi

    if ! command -v R &> /dev/null; then
        echo "❌ R not found. Please install R 4.0+"
        exit 1
    fi

    echo "✅ Python found: $(python3 --version)"
    echo "✅ R found: $(R --version | head -n 1)"
    echo ""

    # Start services
    bash .devcontainer/start.sh
fi
