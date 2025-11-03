# EvidenceOS PRIME - Deployment Guide

Complete guide for deploying EvidenceOS PRIME with AI Copilot in development and production environments.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start (Development)](#quick-start-development)
3. [Production Deployment](#production-deployment)
4. [Security Configuration](#security-configuration)
5. [Monitoring and Logging](#monitoring-and-logging)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Docker** (v20.10+) and **Docker Compose** (v2.0+)
- **Git**
- At least **4GB RAM** and **10GB disk space**

### Optional for Local Development

- **R** (v4.3+) with packages: shiny, bslib, metafor, netmeta, etc.
- **Python** (v3.11+) with FastAPI and dependencies

---

## Quick Start (Development)

### 1. Clone the Repository

```bash
git clone https://github.com/mahmood726-cyber/Metanew.git
cd Metanew
```

### 2. Start Services with Docker Compose

```bash
# Build and start all services
docker-compose up --build

# Or run in detached mode
docker-compose up -d --build
```

### 3. Access the Application

- **Shiny Frontend**: http://localhost:3838/evidenceos/
- **AI Copilot API**: http://localhost:8001
- **API Documentation**: http://localhost:8001/docs

### 4. Stop Services

```bash
docker-compose down

# To also remove volumes
docker-compose down -v
```

---

## Production Deployment

### 1. Environment Configuration

Create a `.env` file in the project root:

```bash
# Application Settings
APP_ENV=production
LOG_LEVEL=warning

# Security
ALLOWED_ORIGINS=https://yourdomain.com
API_RATE_LIMIT=10/minute

# AI Copilot
AI_BACKEND_URL=http://ai-backend:8001
LLM_MODEL_PATH=/models/llama-7b-q4.gguf  # Optional

# Database (if using)
# POSTGRES_URL=postgresql://user:pass@db:5432/evidenceos
```

### 2. SSL/TLS Configuration

Generate SSL certificates (use Let's Encrypt for production):

```bash
mkdir -p nginx/ssl
# For testing, generate self-signed certificates:
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem
```

For production, use **certbot**:

```bash
sudo certbot certonly --standalone -d yourdomain.com
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/key.pem
```

### 3. Update nginx Configuration

Edit `nginx/nginx.conf` and uncomment the HTTPS server block:

```nginx
server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # ... rest of configuration
}
```

### 4. Deploy with Production Profile

```bash
# Start with nginx reverse proxy
docker-compose --profile production up -d
```

### 5. Health Checks

```bash
# Check all services are running
docker-compose ps

# Check logs
docker-compose logs -f

# Test health endpoints
curl http://localhost:8001/health
curl http://localhost:3838/evidenceos/
```

---

## Security Configuration

### Rate Limiting

The API enforces the following rate limits per IP address:

- **NLQ endpoint**: 10 requests/minute
- **Interpretation endpoints**: 30 requests/minute
- **Health/root endpoints**: 60 requests/minute

Adjust in `backend/api/nlq.py`:

```python
@limiter.limit("10/minute")  # Change as needed
async def natural_language_query(...):
```

### Input Validation

All user inputs are validated:

- **Query length**: Max 1000 characters
- **Dangerous characters**: `<`, `>`, `{`, `}` blocked
- **Empty queries**: Rejected with 422 error

### CORS Configuration

For production, restrict allowed origins in `backend/api/nlq.py`:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],  # Restrict to your domain
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)
```

### Firewall Rules

Configure firewall to allow only necessary ports:

```bash
# Example with ufw (Ubuntu)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 3838/tcp  # Block direct Shiny access
sudo ufw deny 8001/tcp  # Block direct API access
sudo ufw enable
```

---

## Monitoring and Logging

### Docker Logs

```bash
# View all logs
docker-compose logs -f

# View specific service
docker-compose logs -f shiny-frontend
docker-compose logs -f ai-backend

# View last 100 lines
docker-compose logs --tail=100 ai-backend
```

### Health Monitoring

Set up automated health checks:

```bash
#!/bin/bash
# health_monitor.sh

while true; do
  if ! curl -sf http://localhost:8001/health > /dev/null; then
    echo "$(date): AI Backend is DOWN!" | tee -a /var/log/evidenceos-health.log
    # Send alert (email, Slack, etc.)
  fi

  if ! curl -sf http://localhost:3838/evidenceos/ > /dev/null; then
    echo "$(date): Shiny Frontend is DOWN!" | tee -a /var/log/evidenceos-health.log
  fi

  sleep 60
done
```

### Application Metrics

The `/health` endpoint provides status information:

```bash
curl http://localhost:8001/health
# {
#   "status": "healthy",
#   "llm_available": false,
#   "llm_model": null,
#   "version": "4.0.0"
# }
```

---

## Troubleshooting

### Issue: Containers fail to start

**Solution**: Check Docker logs

```bash
docker-compose logs
```

Common causes:
- Port conflicts (3838 or 8001 already in use)
- Insufficient memory
- Missing dependencies

### Issue: Shiny app shows error "Cannot connect to API"

**Solution**:

1. Check AI backend is running:
```bash
curl http://localhost:8001/health
```

2. Check network connectivity:
```bash
docker network inspect evidenceos-network
```

3. Update `frontend/modules/ai_copilot.R` API URL:
```r
textInput(ns("api_url"), "API Endpoint",
          value = "http://localhost:8001")  # For development
```

### Issue: Rate limit errors

**Solution**: Increase rate limits or wait 1 minute before retrying.

```python
# In backend/api/nlq.py
@limiter.limit("20/minute")  # Increased from 10
```

### Issue: Permission denied errors in outputs directory

**Solution**: Fix permissions

```bash
sudo chown -R 999:999 frontend/outputs
sudo chmod 755 frontend/outputs
```

### Issue: Tests fail

**Solution**: Run tests with proper dependencies

```bash
# Python tests
cd backend/api
pip install -r requirements.txt
pytest test_nlq_api.py -v

# R tests (if available)
cd frontend
Rscript -e "testthat::test_dir('tests')"
```

### Issue: Docker build fails for frontend

**Solution**: Increase Docker memory

```bash
# In Docker Desktop: Settings > Resources > Memory > 4GB minimum
```

Or build without cache:

```bash
docker-compose build --no-cache shiny-frontend
```

---

## Performance Tuning

### FastAPI Workers

Increase workers for better concurrency:

```dockerfile
# In backend/api/Dockerfile
CMD ["uvicorn", "nlq:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "4"]
```

### Shiny Resource Limits

```yaml
# In docker-compose.yml
shiny-frontend:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
```

### Nginx Worker Processes

```nginx
# In nginx/nginx.conf
worker_processes 4;  # Match CPU cores
```

---

## Backup and Recovery

### Backup User Data

```bash
# Backup outputs and uploads
tar -czf evidenceos-backup-$(date +%Y%m%d).tar.gz \
  frontend/outputs \
  frontend/data/uploads
```

### Restore from Backup

```bash
tar -xzf evidenceos-backup-20250103.tar.gz
```

---

## Updating the Application

### Pull Latest Changes

```bash
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose up -d --build
```

### Database Migrations (if applicable)

```bash
# If using database in future versions
docker-compose exec ai-backend python -m alembic upgrade head
```

---

## Support and Documentation

- **GitHub Issues**: https://github.com/mahmood726-cyber/Metanew/issues
- **API Documentation**: http://localhost:8001/docs
- **Test Coverage**: Run `pytest test_nlq_api.py -v` (37 tests)

---

## License

Copyright © 2025 EvidenceOS PRIME. All rights reserved.
