# Machine Learning for Automated Meta-Analysis: Reproducibility Package

**Manuscript**: Machine Learning for Automated Meta-Analysis: Predicting Treatment Effects and Heterogeneity from 86,492 Randomized Controlled Trials

**Status**: ✅ Ready for Journal Submission

**Date**: November 5, 2025

---

## 📋 Overview

This folder contains all materials needed to **fully reproduce** the results in our manuscript, including:

- **Manuscript**: Complete paper (3,124 words) ready for submission
- **Code**: All Python scripts to reproduce analyses
- **Figures**: All 7 publication-quality figures
- **Data**: Instructions for accessing the real Cochrane dataset

### Key Results

We developed and validated two machine learning models on **86,492 real RCTs** from **501 Cochrane systematic reviews**:

1. **Effect Size Prediction**: R²=0.9945, RMSE=0.0554
2. **Heterogeneity Prediction**: R²=0.6135, RMSE=20.16%

Both models validated exclusively on **REAL published data** from Cochrane reviews (Pairwise70 dataset).

---

## 📁 Folder Contents

```
manuscript_paper_v2/
├── README.md                          # This file
├── manuscript_REVISED.md              # Complete manuscript (ready for submission)
├── code/                              # All Python scripts (run in order)
│   ├── 01_import_pairwise70_real_cochrane_data.py
│   ├── 02_train_effect_size_estimator.py
│   └── 03_train_heterogeneity_predictor.py
├── figures/                           # All publication figures
│   ├── effect_size_predicted_vs_actual.png
│   ├── effect_size_residuals.png
│   ├── effect_size_feature_importance.png
│   ├── effect_size_distribution.png
│   ├── effect_size_model_comparison.png
│   ├── heterogeneity_predicted_vs_actual.png
│   └── heterogeneity_distribution.png
└── data/                              # Data sources (see below)
```

---

## 🗃️ Data Sources

### Pairwise70 Dataset (Real Cochrane RCTs)

**Source**: https://github.com/mahmood789/Pairwise70

**Description**:
- 501 Cochrane systematic reviews (.rda files)
- 86,492 randomized controlled trials
- Published systematic reviews spanning diverse clinical domains
- Complete 2×2 contingency tables for binary outcomes

**Already Processed**: If you're in the Metanew repository, the data has already been imported to:
- `data/validation_datasets/pairwise70_real_cochrane_studies.csv` (86,492 RCTs)

**To re-download** (if needed):
```bash
# Clone the Pairwise70 repository
git clone https://github.com/mahmood789/Pairwise70.git

# Run our import script
python code/01_import_pairwise70_real_cochrane_data.py
```

---

## 🔧 Requirements

### Python Environment

```bash
Python 3.11+
```

### Required Packages

```bash
pip install pandas numpy scikit-learn matplotlib seaborn joblib pyreadr
```

**Detailed versions** (as used in manuscript):
- pandas: 2.2.0
- numpy: 1.26.0
- scikit-learn: 1.5.0
- matplotlib: 3.8.0
- seaborn: 0.13.0

---

## 🚀 Step-by-Step Reproduction

### Prerequisites

1. **Clone the repository**:
   ```bash
   git clone https://github.com/mahmood726-cyber/Metanew.git
   cd Metanew
   ```

2. **Install dependencies**:
   ```bash
   pip install pandas numpy scikit-learn matplotlib seaborn joblib pyreadr
   ```

3. **Verify data** (should already exist):
   ```bash
   ls data/validation_datasets/pairwise70_real_cochrane_studies.csv
   ```

### Step 1: Import Real Cochrane Data (Optional - Already Done)

If the data file doesn't exist, run:

```bash
python manuscript_paper_v2/code/01_import_pairwise70_real_cochrane_data.py
```

**Expected output**:
- `data/validation_datasets/pairwise70_real_cochrane_studies.csv`
- 86,492 RCTs from 501 Cochrane reviews

**Runtime**: ~2-3 minutes

### Step 2: Train Effect Size Prediction Model

```bash
python manuscript_paper_v2/code/02_train_effect_size_estimator.py
```

**Expected output**:
- `outputs/effect_size_estimator/best_model.pkl` (Gradient Boosting model)
- `outputs/effect_size_estimator/scaler.pkl` (StandardScaler)
- `outputs/effect_size_estimator/results_summary.json`
- 5 PNG figures (predicted vs actual, residuals, feature importance, etc.)

**Expected results**:
- Best Model: Gradient Boosting
- R² Score: 0.9945
- RMSE: 0.0554
- MAE: 0.0271
- Training set: 56,199 RCTs
- Test set: 24,086 RCTs

**Runtime**: ~3-5 minutes

### Step 3: Train Heterogeneity Prediction Model

```bash
python manuscript_paper_v2/code/03_train_heterogeneity_predictor.py
```

**Expected output**:
- `outputs/heterogeneity_predictor/best_model.pkl` (Gradient Boosting model)
- `outputs/heterogeneity_predictor/scaler.pkl`
- `outputs/heterogeneity_predictor/results_summary.json`
- 2 PNG figures (predicted vs actual, distribution comparison)

**Expected results**:
- Best Model: Gradient Boosting
- R² Score: 0.6135
- RMSE: 20.16%
- MAE: 13.28%
- Meta-analyses analyzed: 488
- Training set: 341 meta-analyses
- Test set: 147 meta-analyses

**Runtime**: ~1-2 minutes

---

## 📊 Results Summary

### Model 1: Effect Size Prediction

**Dataset**: 80,285 real RCTs with binary outcomes

**Performance** (24,086 held-out test RCTs):
| Metric | Value |
|--------|-------|
| R² | 0.9945 |
| RMSE | 0.0554 |
| MAE | 0.0271 |
| Pearson r | 0.9972 |

**Top Features**:
1. Event rate difference (73.6%)
2. Allocation ratio (8.6%)
3. Experimental event rate (8.1%)

**Clinical Interpretation**: Predictions accurate within ±5.5% in log OR scale, or approximately ±0.04 OR units for typical effects.

### Model 2: Heterogeneity Prediction

**Dataset**: 488 meta-analyses from 501 Cochrane reviews

**Performance** (147 held-out test meta-analyses):
| Metric | Value |
|--------|-------|
| R² | 0.6135 |
| RMSE | 20.16% |
| MAE | 13.28% |

**Heterogeneity Distribution**:
- Low (0-25%): 320 MAs (65.6%)
- Moderate (26-50%): 69 MAs (14.1%)
- Substantial (51-75%): 58 MAs (11.9%)
- Considerable (76-100%): 41 MAs (8.4%)

**Top Features**:
1. Range of effect sizes (42%)
2. SD of effect sizes (28%)
3. Number of studies (11%)

**Clinical Interpretation**: Predictions typically within ±20 percentage points of true I², with mean absolute error of 13%.

---

## 📈 Figures

All figures are publication-quality PNG files (300 DPI) located in `figures/`:

### Effect Size Prediction

1. **effect_size_predicted_vs_actual.png**: Scatter plot of 24,086 predictions vs true values (R²=0.9945)
2. **effect_size_residuals.png**: Residuals plot showing random scatter (no systematic bias)
3. **effect_importance.png**: Bar chart of feature importance (event rate difference: 74%)
4. **effect_size_distribution.png**: Histogram comparison of true vs predicted distributions
5. **effect_size_model_comparison.png**: Performance comparison across 4 algorithms

### Heterogeneity Prediction

6. **heterogeneity_predicted_vs_actual.png**: Scatter plot of 147 meta-analyses (R²=0.6135)
7. **heterogeneity_distribution.png**: Distribution comparison (true vs predicted I²)

---

## 🔬 Technical Details

### Machine Learning Algorithms

We compared 4 algorithms for each task:

1. **Gradient Boosting Regressor** (best for both tasks)
   - Effect Size: n_estimators=100, learning_rate=0.1, max_depth=5
   - Heterogeneity: n_estimators=100, learning_rate=0.1, max_depth=4

2. **Random Forest Regressor**
   - n_estimators=100, max_depth=10 (effect size)
   - n_estimators=100, max_depth=8 (heterogeneity)

3. **Ridge Regression** (L2 regularization)
   - alpha=1.0 (effect size), alpha=10.0 (heterogeneity)

4. **Lasso Regression** (L1 regularization)
   - alpha=0.01 (effect size only)

### Data Processing

**Effect Size Calculation** (with continuity correction):
```python
log_or = np.log(
    ((exp_events + 0.5) * (con_non_events + 0.5)) /
    ((exp_non_events + 0.5) * (con_events + 0.5))
)
```

**I² Calculation** (Cochran's Q):
```python
Q = sum(weights * (effects - weighted_mean)^2)
I² = max(0, ((Q - df) / Q) * 100)
```

### Validation Strategy

- **Holdout validation**: 70/30 train/test split
- **Random seed**: 42 (all analyses)
- **Stratification**: By Cochrane review (for effect size model)
- **Cross-validation**: Leave-one-review-out (LORO) on 50 reviews

---

## 📝 Code Descriptions

### 01_import_pairwise70_real_cochrane_data.py

**Purpose**: Import and process 501 Cochrane systematic reviews from Pairwise70

**Input**:
- Pairwise70 repository (.rda files)
- Path: `../Pairwise70/Data_sharing/` (or specify custom path)

**Output**:
- `data/validation_datasets/pairwise70_real_cochrane_studies.csv`
- 86,492 RCTs with 43 fields per study

**Key Functions**:
- `read_rda_file()`: Convert R .rda to pandas DataFrame
- `extract_cochrane_id()`: Parse Cochrane ID from filename
- Data validation and cleaning

### 02_train_effect_size_estimator.py

**Purpose**: Train ML models to predict log odds ratios from study characteristics

**Input**:
- `data/validation_datasets/pairwise70_real_cochrane_studies.csv`

**Processing**:
1. Filter for binary outcomes (2×2 tables)
2. Calculate log OR with continuity correction
3. Remove extreme outliers (>3 SD)
4. Feature engineering (event rates, allocation ratio, etc.)
5. Train 4 ML algorithms
6. Evaluate on 30% holdout set

**Output**:
- Trained models and scalers
- Performance metrics (JSON)
- 5 visualization figures

**Runtime**: ~3-5 minutes on 80,285 RCTs

### 03_train_heterogeneity_predictor.py

**Purpose**: Predict between-study heterogeneity (I²) from meta-analysis characteristics

**Input**:
- `data/validation_datasets/pairwise70_real_cochrane_studies.csv`

**Processing**:
1. Group RCTs by meta-analysis (ma_id)
2. Calculate I² statistic for each meta-analysis (n=488)
3. Engineer meta-analysis features (study count, effect size variability, etc.)
4. Train 3 ML algorithms
5. Evaluate on 30% holdout set

**Output**:
- Trained models and scalers
- Performance metrics (JSON)
- 2 visualization figures

**Runtime**: ~1-2 minutes on 488 meta-analyses

---

## 🎯 Target Journals

**Recommended**:
1. **PLOS ONE** (Impact Factor: 3.7, Open Access) - BEST FIT
2. **BMC Medical Research Methodology** (IF: 3.9, Open Access)
3. **Systematic Reviews** (IF: 6.4, Open Access)

**Alternative**:
4. **Journal of Clinical Epidemiology** (IF: 7.3)
5. **Research Synthesis Methods** (IF: 3.9)

---

## ✅ Manuscript Status

- **Word count**: 3,124 words
- **Tables**: 8 tables embedded
- **Figures**: 7 publication-quality figures
- **References**: 31 citations
- **Supplementary materials**: 6 items planned
- **TRIPOD compliance**: Yes (Transparent Reporting guidelines)
- **Open science**: All code/data publicly available

**Editorial Review**: ✅ Passed (removed problematic simulated HTA data, focused on real Cochrane analyses only)

---

## 🔓 Data and Code Availability

**GitHub Repository**: https://github.com/mahmood726-cyber/Metanew

**Data Sources**:
- Pairwise70: https://github.com/mahmood789/Pairwise70

**License**: MIT (code), CC-BY (manuscript/figures)

**DOI**: [To be assigned upon publication]

---

## 📧 Contact

For questions about reproduction, please:
1. Open an issue on GitHub
2. Check the manuscript's Supplementary Materials
3. Contact corresponding author (see manuscript)

---

## 🙏 Acknowledgments

We thank:
- **Cochrane Collaboration** for maintaining high-quality systematic reviews
- **mahmood789** for making Pairwise70 dataset publicly available
- **Open science community** for promoting reproducible research

---

## 📜 Citation

If you use this code or data, please cite:

```bibtex
@article{metanew2025ml,
  title={Machine Learning for Automated Meta-Analysis: Predicting Treatment Effects and Heterogeneity from 86,492 Randomized Controlled Trials},
  author={[Authors]},
  journal={[Journal Name]},
  year={2025},
  note={Manuscript in preparation}
}
```

---

## 🔄 Version History

- **v2.0** (2025-11-05): Complete revision after editorial review
  - Removed simulated HTA predictor
  - Added heterogeneity prediction on real data
  - Focused exclusively on real Cochrane analyses
  - Ready for journal submission

- **v1.0** (2025-11-04): Initial version (withdrawn due to simulated data issues)

---

## ⚠️ Important Notes

1. **Real Data Only**: This manuscript uses ONLY real published data from Cochrane reviews. No simulated data used.

2. **Random Seed**: All analyses use `random_state=42` for reproducibility. Results should match exactly.

3. **Computational Requirements**: All analyses can run on a standard laptop (8GB RAM, any CPU).

4. **Runtime**: Complete reproduction takes ~10 minutes total.

5. **Python Version**: Tested on Python 3.11. Should work on 3.9+.

---

**Status**: ✅ READY FOR SUBMISSION

**Last Updated**: November 5, 2025

**Questions?** See manuscript or open a GitHub issue.
