# EvidenceOS PRIME - Production Deployment Guide

**Version:** 2.0 (Secured)
**Last Updated:** 2025-11-04
**Status:** PRODUCTION READY

---

## Overview

This guide covers deployment of EvidenceOS PRIME to production environments with enterprise-grade security, monitoring, and scalability.

## Prerequisites

### Hardware Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **CPU** | 4 cores | 8+ cores | More cores = better concurrent user support |
| **RAM** | 8 GB | 16+ GB | 4GB for Shiny, 4GB for FastAPI, rest for OS/cache |
| **Storage** | 50 GB | 100+ GB SSD | Fast storage improves cache performance |
| **Network** | 100 Mbps | 1 Gbps | For file uploads and report downloads |

### Software Requirements

- **Docker:** 20.10+ and Docker Compose 2.0+
- **Operating System:** Linux (Ubuntu 20.04/22.04 LTS recommended)
- **Database (optional):** PostgreSQL 13+ for user management
- **Reverse Proxy:** Nginx 1.20+ or similar
- **SSL Certificate:** Valid SSL certificate for HTTPS

---

## Installation Steps

### 1. Server Setup

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install required utilities
sudo apt-get install -y git nginx certbot python3-certbot-nginx htop iotop

# Create evidenceos user
sudo useradd -m -s /bin/bash evidenceos
sudo usermod -aG docker evidenceos
```

### 2. Clone and Configure

```bash
# Switch to evidenceos user
sudo su - evidenceos

# Clone repository
git clone https://github.com/your-org/evidenceos-prime.git
cd evidenceos-prime

# Checkout production branch
git checkout main

# Create environment file
cp .env.example .env
```

### 3. Configure Environment Variables

Edit `.env`:

```bash
# API Configuration
API_BASE_URL=https://api.yourdomain.com
SECRET_KEY=<generate-strong-random-key-here>  # Use: openssl rand -hex 32

# Database (if using PostgreSQL)
DATABASE_URL=postgresql://evidenceos:password@localhost:5432/evidenceos_db

# CORS Origins (comma-separated)
ALLOWED_ORIGINS=https://app.yourdomain.com,https://yourdomain.com

# Security
ENABLE_RATE_LIMITING=true
MAX_UPLOAD_SIZE_MB=100

# R Shiny
SHINY_LOG_LEVEL=INFO
SHINY_PORT=3838

# Monitoring
SENTRY_DSN=<your-sentry-dsn>  # Optional: for error tracking
```

### 4. SSL Certificate Setup

```bash
# Using Let's Encrypt (free)
sudo certbot certonly --nginx -d yourdomain.com -d www.yourdomain.com -d api.yourdomain.com

# Certificates will be in /etc/letsencrypt/live/yourdomain.com/
```

### 5. Nginx Configuration

Create `/etc/nginx/sites-available/evidenceos`:

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# Main Application (Shiny)
server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=app_limit:10m rate=10r/s;
    limit_req zone=app_limit burst=20 nodelay;

    # Max upload size
    client_max_body_size 100M;

    # Proxy to Shiny
    location / {
        proxy_pass http://localhost:3838;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}

# API Server (FastAPI)
server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    # SSL Configuration (same as above)
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # Rate Limiting (more restrictive for API)
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=5r/s;
    limit_req zone=api_limit burst=10 nodelay;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable site:

```bash
sudo ln -s /etc/nginx/sites-available/evidenceos /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. Build and Start Services

```bash
# Build Docker images
docker-compose -f docker-compose.prod.yml build

# Start services
docker-compose -f docker-compose.prod.yml up -d

# Check logs
docker-compose -f docker-compose.prod.yml logs -f

# Verify health
curl https://api.yourdomain.com/health
curl https://yourdomain.com/
```

---

## Security Configuration

### 1. Change Default Credentials

**CRITICAL:** Change default admin password immediately!

```python
# In backend/api/security.py, update:
USERS_DB = {
    "admin": {
        "username": "admin",
        "hashed_password": hashlib.sha256("YOUR_SECURE_PASSWORD".encode()).hexdigest(),
        "role": "admin",
        "email": "admin@yourdomain.com"
    }
}
```

Better: Use PostgreSQL for user management (see Section 5).

### 2. Generate Strong Secret Key

```bash
# Generate 256-bit secret key
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Add to .env
SECRET_KEY=<generated-key>
```

### 3. Configure CORS

Edit `.env`:

```bash
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

### 4. Enable Firewall

```bash
# UFW (Ubuntu)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# Block direct access to application ports
sudo ufw deny 3838/tcp   # Shiny (only via Nginx)
sudo ufw deny 8000/tcp   # FastAPI (only via Nginx)
```

### 5. Database Setup (Recommended for Production)

```bash
# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql

CREATE DATABASE evidenceos_db;
CREATE USER evidenceos WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE evidenceos_db TO evidenceos;
\q

# Update .env
DATABASE_URL=postgresql://evidenceos:your-secure-password@localhost:5432/evidenceos_db
```

---

## Monitoring and Logging

### 1. Application Logs

```bash
# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Export logs
docker-compose -f docker-compose.prod.yml logs > evidenceos_logs_$(date +%Y%m%d).txt
```

### 2. System Monitoring

```bash
# Install monitoring tools
sudo apt-get install -y prometheus grafana

# Monitor Docker containers
docker stats

# Monitor system resources
htop
iotop
```

### 3. Error Tracking (Optional)

Configure Sentry for error tracking:

```python
# In backend/api/main_secured.py, add:
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

sentry_sdk.init(
    dsn="YOUR_SENTRY_DSN",
    integrations=[FastApiIntegration()],
    traces_sample_rate=0.1
)
```

---

## Backup and Disaster Recovery

### 1. Automated Backups

Create `/home/evidenceos/backup.sh`:

```bash
#!/bin/bash

BACKUP_DIR="/var/backups/evidenceos"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup data volumes
docker run --rm \
  -v evidenceos_outputs:/data \
  -v $BACKUP_DIR:/backup \
  ubuntu tar czf /backup/outputs_$DATE.tar.gz -C /data .

docker run --rm \
  -v evidenceos_uploads:/data \
  -v $BACKUP_DIR:/backup \
  ubuntu tar czf /backup/uploads_$DATE.tar.gz -C /data .

# Backup database (if using PostgreSQL)
pg_dump -U evidenceos evidenceos_db | gzip > $BACKUP_DIR/database_$DATE.sql.gz

# Backup configuration
tar czf $BACKUP_DIR/config_$DATE.tar.gz /home/evidenceos/evidenceos-prime/.env

# Delete backups older than 30 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
```

Schedule with cron:

```bash
chmod +x /home/evidenceos/backup.sh
crontab -e

# Add: Daily backup at 2 AM
0 2 * * * /home/evidenceos/backup.sh >> /var/log/evidenceos_backup.log 2>&1
```

### 2. Disaster Recovery Plan

1. **Backup Verification:** Test backups monthly
2. **Recovery Time Objective (RTO):** 4 hours
3. **Recovery Point Objective (RPO):** 24 hours
4. **Off-site Backups:** Copy backups to S3/Azure Blob Storage

---

## Scaling and Performance

### 1. Horizontal Scaling (Multiple Instances)

Use Docker Swarm or Kubernetes for multi-server deployment:

```yaml
# docker-compose.swarm.yml
version: '3.8'

services:
  shiny-frontend:
    image: evidenceos-shiny-frontend:latest
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '2'
          memory: 4G
      restart_policy:
        condition: on-failure

  ai-backend:
    image: evidenceos-ai-backend:latest
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 2G
```

### 2. Load Balancing

Configure Nginx for load balancing:

```nginx
upstream shiny_backend {
    least_conn;
    server shiny1:3838;
    server shiny2:3838;
    server shiny3:3838;
}

server {
    location / {
        proxy_pass http://shiny_backend;
    }
}
```

### 3. Caching

- **Parquet Cache:** Already implemented, ensure cache directory has enough space
- **Nginx Caching:** Add for static assets
- **Redis:** Optional for session management (future enhancement)

---

## Maintenance

### 1. Updates

```bash
# Pull latest code
cd /home/evidenceos/evidenceos-prime
git pull origin main

# Rebuild and restart
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d

# Verify
curl https://api.yourdomain.com/health
```

### 2. SSL Certificate Renewal

Certbot auto-renews, but verify:

```bash
# Test renewal
sudo certbot renew --dry-run

# Force renewal (if needed)
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

### 3. Log Rotation

Create `/etc/logrotate.d/evidenceos`:

```
/var/log/evidenceos/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 evidenceos evidenceos
    sharedscripts
    postrotate
        docker-compose -f /home/evidenceos/evidenceos-prime/docker-compose.prod.yml restart
    endscript
}
```

---

## Troubleshooting

### Issue: Container Won't Start

```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs [service-name]

# Check port conflicts
sudo netstat -tulpn | grep -E ':(3838|8000)'

# Rebuild from scratch
docker-compose -f docker-compose.prod.yml down -v
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d
```

### Issue: High Memory Usage

```bash
# Check memory
docker stats

# Restart service
docker-compose -f docker-compose.prod.yml restart shiny-frontend

# Increase memory limits in docker-compose.prod.yml
```

### Issue: Slow Performance

1. Check CPU/memory usage: `htop`
2. Check disk I/O: `iotop`
3. Check cache size: `du -sh /home/evidenceos/evidenceos-prime/cache`
4. Review logs for errors
5. Consider horizontal scaling

---

## Security Checklist

- [ ] Changed default admin password
- [ ] Generated strong SECRET_KEY
- [ ] Configured CORS with specific origins (not "*")
- [ ] Enabled HTTPS with valid SSL certificate
- [ ] Configured firewall (UFW/iptables)
- [ ] Disabled direct access to application ports
- [ ] Set up automated backups
- [ ] Configured log rotation
- [ ] Enabled rate limiting in Nginx
- [ ] Set max_upload_size limits
- [ ] Configured security headers
- [ ] Set up monitoring and alerting
- [ ] Documented disaster recovery plan
- [ ] Tested backup restoration
- [ ] Configured database with authentication
- [ ] Reviewed and hardened Docker images

---

## Support

- **Documentation:** https://docs.evidenceos.com
- **Issues:** https://github.com/your-org/evidenceos-prime/issues
- **Email:** support@evidenceos.com
- **Phone:** +1 (555) 123-4567 (Business hours: Mon-Fri 9AM-5PM EST)

---

## Appendix

### A. Production docker-compose.yml

See `docker-compose.prod.yml` in repository.

### B. Environment Variables Reference

See `.env.example` in repository.

### C. API Rate Limits

| Endpoint | Rate Limit | Notes |
|----------|------------|-------|
| `/auth/login` | 5/minute | Per IP |
| `/validate` | 30/minute | Per authenticated user |
| `/compute/yi` | 30/minute | Per authenticated user |
| `/econ/params` | 20/minute | Per authenticated user |
| Admin endpoints | 10/minute | Per admin user |

### D. Monitoring Endpoints

- **Health Check:** `GET /health`
- **Metrics:** `GET /metrics` (if Prometheus enabled)
- **Status:** `GET /`

---

**Document Version:** 2.0
**Last Reviewed:** 2025-11-04
**Next Review:** 2026-01-04
