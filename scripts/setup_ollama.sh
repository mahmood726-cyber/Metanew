#!/bin/bash
# Ollama Setup Script for EvidenceOS PRIME
# Automates model installation and testing

set -e  # Exit on error

echo "=================================================="
echo "  Ollama AI Setup for EvidenceOS PRIME"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Ollama container is running
echo -e "${YELLOW}[1/5] Checking Ollama container status...${NC}"
if docker ps | grep -q evidenceos-ollama; then
    echo -e "${GREEN}✓ Ollama container is running${NC}"
else
    echo -e "${RED}✗ Ollama container is not running${NC}"
    echo "Starting Ollama container..."
    docker-compose up -d ollama
    echo "Waiting for Ollama to start (30 seconds)..."
    sleep 30
fi

# Test Ollama API
echo ""
echo -e "${YELLOW}[2/5] Testing Ollama API...${NC}"
if curl -f http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama API is accessible${NC}"
else
    echo -e "${RED}✗ Ollama API is not accessible${NC}"
    echo "Please check Ollama container logs: docker logs evidenceos-ollama"
    exit 1
fi

# Pull essential models
echo ""
echo -e "${YELLOW}[3/5] Installing essential models...${NC}"
echo "This will download ~5GB of data. Please be patient..."
echo ""

# Llama 3 (8B) - General purpose
echo "Pulling llama3 (8B) - General purpose model..."
docker exec evidenceos-ollama ollama pull llama3

# Nomic Embed - Embeddings
echo ""
echo "Pulling nomic-embed-text - Embeddings model..."
docker exec evidenceos-ollama ollama pull nomic-embed-text

# Optional: BioMistral
read -p "Do you want to install BioMistral (7B) for biomedical text? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Pulling biomistral..."
    docker exec evidenceos-ollama ollama pull biomistral
fi

# List installed models
echo ""
echo -e "${YELLOW}[4/5] Installed models:${NC}"
docker exec evidenceos-ollama ollama list

# Test model with simple query
echo ""
echo -e "${YELLOW}[5/5] Testing Llama 3 model...${NC}"
RESPONSE=$(docker exec evidenceos-ollama ollama run llama3 "What is meta-analysis? Answer in one sentence.")
echo "Response: $RESPONSE"

# Summary
echo ""
echo "=================================================="
echo -e "${GREEN}✓ Ollama Setup Complete!${NC}"
echo "=================================================="
echo ""
echo "Available models:"
docker exec evidenceos-ollama ollama list
echo ""
echo "Usage examples:"
echo "  1. List models:        docker exec evidenceos-ollama ollama list"
echo "  2. Test model:         docker exec evidenceos-ollama ollama run llama3 'Your prompt'"
echo "  3. Pull more models:   docker exec evidenceos-ollama ollama pull mistral"
echo ""
echo "Python integration:"
echo "  from ai.ollama_client import OllamaClient"
echo "  client = OllamaClient()"
echo "  response = client.generate('llama3', 'Your prompt')"
echo ""
echo "Next steps:"
echo "  - See OLLAMA_INTEGRATION_GUIDE.md for detailed usage"
echo "  - Run validation tests: python backend/ai/ollama_client.py"
echo "  - Integrate with R Shiny frontend"
echo ""

# Calculate storage used
STORAGE=$(docker exec evidenceos-ollama du -sh /root/.ollama 2>/dev/null | cut -f1)
echo "Storage used by models: ${STORAGE}"
echo ""

echo "For support, see: OLLAMA_INTEGRATION_GUIDE.md"
