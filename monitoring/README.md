# EvidenceOS PRIME - Monitoring Stack

Comprehensive monitoring and observability setup using Prometheus, Grafana, and AlertManager.

## 📊 Components

### Prometheus
- **Metrics Collection & Storage**
- Scrapes metrics from backend, Redis, PostgreSQL, and system
- 30-day retention with 50GB storage limit
- Custom alerting rules for proactive monitoring
- Web UI: http://localhost:9090

### Grafana
- **Metrics Visualization**
- Pre-configured dashboards for application and ML metrics
- Real-time monitoring with 10-second refresh
- Default credentials: `admin` / `admin123` (change in production!)
- Web UI: http://localhost:3000

### AlertManager
- **Alert Management & Routing**
- Configurable alert receivers (Email, Slack, PagerDuty)
- Alert grouping and inhibition rules
- Web UI: http://localhost:9093

### Exporters
- **Node Exporter**: System metrics (CPU, memory, disk, network)
- **Redis Exporter**: Redis performance metrics
- **Postgres Exporter**: PostgreSQL database metrics

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose installed
- At least 4GB RAM available
- Ports 3000, 8000, 9090, 9093, 9100, 9121, 9187 available

### Start Monitoring Stack

```bash
# From the monitoring directory
cd monitoring

# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### Access Dashboards

1. **Grafana**: http://localhost:3000
   - Username: `admin`
   - Password: `admin123`
   - Navigate to Dashboards → EvidenceOS

2. **Prometheus**: http://localhost:9090
   - Query metrics directly
   - View targets and alerts

3. **AlertManager**: http://localhost:9093
   - View active alerts
   - Manage silences

4. **Backend API**: http://localhost:8000
   - Health check: http://localhost:8000/health
   - Metrics endpoint: http://localhost:8000/metrics

## 📈 Pre-configured Dashboards

### 1. EvidenceOS Overview (`evidenceos-overview.json`)
Comprehensive application monitoring dashboard with:
- HTTP request rate and latency (p95)
- ML prediction rate and duration
- Cache hit rate and operations
- Database operations and latency
- System resources (CPU, memory, disk)
- ML training jobs status

### 2. EvidenceOS ML/AI Metrics (`evidenceos-ml-metrics.json`)
Detailed ML and AI performance dashboard with:
- ML predictions by model type (Ensemble, XGBoost, AutoML)
- Prediction latency percentiles (p50, p95, p99)
- Training job status and duration
- Training failure rate gauge
- Cache performance by type (RAG, ML)
- Study database operations
- API endpoint usage breakdown

## 🔔 Alert Rules

### Application Alerts
- **HighHTTPErrorRate**: HTTP 5xx error rate > 5%
- **HighHTTPLatency**: p95 latency > 2 seconds
- **ServiceDown**: Backend service unavailable

### ML Alerts
- **HighMLPredictionFailureRate**: Prediction failures > 10%
- **SlowMLPredictions**: p95 prediction time > 5 seconds
- **HighMLTrainingFailureRate**: Training failures > 20%

### Cache Alerts
- **LowCacheHitRate**: Cache hit rate < 50%
- **RedisConnectionIssues**: Redis unavailable

### Database Alerts
- **HighDatabaseLatency**: Average query time > 1 second
- **DatabaseConnectionIssues**: PostgreSQL unavailable

### System Alerts
- **HighCPUUsage**: CPU > 85%
- **HighMemoryUsage**: Memory > 85%
- **HighDiskUsage**: Disk > 90%
- **LowDiskSpace**: Disk > 95% (critical)

### Kubernetes Alerts
- **PodRestartLoop**: Pod restarting frequently
- **PodNotReady**: Pod not in Running phase
- **HPAAtMaxCapacity**: HPA at maximum replicas

## ⚙️ Configuration

### Customize Prometheus Scrape Targets

Edit `prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'your-service'
    static_configs:
      - targets: ['hostname:port']
```

### Configure Alert Notifications

Edit `alertmanager/alertmanager.yml`:

**Email Notifications:**
```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@evidenceos.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'

receivers:
  - name: 'critical'
    email_configs:
      - to: 'oncall@evidenceos.com'
        subject: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
```

**Slack Notifications:**
```yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

receivers:
  - name: 'critical'
    slack_configs:
      - channel: '#alerts-critical'
        title: '🚨 CRITICAL Alert'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### Add Custom Dashboards

1. Create dashboard JSON in `grafana/dashboards/`
2. Restart Grafana: `docker-compose restart grafana`
3. Dashboard will auto-load on next refresh

## 🔍 Useful Queries

### HTTP Metrics
```promql
# Request rate by endpoint
rate(http_requests_total[5m])

# p95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

### ML Metrics
```promql
# Prediction rate by model
rate(ml_predictions_total{model_type="xgboost"}[5m])

# Average prediction duration
rate(ml_prediction_duration_seconds_sum[5m]) / rate(ml_predictions_total[5m])

# Training success rate
sum(rate(ml_training_jobs_total{status="success"}[1h])) / sum(rate(ml_training_jobs_total[1h]))
```

### Cache Metrics
```promql
# Cache hit rate
100 * (cache_hits_total / (cache_hits_total + cache_misses_total))

# Cache operations by type
rate(cache_hits_total{cache_type="rag"}[5m])
```

### System Metrics
```promql
# CPU usage
system_cpu_percent

# Memory usage
system_memory_percent

# Disk usage
system_disk_percent
```

## 🛠️ Maintenance

### Update Retention Policy

Edit `prometheus/prometheus.yml`:
```yaml
storage:
  tsdb:
    retention.time: 30d  # Change as needed
    retention.size: 50GB # Change as needed
```

### Backup Prometheus Data

```bash
# Stop Prometheus
docker-compose stop prometheus

# Backup data directory
docker run --rm -v evidenceos_prometheus-data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz /data

# Restart Prometheus
docker-compose start prometheus
```

### Backup Grafana Dashboards

```bash
# Export dashboards via API
curl -u admin:admin123 http://localhost:3000/api/dashboards/uid/evidenceos-overview -o dashboard-backup.json
```

## 🐛 Troubleshooting

### Prometheus Not Scraping Targets

1. Check target status: http://localhost:9090/targets
2. Verify backend metrics endpoint: http://localhost:8000/metrics
3. Check Docker network connectivity:
   ```bash
   docker-compose exec prometheus ping backend
   ```

### Grafana Dashboards Not Loading

1. Check datasource connection: Grafana → Configuration → Data Sources
2. Verify Prometheus URL: `http://prometheus:9090`
3. Test connection with query in Explore tab

### High Memory Usage

1. Reduce Prometheus retention:
   - Lower `retention.time` or `retention.size`
2. Increase scrape intervals:
   - Change `scrape_interval` in `prometheus.yml`

### Alerts Not Firing

1. Check AlertManager is running: http://localhost:9093
2. Verify alert rules loaded: http://localhost:9090/alerts
3. Check AlertManager logs:
   ```bash
   docker-compose logs alertmanager
   ```

## 📊 Kubernetes Deployment

For production Kubernetes deployment:

1. Use the Kubernetes manifests in `k8s/` directory
2. Configure Prometheus to scrape pods with annotations:
   ```yaml
   prometheus.io/scrape: "true"
   prometheus.io/port: "8000"
   prometheus.io/path: "/metrics"
   ```
3. Install Prometheus Operator for advanced management
4. Use persistent volumes for data retention

## 🔐 Security Best Practices

1. **Change Default Passwords**
   - Grafana admin password
   - PostgreSQL password
   - Update in `docker-compose.yml` and `.env`

2. **Enable Authentication**
   - Configure Grafana OAuth/LDAP
   - Enable Prometheus basic auth
   - Secure AlertManager webhook endpoints

3. **Network Security**
   - Use reverse proxy (NGINX) for public access
   - Enable TLS/SSL certificates
   - Restrict port access with firewall rules

4. **Data Privacy**
   - Avoid logging sensitive data in metrics
   - Use label drop for PII removal
   - Configure data retention policies

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Guide](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)

## 🤝 Support

For issues or questions:
1. Check logs: `docker-compose logs [service-name]`
2. Review troubleshooting section above
3. Consult component documentation
4. Open an issue in the repository

---

**Note**: This monitoring stack is configured for development/testing. For production deployments, implement proper security measures, data backup strategies, and high availability configurations.
