# GitHub Codespaces Setup Guide

This guide explains how to get EvidenceOS PRIME running immediately in GitHub Codespaces.

## Quick Start (1-Click)

1. **Open in Codespaces**
   - Navigate to the GitHub repository
   - Click the green "Code" button
   - Select "Codespaces" tab
   - Click "Create codespace on [your-branch]"

2. **Wait for Setup** (~3-5 minutes first time)
   - Codespace will automatically configure
   - Docker-in-Docker will be set up
   - Extensions will be installed

3. **Start the Application**
   ```bash
   docker-compose up -d
   ```

4. **Access the Services**
   - Look for "Ports" tab in VS Code terminal panel
   - Click the globe icon next to port 3838 to open Shiny UI
   - Port 8001 provides the AI Copilot API

## What Gets Configured Automatically

The `.devcontainer/devcontainer.json` configuration automatically sets up:

### Development Tools
- **Docker-in-Docker**: Full Docker support inside Codespaces
- **Git**: Version control ready to go
- **VS Code Extensions**:
  - R language support (syntax highlighting, REPL)
  - Python with Pylance (IntelliSense, type checking)
  - Docker tools (container management)
  - GitLens (enhanced git capabilities)
  - YAML editor (for config files)

### Port Forwarding
- **Port 3838**: Shiny Frontend (public, auto-notify on forward)
- **Port 8001**: AI Copilot API (private)
- **Port 80**: Nginx reverse proxy (for production mode)

### Environment
- Python 3.11 configured as default interpreter
- R 4.3+ with language server
- All linters and formatters pre-configured

## Using the Application

### Starting Services

```bash
# Start all services in detached mode
docker-compose up -d

# View logs from all services
docker-compose logs -f

# View logs from specific service
docker-compose logs -f shiny-frontend
docker-compose logs -f ai-backend

# Check service status
docker-compose ps
```

### Stopping Services

```bash
# Stop all services (keep data)
docker-compose down

# Stop and remove volumes (fresh start)
docker-compose down -v
```

### Rebuilding After Code Changes

```bash
# Rebuild specific service
docker-compose up -d --build shiny-frontend

# Rebuild everything
docker-compose down
docker-compose up -d --build
```

## Architecture

The application runs as two separate Docker containers:

1. **shiny-frontend** (Port 3838)
   - R Shiny application
   - Interactive UI for meta-analysis
   - Connects to AI backend via internal network

2. **ai-backend** (Port 8001)
   - FastAPI Python service
   - Natural language query processing
   - Rate limiting and caching

3. **nginx** (Port 80) - Optional, production only
   - Reverse proxy
   - Load balancing
   - Only starts with `--profile production`

## Accessing Forwarded Ports

When Codespaces forwards a port, you get a URL like:
```
https://[codespace-name]-3838.app.github.dev
```

### Making Ports Public

By default, forwarded ports are private (require GitHub authentication). To make them public:

1. Click on "Ports" tab in VS Code
2. Right-click the port (e.g., 3838)
3. Select "Port Visibility" → "Public"

This allows you to share the URL with others.

## Development Workflow

### Editing R Shiny Code

1. Navigate to `frontend/` directory
2. Edit files in `frontend/app.R` or `frontend/modules/`
3. Rebuild: `docker-compose up -d --build shiny-frontend`
4. Refresh browser to see changes

### Editing Python API Code

1. Navigate to `backend/api/` directory
2. Edit `nlq.py` for AI Copilot or `main.py` for main API
3. Rebuild: `docker-compose up -d --build ai-backend`
4. API will automatically reload

### Working with Data

Sample data is in `/data/` directory:
- `sample_binary.csv` - Binary outcomes
- `sample_continuous.csv` - Continuous outcomes
- `sample_tte.csv` - Time-to-event data

Upload your own data through the Shiny UI (Data tab).

## Troubleshooting

### Services Won't Start

**Check Docker is running:**
```bash
docker ps
```

**Check for port conflicts:**
```bash
ss -tulpn | grep -E ':(3838|8001)'
```

**View container logs:**
```bash
docker-compose logs ai-backend
docker-compose logs shiny-frontend
```

### Health Check Failures

**AI Backend health check:**
```bash
curl http://localhost:8001/health
```

**Shiny Frontend health check:**
```bash
curl http://localhost:3838/evidenceos/
```

### Port Not Forwarding

1. Check "Ports" tab in VS Code
2. Verify service is running: `docker-compose ps`
3. Check firewall: `docker-compose logs nginx`

### Out of Memory

Codespaces has memory limits. If you encounter OOM errors:

```bash
# Check memory usage
docker stats

# Restart with lower resource limits
docker-compose down
docker-compose up -d
```

### Complete Reset

If everything is broken, reset completely:

```bash
# Stop all containers and remove everything
docker-compose down -v --rmi all

# Clean Docker system
docker system prune -af

# Rebuild from scratch
docker-compose up -d --build
```

## Tips & Best Practices

### 1. Use Docker Compose for Everything

Don't manually run `docker run`. Always use `docker-compose` to ensure services are networked correctly.

### 2. Check Logs First

When debugging, always check logs:
```bash
docker-compose logs -f --tail=50
```

### 3. Rebuild After Dependency Changes

If you modify `requirements.txt` or R package installations:
```bash
docker-compose up -d --build
```

### 4. Use Volumes for Persistence

Your outputs and uploads are stored in Docker volumes. They persist across rebuilds unless you use `docker-compose down -v`.

### 5. Keep Codespace Running

Codespaces auto-suspend after 30 minutes of inactivity (default). Increase timeout in Settings → Codespaces.

## Cost Considerations

- **Free tier**: 120 core-hours/month for Free plan
- **2-core Codespace**: ~60 hours of usage
- **4-core Codespace**: ~30 hours of usage

**Recommendation**: Use 2-core for development, 4-core for heavy R computations.

## Advanced: Customizing the Devcontainer

Edit `.devcontainer/devcontainer.json` to:

- Add more VS Code extensions
- Change port forwarding behavior
- Add post-create commands
- Configure environment variables

Example - Add more R packages:
```json
"postCreateCommand": "R -e 'install.packages(\"tidyverse\")'"
```

## Resources

- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Dev Containers Specification](https://containers.dev/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [EvidenceOS PRIME README](./README.md)

## Getting Help

If you encounter issues:

1. Check logs: `docker-compose logs -f`
2. Review this troubleshooting guide
3. Open an issue on GitHub
4. Check [QUICKSTART.md](./QUICKSTART.md) for alternative setup methods

---

**Ready to start analyzing! Access your Shiny app at the forwarded port 3838.**
