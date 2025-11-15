# EvidenceOS PRIME - Codespaces Configuration

This directory contains the GitHub Codespaces / VS Code Dev Container configuration for EvidenceOS PRIME.

## Quick Start in Codespaces

1. **Open in Codespaces** - Click "Code" → "Create codespace on [branch]"
2. **Wait for container build** - First build takes ~5-10 minutes
3. **Start services**:
   ```bash
   docker-compose up -d
   ```
4. **Access the application**:
   - Shiny Frontend: Port 3838 (auto-forwarded)
   - AI Copilot API: Port 8001 (auto-forwarded)

## What's Configured

- **Docker-in-Docker** - Full Docker support inside Codespaces
- **VS Code Extensions**:
  - R language support
  - Python with Pylance
  - Docker tools
  - YAML editing
- **Port Forwarding**:
  - 3838: Shiny frontend (public)
  - 8001: AI Copilot backend (private)
  - 80: Nginx reverse proxy (production only)

## Development Workflow

### Starting the Application

```bash
# Start all services in background
docker-compose up -d

# View logs
docker-compose logs -f

# Check service health
docker-compose ps
```

### Stopping the Application

```bash
# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Rebuilding After Changes

```bash
# Rebuild specific service
docker-compose up -d --build shiny-frontend

# Rebuild all services
docker-compose up -d --build
```

## Accessing Services

When ports are forwarded, Codespaces provides URLs like:
- `https://[codespace-name]-3838.app.github.dev` - Shiny UI
- `https://[codespace-name]-8001.app.github.dev` - API docs

You can also click on the "Ports" tab in VS Code to see all forwarded ports.

## Troubleshooting

### Services not starting

```bash
# Check Docker is running
docker ps

# Check service logs
docker-compose logs shiny-frontend
docker-compose logs ai-backend
```

### Port conflicts

```bash
# Check what's using ports
ss -tulpn | grep -E ':(3838|8001|80)'

# Kill conflicting processes
docker-compose down
```

### Rebuild from scratch

```bash
# Remove all containers, images, and volumes
docker-compose down -v --rmi all

# Rebuild
docker-compose up -d --build
```

## Files in This Directory

- `devcontainer.json` - Main configuration file
- `README.md` - This file

## Resources

- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Dev Containers Spec](https://containers.dev/)
- [EvidenceOS PRIME Docs](../README.md)
