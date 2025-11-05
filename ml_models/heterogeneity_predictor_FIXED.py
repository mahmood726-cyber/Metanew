#!/usr/bin/env python3
"""
Heterogeneity (I²) Predictor - FIXED VERSION (No Data Leakage)
Predict between-study heterogeneity from PRE-EFFECT SIZE meta-analysis characteristics

CRITICAL FIX: Removed all effect size variability features (SD, range of effect sizes)
Now uses only features available BEFORE calculating individual study effect sizes

Dataset: 501 real Cochrane systematic reviews (Pairwise70)
Outcome: I² statistic (0-100%)
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.dummy import DummyRegressor
import joblib
import json
import warnings
warnings.filterwarnings('ignore')

# Set random seed
np.random.seed(42)

# Configure plotting
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)

print("=" * 80)
print("HETEROGENEITY (I²) PREDICTOR - FIXED (NO DATA LEAKAGE)")
print("=" * 80)
print("\n⚠️  CRITICAL CHANGE: Using ONLY pre-effect size features")
print("   Removed: SD of effect sizes, range of effect sizes")
print("   Using: study count, sample sizes, baseline risks")
print("=" * 80)

# ============================================================================
# 1. LOAD REAL COCHRANE DATA
# ============================================================================
print("\n📊 Loading REAL Cochrane meta-analysis data...")

df = pd.read_csv('data/validation_datasets/pairwise70_real_cochrane_studies.csv')

print(f"✅ Loaded {len(df):,} RCTs from Cochrane reviews")
print(f"   From {df['ma_id'].nunique()} meta-analyses")

# ============================================================================
# 2. CALCULATE I² FOR EACH META-ANALYSIS
# ============================================================================
print("\n🔧 Calculating I² statistic for each meta-analysis...")

# Group by meta-analysis
ma_groups = df.groupby('ma_id')

meta_analyses = []

for ma_id, ma_data in ma_groups:
    # Need at least 2 studies for I²
    if len(ma_data) < 2:
        continue

    # Calculate effect sizes (log OR for binary outcomes)
    # Filter for studies with complete data
    complete = ma_data[
        ma_data['Experimental.cases'].notna() &
        ma_data['Experimental.N'].notna() &
        ma_data['Control.cases'].notna() &
        ma_data['Control.N'].notna() &
        (ma_data['Experimental.N'] > 0) &
        (ma_data['Control.N'] > 0)
    ].copy()

    if len(complete) < 2:
        continue

    # Calculate log OR with continuity correction
    complete['log_or'] = np.log(
        ((complete['Experimental.cases'] + 0.5) * (complete['Control.N'] - complete['Control.cases'] + 0.5)) /
        ((complete['Experimental.N'] - complete['Experimental.cases'] + 0.5) * (complete['Control.cases'] + 0.5))
    )

    # Calculate variance
    complete['var_log_or'] = (
        1/(complete['Experimental.cases'] + 0.5) +
        1/(complete['Experimental.N'] - complete['Experimental.cases'] + 0.5) +
        1/(complete['Control.cases'] + 0.5) +
        1/(complete['Control.N'] - complete['Control.cases'] + 0.5)
    )

    # Remove extreme values
    log_or_std = complete['log_or'].std()
    if pd.isna(log_or_std) or log_or_std == 0:
        continue

    complete = complete[
        (complete['log_or'] > complete['log_or'].mean() - 3*log_or_std) &
        (complete['log_or'] < complete['log_or'].mean() + 3*log_or_std)
    ]

    if len(complete) < 2:
        continue

    # Calculate Q statistic (Cochran's Q)
    weights = 1 / complete['var_log_or']
    weighted_mean = (weights * complete['log_or']).sum() / weights.sum()
    Q = (weights * (complete['log_or'] - weighted_mean)**2).sum()

    # Degrees of freedom
    df_q = len(complete) - 1

    # Calculate I² = ((Q - df) / Q) * 100, bounded at 0
    i_squared = max(0, ((Q - df_q) / Q) * 100) if Q > 0 else 0

    # PRE-EFFECT SIZE Meta-analysis characteristics
    # Calculate baseline event rates (these are OK - not derived from effect sizes)
    complete['exp_event_rate'] = complete['Experimental.cases'] / complete['Experimental.N']
    complete['con_event_rate'] = complete['Control.cases'] / complete['Control.N']
    complete['total_n'] = complete['Experimental.N'] + complete['Control.N']
    complete['allocation_ratio'] = complete['Experimental.N'] / complete['Control.N']

    ma_stats = {
        'ma_id': ma_id,

        # Study count features
        'n_studies': len(complete),
        'log_n_studies': np.log(len(complete)),

        # Sample size features
        'total_participants': complete['Experimental.N'].sum() + complete['Control.N'].sum(),
        'log_total_participants': np.log(complete['Experimental.N'].sum() + complete['Control.N'].sum()),
        'mean_sample_size': complete['total_n'].mean(),
        'sd_sample_size': complete['total_n'].std(),
        'min_sample_size': complete['total_n'].min(),
        'max_sample_size': complete['total_n'].max(),
        'range_sample_size': complete['total_n'].max() - complete['total_n'].min(),
        'cv_sample_size': complete['total_n'].std() / complete['total_n'].mean() if complete['total_n'].mean() > 0 else 0,

        # Baseline risk features (event rates - NOT effect sizes)
        'mean_events_exp': complete['exp_event_rate'].mean(),
        'sd_events_exp': complete['exp_event_rate'].std(),
        'mean_events_con': complete['con_event_rate'].mean(),
        'sd_events_con': complete['con_event_rate'].std(),
        'mean_baseline_risk': (complete['exp_event_rate'].mean() + complete['con_event_rate'].mean()) / 2,

        # Allocation ratio features
        'mean_allocation_ratio': complete['allocation_ratio'].mean(),
        'sd_allocation_ratio': complete['allocation_ratio'].std(),

        # Outcome variable
        'i_squared': i_squared,
        'Q_statistic': Q
    }

    meta_analyses.append(ma_stats)

ma_df = pd.DataFrame(meta_analyses)

print(f"✅ Calculated I² for {len(ma_df)} meta-analyses")
print(f"\nI² Statistics:")
print(f"   Mean: {ma_df['i_squared'].mean():.1f}%")
print(f"   Median: {ma_df['i_squared'].median():.1f}%")
print(f"   Range: [{ma_df['i_squared'].min():.1f}%, {ma_df['i_squared'].max():.1f}%]")

# Categorize heterogeneity
ma_df['heterogeneity_category'] = pd.cut(
    ma_df['i_squared'],
    bins=[0, 25, 50, 75, 100],
    labels=['Low', 'Moderate', 'Substantial', 'Considerable'],
    include_lowest=True
)

print(f"\nHeterogeneity Categories:")
print(ma_df['heterogeneity_category'].value_counts().sort_index())

# ============================================================================
# 3. FEATURE ENGINEERING - PRE-EFFECT SIZE FEATURES ONLY
# ============================================================================
print("\n🔧 Engineering features - PRE-EFFECT SIZE characteristics ONLY...")
print("   ⚠️  NO SD/range of effect sizes")
print("   ✅ Study count, sample sizes, baseline risks, allocation ratios")

# Select features for prediction - NO EFFECT SIZE VARIABILITY
feature_cols = [
    # Study count
    'n_studies',
    'log_n_studies',

    # Sample size features
    'total_participants',
    'log_total_participants',
    'mean_sample_size',
    'sd_sample_size',
    'range_sample_size',
    'cv_sample_size',

    # Baseline risk features
    'mean_events_exp',
    'sd_events_exp',
    'mean_events_con',
    'sd_events_con',
    'mean_baseline_risk',

    # Allocation features
    'mean_allocation_ratio',
    'sd_allocation_ratio'
]

X = ma_df[feature_cols].copy()
y = ma_df['i_squared'].copy()

# Remove any remaining NaN
mask = ~(X.isna().any(axis=1) | y.isna())
X = X[mask]
y = y[mask]

print(f"✅ Final dataset: {len(X)} meta-analyses with complete data")
print(f"   Features: {len(X.columns)}")
print(f"   Feature list: {', '.join(feature_cols[:5])}... (+{len(feature_cols)-5} more)")

# ============================================================================
# 4. TRAIN-TEST SPLIT
# ============================================================================
print("\n📊 Splitting data...")

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42
)

print(f"✅ Training set: {len(X_train)} meta-analyses")
print(f"✅ Test set: {len(X_test)} meta-analyses")
print(f"\n   Training I²: mean={y_train.mean():.1f}%, std={y_train.std():.1f}%")
print(f"   Test I²: mean={y_test.mean():.1f}%, std={y_test.std():.1f}%")

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# ============================================================================
# 5. BASELINE MODEL - PREDICT MEAN
# ============================================================================
print("\n📊 Training BASELINE: Predict Mean (Null Model)...")

baseline = DummyRegressor(strategy='mean')
baseline.fit(X_train, y_train)
y_pred_baseline = baseline.predict(X_test)

baseline_rmse = np.sqrt(mean_squared_error(y_test, y_pred_baseline))
baseline_mae = mean_absolute_error(y_test, y_pred_baseline)
baseline_r2 = r2_score(y_test, y_pred_baseline)

print(f"   RMSE: {baseline_rmse:.2f}%")
print(f"   MAE: {baseline_mae:.2f}%")
print(f"   R²: {baseline_r2:.4f}")
print("   ⚠️  This is the performance ML models must BEAT")

# ============================================================================
# 6. MODEL TRAINING
# ============================================================================
print("\n🤖 Training Models on REAL Cochrane Data (Pre-effect size features only)...")
print("-" * 80)

models = {
    'Random Forest': RandomForestRegressor(
        n_estimators=100,
        max_depth=8,
        min_samples_split=5,
        random_state=42,
        n_jobs=-1
    ),
    'Gradient Boosting': GradientBoostingRegressor(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=4,
        random_state=42
    ),
    'Ridge Regression': Ridge(alpha=10.0, random_state=42)
}

results = {}

for name, model in models.items():
    print(f"\n🔄 Training {name}...")

    if 'Ridge' in name:
        model.fit(X_train_scaled, y_train)
        y_pred = model.predict(X_test_scaled)
    else:
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)

    # Bound predictions to [0, 100]
    y_pred = np.clip(y_pred, 0, 100)

    # Evaluate
    mse = mean_squared_error(y_test, y_pred)
    rmse = np.sqrt(mse)
    mae = mean_absolute_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)

    results[name] = {
        'model': model,
        'rmse': rmse,
        'mae': mae,
        'r2': r2,
        'predictions': y_pred
    }

    # Improvement over baseline
    improvement = ((baseline_rmse - rmse) / baseline_rmse) * 100

    print(f"   RMSE: {rmse:.2f}% (baseline: {baseline_rmse:.2f}%)")
    print(f"   MAE: {mae:.2f}% (baseline: {baseline_mae:.2f}%)")
    print(f"   R²: {r2:.4f} (baseline: {baseline_r2:.4f})")
    print(f"   Improvement over baseline: {improvement:+.1f}%")

# ============================================================================
# 7. SELECT BEST MODEL
# ============================================================================
print("\n" + "=" * 80)
print("📊 MODEL COMPARISON")
print("=" * 80)

comparison_df = pd.DataFrame({
    'Model': list(results.keys()),
    'RMSE (%)': [results[m]['rmse'] for m in results.keys()],
    'MAE (%)': [results[m]['mae'] for m in results.keys()],
    'R²': [results[m]['r2'] for m in results.keys()]
})

# Add baseline
baseline_row = pd.DataFrame({
    'Model': ['Baseline (Mean)'],
    'RMSE (%)': [baseline_rmse],
    'MAE (%)': [baseline_mae],
    'R²': [baseline_r2]
})

comparison_df = pd.concat([baseline_row, comparison_df], ignore_index=True)

print(comparison_df.to_string(index=False))

# Best model (lowest RMSE, excluding baseline)
best_model_name = min(results.keys(), key=lambda k: results[k]['rmse'])
best_model = results[best_model_name]['model']
best_rmse = results[best_model_name]['rmse']
best_mae = results[best_model_name]['mae']
best_r2 = results[best_model_name]['r2']

print(f"\n✅ BEST MODEL: {best_model_name}")
print(f"   RMSE: {best_rmse:.2f}%")
print(f"   MAE: {best_mae:.2f}%")
print(f"   R²: {best_r2:.4f}")

# Realistic assessment
if best_r2 < 0.10:
    assessment = "Very weak predictive power - essentially no better than mean"
elif best_r2 < 0.25:
    assessment = "Weak predictive power - minimal practical utility"
elif best_r2 < 0.40:
    assessment = "Moderate predictive power - some practical utility"
else:
    assessment = "Good predictive power - useful for planning"

print(f"   Assessment: {assessment}")

# ============================================================================
# 8. FEATURE IMPORTANCE (BEST MODEL)
# ============================================================================
print("\n📊 Feature Importance Analysis...")

if hasattr(best_model, 'feature_importances_'):
    importances = best_model.feature_importances_
    feature_imp_df = pd.DataFrame({
        'Feature': feature_cols,
        'Importance': importances
    }).sort_values('Importance', ascending=False)

    print(feature_imp_df.to_string(index=False))

# ============================================================================
# 9. VISUALIZATIONS
# ============================================================================
print("\n📊 Creating visualizations...")

import os
os.makedirs('outputs/heterogeneity_predictor_FIXED', exist_ok=True)

# 1. Feature importance
if hasattr(best_model, 'feature_importances_'):
    plt.figure(figsize=(10, 8))
    plt.barh(feature_imp_df['Feature'][:10], feature_imp_df['Importance'][:10])
    plt.xlabel('Importance')
    plt.title(f'Top 10 Feature Importance - {best_model_name}\n(Pre-effect size features only)')
    plt.tight_layout()
    plt.savefig('outputs/heterogeneity_predictor_FIXED/feature_importance.png', dpi=300, bbox_inches='tight')
    print("   ✅ Saved: feature_importance.png")

# 2. Predicted vs Actual
plt.figure(figsize=(10, 10))
plt.scatter(y_test, results[best_model_name]['predictions'], alpha=0.5, s=50)
plt.plot([0, 100], [0, 100], 'r--', lw=2, label='Perfect Prediction')
plt.xlabel('Actual I² (%)')
plt.ylabel('Predicted I² (%)')
plt.title(f'Predicted vs Actual - {best_model_name}\n(Pre-effect size features only: R²={best_r2:.4f})')
plt.legend()
plt.grid(True, alpha=0.3)
plt.xlim(-5, 105)
plt.ylim(-5, 105)
plt.tight_layout()
plt.savefig('outputs/heterogeneity_predictor_FIXED/predicted_vs_actual.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: predicted_vs_actual.png")

# 3. Distribution comparison
plt.figure(figsize=(10, 6))
plt.hist(y_test, bins=20, alpha=0.5, label='Actual', density=True)
plt.hist(results[best_model_name]['predictions'], bins=20, alpha=0.5, label='Predicted', density=True)
plt.xlabel('I² (%)')
plt.ylabel('Density')
plt.title(f'Distribution Comparison - {best_model_name}')
plt.legend()
plt.tight_layout()
plt.savefig('outputs/heterogeneity_predictor_FIXED/distribution_comparison.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: distribution_comparison.png")

# 4. Model comparison
plt.figure(figsize=(10, 6))
x_pos = np.arange(len(comparison_df))
plt.bar(x_pos, comparison_df['R²'])
plt.xticks(x_pos, comparison_df['Model'], rotation=45, ha='right')
plt.ylabel('R² Score')
plt.title('Model Comparison (Pre-effect size features only)')
plt.axhline(y=0, color='r', linestyle='--', lw=1)
plt.tight_layout()
plt.savefig('outputs/heterogeneity_predictor_FIXED/model_comparison.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: model_comparison.png")

# ============================================================================
# 10. SAVE MODELS
# ============================================================================
print("\n💾 Saving models and results...")

# Save best model
joblib.dump(best_model, 'outputs/heterogeneity_predictor_FIXED/best_model.pkl')
joblib.dump(scaler, 'outputs/heterogeneity_predictor_FIXED/scaler.pkl')
print(f"   ✅ Saved best model: {best_model_name}")

# Save results summary
summary = {
    'best_model': best_model_name,
    'best_r2': float(best_r2),
    'best_rmse': float(best_rmse),
    'best_mae': float(best_mae),
    'baseline_r2': float(baseline_r2),
    'baseline_rmse': float(baseline_rmse),
    'baseline_mae': float(baseline_mae),
    'n_train': int(len(X_train)),
    'n_test': int(len(X_test)),
    'features': feature_cols,
    'feature_engineering': 'Pre-effect size features only (NO effect size variability)',
    'data_leakage': 'FIXED - no effect size variability features',
    'all_models': {
        name: {
            'rmse': float(results[name]['rmse']),
            'mae': float(results[name]['mae']),
            'r2': float(results[name]['r2'])
        }
        for name in results.keys()
    }
}

with open('outputs/heterogeneity_predictor_FIXED/results_summary.json', 'w') as f:
    json.dump(summary, f, indent=2)

print("   ✅ Saved results_summary.json")

# ============================================================================
# 11. FINAL SUMMARY
# ============================================================================
print("\n" + "=" * 80)
print("✅ HETEROGENEITY PREDICTOR - FIXED VERSION COMPLETE")
print("=" * 80)
print(f"\n📊 FINAL RESULTS:")
print(f"   Dataset: {len(X)} meta-analyses from Cochrane reviews")
print(f"   Features: {len(feature_cols)} PRE-EFFECT SIZE features")
print(f"   Best Model: {best_model_name}")
print(f"   R²: {best_r2:.4f} (Baseline: {baseline_r2:.4f})")
print(f"   RMSE: {best_rmse:.2f}% (Baseline: {baseline_rmse:.2f}%)")
print(f"   MAE: {best_mae:.2f}% (Baseline: {baseline_mae:.2f}%)")
print(f"\n⚠️  CRITICAL NOTE:")
print(f"   This model uses ONLY pre-effect size features")
print(f"   (study counts, sample sizes, baseline risks, allocation ratios)")
print(f"   Performance is realistic for GENUINE prediction (R²={best_r2:.4f})")
print(f"   Previous version (R²=0.6135) had data leakage and inflated performance")
print(f"\n💡 INTERPRETATION:")
print(f"   {assessment}")
print(f"   Pre-effect size features explain {best_r2*100:.1f}% of variance in heterogeneity")
print(f"\n📁 All outputs saved to: outputs/heterogeneity_predictor_FIXED/")
print("=" * 80)
