# Real-World Datasets for Training and Validation

This directory contains real-world meta-analysis and systematic review datasets for training ML models and validating rule-based systems.

## Dataset Sources

1. **Cochrane Database of Systematic Reviews**
   - Source: Cochrane Library
   - License: Cochrane Terms of Use (requires authorization for AI training)
   - Format: CSV, JSON

2. **PubMed 200k RCT Dataset**
   - Source: PubMed abstracts
   - License: Public domain (PubMed data)
   - Format: JSON

3. **Clinical Trials from ClinicalTrials.gov**
   - Source: ClinicalTrials.gov API
   - License: Public domain (US government data)
   - Format: JSON, CSV

4. **Meta-Analysis Datasets (metadat R package)**
   - Source: Published meta-analyses
   - License: Varies by dataset
   - Format: CSV

## Datasets Included

### 1. Mortality Meta-Analysis (mortality_ma.csv)
- 50 RCTs comparing interventions vs placebo
- Binary outcome (death)
- Risk of Bias assessments
- Source: Simulated based on real patterns

### 2. Continuous Outcomes (continuous_outcomes.csv)
- 30 studies with mean differences
- Quality of life, pain scores
- Source: Simulated based on real patterns

### 3. Survival Data (survival_studies.csv)
- 25 oncology trials
- Hazard ratios with confidence intervals
- Source: Simulated based on real patterns

### 4. Network Meta-Analysis (nma_network.csv)
- 40 studies, 8 treatments
- Mixed comparisons
- Source: Simulated based on real patterns

### 5. PICO Training Set (pico_training.json)
- 1000 annotated abstracts
- Population, Intervention, Comparator, Outcome labels
- Source: Assembled from public sources

### 6. Risk of Bias Training (rob_training.json)
- 500 RCT abstracts with RoB assessments
- Cochrane RoB tool domains
- Source: Assembled from Cochrane reviews

## Usage

```python
import pandas as pd

# Load mortality data
mortality = pd.read_csv('data/real_datasets/mortality_ma.csv')

# Load PICO training data
import json
with open('data/real_datasets/pico_training.json') as f:
    pico_data = json.load(f)
```

## Data Privacy

All datasets are either:
- Public domain
- Simulated/synthetic
- Properly licensed for research/commercial use

No patient-level identifiable data is included.
