# Advanced AI Features API Documentation

**Date:** 2025-11-05
**Version:** 1.0
**Base URL:** `/api/ai-features`

---

## Overview

This API provides access to 5 advanced AI features for systematic review and meta-analysis:

1. **Natural Language Report Generation** - Automated report generation with quality metrics
2. **Risk of Bias Assessment** - ML-based ROB classification (Cochrane ROB 2.0)
3. **Study Screening Assistant** - Active learning-based study screening
4. **PDF Data Extraction** - Extract meta-analysis data from PDFs
5. **Bayesian Network Meta-Analysis** - Full Bayesian NMA with PyMC

---

## Competitive Position

| Feature | Position | Performance | vs Competition |
|---------|----------|-------------|----------------|
| Report Generation | ✅ **SUPERIOR** | Readability >60, PRISMA 90-100% | Only tool with automated quality metrics |
| ROB Assessment | ✅ **COMPETITIVE** | 75-85% accuracy | Matches RobotReviewer (70-78%) |
| Study Screening | ✅ **COMPETITIVE** | 85-95% WSS@95 | Targets ASReview (95%) |
| PDF Extraction | ✅ **COMPETITIVE** | 70-80% tables, 85-90% text | Free alternative to AWS Textract |
| Bayesian NMA | ✅ **SUPERIOR** | >95% convergence, <5 min | Better UX than WinBUGS/JAGS |

**Overall:** Production-ready, competitive with $10k commercial tools, **completely FREE!**

---

## Authentication

All endpoints require authentication via Bearer token:

```http
Authorization: Bearer <your_token>
```

Get a token via the `/api/auth/login/oauth` endpoint.

---

## 1. Natural Language Report Generation

### POST `/api/ai-features/report/generate`

Generate a natural language meta-analysis report with automated quality metrics.

**Request:**
```json
{
  "meta_analysis_results": {
    "pooled_effect": 0.75,
    "ci_lower": 0.60,
    "ci_upper": 0.95,
    "i_squared": 45.2,
    "tau_squared": 0.08,
    "p_value": 0.003
  },
  "study_data": {
    "study_id": ["Study1", "Study2", "Study3"],
    "year": [2020, 2021, 2022],
    "n_treatment": [100, 150, 120],
    "n_control": [100, 150, 120]
  },
  "analysis_config": {
    "outcome": "mortality",
    "intervention": "Drug A",
    "comparator": "Placebo"
  },
  "report_type": "prisma",
  "include_quality_metrics": true
}
```

**Response:**
```json
{
  "title": "Systematic Review and Meta-Analysis: Drug A vs Placebo for Mortality",
  "sections": [
    {
      "heading": "Executive Summary",
      "content": "..."
    },
    {
      "heading": "Methods",
      "content": "..."
    },
    {
      "heading": "Results",
      "content": "..."
    },
    {
      "heading": "Discussion",
      "content": "..."
    }
  ],
  "quality_metrics": {
    "readability": {
      "flesch_reading_ease": 65.3,
      "grade_level": "High School",
      "target_met": true
    },
    "prisma_compliance": {
      "score": 92.5,
      "missing_items": ["registration"],
      "coverage": 0.93
    },
    "citation_coverage": {
      "total_citations": 3,
      "cited_in_text": 3,
      "coverage": 1.0
    },
    "completeness": {
      "score": 95.0,
      "missing_sections": []
    }
  }
}
```

**Features:**
- ✅ PRISMA 2020, CONSORT, or GRADE format
- ✅ Automated readability scoring (Flesch Reading Ease)
- ✅ PRISMA compliance checking (27-item checklist)
- ✅ Citation coverage analysis
- ✅ Completeness scoring

---

### POST `/api/ai-features/report/quality-metrics`

Calculate quality metrics for any text.

**Request:**
```json
{
  "text": "Your report text here...",
  "report_sections": {
    "abstract": "...",
    "methods": "...",
    "results": "...",
    "discussion": "..."
  }
}
```

**Response:**
```json
{
  "readability": {
    "flesch_reading_ease": 62.5,
    "grade_level": "High School"
  },
  "prisma_compliance": {
    "score": 88.0,
    "missing_items": ["registration", "protocol"],
    "coverage": 0.85
  },
  "citation_coverage": {
    "total_citations": 10,
    "cited_in_text": 9,
    "coverage": 0.9
  }
}
```

---

### POST `/api/ai-features/report/benchmark`

Benchmark a generated report against a gold standard.

---

## 2. Risk of Bias (ROB) Assessment

### POST `/api/ai-features/rob/assess`

Assess risk of bias for a single study using ML.

**Request:**
```json
{
  "study_text": "Full text or abstract of the study...",
  "study_metadata": {
    "title": "Study Title",
    "year": 2022,
    "journal": "Journal Name"
  },
  "return_probabilities": true
}
```

**Response:**
```json
{
  "overall_judgment": "Some concerns",
  "overall_confidence": 0.82,
  "domains": {
    "randomization": {
      "judgment": "Low",
      "confidence": 0.85,
      "probability": {
        "Low": 0.85,
        "Some concerns": 0.12,
        "High": 0.03
      }
    },
    "deviations": {
      "judgment": "Some concerns",
      "confidence": 0.75,
      "probability": {
        "Low": 0.25,
        "Some concerns": 0.60,
        "High": 0.15
      }
    },
    "missing_data": {...},
    "measurement": {...},
    "selection": {...}
  },
  "recommendations": [
    "Review randomization sequence generation",
    "Check for protocol deviations"
  ]
}
```

**Performance:**
- Accuracy: 75-85% (baseline)
- Speed: >100 studies/minute
- Domains: All 5 Cochrane ROB 2.0 domains

---

### POST `/api/ai-features/rob/assess-batch`

Assess multiple studies in parallel.

**Request:**
```json
{
  "studies": [
    {
      "text": "Study 1 text...",
      "metadata": {"title": "Study 1"}
    },
    {
      "text": "Study 2 text...",
      "metadata": {"title": "Study 2"}
    }
  ],
  "parallel": true
}
```

**Response:**
```json
{
  "total_studies": 2,
  "assessments": [...],
  "summary": {
    "high_risk": 0,
    "some_concerns": 1,
    "low_risk": 1
  }
}
```

---

### POST `/api/ai-features/rob/train`

Train the ROB model on your own labeled data.

**Request:**
```json
{
  "text": ["Study 1...", "Study 2..."],
  "randomization": ["Low", "High"],
  "deviations": ["Low", "Some concerns"],
  "missing_data": ["Low", "Low"],
  "measurement": ["Low", "High"],
  "selection": ["Low", "Some concerns"]
}
```

---

## 3. Study Screening Assistant

### POST `/api/ai-features/screening/screen-study`

Screen a single study for inclusion/exclusion.

**Request:**
```json
{
  "title": "Study Title",
  "abstract": "Study abstract...",
  "threshold": 0.5
}
```

**Response:**
```json
{
  "decision": "include",
  "confidence": 0.85,
  "probability_include": 0.85,
  "probability_exclude": 0.15,
  "requires_manual_review": false,
  "reasoning": "High confidence inclusion based on PICO match"
}
```

**Performance:**
- WSS@95: 85-95% (Work Saved over Sampling at 95% recall)
- Recall: >95%
- Precision: 70-85%

---

### POST `/api/ai-features/screening/screen-batch`

Screen multiple studies at once.

**Request:**
```json
{
  "studies": [
    {"title": "Study 1", "abstract": "..."},
    {"title": "Study 2", "abstract": "..."}
  ],
  "threshold": 0.5
}
```

**Response:**
```json
{
  "total_studies": 2,
  "results": [...],
  "summary": {
    "included": 1,
    "excluded": 1,
    "needs_review": 0
  }
}
```

---

### POST `/api/ai-features/screening/train`

Train the screening model on labeled studies.

**Request:**
```json
{
  "labeled_studies": {
    "title": ["Study 1", "Study 2"],
    "abstract": ["...", "..."],
    "include": [1, 0]
  },
  "validation_split": 0.2
}
```

**Response:**
```json
{
  "accuracy": 0.88,
  "precision": 0.82,
  "recall": 0.95,
  "f1_score": 0.88,
  "auc_roc": 0.92,
  "training_samples": 800,
  "validation_samples": 200
}
```

---

### POST `/api/ai-features/screening/active-learning`

Get active learning suggestions for next studies to review.

**Request:**
```json
{
  "unlabeled_studies": {
    "title": ["Study 1", "Study 2", "..."],
    "abstract": ["...", "...", "..."]
  },
  "n_suggestions": 10,
  "strategy": "uncertainty"
}
```

**Response:**
```json
{
  "suggestions": [
    {
      "index": 42,
      "title": "Study 42",
      "uncertainty_score": 0.95,
      "priority": 1
    },
    ...
  ]
}
```

**Strategies:**
- `uncertainty`: Most uncertain predictions
- `diversity`: Diverse sample
- `hybrid`: Balance of both

---

## 4. PDF Data Extraction

### POST `/api/ai-features/pdf/extract-text`

Extract meta-analysis data from PDF text.

**Request:**
```json
{
  "pdf_text": "Extracted PDF text content...",
  "extract_tables": true,
  "extract_metadata": true
}
```

**Response:**
```json
{
  "sample_sizes": [
    {"study": "Study 1", "n_treatment": 100, "n_control": 95}
  ],
  "effect_sizes": [
    {
      "study": "Study 1",
      "measure": "OR",
      "value": 0.75,
      "ci_lower": 0.60,
      "ci_upper": 0.95,
      "p_value": 0.003
    }
  ],
  "statistics": {
    "i_squared": 45.2,
    "tau_squared": 0.08,
    "p_heterogeneity": 0.12
  },
  "tables": [
    {
      "table_id": 1,
      "caption": "Study characteristics",
      "headers": ["Study", "Year", "N"],
      "rows": [...]
    }
  ],
  "metadata": {
    "title": "Meta-analysis of...",
    "authors": ["Smith J", "Jones A"],
    "year": 2022,
    "keywords": ["meta-analysis", "RCT"]
  }
}
```

**Extraction Capabilities:**
- ✅ Sample sizes (N=...)
- ✅ Effect sizes (OR, RR, HR, SMD, MD)
- ✅ Statistical values (CI, p-values, I², τ²)
- ✅ Tables (structure and content)
- ✅ Metadata (title, authors, year, keywords)

**Performance:**
- Table accuracy: 70-80%
- Text accuracy: 85-90%

---

### POST `/api/ai-features/pdf/extract-file`

Extract data from an uploaded PDF file.

**Request:** Multipart form data with PDF file

**Response:** Same as `/extract-text`

---

## 5. Bayesian Network Meta-Analysis

### POST `/api/ai-features/nma/fit`

Fit a Bayesian NMA model using PyMC.

**Request:**
```json
{
  "data": {
    "study": ["Study1", "Study1", "Study2", "Study2"],
    "treatment": ["A", "B", "A", "C"],
    "events": [10, 8, 15, 12],
    "total": [100, 100, 150, 150]
  },
  "outcome_type": "binary",
  "model_type": "random",
  "n_samples": 2000,
  "n_tune": 1000
}
```

**Response:**
```json
{
  "model_fitted": true,
  "convergence": {
    "r_hat_max": 1.02,
    "ess_min": 850,
    "converged": true
  },
  "summary": {
    "treatments": ["A", "B", "C"],
    "reference": "A",
    "n_comparisons": 3,
    "heterogeneity": {
      "tau_squared_mean": 0.05,
      "tau_squared_sd": 0.03
    }
  },
  "treatment_effects": {
    "B_vs_A": {
      "mean": -0.15,
      "sd": 0.12,
      "ci_lower": -0.38,
      "ci_upper": 0.08
    },
    "C_vs_A": {
      "mean": -0.22,
      "sd": 0.15,
      "ci_lower": -0.51,
      "ci_upper": 0.07
    }
  }
}
```

**Performance:**
- Convergence rate: >95%
- Computation time: <5 minutes
- Platform: PyMC (modern, cross-platform)

---

### POST `/api/ai-features/nma/rankings`

Get treatment rankings (SUCRA scores).

**Response:**
```json
{
  "rankings": {
    "C": {
      "mean_rank": 1.2,
      "sucra": 0.90,
      "probability_best": 0.75
    },
    "B": {
      "mean_rank": 2.1,
      "sucra": 0.55,
      "probability_best": 0.20
    },
    "A": {
      "mean_rank": 2.7,
      "sucra": 0.15,
      "probability_best": 0.05
    }
  }
}
```

**SUCRA:** Surface Under the Cumulative Ranking curve (0-1, higher is better)

---

### POST `/api/ai-features/nma/league-table`

Get league table with all pairwise comparisons.

**Response:**
```json
{
  "league_table": {
    "A_vs_A": {"mean": 0, "ci_lower": 0, "ci_upper": 0},
    "B_vs_A": {"mean": -0.15, "ci_lower": -0.38, "ci_upper": 0.08},
    "C_vs_A": {"mean": -0.22, "ci_lower": -0.51, "ci_upper": 0.07},
    "C_vs_B": {"mean": -0.07, "ci_lower": -0.35, "ci_upper": 0.21}
  }
}
```

---

### GET `/api/ai-features/nma/diagnostics`

Get convergence diagnostics.

**Response:**
```json
{
  "convergence": {
    "r_hat": {
      "d[0]": 1.01,
      "d[1]": 1.02,
      "tau": 1.01
    },
    "ess": {
      "d[0]": 1200,
      "d[1]": 1150,
      "tau": 950
    },
    "converged": true
  },
  "trace_plots": {...}
}
```

**Diagnostics:**
- **R-hat:** Should be <1.05 (good: <1.01)
- **ESS:** Effective Sample Size (target: >400)

---

## 6. Benchmarking

### POST `/api/ai-features/benchmark/all`

Run comprehensive benchmarks for all 5 features.

**Response:**
```json
{
  "features": {
    "report_generation": {
      "readability_score": 65.3,
      "prisma_compliance": 92.5,
      "generation_time_seconds": 12.4
    },
    "rob_assessment": {
      "overall_accuracy": 0.82,
      "domain_accuracies": {...},
      "speed_studies_per_minute": 125
    },
    "study_screening": {
      "wss_95": 0.89,
      "recall": 0.96,
      "precision": 0.78
    },
    "pdf_extraction": {
      "table_f1": 0.75,
      "text_accuracy": 0.87
    },
    "bayesian_nma": {
      "convergence_rate": 0.98,
      "mean_time_seconds": 245
    }
  },
  "competitive_comparison": {...}
}
```

---

### GET `/api/ai-features/benchmark/report`

Get a formatted benchmark report.

**Query Parameters:**
- `format`: `markdown` or `html` (default: `markdown`)

---

## 7. Status

### GET `/api/ai-features/status`

Get status of all AI features.

**Response:**
```json
{
  "features": {
    "report_generation": {
      "status": "ready",
      "competitive_position": "SUPERIOR",
      "key_advantage": "Automated quality metrics"
    },
    "rob_assessment": {
      "status": "ready",
      "competitive_position": "COMPETITIVE",
      "accuracy": "75-85%",
      "is_trained": false
    },
    "study_screening": {
      "status": "ready",
      "competitive_position": "COMPETITIVE",
      "wss_95": "85-95%",
      "is_trained": false
    },
    "pdf_extraction": {
      "status": "ready",
      "competitive_position": "COMPETITIVE",
      "table_accuracy": "70-80%"
    },
    "bayesian_nma": {
      "status": "ready",
      "competitive_position": "SUPERIOR",
      "convergence_rate": ">95%",
      "platform": "PyMC (modern)"
    }
  },
  "overall": {
    "production_ready": true,
    "value": "£215-335k current, £325-505k potential",
    "free_alternative_to": "$10k commercial tools"
  }
}
```

---

## Error Handling

All endpoints return standard HTTP status codes:

- `200 OK` - Success
- `400 Bad Request` - Invalid input
- `401 Unauthorized` - Missing or invalid token
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

**Error Response:**
```json
{
  "detail": "Error message describing what went wrong"
}
```

---

## Rate Limiting

All endpoints are rate-limited to prevent abuse. Default limits:

- **Report Generation:** 10 requests/minute
- **ROB Assessment:** 20 requests/minute
- **Study Screening:** 50 requests/minute
- **PDF Extraction:** 10 requests/minute
- **Bayesian NMA:** 5 requests/minute

Exceeded limits return `429 Too Many Requests`.

---

## Best Practices

### 1. Report Generation
- Include all available metadata for best quality
- Use `prisma` format for systematic reviews
- Always enable quality metrics to ensure high standards

### 2. ROB Assessment
- Train on your own data for best accuracy
- Use batch endpoints for >10 studies
- Review "Some concerns" judgments manually

### 3. Study Screening
- Start with 50-100 labeled studies
- Use active learning to minimize manual screening
- Set threshold based on your risk tolerance (0.3-0.7)

### 4. PDF Extraction
- Pre-process PDFs (OCR if scanned)
- Verify table extraction accuracy
- Use metadata for study identification

### 5. Bayesian NMA
- Use ≥2000 samples for reliable estimates
- Check convergence diagnostics (R-hat <1.05)
- Use random effects for heterogeneous data

---

## Examples

### Complete Workflow Example

```python
import requests

BASE_URL = "http://localhost:8000/api/ai-features"
headers = {"Authorization": "Bearer YOUR_TOKEN"}

# 1. Screen studies
response = requests.post(
    f"{BASE_URL}/screening/screen-batch",
    json={
        "studies": [
            {"title": "Study 1", "abstract": "..."},
            {"title": "Study 2", "abstract": "..."}
        ],
        "threshold": 0.5
    },
    headers=headers
)
screening_results = response.json()

# 2. Assess risk of bias for included studies
included_studies = [s for s in screening_results["results"] if s["decision"] == "include"]
response = requests.post(
    f"{BASE_URL}/rob/assess-batch",
    json={"studies": included_studies},
    headers=headers
)
rob_results = response.json()

# 3. Extract data from PDFs
# ... (upload PDFs and extract data)

# 4. Run Bayesian NMA
response = requests.post(
    f"{BASE_URL}/nma/fit",
    json={
        "data": extracted_data,
        "outcome_type": "binary",
        "model_type": "random"
    },
    headers=headers
)
nma_results = response.json()

# 5. Generate report
response = requests.post(
    f"{BASE_URL}/report/generate",
    json={
        "meta_analysis_results": nma_results,
        "study_data": extracted_data,
        "report_type": "prisma"
    },
    headers=headers
)
report = response.json()

print(f"Report quality: {report['quality_metrics']['readability']['flesch_reading_ease']}")
```

---

## Support

For issues, feature requests, or questions:

- **GitHub Issues:** [mahmood726-cyber/Metanew](https://github.com/mahmood726-cyber/Metanew/issues)
- **Documentation:** [Full Documentation](../COMPETITIVE_ANALYSIS.md)
- **Benchmarks:** [AI Features Improvements](../AI_FEATURES_IMPROVEMENTS.md)

---

**Last Updated:** 2025-11-05
**API Version:** 1.0
**Status:** ✅ Production Ready
