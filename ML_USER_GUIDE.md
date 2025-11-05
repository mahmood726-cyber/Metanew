# EvidenceOS PRIME - ML/AI Features User Guide

**Version:** 2.0
**Last Updated:** 2025-01-05
**Audience:** Researchers, Meta-Analysts, Healthcare Decision Makers

---

## 📚 Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [ML/AI Features Overview](#mlai-features-overview)
4. [Feature Guides](#feature-guides)
   - [Ensemble Models](#1-ensemble-models)
   - [Model Explainability](#2-model-explainability)
   - [RAG Q&A System](#3-rag-qa-system)
   - [AutoML Optimization](#4-automl-optimization)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)
7. [FAQs](#faqs)

---

## 🎯 Introduction

EvidenceOS PRIME includes world-class machine learning and AI capabilities designed specifically for evidence synthesis and meta-analysis. These features help you:

- **Predict study outcomes** with state-of-the-art gradient boosting
- **Understand model decisions** with SHAP and LIME explainability
- **Ask questions** about your literature using RAG (Retrieval-Augmented Generation)
- **Optimize models automatically** with AutoML and Bayesian optimization

### Key Benefits

✅ **No coding required** - All features accessible through intuitive UI
✅ **Production-grade ML** - XGBoost, LightGBM, CatBoost integration
✅ **Explainable results** - Every prediction comes with clinical narratives
✅ **Lightning fast** - Redis caching provides 10-100x speedup
✅ **Privacy-first** - All processing happens locally (no external APIs)

---

## 🚀 Getting Started

### Prerequisites

Before using ML/AI features, ensure:

1. ✅ Backend server is running (`http://localhost:8000`)
2. ✅ Redis is available (optional but recommended for caching)
3. ✅ You have study data loaded in the application

### Accessing ML/AI Features

1. Launch the EvidenceOS PRIME application
2. Navigate to the **"ML/AI"** tab in the navigation bar
3. Choose from 4 sub-panels:
   - 🎯 Ensemble Models
   - 🔍 Explainability
   - 💬 RAG Q&A
   - ⚡ AutoML

---

## 🤖 ML/AI Features Overview

| Feature | Purpose | Time to Run | When to Use |
|---------|---------|-------------|-------------|
| **Ensemble Models** | Train predictive models | 30-60 seconds | When you need accurate predictions |
| **Explainability** | Understand model decisions | 10-30 seconds | After training a model |
| **RAG Q&A** | Ask questions about literature | 2-5 seconds | When you need quick insights |
| **AutoML** | Optimize hyperparameters | 5-15 minutes | For maximum model performance |

---

## 📖 Feature Guides

### 1. Ensemble Models

**Purpose:** Train state-of-the-art gradient boosting models on your meta-analysis data.

#### Supported Models

- **XGBoost** - Best for regularization and missing value handling
- **LightGBM** - Fastest, ideal for large datasets (>10,000 studies)
- **CatBoost** - Best for categorical features

#### Step-by-Step Guide

1. **Select Target Variable**
   - Choose what you want to predict (e.g., `effect_size`, `heterogeneity`)
   - Ensure the variable exists in your dataset

2. **Choose Features**
   - Select predictor variables (e.g., `sample_size`, `year`, `risk_of_bias`)
   - Recommended: 3-10 features for best results

3. **Select Strategy**
   - **Single Model:** Train one model (fastest)
   - **Voting:** Average predictions from multiple models
   - **Stacking:** Use meta-learner to combine models (most accurate)

4. **Train Model**
   - Click "Train Model"
   - Wait 30-60 seconds for training
   - Model is automatically cached for future use

5. **View Results**
   - Performance metrics (R², MAE, RMSE for regression; AUC, F1 for classification)
   - Feature importance chart
   - Model comparison table (if multiple models)

#### Example Use Case

**Scenario:** Predict heterogeneity (I²) from study characteristics

```
Target: i_squared
Features: n_studies, mean_sample_size, year_range, risk_of_bias_score
Strategy: Stacking
Result: R² = 0.78, MAE = 12.5
```

**Interpretation:** Model can predict 78% of heterogeneity variance. Key drivers are `n_studies` and `year_range`.

---

### 2. Model Explainability

**Purpose:** Understand *why* your model made specific predictions using SHAP and LIME.

#### Available Explanations

1. **SHAP Waterfall** - Shows how each feature contributes to a single prediction
2. **LIME Contributions** - Alternative explanation method for comparison
3. **Global Feature Importance** - Which features matter most overall
4. **Clinical Narrative** - Plain English explanation for healthcare context

#### Step-by-Step Guide

1. **Select a Trained Model**
   - Must first train a model in the Ensemble Models tab
   - Model must be registered in the model registry

2. **Choose Instance to Explain**
   - Select a study from your dataset
   - Or upload new study characteristics

3. **Generate Explanation**
   - Click "Explain Prediction"
   - Wait 10-30 seconds (first time may be slower)
   - Subsequent requests are cached (<10ms)

4. **Interpret Results**
   - **SHAP Values:** Positive = increases prediction, Negative = decreases
   - **Base Value:** Average prediction across all training data
   - **Final Prediction:** Base + sum of SHAP values

5. **Read Clinical Narrative**
   - AI-generated explanation in plain English
   - Highlights top 3 contributing factors
   - Provides clinical context

#### Example Output

```
Study: Johnson et al. 2022
Prediction: High heterogeneity (I² = 75%)

Top 3 Contributors:
1. ⬆️ Few studies (n=4): +18% I²
2. ⬆️ Wide year range (20 years): +12% I²
3. ⬇️ Low risk of bias: -5% I²

Clinical Narrative:
"This meta-analysis is predicted to have high heterogeneity primarily
due to the small number of included studies (n=4) and wide publication
year range (20 years). Despite low risk of bias, the limited sample
and temporal heterogeneity drive the high I² prediction."
```

#### Best Practices

✅ **Always check both SHAP and LIME** - Should agree on major features
✅ **Focus on top 3-5 features** - Others usually contribute minimally
✅ **Use clinical narratives** for reporting and presentations
✅ **Verify with domain knowledge** - ML should align with clinical reasoning

---

### 3. RAG Q&A System

**Purpose:** Ask natural language questions about your meta-analysis literature and get AI-powered answers with citations.

#### What is RAG?

RAG (Retrieval-Augmented Generation) combines:
- **Retrieval:** Finds relevant studies in your knowledge base
- **Generation:** Uses LLM to synthesize answers from retrieved content
- **Citations:** Every answer includes source studies

#### Step-by-Step Guide

1. **Upload Knowledge Base** (First Time Only)
   - Click "Upload Studies (CSV)"
   - Format: columns must include `title`, `abstract`, `authors`, `year`
   - Example: `meta_analysis_studies.csv`

2. **Choose Retrieval Method**
   - **TF-IDF:** Fast keyword matching (recommended for >100 studies)
   - **Semantic:** Neural embeddings for meaning-based search (more accurate)
   - **Hybrid:** Combines both (best results, slightly slower)

3. **Ask Questions**
   - Type your question in the text box
   - Or use Quick Query buttons for common questions:
     - "Why is there heterogeneity?"
     - "What are the publication bias risks?"
     - "Should I do a network meta-analysis?"
     - "How should I assess quality (GRADE)?"

4. **Review Answer**
   - AI-generated response based on your studies
   - Source citations with relevance scores
   - Retrieval method used (TF-IDF/Semantic/Hybrid)

#### Example Interaction

**Question:** "Why is there high heterogeneity in my meta-analysis?"

**Answer:**
```
Based on 12 retrieved studies, heterogeneity may stem from:

1. Different interventions: Studies compare Drug A vs Placebo (5 studies),
   Drug A vs Drug B (4 studies), and combination therapy (3 studies).

2. Population heterogeneity: Age ranges from 18-45 (pediatric-adjacent)
   to 65+ (elderly), with different baseline risk profiles.

3. Outcome measurement: 5 studies use continuous outcomes (change in BP),
   7 studies use binary outcomes (reaching target BP <140/90).

Sources:
• Smith et al. 2020 (relevance: 0.92)
• Johnson et al. 2021 (relevance: 0.88)
• [10 more studies...]
```

#### Quick Query Examples

| Button | Purpose | Use When |
|--------|---------|----------|
| **Heterogeneity** | Understand I² sources | I² > 50% |
| **Publication Bias** | Assess bias risks | Funnel plot asymmetry |
| **NMA** | Network MA feasibility | >2 treatment comparisons |
| **GRADE** | Quality assessment guidance | Writing recommendations |

#### Tips for Better Results

✅ **Be specific:** "Why do RCTs show different effects than cohort studies?"
   vs. "Why different results?"
✅ **Include context:** "For cardiovascular outcomes, what's the risk of bias?"
✅ **Upload complete abstracts:** More text = better retrieval
✅ **Use hybrid mode** for most accurate answers

---

### 4. AutoML Optimization

**Purpose:** Automatically find the best hyperparameters for your ML models using Bayesian optimization.

#### What is AutoML?

AutoML uses **Optuna** (state-of-the-art Bayesian optimization) to:
- Try hundreds of hyperparameter combinations
- Learn which configurations work best
- Find optimal settings in minutes instead of hours

#### Step-by-Step Guide

**Step 1: Upload Data**
- Click "Browse" and select your CSV file
- Required columns: target variable + feature columns
- Recommended: >100 rows for reliable optimization

**Step 2: Configure Optimization**
- **Target Variable:** What to predict (e.g., `heterogeneity_i2`)
- **Features:** Predictor columns (select multiple)
- **Models:** Which models to optimize:
  - ☑️ XGBoost
  - ☑️ LightGBM
  - ☑️ CatBoost
- **Metric:** Optimization goal (AUC, F1, Accuracy, R², MAE)
- **Trials:** Number of configurations to try (recommended: 20-50)

**Step 3: Run Optimization**
- Click "Start Optimization"
- **Time estimate:** 1-2 minutes per trial
  - 20 trials ≈ 30-40 minutes
  - 50 trials ≈ 1.5-2 hours
- Progress updates every 5 trials
- Can be interrupted (best result so far will be saved)

**Step 4: Review Results**
- **Best Model:** Top-performing model and hyperparameters
- **Performance:** Cross-validated metrics
- **Hyperparameters:** Optimal settings found
- **Trial History:** All configurations tried
- **Comparison Table:** All 3 models side-by-side

**Step 5: Deploy Model**
- Click "Deploy Best Model"
- Model is registered in model registry
- Available for predictions and explainability

#### Example Output

```
Optimization Complete! (25 trials, 45 minutes)

Best Model: XGBoost
Performance:
  - Cross-validated AUC: 0.89 (±0.03)
  - Training time: 2.3 seconds

Optimal Hyperparameters:
  - max_depth: 6
  - learning_rate: 0.05
  - n_estimators: 200
  - min_child_weight: 3
  - subsample: 0.8
  - colsample_bytree: 0.7

Comparison:
| Model     | AUC   | F1    | Training Time |
|-----------|-------|-------|---------------|
| XGBoost   | 0.89  | 0.84  | 2.3s          |
| LightGBM  | 0.87  | 0.82  | 1.1s          |
| CatBoost  | 0.88  | 0.83  | 3.7s          |
```

#### When to Use AutoML

✅ **You need maximum accuracy** - AutoML finds better hyperparameters
✅ **You have time** - Optimization takes 30-120 minutes
✅ **Your task is important** - Production deployment, publications
✅ **Default models underperform** - When baseline results aren't good enough

#### When NOT to Use AutoML

❌ **Quick exploration** - Use default models in Ensemble tab
❌ **Small datasets** - <50 samples makes optimization unreliable
❌ **Time-sensitive** - Need results in <5 minutes

---

## 💡 Best Practices

### Data Preparation

1. **Clean your data**
   - Remove rows with >50% missing values
   - Handle outliers (>3 SD from mean)
   - Encode categorical variables consistently

2. **Feature engineering**
   - Create meaningful features (e.g., `year_since_first_study`)
   - Avoid highly correlated features (r > 0.9)
   - Normalize if features have different scales

3. **Train/test split**
   - Use 80/20 split for evaluation
   - Or k-fold cross-validation (k=5 or 10)

### Model Selection

| Dataset Size | Recommended Model | Reason |
|--------------|-------------------|--------|
| <100 samples | XGBoost | Best with small data |
| 100-1,000 | XGBoost or CatBoost | Balanced speed/accuracy |
| >1,000 | LightGBM | Fastest for large data |
| Many categorical features | CatBoost | Native categorical support |

### Caching Strategy

- **First run:** May take 30-60 seconds
- **Cached runs:** <10ms (100-1000x faster)
- **Cache duration:** 1 hour for predictions, 30 minutes for recommendations
- **Clear cache:** If you update your data or retrain models

### Explainability Tips

1. **Always explain important predictions**
   - High-stakes decisions
   - Unexpected results
   - Outliers

2. **Use both SHAP and LIME**
   - Should agree on top features
   - If they disagree, investigate further

3. **Generate clinical narratives**
   - For presentations
   - For manuscript methods sections
   - For stakeholder communication

---

## 🔧 Troubleshooting

### Common Issues

#### 1. "Model training failed"

**Cause:** Insufficient or incompatible data

**Solutions:**
- Ensure ≥50 rows in dataset
- Check for missing target variable
- Verify feature columns have numerical values
- Remove columns with >80% missing values

#### 2. "Explanation generation slow"

**Cause:** First-time computation (no cache)

**Solutions:**
- Wait for initial computation (10-30 seconds)
- Subsequent requests will be cached (<10ms)
- Check Redis is running for caching

#### 3. "RAG answers are irrelevant"

**Cause:** Poor retrieval or insufficient context

**Solutions:**
- Use **Hybrid** mode instead of TF-IDF
- Upload complete abstracts (not just titles)
- Ensure studies are relevant to your question
- Rephrase question with more specific terms

#### 4. "AutoML taking too long"

**Cause:** Too many trials or complex models

**Solutions:**
- Reduce number of trials (20-30 is usually enough)
- Optimize only 1-2 models instead of all 3
- Use smaller dataset for initial exploration
- Can interrupt and use best result so far

#### 5. "Cache not working"

**Cause:** Redis not running or misconfigured

**Solutions:**
```bash
# Check if Redis is running
redis-cli ping
# Should return: PONG

# Start Redis if not running
redis-server

# Check cache stats in application
# Navigate to ML/AI → Settings → Cache Stats
```

### Performance Issues

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| Slow predictions | No caching | Start Redis server |
| Out of memory | Dataset too large | Use LightGBM, reduce features |
| Model won't train | Incompatible data types | Check all features are numeric |
| Explainability errors | Model not registered | Retrain and register model |

### Getting Help

If you encounter issues not covered here:

1. **Check logs:**
   ```bash
   # Backend logs
   tail -f backend/logs/ml.log

   # Frontend R console
   # Check RStudio console for error messages
   ```

2. **Test ML backend:**
   ```bash
   curl http://localhost:8000/health/ml
   # Should return JSON with component status
   ```

3. **GitHub Issues:**
   - Report bugs: https://github.com/your-org/evidenceos/issues
   - Check existing issues for solutions

---

## ❓ FAQs

### General

**Q: Do I need coding skills to use ML features?**
A: No! All features are accessible through the UI with no coding required.

**Q: Is my data sent to external servers?**
A: No. All processing happens locally. RAG uses local Llama 3 model.

**Q: How much data do I need?**
A: Minimum 50 samples, but 100-500 is ideal for reliable models.

**Q: Can I use my own data format?**
A: Yes, but must have CSV with required columns (varies by feature).

### Technical

**Q: Which model should I choose?**
A: Start with XGBoost (best all-around). Use LightGBM if >1,000 studies. Use CatBoost if many categorical features.

**Q: What's the difference between SHAP and LIME?**
A: SHAP is theoretically grounded (game theory), LIME is faster but less rigorous. Both should agree on important features.

**Q: How long does AutoML take?**
A: 1-2 minutes per trial. 20 trials ≈ 30-40 minutes. 50 trials ≈ 1-2 hours.

**Q: Can I export models for use elsewhere?**
A: Yes! Models are saved in the model registry. Export as .pkl files.

### Interpretation

**Q: What's a good AUC score?**
A: 0.5 = random, 0.7 = acceptable, 0.8 = good, 0.9 = excellent, >0.95 = possibly overfit

**Q: What's a good R² for regression?**
A: Depends on domain. For meta-analysis: 0.3 = weak, 0.5 = moderate, 0.7 = strong, >0.8 = very strong

**Q: How do I know if my model is overfitting?**
A: Compare training vs validation performance. If training >> validation (>10% difference), you're overfitting.

### Data Privacy

**Q: Where is my data stored?**
A: Locally on your server. Nothing leaves your infrastructure.

**Q: Is the LLM sending my data to OpenAI/Anthropic?**
A: No. We use local Llama 3 models. Zero external API calls.

**Q: Can I use this for HIPAA-compliant projects?**
A: Yes, since all processing is local. However, consult your compliance officer.

---

## 📚 Additional Resources

### Documentation
- [ML/AI Features Overview](AI_ML_FEATURES.md)
- [Caching Guide](backend/docs/CACHING_GUIDE.md)
- [Testing Guide](backend/docs/TESTING_GUIDE.md)
- [Production Runbook](PRODUCTION_RUNBOOK.md)

### Tutorials
- Video: "Getting Started with ML Features" (15 min)
- Video: "Understanding SHAP Explanations" (10 min)
- Video: "RAG Q&A System Deep Dive" (12 min)

### Scientific Background
- [SHAP Paper](https://arxiv.org/abs/1705.07874) - Lundberg & Lee, 2017
- [LIME Paper](https://arxiv.org/abs/1602.04938) - Ribeiro et al., 2016
- [XGBoost Paper](https://arxiv.org/abs/1603.02754) - Chen & Guestrin, 2016

---

## 📞 Support

**Questions?** Contact: support@evidenceos.com
**Bug reports:** GitHub Issues
**Feature requests:** GitHub Discussions

---

**Last Updated:** 2025-01-05
**Version:** 2.0
**License:** MIT
