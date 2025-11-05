# EvidenceOS PRIME - Production Runbook

## Table of Contents
1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Deployment Procedures](#deployment-procedures)
3. [Monitoring & Alerts](#monitoring--alerts)
4. [Backup & Recovery](#backup--recovery)
5. [Incident Response](#incident-response)
6. [Scaling Procedures](#scaling-procedures)
7. [Security Procedures](#security-procedures)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Pre-Deployment Checklist

### Security Configuration
- [ ] Change all default passwords (admin, analyst, database, Redis)
- [ ] Generate new JWT_SECRET_KEY: `python -c "import secrets; print(secrets.token_urlsafe(32))"`
- [ ] Configure ALLOWED_ORIGINS with actual production domains (never use "*")
- [ ] Set APP_ENV=production
- [ ] Set ENABLE_AUTH=true
- [ ] Configure TRUSTED_HOSTS with production domains
- [ ] Enable HTTPS (FORCE_HTTPS=true)
- [ ] Configure SSL/TLS certificates
- [ ] Review and restrict CORS settings
- [ ] Enable security headers (CSP, HSTS, X-Frame-Options)

### Database Configuration
- [ ] Set up PostgreSQL database with strong password
- [ ] Configure connection pooling (DB_POOL_SIZE, DB_MAX_OVERFLOW)
- [ ] Run database migrations: `alembic upgrade head`
- [ ] Create database backups directory
- [ ] Configure automated backup schedule
- [ ] Test database restore procedure

### Redis Configuration
- [ ] Set up Redis with authentication (REDIS_PASSWORD)
- [ ] Configure Redis persistence (RDB + AOF)
- [ ] Set memory limits and eviction policy
- [ ] Test Redis connection and caching

### Monitoring Setup
- [ ] Configure Prometheus metrics endpoint
- [ ] Set up Grafana dashboards
- [ ] Configure Sentry error tracking (SENTRY_DSN)
- [ ] Set up log aggregation (ELK stack or equivalent)
- [ ] Configure health check monitoring
- [ ] Set up alerting (PagerDuty, Slack, email)

### Environment Variables
- [ ] Create production .env file from .env.example
- [ ] Verify all required environment variables are set
- [ ] Store secrets in secure secret manager (AWS Secrets Manager, HashiCorp Vault)
- [ ] Never commit .env to version control

### Testing
- [ ] Run full test suite: `pytest tests/ -v`
- [ ] Run security scans: `bandit -r backend/`
- [ ] Run Docker vulnerability scan: `trivy image evidenceos:latest`
- [ ] Perform load testing
- [ ] Test backup and restore procedures
- [ ] Test disaster recovery procedures

### Documentation
- [ ] Update API documentation
- [ ] Review user documentation
- [ ] Document architecture changes
- [ ] Update runbook with any new procedures
- [ ] Document all configuration changes

---

## Deployment Procedures

### Initial Deployment

#### 1. Prepare Infrastructure
```bash
# Create Docker network
docker network create evidenceos-network

# Create volumes for persistent data
docker volume create evidenceos-postgres-data
docker volume create evidenceos-redis-data
docker volume create evidenceos-outputs
docker volume create evidenceos-backups
```

#### 2. Deploy PostgreSQL
```bash
docker run -d \
  --name evidenceos-postgres \
  --network evidenceos-network \
  -v evidenceos-postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=${DB_USER} \
  -e POSTGRES_PASSWORD=${DB_PASSWORD} \
  -e POSTGRES_DB=${DB_NAME} \
  -p 5432:5432 \
  --restart unless-stopped \
  postgres:15
```

#### 3. Deploy Redis
```bash
docker run -d \
  --name evidenceos-redis \
  --network evidenceos-network \
  -v evidenceos-redis-data:/data \
  -e REDIS_PASSWORD=${REDIS_PASSWORD} \
  -p 6379:6379 \
  --restart unless-stopped \
  redis:7 redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
```

#### 4. Run Database Migrations
```bash
# Inside backend container or locally
alembic upgrade head
```

#### 5. Deploy Backend API
```bash
docker run -d \
  --name evidenceos-backend \
  --network evidenceos-network \
  -v evidenceos-outputs:/app/outputs \
  --env-file .env \
  -p 8000:8000 \
  --restart unless-stopped \
  evidenceos-backend:latest
```

#### 6. Deploy Frontend (Shiny)
```bash
docker run -d \
  --name evidenceos-frontend \
  --network evidenceos-network \
  --env-file .env \
  -p 3838:3838 \
  --restart unless-stopped \
  evidenceos-frontend:latest
```

#### 7. Deploy Nginx (Reverse Proxy)
```bash
docker run -d \
  --name evidenceos-nginx \
  --network evidenceos-network \
  -v /path/to/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /path/to/ssl:/etc/nginx/ssl:ro \
  -p 80:80 \
  -p 443:443 \
  --restart unless-stopped \
  nginx:alpine
```

#### 8. Verify Deployment
```bash
# Check all containers are running
docker ps

# Test health endpoints
curl https://your-domain.com/api/health
curl https://your-domain.com/

# Check logs
docker logs evidenceos-backend
docker logs evidenceos-frontend

# Run smoke tests
./scripts/smoke-tests.sh
```

### Rolling Updates (Zero Downtime)

#### Backend Update
```bash
# Build new image
docker build -t evidenceos-backend:new -f backend/api/Dockerfile .

# Start new container
docker run -d \
  --name evidenceos-backend-new \
  --network evidenceos-network \
  --env-file .env \
  -p 8001:8000 \
  evidenceos-backend:new

# Wait for new container to be healthy
sleep 10
curl http://localhost:8001/health

# Update Nginx to point to new container
# Update upstream in nginx.conf and reload
docker exec evidenceos-nginx nginx -s reload

# Stop old container
docker stop evidenceos-backend

# Remove old container
docker rm evidenceos-backend

# Rename new container
docker rename evidenceos-backend-new evidenceos-backend
```

---

## Monitoring & Alerts

### Key Metrics to Monitor

#### Application Metrics
- Request rate (requests/second)
- Response time (p50, p95, p99)
- Error rate (%)
- Active users
- Analysis duration
- Cache hit rate

#### System Metrics
- CPU usage (%)
- Memory usage (%)
- Disk usage (%)
- Network I/O
- Database connections
- Redis memory usage

#### Business Metrics
- Analyses completed
- Reports generated
- User registrations
- Active projects

### Health Checks

#### API Health Check
```bash
curl https://your-domain.com/api/health
# Expected: {"status": "healthy", ...}
```

#### Database Health Check
```bash
docker exec evidenceos-postgres pg_isready
# Expected: accepting connections
```

#### Redis Health Check
```bash
docker exec evidenceos-redis redis-cli ping
# Expected: PONG
```

### Alerting Rules

#### Critical Alerts (Page Immediately)
- API down (health check fails for 2 minutes)
- Database down
- Disk usage > 90%
- Error rate > 5%
- Memory usage > 95%

#### Warning Alerts (Email/Slack)
- Response time p95 > 2 seconds
- CPU usage > 80% for 5 minutes
- Disk usage > 75%
- Cache hit rate < 70%
- Failed backups

#### Info Alerts (Log Only)
- New user registration
- Large analysis completed
- Configuration changes

---

## Backup & Recovery

### Automated Backups

#### Database Backup Script
```bash
#!/bin/bash
# /opt/evidenceos/scripts/backup-database.sh

BACKUP_DIR="/backups/evidenceos/database"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/evidenceos_${TIMESTAMP}.sql.gz"

# Create backup
docker exec evidenceos-postgres pg_dump \
  -U ${DB_USER} ${DB_NAME} | gzip > ${BACKUP_FILE}

# Upload to S3 (optional)
aws s3 cp ${BACKUP_FILE} s3://evidenceos-backups/database/

# Clean old backups (keep last 30 days)
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: ${BACKUP_FILE}"
```

#### Redis Backup
```bash
#!/bin/bash
# Redis automatically persists data with AOF and RDB

# Copy RDB snapshot
docker exec evidenceos-redis redis-cli --no-auth-warning \
  -a ${REDIS_PASSWORD} BGSAVE

sleep 5

# Copy dump file
docker cp evidenceos-redis:/data/dump.rdb \
  /backups/evidenceos/redis/dump_$(date +%Y%m%d_%H%M%S).rdb
```

#### Application Data Backup
```bash
#!/bin/bash
# Backup outputs and uploads

BACKUP_DIR="/backups/evidenceos/data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Tar outputs directory
tar -czf ${BACKUP_DIR}/outputs_${TIMESTAMP}.tar.gz \
  /var/lib/evidenceos/outputs

# Clean old backups
find ${BACKUP_DIR} -name "*.tar.gz" -mtime +7 -delete
```

#### Backup Schedule (Cron)
```cron
# Add to crontab
# Database backup: Every day at 2 AM
0 2 * * * /opt/evidenceos/scripts/backup-database.sh >> /var/log/evidenceos/backup.log 2>&1

# Redis backup: Every 6 hours
0 */6 * * * /opt/evidenceos/scripts/backup-redis.sh >> /var/log/evidenceos/backup.log 2>&1

# Application data: Every day at 3 AM
0 3 * * * /opt/evidenceos/scripts/backup-data.sh >> /var/log/evidenceos/backup.log 2>&1
```

### Recovery Procedures

#### Database Recovery
```bash
# Stop application
docker stop evidenceos-backend evidenceos-frontend

# Restore database
gunzip < /backups/evidenceos/database/evidenceos_20250101_020000.sql.gz | \
  docker exec -i evidenceos-postgres psql -U ${DB_USER} ${DB_NAME}

# Run any missing migrations
docker exec evidenceos-backend alembic upgrade head

# Start application
docker start evidenceos-backend evidenceos-frontend

# Verify
curl https://your-domain.com/api/health
```

#### Redis Recovery
```bash
# Stop Redis
docker stop evidenceos-redis

# Restore dump file
docker cp /backups/evidenceos/redis/dump_20250101_020000.rdb \
  evidenceos-redis:/data/dump.rdb

# Start Redis
docker start evidenceos-redis

# Verify
docker exec evidenceos-redis redis-cli -a ${REDIS_PASSWORD} ping
```

#### Disaster Recovery (Complete System)
```bash
# 1. Provision new infrastructure
# 2. Restore database from backup
# 3. Restore Redis from backup
# 4. Restore application data
# 5. Deploy containers
# 6. Update DNS
# 7. Run smoke tests
# 8. Monitor closely for 24 hours
```

---

## Incident Response

### Severity Levels

#### SEV 1 - Critical (Service Down)
- **Response Time**: 15 minutes
- **Resolution Target**: 2 hours
- **Escalation**: Immediate to on-call engineer

#### SEV 2 - Major (Degraded Performance)
- **Response Time**: 30 minutes
- **Resolution Target**: 4 hours
- **Escalation**: After 1 hour

#### SEV 3 - Minor (Non-Critical Issue)
- **Response Time**: 2 hours
- **Resolution Target**: 24 hours
- **Escalation**: After 8 hours

### Incident Response Checklist

1. **Acknowledge** - Acknowledge the alert
2. **Assess** - Determine severity and impact
3. **Communicate** - Update status page, notify stakeholders
4. **Investigate** - Check logs, metrics, recent changes
5. **Mitigate** - Apply immediate fix or rollback
6. **Resolve** - Fix root cause
7. **Document** - Write postmortem
8. **Follow-up** - Implement preventive measures

### Common Issues & Solutions

#### Issue: API Not Responding
```bash
# Check container status
docker ps -a

# Check logs
docker logs evidenceos-backend --tail 100

# Restart container
docker restart evidenceos-backend

# If still failing, check database and Redis
docker logs evidenceos-postgres
docker logs evidenceos-redis
```

#### Issue: High Memory Usage
```bash
# Check container stats
docker stats

# Check application metrics
curl https://your-domain.com/metrics

# Restart container to free memory
docker restart evidenceos-backend

# Scale horizontally if persistent
# Add more backend instances
```

#### Issue: Database Connection Pool Exhausted
```bash
# Check active connections
docker exec evidenceos-postgres psql -U ${DB_USER} -c \
  "SELECT count(*) FROM pg_stat_activity;"

# Kill idle connections
docker exec evidenceos-postgres psql -U ${DB_USER} -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
   WHERE state = 'idle' AND state_change < now() - interval '5 minutes';"

# Increase pool size in .env
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=40
```

---

## Scaling Procedures

### Vertical Scaling (Increase Resources)

#### Increase Container Resources
```bash
# Update docker-compose.yml or run command
docker run -d \
  --name evidenceos-backend \
  --cpus="2.0" \
  --memory="4g" \
  ...
```

### Horizontal Scaling (Add More Instances)

#### Add Backend Instances
```bash
# Start additional backend instance
docker run -d \
  --name evidenceos-backend-2 \
  --network evidenceos-network \
  --env-file .env \
  -p 8002:8000 \
  evidenceos-backend:latest

# Update Nginx upstream configuration
upstream backend {
    server evidenceos-backend:8000;
    server evidenceos-backend-2:8000;
}
```

#### Database Read Replicas
```bash
# Set up PostgreSQL read replica
# Update connection strings to use read replica for read-only queries
```

---

## Security Procedures

### Security Monitoring
- Monitor failed login attempts
- Monitor unusual API usage patterns
- Monitor unauthorized access attempts
- Review audit logs daily
- Scan for vulnerabilities weekly

### Security Incident Response
1. Isolate affected systems
2. Assess impact and data exposure
3. Notify security team
4. Collect evidence
5. Remediate vulnerability
6. Reset compromised credentials
7. Notify affected users if required
8. Document and review

### Regular Security Tasks

#### Weekly
- Review audit logs
- Check for failed authentication attempts
- Review unusual activity

#### Monthly
- Update dependencies
- Run security scans
- Review access permissions
- Rotate API keys

#### Quarterly
- Security audit
- Penetration testing
- Review and update security policies
- Disaster recovery drill

---

## Troubleshooting Guide

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=DEBUG
docker restart evidenceos-backend

# View detailed logs
docker logs -f evidenceos-backend
```

### Performance Debugging
```bash
# Check slow queries
docker exec evidenceos-postgres psql -U ${DB_USER} -c \
  "SELECT query, mean_time FROM pg_stat_statements
   ORDER BY mean_time DESC LIMIT 10;"

# Check Redis memory
docker exec evidenceos-redis redis-cli --no-auth-warning \
  -a ${REDIS_PASSWORD} INFO memory

# Profile Python application
# Add profiling middleware in code
```

### Log Locations
- Backend API: `docker logs evidenceos-backend`
- Frontend: `docker logs evidenceos-frontend`
- Nginx: `docker logs evidenceos-nginx`
- PostgreSQL: `docker logs evidenceos-postgres`
- Application logs: `/var/log/evidenceos/app.log`

---

## Emergency Contacts

- **On-Call Engineer**: [phone number]
- **System Administrator**: [phone number]
- **Database Administrator**: [phone number]
- **Security Team**: [email]
- **Management**: [phone number]

---

## Related Documentation

- [Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Security Documentation](SECURITY.md)
- [API Documentation](https://your-domain.com/docs)
- [Architecture Overview](ARCHITECTURE.md)

---

**Last Updated**: 2025-01-05
**Version**: 2.0.0
**Maintained By**: DevOps Team
