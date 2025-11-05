#!/usr/bin/env python3
"""
Effect Size Estimator - FIXED VERSION (No Data Leakage)
Predict treatment effect sizes from PRE-OUTCOME study characteristics ONLY

CRITICAL FIX: Removed all outcome-derived features (event rates, event rate differences)
Now uses only features available BEFORE observing outcomes

Dataset: 86,492 real RCTs from 501 Cochrane systematic reviews (Pairwise70)
Source: Real published Cochrane reviews
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import Ridge, Lasso
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
print("EFFECT SIZE ESTIMATOR - FIXED (NO DATA LEAKAGE)")
print("=" * 80)
print("\n⚠️  CRITICAL CHANGE: Using ONLY pre-outcome features")
print("   Removed: event rates, event rate differences, total events")
print("   Using: sample sizes, allocation ratio, publication year")
print("=" * 80)

# ============================================================================
# 1. LOAD REAL COCHRANE DATA
# ============================================================================
print("\n📊 Loading REAL Cochrane RCT data from Pairwise70...")

df = pd.read_csv('data/validation_datasets/pairwise70_real_cochrane_studies.csv')

print(f"✅ Loaded {len(df):,} REAL RCTs from Cochrane reviews")
print(f"   From {df['cochrane_id'].nunique()} Cochrane systematic reviews")
print(f"   Meta-analyses: {df['ma_id'].nunique()}")
print(f"   Fields: {len(df.columns)}")

# ============================================================================
# 2. DATA PREPROCESSING
# ============================================================================
print("\n🔧 Preprocessing real data...")

# Filter for studies with effect size data
binary_data = df[
    df['Experimental.cases'].notna() &
    df['Experimental.N'].notna() &
    df['Control.cases'].notna() &
    df['Control.N'].notna() &
    (df['Experimental.N'] > 0) &
    (df['Control.N'] > 0)
].copy()

print(f"✅ Binary outcome studies: {len(binary_data):,}")

# Calculate log odds ratio (effect size for binary outcomes)
def calculate_log_or(row):
    """Calculate log odds ratio with continuity correction"""
    exp_events = row['Experimental.cases'] + 0.5
    exp_non = row['Experimental.N'] - row['Experimental.cases'] + 0.5
    con_events = row['Control.cases'] + 0.5
    con_non = row['Control.N'] - row['Control.cases'] + 0.5

    exp_odds = exp_events / exp_non
    con_odds = con_events / con_non

    if exp_odds > 0 and con_odds > 0:
        return np.log(exp_odds / con_odds)
    else:
        return np.nan

binary_data['log_or'] = binary_data.apply(calculate_log_or, axis=1)

# Remove extreme outliers (more than 3 standard deviations)
log_or_mean = binary_data['log_or'].mean()
log_or_std = binary_data['log_or'].std()
binary_data = binary_data[
    (binary_data['log_or'] > log_or_mean - 3*log_or_std) &
    (binary_data['log_or'] < log_or_mean + 3*log_or_std)
].copy()

print(f"✅ After filtering: {len(binary_data):,} studies")
print(f"   Log OR range: [{binary_data['log_or'].min():.3f}, {binary_data['log_or'].max():.3f}]")
print(f"   Log OR mean: {binary_data['log_or'].mean():.3f}")
print(f"   Log OR std: {binary_data['log_or'].std():.3f}")

# ============================================================================
# 3. FEATURE ENGINEERING - PRE-OUTCOME FEATURES ONLY
# ============================================================================
print("\n🔧 Engineering features - PRE-OUTCOME characteristics ONLY...")
print("   ⚠️  NO event rates, NO event rate differences, NO total events")
print("   ✅ Sample sizes, allocation ratio, publication year")

# Create PRE-OUTCOME features only
binary_data['total_n'] = binary_data['Experimental.N'] + binary_data['Control.N']
binary_data['exp_n'] = binary_data['Experimental.N']
binary_data['con_n'] = binary_data['Control.N']
binary_data['allocation_ratio'] = binary_data['Experimental.N'] / binary_data['Control.N']

# Log transformations for skewed features
binary_data['log_total_n'] = np.log(binary_data['total_n'] + 1)
binary_data['log_exp_n'] = np.log(binary_data['exp_n'] + 1)
binary_data['log_con_n'] = np.log(binary_data['con_n'] + 1)

# Study year if available
if 'Study.year' in binary_data.columns:
    binary_data['study_year'] = pd.to_numeric(binary_data['Study.year'], errors='coerce')
    binary_data['study_year'] = binary_data['study_year'].fillna(binary_data['study_year'].median())
    binary_data['years_since_2000'] = binary_data['study_year'] - 2000
else:
    binary_data['years_since_2000'] = 0

# Interaction features
binary_data['total_n_squared'] = binary_data['total_n'] ** 2
binary_data['allocation_ratio_squared'] = binary_data['allocation_ratio'] ** 2

# Select features for modeling - PRE-OUTCOME ONLY
feature_cols = [
    'total_n',
    'log_total_n',
    'exp_n',
    'log_exp_n',
    'con_n',
    'log_con_n',
    'allocation_ratio',
    'allocation_ratio_squared',
    'years_since_2000',
    'total_n_squared'
]

# Remove rows with missing features
modeling_data = binary_data[feature_cols + ['log_or']].dropna()

print(f"✅ Final modeling dataset: {len(modeling_data):,} studies")
print(f"   Features: {len(feature_cols)}")
print(f"   Feature list: {', '.join(feature_cols)}")

X = modeling_data[feature_cols].copy()
y = modeling_data['log_or'].copy()

# ============================================================================
# 4. TRAIN-TEST SPLIT
# ============================================================================
print("\n📊 Splitting real Cochrane data...")

# Use 70-30 split for large dataset
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.30, random_state=42
)

print(f"✅ Training set: {len(X_train):,} RCTs ({len(X_train)/len(X)*100:.1f}%)")
print(f"✅ Test set: {len(X_test):,} RCTs ({len(X_test)/len(X)*100:.1f}%)")
print(f"\n   Training log OR: mean={y_train.mean():.3f}, std={y_train.std():.3f}")
print(f"   Test log OR: mean={y_test.mean():.3f}, std={y_test.std():.3f}")

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

print(f"   RMSE: {baseline_rmse:.4f}")
print(f"   MAE: {baseline_mae:.4f}")
print(f"   R²: {baseline_r2:.4f}")
print("   ⚠️  This is the performance ML models must BEAT")

# ============================================================================
# 6. MODEL TRAINING
# ============================================================================
print("\n🤖 Training Models on REAL Cochrane Data (Pre-outcome features only)...")
print("-" * 80)

models = {
    'Random Forest': RandomForestRegressor(
        n_estimators=100,
        max_depth=10,
        min_samples_split=20,
        min_samples_leaf=10,
        random_state=42,
        n_jobs=-1
    ),
    'Gradient Boosting': GradientBoostingRegressor(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=5,
        random_state=42
    ),
    'Ridge Regression': Ridge(alpha=1.0, random_state=42),
    'Lasso Regression': Lasso(alpha=0.01, random_state=42, max_iter=10000)
}

results = {}

for name, model in models.items():
    print(f"\n🔄 Training {name}...")

    # Use scaled data for linear models
    if 'Ridge' in name or 'Lasso' in name:
        model.fit(X_train_scaled, y_train)
        y_pred = model.predict(X_test_scaled)
    else:
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)

    # Calculate metrics
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    mae = mean_absolute_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)

    # Pearson correlation
    correlation = np.corrcoef(y_test, y_pred)[0, 1]

    results[name] = {
        'model': model,
        'rmse': rmse,
        'mae': mae,
        'r2': r2,
        'correlation': correlation,
        'predictions': y_pred
    }

    # Improvement over baseline
    improvement = ((baseline_rmse - rmse) / baseline_rmse) * 100

    print(f"   RMSE: {rmse:.4f} (baseline: {baseline_rmse:.4f})")
    print(f"   MAE: {mae:.4f} (baseline: {baseline_mae:.4f})")
    print(f"   R²: {r2:.4f} (baseline: {baseline_r2:.4f})")
    print(f"   Pearson r: {correlation:.4f}")
    print(f"   Improvement over baseline: {improvement:+.1f}%")

# ============================================================================
# 7. SELECT BEST MODEL
# ============================================================================
print("\n" + "=" * 80)
print("📊 MODEL COMPARISON")
print("=" * 80)

comparison_df = pd.DataFrame({
    'Model': list(results.keys()),
    'RMSE': [results[m]['rmse'] for m in results.keys()],
    'MAE': [results[m]['mae'] for m in results.keys()],
    'R²': [results[m]['r2'] for m in results.keys()],
    'Pearson r': [results[m]['correlation'] for m in results.keys()]
})

# Add baseline
baseline_row = pd.DataFrame({
    'Model': ['Baseline (Mean)'],
    'RMSE': [baseline_rmse],
    'MAE': [baseline_mae],
    'R²': [baseline_r2],
    'Pearson r': [0.0]
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
print(f"   RMSE: {best_rmse:.4f}")
print(f"   MAE: {best_mae:.4f}")
print(f"   R²: {best_r2:.4f}")

# Realistic assessment
if best_r2 < 0.05:
    assessment = "Very weak predictive power - essentially no better than mean"
elif best_r2 < 0.15:
    assessment = "Weak predictive power - minimal practical utility"
elif best_r2 < 0.30:
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

    # Plot feature importance
    plt.figure(figsize=(10, 6))
    plt.barh(feature_imp_df['Feature'], feature_imp_df['Importance'])
    plt.xlabel('Importance')
    plt.title(f'Feature Importance - {best_model_name} (Pre-outcome features only)')
    plt.tight_layout()
    plt.savefig('outputs/effect_size_estimator_FIXED/feature_importance.png', dpi=300, bbox_inches='tight')
    print("   ✅ Saved: outputs/effect_size_estimator_FIXED/feature_importance.png")

# ============================================================================
# 9. VISUALIZATIONS
# ============================================================================
print("\n📊 Creating visualizations...")

import os
os.makedirs('outputs/effect_size_estimator_FIXED', exist_ok=True)

# 1. Predicted vs Actual
plt.figure(figsize=(10, 10))
plt.scatter(y_test, results[best_model_name]['predictions'], alpha=0.3, s=10)
plt.plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()], 'r--', lw=2, label='Perfect Prediction')
plt.xlabel('Actual Log OR')
plt.ylabel('Predicted Log OR')
plt.title(f'Predicted vs Actual - {best_model_name}\n(Pre-outcome features only: R²={best_r2:.4f})')
plt.legend()
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator_FIXED/predicted_vs_actual.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: predicted_vs_actual.png")

# 2. Residuals
residuals = y_test - results[best_model_name]['predictions']
plt.figure(figsize=(10, 6))
plt.scatter(results[best_model_name]['predictions'], residuals, alpha=0.3, s=10)
plt.axhline(y=0, color='r', linestyle='--', lw=2)
plt.xlabel('Predicted Log OR')
plt.ylabel('Residuals')
plt.title(f'Residuals Plot - {best_model_name}\n(Mean={residuals.mean():.4f}, Std={residuals.std():.4f})')
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator_FIXED/residuals.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: residuals.png")

# 3. Model comparison
plt.figure(figsize=(10, 6))
x_pos = np.arange(len(comparison_df))
plt.bar(x_pos, comparison_df['R²'])
plt.xticks(x_pos, comparison_df['Model'], rotation=45, ha='right')
plt.ylabel('R² Score')
plt.title('Model Comparison (Pre-outcome features only)')
plt.axhline(y=0, color='r', linestyle='--', lw=1)
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator_FIXED/model_comparison.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: model_comparison.png")

# 4. Distribution comparison
plt.figure(figsize=(10, 6))
plt.hist(y_test, bins=50, alpha=0.5, label='Actual', density=True)
plt.hist(results[best_model_name]['predictions'], bins=50, alpha=0.5, label='Predicted', density=True)
plt.xlabel('Log OR')
plt.ylabel('Density')
plt.title(f'Distribution Comparison - {best_model_name}')
plt.legend()
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator_FIXED/distribution_comparison.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: distribution_comparison.png")

# ============================================================================
# 10. SAVE MODELS
# ============================================================================
print("\n💾 Saving models and results...")

# Save best model
joblib.dump(best_model, 'outputs/effect_size_estimator_FIXED/best_model.pkl')
joblib.dump(scaler, 'outputs/effect_size_estimator_FIXED/scaler.pkl')
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
    'feature_engineering': 'Pre-outcome features only (NO event rates)',
    'data_leakage': 'FIXED - no outcome-derived features',
    'all_models': {
        name: {
            'rmse': float(results[name]['rmse']),
            'mae': float(results[name]['mae']),
            'r2': float(results[name]['r2']),
            'correlation': float(results[name]['correlation'])
        }
        for name in results.keys()
    }
}

with open('outputs/effect_size_estimator_FIXED/results_summary.json', 'w') as f:
    json.dump(summary, f, indent=2)

print("   ✅ Saved results_summary.json")

# ============================================================================
# 11. FINAL SUMMARY
# ============================================================================
print("\n" + "=" * 80)
print("✅ EFFECT SIZE ESTIMATOR - FIXED VERSION COMPLETE")
print("=" * 80)
print(f"\n📊 FINAL RESULTS:")
print(f"   Dataset: {len(X):,} real RCTs from Cochrane reviews")
print(f"   Features: {len(feature_cols)} PRE-OUTCOME features")
print(f"   Best Model: {best_model_name}")
print(f"   R²: {best_r2:.4f} (Baseline: {baseline_r2:.4f})")
print(f"   RMSE: {best_rmse:.4f} (Baseline: {baseline_rmse:.4f})")
print(f"   MAE: {best_mae:.4f} (Baseline: {baseline_mae:.4f})")
print(f"\n⚠️  CRITICAL NOTE:")
print(f"   This model uses ONLY pre-outcome features (sample sizes, allocation ratio, year)")
print(f"   Performance is realistic for GENUINE prediction (R²={best_r2:.4f})")
print(f"   This is scientifically valid but has limited practical utility")
print(f"   Previous version (R²=0.9945) had data leakage and was invalid")
print(f"\n💡 INTERPRETATION:")
print(f"   {assessment}")
print(f"   Pre-outcome features explain {best_r2*100:.1f}% of variance in treatment effects")
print(f"\n📁 All outputs saved to: outputs/effect_size_estimator_FIXED/")
print("=" * 80)
