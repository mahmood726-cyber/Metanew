#!/usr/bin/env python3
"""
Effect Size Estimator - Using REAL Cochrane Data
Predict treatment effect sizes from study characteristics

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
import joblib
import warnings
warnings.filterwarnings('ignore')

# Set random seed
np.random.seed(42)

# Configure plotting
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)

print("=" * 80)
print("EFFECT SIZE ESTIMATOR - REAL COCHRANE DATA")
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
# For binary outcomes: need Experimental.cases, Experimental.N, Control.cases, Control.N
# For continuous: need Experimental.mean, Experimental.SD, Control.mean, Control.SD

# Focus on binary outcomes (most common)
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
# 3. FEATURE ENGINEERING
# ============================================================================
print("\n🔧 Engineering features from study characteristics...")

# Create features
binary_data['total_n'] = binary_data['Experimental.N'] + binary_data['Control.N']
binary_data['exp_event_rate'] = binary_data['Experimental.cases'] / binary_data['Experimental.N']
binary_data['con_event_rate'] = binary_data['Control.cases'] / binary_data['Control.N']
binary_data['event_rate_diff'] = binary_data['exp_event_rate'] - binary_data['con_event_rate']
binary_data['allocation_ratio'] = binary_data['Experimental.N'] / binary_data['Control.N']
binary_data['total_events'] = binary_data['Experimental.cases'] + binary_data['Control.cases']

# Log transformations for skewed features
binary_data['log_total_n'] = np.log(binary_data['total_n'] + 1)
binary_data['log_total_events'] = np.log(binary_data['total_events'] + 1)

# Study year if available
if 'Study.year' in binary_data.columns:
    binary_data['study_year'] = pd.to_numeric(binary_data['Study.year'], errors='coerce')
    binary_data['study_year'] = binary_data['study_year'].fillna(binary_data['study_year'].median())
    binary_data['years_since_2000'] = binary_data['study_year'] - 2000
else:
    binary_data['years_since_2000'] = 0

# Select features for modeling
feature_cols = [
    'total_n',
    'log_total_n',
    'exp_event_rate',
    'con_event_rate',
    'event_rate_diff',
    'allocation_ratio',
    'total_events',
    'log_total_events',
    'years_since_2000'
]

# Remove rows with missing features
modeling_data = binary_data[feature_cols + ['log_or']].dropna()

print(f"✅ Final modeling dataset: {len(modeling_data):,} studies")
print(f"   Features: {len(feature_cols)}")

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

    print(f"   ✅ RMSE: {rmse:.4f}")
    print(f"   ✅ MAE: {mae:.4f}")
    print(f"   ✅ R² Score: {r2:.4f}")

# ============================================================================
# 6. MODEL COMPARISON
# ============================================================================
print("\n" + "=" * 80)
print("MODEL COMPARISON - REAL COCHRANE DATA VALIDATION")
print("=" * 80)

comparison_df = pd.DataFrame({
    'Model': results.keys(),
    'RMSE': [r['rmse'] for r in results.values()],
    'MAE': [r['mae'] for r in results.values()],
    'R²': [r['r2'] for r in results.values()]
})

print(comparison_df.to_string(index=False))

# Select best model (lowest RMSE)
best_model_name = min(results, key=lambda x: results[x]['rmse'])
best_model = results[best_model_name]['model']
best_predictions = results[best_model_name]['predictions']
best_rmse = results[best_model_name]['rmse']
best_r2 = results[best_model_name]['r2']

print(f"\n🏆 Best Model: {best_model_name}")
print(f"   RMSE: {best_rmse:.4f}")
print(f"   R²: {best_r2:.4f}")

# ============================================================================
# 7. FEATURE IMPORTANCE
# ============================================================================
print("\n" + "=" * 80)
print("FEATURE IMPORTANCE")
print("=" * 80)

if 'Random Forest' in best_model_name or 'Gradient' in best_model_name:
    feature_importance = pd.DataFrame({
        'feature': feature_cols,
        'importance': best_model.feature_importances_
    }).sort_values('importance', ascending=False)
elif 'Ridge' in best_model_name or 'Lasso' in best_model_name:
    feature_importance = pd.DataFrame({
        'feature': feature_cols,
        'importance': np.abs(best_model.coef_)
    }).sort_values('importance', ascending=False)

print(feature_importance.to_string(index=False))

# ============================================================================
# 8. VISUALIZATIONS
# ============================================================================
print("\n📊 Generating visualizations...")

import os
os.makedirs('outputs/effect_size_estimator', exist_ok=True)

# 8.1 Predicted vs Actual
fig, ax = plt.subplots(figsize=(10, 10))
ax.scatter(y_test, best_predictions, alpha=0.3, s=20)
ax.plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()],
        'r--', lw=2, label='Perfect Prediction')
ax.set_xlabel('True Log Odds Ratio', fontsize=12)
ax.set_ylabel('Predicted Log Odds Ratio', fontsize=12)
ax.set_title(f'Predicted vs Actual Effect Sizes - {best_model_name}\n'
             f'RMSE: {best_rmse:.4f}, R²: {best_r2:.4f}',
             fontsize=14, fontweight='bold')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator/predicted_vs_actual.png',
            dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/effect_size_estimator/predicted_vs_actual.png")
plt.close()

# 8.2 Residuals Plot
residuals = y_test - best_predictions
fig, ax = plt.subplots(figsize=(10, 6))
ax.scatter(best_predictions, residuals, alpha=0.3, s=20)
ax.axhline(y=0, color='r', linestyle='--', lw=2)
ax.set_xlabel('Predicted Log Odds Ratio', fontsize=12)
ax.set_ylabel('Residuals', fontsize=12)
ax.set_title(f'Residual Plot - {best_model_name}', fontsize=14, fontweight='bold')
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator/residuals.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/effect_size_estimator/residuals.png")
plt.close()

# 8.3 Feature Importance
fig, ax = plt.subplots(figsize=(10, 6))
sns.barplot(data=feature_importance, x='importance', y='feature', palette='viridis')
ax.set_title(f'Feature Importance - {best_model_name}', fontsize=14, fontweight='bold')
ax.set_xlabel('Importance', fontsize=12)
ax.set_ylabel('Feature', fontsize=12)
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator/feature_importance.png',
            dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/effect_size_estimator/feature_importance.png")
plt.close()

# 8.4 Model Comparison
fig, ax = plt.subplots(figsize=(10, 6))
comparison_df_plot = comparison_df.set_index('Model')
comparison_df_plot[['RMSE', 'MAE']].plot(kind='bar', ax=ax)
ax.set_title('Model Performance Comparison (Lower is Better)',
             fontsize=14, fontweight='bold')
ax.set_ylabel('Error', fontsize=12)
ax.set_xlabel('Model', fontsize=12)
ax.legend(['RMSE', 'MAE'])
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.savefig('outputs/effect_size_estimator/model_comparison.png',
            dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/effect_size_estimator/model_comparison.png")
plt.close()

# 8.5 Distribution of true vs predicted
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

ax1.hist(y_test, bins=50, alpha=0.7, color='steelblue', edgecolor='black')
ax1.set_title('True Log Odds Ratio Distribution', fontsize=12, fontweight='bold')
ax1.set_xlabel('Log OR', fontsize=10)
ax1.set_ylabel('Frequency', fontsize=10)
ax1.axvline(y_test.mean(), color='red', linestyle='--', linewidth=2, label=f'Mean: {y_test.mean():.3f}')
ax1.legend()

ax2.hist(best_predictions, bins=50, alpha=0.7, color='coral', edgecolor='black')
ax2.set_title('Predicted Log Odds Ratio Distribution', fontsize=12, fontweight='bold')
ax2.set_xlabel('Log OR', fontsize=10)
ax2.set_ylabel('Frequency', fontsize=10)
ax2.axvline(best_predictions.mean(), color='red', linestyle='--', linewidth=2,
            label=f'Mean: {best_predictions.mean():.3f}')
ax2.legend()

plt.tight_layout()
plt.savefig('outputs/effect_size_estimator/distribution_comparison.png',
            dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/effect_size_estimator/distribution_comparison.png")
plt.close()

# ============================================================================
# 9. SAVE MODEL
# ============================================================================
print("\n💾 Saving model and artifacts...")

joblib.dump(best_model, 'outputs/effect_size_estimator/best_model.pkl')
print("   ✅ Saved: outputs/effect_size_estimator/best_model.pkl")

joblib.dump(scaler, 'outputs/effect_size_estimator/scaler.pkl')
print("   ✅ Saved: outputs/effect_size_estimator/scaler.pkl")

# Save results
import json
results_summary = {
    'best_model': best_model_name,
    'rmse': float(best_rmse),
    'mae': float(results[best_model_name]['mae']),
    'r2': float(best_r2),
    'n_train': len(X_train),
    'n_test': len(X_test),
    'n_features': len(feature_cols),
    'feature_importance': feature_importance.to_dict('records'),
    'data_source': 'Pairwise70 - Real Cochrane Reviews',
    'n_cochrane_reviews': int(df['cochrane_id'].nunique())
}

with open('outputs/effect_size_estimator/results_summary.json', 'w') as f:
    json.dump(results_summary, f, indent=2)
print("   ✅ Saved: outputs/effect_size_estimator/results_summary.json")

# ============================================================================
# 10. EXAMPLE PREDICTIONS
# ============================================================================
print("\n" + "=" * 80)
print("EXAMPLE PREDICTIONS ON REAL COCHRANE RCTs")
print("=" * 80)

# Show random examples
example_indices = np.random.choice(len(X_test), 10, replace=False)
examples = X_test.iloc[example_indices]
example_true = y_test.iloc[example_indices]
example_pred = best_predictions[example_indices]

print("\n📋 Sample Predictions (Real Published Studies):")
for i, idx in enumerate(example_indices):
    error = abs(example_true.iloc[i] - example_pred[i])
    print(f"\nExample {i+1}:")
    print(f"   True Log OR: {example_true.iloc[i]:.3f}")
    print(f"   Predicted: {example_pred[i]:.3f}")
    print(f"   Error: {error:.3f}")
    print(f"   Total N: {examples.iloc[i]['total_n']:.0f}")
    print(f"   Event rate (exp/con): {examples.iloc[i]['exp_event_rate']:.3f} / "
          f"{examples.iloc[i]['con_event_rate']:.3f}")

# ============================================================================
# FINAL SUMMARY
# ============================================================================
print("\n" + "=" * 80)
print("✅ VALIDATION ON REAL COCHRANE DATA COMPLETE!")
print("=" * 80)

print(f"\n📊 Dataset: REAL Cochrane Reviews (Pairwise70)")
print(f"   Source: {df['cochrane_id'].nunique()} Cochrane systematic reviews")
print(f"   Training RCTs: {len(X_train):,}")
print(f"   Test RCTs: {len(X_test):,}")
print(f"   Total: {len(X):,} real published RCTs")

print(f"\n🏆 Best Model: {best_model_name}")
print(f"   RMSE: {best_rmse:.4f}")
print(f"   MAE: {results[best_model_name]['mae']:.4f}")
print(f"   R² Score: {best_r2:.4f}")

print(f"\n📊 Top 5 Important Features:")
for i, row in feature_importance.head(5).iterrows():
    print(f"   {row['feature']:25s} {row['importance']:.4f}")

print(f"\n💾 Saved Artifacts:")
print(f"   - Model: outputs/effect_size_estimator/best_model.pkl")
print(f"   - Scaler: outputs/effect_size_estimator/scaler.pkl")
print(f"   - Results: outputs/effect_size_estimator/results_summary.json")
print(f"   - Visualizations: outputs/effect_size_estimator/*.png")

print("\n🎉 Effect Size Estimator validated on REAL Cochrane data!")
print("   This model is trained on actual published systematic reviews!")
print("=" * 80)
