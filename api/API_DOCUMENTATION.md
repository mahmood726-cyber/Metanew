# ML Evidence Synthesis API Documentation

**Version**: 1.0.0
**Base URL**: `http://localhost:8000` (development) | `https://your-domain.com` (production)

---

## 📚 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Authentication](#authentication)
4. [Endpoints](#endpoints)
5. [Request/Response Examples](#examples)
6. [Error Handling](#error-handling)
7. [Rate Limiting](#rate-limiting)
8. [Deployment](#deployment)
9. [Client Libraries](#client-libraries)

---

## 🎯 Overview

The ML Evidence Synthesis API provides machine learning-powered predictions for:

1. **HTA Reimbursement Decisions** - Predict regulatory approval status
2. **Treatment Effect Sizes** - Estimate log odds ratios from study characteristics

### Models

| Model | Performance | Input | Output |
|-------|-------------|-------|--------|
| HTA Predictor | 100% accuracy | 14 features | Decision class + probabilities |
| Effect Size Estimator | R²=0.9945 | 5 features | Log OR + interpretation |

---

## 🚀 Quick Start

### Installation

```bash
# Clone repository
git clone https://github.com/mahmood726-cyber/Metanew.git
cd Metanew/api

# Install dependencies
pip install -r requirements.txt

# Run server
uvicorn main:app --reload
```

### First Request

```bash
# Health check
curl http://localhost:8000/health

# HTA prediction
curl -X POST http://localhost:8000/predict/hta \
  -H "Content-Type: application/json" \
  -d '{
    "effect_size": 0.45,
    "icer_per_qaly": 75000,
    "serious_adverse_events_rate": 0.12,
    "discontinuation_rate": 0.20,
    "n_rcts": 8,
    "n_observational_studies": 3,
    "total_patients_evidence": 2500,
    "cost_effectiveness_score": 7.5,
    "clinical_benefit_score": 6.8,
    "innovation_score": 8.2
  }'
```

---

## 🔐 Authentication

**Current Version**: No authentication required (development)

**Production**: Implement API key authentication:

```bash
curl -H "X-API-Key: your-api-key" http://localhost:8000/predict/hta
```

---

## 📡 Endpoints

### 1. Health Check

**Endpoint**: `GET /health`

**Description**: Check API health and model status

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-05T12:00:00",
  "models_loaded": true,
  "version": "1.0.0"
}
```

---

### 2. HTA Reimbursement Prediction

**Endpoint**: `POST /predict/hta`

**Description**: Predict HTA decision (Recommended/Restricted/Conditional/Not Recommended)

**Request Body**:

| Field | Type | Required | Range | Description |
|-------|------|----------|-------|-------------|
| `effect_size` | float | Yes | -3 to 3 | Treatment effect (SMD or log OR) |
| `icer_per_qaly` | float | Yes | ≥0 | ICER per QALY (USD) |
| `serious_adverse_events_rate` | float | Yes | 0-1 | SAE rate (proportion) |
| `discontinuation_rate` | float | Yes | 0-1 | Discontinuation rate |
| `n_rcts` | int | Yes | ≥0 | Number of RCTs |
| `n_observational_studies` | int | No | ≥0 | Number of observational studies |
| `total_patients_evidence` | int | Yes | ≥0 | Total patients in evidence base |
| `cost_effectiveness_score` | float | Yes | 1-10 | CE score |
| `clinical_benefit_score` | float | Yes | 1-10 | Clinical benefit score |
| `innovation_score` | float | Yes | 1-10 | Innovation score |
| `time_to_decision_months` | int | No | ≥0 | Expected decision time (default: 12) |
| `market_exclusivity_years` | int | No | ≥0 | Market exclusivity (default: 10) |
| `certainty_of_evidence` | string | No | - | High/Moderate/Low/Very Low (default: Moderate) |
| `willingness_to_pay_threshold` | float | No | ≥0 | WTP threshold (default: 100000) |

**Example Request**:

```json
{
  "effect_size": 0.45,
  "icer_per_qaly": 75000,
  "serious_adverse_events_rate": 0.12,
  "discontinuation_rate": 0.20,
  "n_rcts": 8,
  "n_observational_studies": 3,
  "total_patients_evidence": 2500,
  "cost_effectiveness_score": 7.5,
  "clinical_benefit_score": 6.8,
  "innovation_score": 8.2,
  "certainty_of_evidence": "Moderate",
  "willingness_to_pay_threshold": 100000
}
```

**Example Response**:

```json
{
  "decision": "Recommended",
  "probability": {
    "Recommended": 0.85,
    "Restricted": 0.10,
    "Conditional": 0.04,
    "Not Recommended": 0.01
  },
  "confidence": 0.85,
  "composite_score": 7.50,
  "icer_ratio": 0.75,
  "recommendation": "✅ RECOMMENDED for reimbursement. Strong composite score (7.50/10) and favorable cost-effectiveness (ICER ratio: 0.75).",
  "timestamp": "2025-11-05T12:00:00"
}
```

---

### 3. Effect Size Estimation

**Endpoint**: `POST /predict/effect-size`

**Description**: Predict treatment effect size (log odds ratio) from study characteristics

**Request Body**:

| Field | Type | Required | Range | Description |
|-------|------|----------|-------|-------------|
| `experimental_n` | int | Yes | >0 | Experimental group sample size |
| `control_n` | int | Yes | >0 | Control group sample size |
| `experimental_events` | int | Yes | ≥0 | Events in experimental group |
| `control_events` | int | Yes | ≥0 | Events in control group |
| `study_year` | int | No | 1990-2025 | Publication year (default: 2020) |

**Example Request**:

```json
{
  "experimental_n": 250,
  "control_n": 250,
  "experimental_events": 45,
  "control_events": 62,
  "study_year": 2020
}
```

**Example Response**:

```json
{
  "predicted_log_or": -0.321,
  "predicted_or": 0.725,
  "odds_ratio_ci_lower": 0.651,
  "odds_ratio_ci_upper": 0.808,
  "event_rate_experimental": 0.180,
  "event_rate_control": 0.248,
  "event_rate_difference": -0.068,
  "interpretation": "Moderate beneficial effect detected. Odds ratio: 0.725, Absolute risk difference: -6.8%. Effect moderately clinically significant.",
  "timestamp": "2025-11-05T12:00:00"
}
```

---

### 4. Batch HTA Prediction

**Endpoint**: `POST /predict/hta/batch`

**Description**: Predict multiple HTA assessments in one request

**Request Body**:

```json
{
  "assessments": [
    {
      "effect_size": 0.45,
      "icer_per_qaly": 75000,
      ...
    },
    {
      "effect_size": 0.32,
      "icer_per_qaly": 125000,
      ...
    }
  ]
}
```

**Response**:

```json
{
  "total": 2,
  "successful": 2,
  "failed": 0,
  "results": [
    {
      "index": 0,
      "prediction": { ... },
      "status": "success"
    },
    {
      "index": 1,
      "prediction": { ... },
      "status": "success"
    }
  ]
}
```

---

### 5. Batch Effect Size Prediction

**Endpoint**: `POST /predict/effect-size/batch`

**Description**: Predict multiple effect sizes in one request

**Request Body**:

```json
{
  "studies": [
    {
      "experimental_n": 250,
      "control_n": 250,
      "experimental_events": 45,
      "control_events": 62
    },
    {
      "experimental_n": 150,
      "control_n": 150,
      "experimental_events": 22,
      "control_events": 35
    }
  ]
}
```

**Response**: Similar structure to batch HTA response

---

## 💡 Request/Response Examples

### Python Example

```python
import requests
import json

# HTA Prediction
url = "http://localhost:8000/predict/hta"

data = {
    "effect_size": 0.45,
    "icer_per_qaly": 75000,
    "serious_adverse_events_rate": 0.12,
    "discontinuation_rate": 0.20,
    "n_rcts": 8,
    "n_observational_studies": 3,
    "total_patients_evidence": 2500,
    "cost_effectiveness_score": 7.5,
    "clinical_benefit_score": 6.8,
    "innovation_score": 8.2
}

response = requests.post(url, json=data)
result = response.json()

print(f"Decision: {result['decision']}")
print(f"Confidence: {result['confidence']:.2%}")
print(f"Recommendation: {result['recommendation']}")
```

### JavaScript/Node.js Example

```javascript
const axios = require('axios');

const data = {
  experimental_n: 250,
  control_n: 250,
  experimental_events: 45,
  control_events: 62,
  study_year: 2020
};

axios.post('http://localhost:8000/predict/effect-size', data)
  .then(response => {
    console.log('Predicted OR:', response.data.predicted_or);
    console.log('Interpretation:', response.data.interpretation);
  })
  .catch(error => {
    console.error('Error:', error.response.data);
  });
```

### R Example

```r
library(httr)
library(jsonlite)

# Effect Size Prediction
url <- "http://localhost:8000/predict/effect-size"

data <- list(
  experimental_n = 250,
  control_n = 250,
  experimental_events = 45,
  control_events = 62,
  study_year = 2020
)

response <- POST(
  url,
  body = toJSON(data, auto_unbox = TRUE),
  content_type("application/json")
)

result <- content(response, as = "parsed")
print(paste("Predicted OR:", result$predicted_or))
```

### curl Example

```bash
# HTA Prediction
curl -X POST http://localhost:8000/predict/hta \
  -H "Content-Type: application/json" \
  -d '{
    "effect_size": 0.45,
    "icer_per_qaly": 75000,
    "serious_adverse_events_rate": 0.12,
    "discontinuation_rate": 0.20,
    "n_rcts": 8,
    "n_observational_studies": 3,
    "total_patients_evidence": 2500,
    "cost_effectiveness_score": 7.5,
    "clinical_benefit_score": 6.8,
    "innovation_score": 8.2
  }' | jq .

# Effect Size Prediction
curl -X POST http://localhost:8000/predict/effect-size \
  -H "Content-Type: application/json" \
  -d '{
    "experimental_n": 250,
    "control_n": 250,
    "experimental_events": 45,
    "control_events": 62
  }' | jq .
```

---

## ⚠️ Error Handling

### HTTP Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 400 | Bad Request | Invalid input parameters |
| 422 | Unprocessable Entity | Validation error |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Models not loaded |

### Error Response Format

```json
{
  "error": "Validation error",
  "detail": "experimental_events cannot exceed experimental_n",
  "status_code": 422,
  "timestamp": "2025-11-05T12:00:00"
}
```

### Common Errors

#### 1. Invalid Input Range

**Request**:
```json
{
  "cost_effectiveness_score": 15,  // Should be 1-10
  ...
}
```

**Response** (422):
```json
{
  "detail": [
    {
      "loc": ["body", "cost_effectiveness_score"],
      "msg": "ensure this value is less than or equal to 10",
      "type": "value_error"
    }
  ]
}
```

#### 2. Missing Required Field

**Request**:
```json
{
  "effect_size": 0.45
  // Missing other required fields
}
```

**Response** (422):
```json
{
  "detail": [
    {
      "loc": ["body", "icer_per_qaly"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

---

## 🔄 Rate Limiting

**Current**: No rate limits (development)

**Production Recommendations**:
- 100 requests/minute per IP
- 1,000 requests/day per API key
- Batch endpoints: 10 requests/minute

Implement using middleware:

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/predict/hta")
@limiter.limit("100/minute")
async def predict_hta_decision(...):
    ...
```

---

## 🚀 Deployment

### Option 1: Docker

```bash
# Build image
docker build -t ml-evidence-api .

# Run container
docker run -d \
  --name ml-api \
  -p 8000:8000 \
  ml-evidence-api

# Check logs
docker logs -f ml-api
```

### Option 2: Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - LOG_LEVEL=info
    restart: unless-stopped
```

```bash
docker-compose up -d
```

### Option 3: Cloud Deployment

#### AWS Elastic Beanstalk

```bash
eb init -p python-3.11 ml-evidence-api
eb create ml-api-env
eb deploy
```

#### Google Cloud Run

```bash
gcloud run deploy ml-evidence-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

#### Azure App Service

```bash
az webapp up \
  --name ml-evidence-api \
  --runtime "PYTHON:3.11"
```

### Option 4: Kubernetes

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-evidence-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ml-evidence-api
  template:
    metadata:
      labels:
        app: ml-evidence-api
    spec:
      containers:
      - name: api
        image: ml-evidence-api:1.0.0
        ports:
        - containerPort: 8000
```

---

## 📚 Interactive Documentation

The API provides automatic interactive documentation:

### Swagger UI (OpenAPI)

- **URL**: http://localhost:8000/docs
- **Features**:
  - Interactive request testing
  - Complete schema documentation
  - Example values
  - Authentication testing

### ReDoc

- **URL**: http://localhost:8000/redoc
- **Features**:
  - Clean, readable documentation
  - Sidebar navigation
  - Downloadable OpenAPI spec

---

## 🔧 Configuration

### Environment Variables

```bash
# .env file
API_HOST=0.0.0.0
API_PORT=8000
LOG_LEVEL=info
MODEL_DIR=/app/outputs
CORS_ORIGINS=*
MAX_BATCH_SIZE=100
```

### Production Settings

```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    log_level: str = "info"
    cors_origins: list = ["*"]
    max_batch_size: int = 100

    class Config:
        env_file = ".env"

settings = Settings()
```

---

## 📊 Monitoring

### Health Checks

```bash
# Simple health check
curl http://localhost:8000/health

# With monitoring
while true; do
  curl -s http://localhost:8000/health | jq .status
  sleep 30
done
```

### Metrics (Prometheus)

```python
from prometheus_fastapi_instrumentator import Instrumentator

Instrumentator().instrument(app).expose(app)
```

Access metrics: http://localhost:8000/metrics

---

## 🐛 Troubleshooting

### Issue: Models Not Loading

**Error**: `503 Service Unavailable - HTA model not loaded`

**Solution**:
```bash
# Check model files exist
ls outputs/hta_predictor/best_model.pkl
ls outputs/effect_size_estimator/best_model.pkl

# Check permissions
chmod 644 outputs/*/*.pkl
```

### Issue: Validation Errors

**Error**: `422 Unprocessable Entity`

**Solution**: Check request body matches schema exactly. View `/docs` for schema details.

### Issue: High Memory Usage

**Solution**: Limit batch sizes, use model caching, implement request queuing.

---

## 📝 Changelog

### Version 1.0.0 (2025-11-05)

- ✅ Initial release
- ✅ HTA prediction endpoint
- ✅ Effect size estimation endpoint
- ✅ Batch prediction support
- ✅ Interactive documentation
- ✅ Docker support

---

## 📖 References

- FastAPI Documentation: https://fastapi.tiangolo.com/
- Pydantic Documentation: https://docs.pydantic.dev/
- GitHub Repository: https://github.com/mahmood726-cyber/Metanew

---

## 📧 Support

For issues, questions, or feature requests:
- GitHub Issues: https://github.com/mahmood726-cyber/Metanew/issues
- Email: [your-email]

---

**API Version**: 1.0.0
**Last Updated**: 2025-11-05
**License**: MIT
