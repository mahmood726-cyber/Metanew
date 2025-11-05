# EvidenceOS PRIME - Load Testing

Comprehensive load testing setup using Locust for performance validation and capacity planning.

## 📊 Overview

This load testing suite simulates realistic user behavior and measures system performance under various load conditions:

- **User Types**: Regular users and admin users with different task patterns
- **Test Scenarios**: Study uploads, meta-analysis, ML predictions, RAG queries, cache performance
- **Metrics**: Response times, throughput, error rates, resource utilization
- **Scalability**: Distributed load testing with master-worker architecture

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose installed
- At least 8GB RAM available
- Backend service configured and ready

### Run Load Test (Docker)

```bash
# From the load-testing directory
cd load-testing

# Start load testing environment
docker-compose up -d

# Access Locust Web UI
open http://localhost:8089
```

### Run Load Test (Local)

```bash
# Install dependencies
pip install -r requirements.txt

# Start backend (if not running)
cd ../backend
python main.py

# Run Locust
cd ../load-testing
locust -f locustfile.py --host=http://localhost:8000
```

## 🎯 Test Scenarios

### 1. EvidenceOSUser (Main User Class)

Simulates typical researchers using the platform:

**High Frequency Tasks (weight 8-10):**
- Health checks (10)
- Study uploads (8)
- RAG queries (8)

**Medium Frequency Tasks (weight 5-7):**
- Meta-analysis (7)
- Get studies list (6)
- RAG document upload (5)
- Ensemble predictions (5)

**Low Frequency Tasks (weight 2-4):**
- AutoML training (4)
- Get study by ID (4)
- Cache performance tests (3)
- Knowledge graph queries (2)
- Study deduplication (2)

### 2. AdminUser

Simulates administrators monitoring system health:

**Tasks:**
- View Prometheus metrics (weight 5)
- Detailed health checks (weight 3)
- System metrics (weight 2)
- Admin statistics (weight 1)

## 📈 Using Locust Web UI

### Starting a Test

1. Open http://localhost:8089
2. Configure test parameters:
   - **Number of users**: Start with 10-50
   - **Spawn rate**: 1-5 users per second
   - **Host**: http://backend:8000 (Docker) or http://localhost:8000 (local)
3. Click "Start swarming"

### Monitoring Results

**Statistics Tab:**
- Request counts and failures
- Response times (min, median, max, p95, p99)
- Requests per second (RPS)
- Average response size

**Charts Tab:**
- Total requests per second
- Response times over time
- Number of active users

**Failures Tab:**
- Detailed error messages
- Failure counts by endpoint

**Download Data:**
- Download CSV reports for analysis
- Export statistics and exceptions

## 🔬 Test Scenarios

### Scenario 1: Baseline Performance

**Goal**: Establish baseline metrics under normal load

```bash
# 10 users, 1 user/sec spawn rate, 5 minutes
locust -f locustfile.py --host=http://localhost:8000 \
       --users 10 --spawn-rate 1 --run-time 5m --headless \
       --html reports/baseline.html
```

**Expected Results:**
- Response time p95 < 500ms (most endpoints)
- Response time p95 < 2s (ML endpoints)
- Error rate < 1%
- RPS: 50-100

### Scenario 2: Load Testing

**Goal**: Test system under expected production load

```bash
# 50 users, 5 users/sec spawn rate, 10 minutes
locust -f locustfile.py --host=http://localhost:8000 \
       --users 50 --spawn-rate 5 --run-time 10m --headless \
       --html reports/load.html
```

**Expected Results:**
- Response time p95 < 1s (most endpoints)
- Response time p95 < 5s (ML endpoints)
- Error rate < 2%
- RPS: 200-400

### Scenario 3: Stress Testing

**Goal**: Find breaking point and system limits

```bash
# 200 users, 10 users/sec spawn rate, 15 minutes
locust -f locustfile.py --host=http://localhost:8000 \
       --users 200 --spawn-rate 10 --run-time 15m --headless \
       --html reports/stress.html
```

**Expected Results:**
- Identify resource bottlenecks (CPU, memory, database)
- Find maximum sustainable RPS
- Observe degradation patterns

### Scenario 4: Spike Testing

**Goal**: Test system recovery from sudden traffic spikes

```bash
# Ramp up: 0 → 100 users in 10 seconds
# Sustain: 100 users for 5 minutes
# Ramp down: 100 → 0 users in 10 seconds
locust -f locustfile.py --host=http://localhost:8000 \
       --users 100 --spawn-rate 10 --run-time 5m --headless \
       --html reports/spike.html
```

**Expected Results:**
- System remains stable during spike
- Fast recovery after spike ends
- No cascading failures

### Scenario 5: Endurance Testing

**Goal**: Verify system stability over extended period

```bash
# 30 users for 2 hours
locust -f locustfile.py --host=http://localhost:8000 \
       --users 30 --spawn-rate 2 --run-time 2h --headless \
       --html reports/endurance.html
```

**Expected Results:**
- No memory leaks
- Consistent performance over time
- No degradation after extended use

## 📊 Performance Targets

### Response Time Targets

| Endpoint Category | p50 | p95 | p99 |
|------------------|-----|-----|-----|
| Health checks | < 50ms | < 100ms | < 200ms |
| Simple queries | < 100ms | < 300ms | < 500ms |
| Study operations | < 200ms | < 500ms | < 1s |
| Meta-analysis | < 500ms | < 2s | < 5s |
| ML predictions | < 1s | < 3s | < 5s |
| AutoML training | < 30s | < 60s | < 120s |
| RAG queries | < 300ms | < 1s | < 2s |

### Throughput Targets

- **Minimum**: 50 RPS (10 concurrent users)
- **Normal**: 200 RPS (50 concurrent users)
- **Peak**: 500 RPS (200 concurrent users)

### Error Rate Targets

- **Normal load**: < 1%
- **High load**: < 2%
- **Stress test**: < 5%

## 🔍 Analyzing Results

### Key Metrics to Review

1. **Response Times**
   - Look at p95 and p99, not just median
   - Identify slow endpoints
   - Check for increasing latency over time

2. **Error Rates**
   - Track by endpoint
   - Identify error patterns
   - Check error types (4xx vs 5xx)

3. **Throughput**
   - Requests per second (RPS)
   - Compare to targets
   - Identify throughput plateaus

4. **Resource Utilization**
   - CPU, memory, disk I/O
   - Database connections
   - Cache hit rates

### Common Issues and Solutions

**High Response Times:**
- Check database query performance
- Review cache hit rates
- Optimize slow endpoints
- Consider adding more workers

**High Error Rates:**
- Check error logs for root cause
- Verify database connection pool
- Check resource limits (connections, file descriptors)
- Review timeout configurations

**Low Throughput:**
- Increase worker processes
- Optimize blocking operations
- Scale horizontally (more instances)
- Optimize database queries

**Memory Growth:**
- Check for memory leaks
- Review cache size limits
- Monitor connection pooling
- Restart workers periodically

## 🛠️ Customizing Tests

### Add New Task

```python
@task(5)  # Weight 5
def my_new_task(self):
    """Description of task."""
    self.client.post(
        "/api/my-endpoint",
        json={"data": "value"},
        name="/api/my-endpoint [POST]"
    )
```

### Adjust Task Weights

Higher weight = more frequent execution:

```python
@task(10)  # Very frequent
def frequent_task(self):
    pass

@task(1)  # Rare
def rare_task(self):
    pass
```

### Custom Wait Time

```python
from locust import constant, constant_pacing

# Fixed wait time (2 seconds between tasks)
wait_time = constant(2)

# Fixed pacing (1 task per second per user)
wait_time = constant_pacing(1)
```

### Add Custom Metrics

```python
from locust import events

@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kwargs):
    if "ml/predict" in name and response_time > 5000:
        print(f"⚠️ Slow ML prediction: {response_time}ms")
```

## 🐛 Troubleshooting

### Locust Won't Start

```bash
# Check Python version (requires 3.7+)
python --version

# Reinstall dependencies
pip install --upgrade -r requirements.txt
```

### Can't Connect to Backend

```bash
# Verify backend is running
curl http://localhost:8000/health

# Check Docker network
docker network inspect loadtest
```

### High Failure Rate

1. Check backend logs: `docker-compose logs backend`
2. Reduce spawn rate: `--spawn-rate 1`
3. Reduce user count: `--users 10`
4. Increase timeouts in locustfile.py

### Workers Not Connecting

```bash
# Check master is running
docker-compose logs locust-master

# Restart workers
docker-compose restart locust-worker-1 locust-worker-2
```

## 📚 Advanced Usage

### Distributed Load Testing

Run master on one machine, workers on multiple machines:

**Master:**
```bash
locust -f locustfile.py --master --host=http://api.example.com
```

**Workers (on different machines):**
```bash
locust -f locustfile.py --worker --master-host=<master-ip>
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Run Load Test
  run: |
    pip install locust
    locust -f load-testing/locustfile.py \
           --host=https://staging.evidenceos.com \
           --users 50 --spawn-rate 5 --run-time 5m \
           --headless --html=loadtest-report.html

- name: Check Performance
  run: |
    # Fail if p95 response time > 2s
    python check_performance.py loadtest-report.html
```

### Custom Reports

```python
import csv

@events.quitting.add_listener
def _(environment, **kwargs):
    """Generate custom CSV report."""
    with open('custom_report.csv', 'w') as f:
        writer = csv.writer(f)
        writer.writerow(['Endpoint', 'Requests', 'Failures', 'Avg RT'])
        for stat in environment.stats.entries.values():
            writer.writerow([
                stat.name,
                stat.num_requests,
                stat.num_failures,
                stat.avg_response_time
            ])
```

## 🔐 Security Considerations

1. **Don't test production without permission**
2. **Use separate test environment**
3. **Limit test data to non-sensitive information**
4. **Monitor resource usage during tests**
5. **Coordinate with ops team for large tests**

## 📖 Additional Resources

- [Locust Documentation](https://docs.locust.io/)
- [Load Testing Best Practices](https://www.locust.io/best-practices)
- [Performance Testing Guide](https://github.com/locustio/locust/wiki/FAQ)

## 🤝 Support

For issues or questions:
1. Review troubleshooting section
2. Check Locust logs: `docker-compose logs`
3. Consult Locust documentation
4. Open an issue in the repository

---

**Note**: Always coordinate load testing with your operations team and ensure you have proper authorization before testing production systems.
