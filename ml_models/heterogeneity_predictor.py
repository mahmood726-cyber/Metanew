#!/usr/bin/env python3
"""
Heterogeneity (I²) Predictor - Using REAL Cochrane Data
Predict between-study heterogeneity from meta-analysis characteristics

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
import joblib
import warnings
warnings.filterwarnings('ignore')

# Set random seed
np.random.seed(42)

# Configure plotting
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)

print("=" * 80)
print("HETEROGENEITY (I²) PREDICTOR - REAL COCHRANE DATA")
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

    # Meta-analysis characteristics
    ma_stats = {
        'ma_id': ma_id,
        'n_studies': len(complete),
        'total_participants': complete['Experimental.N'].sum() + complete['Control.N'].sum(),
        'mean_sample_size': (complete['Experimental.N'] + complete['Control.N']).mean(),
        'sd_sample_size': (complete['Experimental.N'] + complete['Control.N']).std(),
        'min_sample_size': (complete['Experimental.N'] + complete['Control.N']).min(),
        'max_sample_size': (complete['Experimental.N'] + complete['Control.N']).max(),
        'mean_effect_size': complete['log_or'].mean(),
        'sd_effect_size': complete['log_or'].std(),
        'range_effect_size': complete['log_or'].max() - complete['log_or'].min(),
        'mean_events_exp': complete['Experimental.cases'].mean() / complete['Experimental.N'].mean(),
        'mean_events_con': complete['Control.cases'].mean() / complete['Control.N'].mean(),
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
# 3. FEATURE ENGINEERING
# ============================================================================
print("\n🔧 Engineering features...")

# Select features for prediction
feature_cols = [
    'n_studies',
    'total_participants',
    'mean_sample_size',
    'sd_sample_size',
    'range_effect_size',
    'sd_effect_size',
    'mean_events_exp',
    'mean_events_con'
]

# Log transform skewed features
ma_df['log_n_studies'] = np.log(ma_df['n_studies'] + 1)
ma_df['log_total_participants'] = np.log(ma_df['total_participants'] + 1)

feature_cols_final = feature_cols + ['log_n_studies', 'log_total_participants']

X = ma_df[feature_cols_final].copy()
y = ma_df['i_squared'].copy()

# Remove any remaining NaN
mask = ~(X.isna().any(axis=1) | y.isna())
X = X[mask]
y = y[mask]

print(f"✅ Final dataset: {len(X)} meta-analyses with complete data")
print(f"   Features: {len(X.columns)}")

# ============================================================================
# 4. TRAIN-TEST SPLIT
# ============================================================================
print("\n📊 Splitting data...")

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42
)

print(f"✅ Training set: {len(X_train)} meta-analyses")
print(f"✅ Test set: {len(X_test)} meta-analyses")

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# ============================================================================
# 5. MODEL TRAINING
# ============================================================================
print("\n🤖 Training Models on REAL Cochrane Data...")
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

    print(f"   ✅ RMSE: {rmse:.2f}%")
    print(f"   ✅ MAE: {mae:.2f}%")
    print(f"   ✅ R² Score: {r2:.4f}")

# ============================================================================
# 6. SELECT BEST MODEL
# ============================================================================
print("\n" + "=" * 80)
print("MODEL COMPARISON - HETEROGENEITY PREDICTION")
print("=" * 80)

comparison_df = pd.DataFrame({
    'Model': results.keys(),
    'RMSE': [r['rmse'] for r in results.values()],
    'MAE': [r['mae'] for r in results.values()],
    'R²': [r['r2'] for r in results.values()]
})

print(comparison_df.to_string(index=False))

best_model_name = min(results, key=lambda x: results[x]['rmse'])
best_model = results[best_model_name]['model']
best_predictions = results[best_model_name]['predictions']
best_rmse = results[best_model_name]['rmse']
best_r2 = results[best_model_name]['r2']

print(f"\n🏆 Best Model: {best_model_name}")
print(f"   RMSE: {best_rmse:.2f}%")
print(f"   R²: {best_r2:.4f}")

# ============================================================================
# 7. SAVE MODEL AND RESULTS
# ============================================================================
print("\n💾 Saving model and results...")

import os
os.makedirs('outputs/heterogeneity_predictor', exist_ok=True)

joblib.dump(best_model, 'outputs/heterogeneity_predictor/best_model.pkl')
joblib.dump(scaler, 'outputs/heterogeneity_predictor/scaler.pkl')

import json
results_summary = {
    'best_model': best_model_name,
    'rmse': float(best_rmse),
    'mae': float(results[best_model_name]['mae']),
    'r2': float(best_r2),
    'n_train': len(X_train),
    'n_test': len(X_test),
    'n_features': len(X.columns),
    'data_source': 'Pairwise70 - Real Cochrane Reviews',
    'n_meta_analyses': len(ma_df)
}

with open('outputs/heterogeneity_predictor/results_summary.json', 'w') as f:
    json.dump(results_summary, f, indent=2)

print("   ✅ Saved: outputs/heterogeneity_predictor/best_model.pkl")
print("   ✅ Saved: outputs/heterogeneity_predictor/results_summary.json")

# ============================================================================
# 8. VISUALIZATIONS
# ============================================================================
print("\n📊 Generating visualizations...")

# Predicted vs Actual
fig, ax = plt.subplots(figsize=(10, 10))
ax.scatter(y_test, best_predictions, alpha=0.6, s=100)
ax.plot([0, 100], [0, 100], 'r--', lw=2, label='Perfect Prediction')
ax.set_xlabel('True I² (%)', fontsize=14, fontweight='bold')
ax.set_ylabel('Predicted I² (%)', fontsize=14, fontweight='bold')
ax.set_title(f'Heterogeneity Prediction - {best_model_name}\nRMSE: {best_rmse:.2f}%, R²: {best_r2:.4f}',
             fontsize=16, fontweight='bold')
ax.legend(fontsize=12)
ax.grid(True, alpha=0.3)
ax.set_xlim([0, 100])
ax.set_ylim([0, 100])
plt.tight_layout()
plt.savefig('outputs/heterogeneity_predictor/predicted_vs_actual.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/heterogeneity_predictor/predicted_vs_actual.png")
plt.close()

# Distribution comparison
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
ax1.hist(y_test, bins=20, alpha=0.7, color='steelblue', edgecolor='black')
ax1.set_title('True I² Distribution', fontsize=14, fontweight='bold')
ax1.set_xlabel('I² (%)', fontsize=12)
ax1.set_ylabel('Frequency', fontsize=12)
ax1.axvline(y_test.mean(), color='red', linestyle='--', linewidth=2, label=f'Mean: {y_test.mean():.1f}%')
ax1.legend()

ax2.hist(best_predictions, bins=20, alpha=0.7, color='coral', edgecolor='black')
ax2.set_title('Predicted I² Distribution', fontsize=14, fontweight='bold')
ax2.set_xlabel('I² (%)', fontsize=12)
ax2.set_ylabel('Frequency', fontsize=12)
ax2.axvline(best_predictions.mean(), color='red', linestyle='--', linewidth=2,
            label=f'Mean: {best_predictions.mean():.1f}%')
ax2.legend()

plt.tight_layout()
plt.savefig('outputs/heterogeneity_predictor/distribution_comparison.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/heterogeneity_predictor/distribution_comparison.png")
plt.close()

print("\n" + "=" * 80)
print("✅ HETEROGENEITY PREDICTION COMPLETE!")
print("=" * 80)

print(f"\n📊 Final Results:")
print(f"   Meta-analyses analyzed: {len(ma_df)}")
print(f"   Training set: {len(X_train)}")
print(f"   Test set: {len(X_test)}")
print(f"   Best model: {best_model_name}")
print(f"   RMSE: {best_rmse:.2f}%")
print(f"   MAE: {results[best_model_name]['mae']:.2f}%")
print(f"   R²: {best_r2:.4f}")

print("\n🎉 Heterogeneity predictor validated on REAL Cochrane data!")
print("=" * 80)
