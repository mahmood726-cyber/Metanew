#!/usr/bin/env python3
"""
HTA Reimbursement Predictor
Train ML model to predict HTA decisions (Recommended/Restricted/Conditional/Not Recommended)

Dataset: 1,000 simulated HTA technology assessments
Expected Accuracy: 75-85%
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (classification_report, confusion_matrix,
                             accuracy_score, f1_score, roc_auc_score, roc_curve)
from sklearn.inspection import permutation_importance
import joblib
import warnings
warnings.filterwarnings('ignore')

# Set random seed for reproducibility
np.random.seed(42)

# Configure plotting style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)

print("=" * 80)
print("HTA REIMBURSEMENT DECISION PREDICTOR")
print("=" * 80)

# ============================================================================
# 1. LOAD DATA
# ============================================================================
print("\n📊 Loading HTA dataset...")

df = pd.read_csv('data/real_datasets/hta_technology_assessments_1000.csv')

print(f"✅ Loaded {len(df):,} HTA assessments")
print(f"   Fields: {len(df.columns)}")
print(f"   Date range: {df['assessment_year'].min()}-{df['assessment_year'].max()}")

# ============================================================================
# 2. EXPLORATORY DATA ANALYSIS
# ============================================================================
print("\n📊 Decision Distribution:")
print(df['decision'].value_counts())
print(f"\nDecision percentages:")
print(df['decision'].value_counts(normalize=True) * 100)

# ============================================================================
# 3. FEATURE ENGINEERING
# ============================================================================
print("\n🔧 Feature Engineering...")

# Select features for prediction
feature_cols = [
    'effect_size',
    'icer_per_qaly',
    'serious_adverse_events_rate',
    'discontinuation_rate',
    'n_rcts',
    'n_observational_studies',
    'total_patients_evidence',
    'cost_effectiveness_score',
    'clinical_benefit_score',
    'innovation_score',
    'time_to_decision_months',
    'market_exclusivity_years'
]

# Create feature matrix
X = df[feature_cols].copy()

# Handle any missing values (shouldn't be any, but just in case)
X = X.fillna(X.median())

# Encode categorical features
# Certainty of evidence: High > Moderate > Low > Very Low
certainty_map = {'High': 4, 'Moderate': 3, 'Low': 2, 'Very Low': 1}
X['certainty_score'] = df['certainty_of_evidence'].map(certainty_map)

# Add derived features
X['icer_ratio'] = X['icer_per_qaly'] / df['willingness_to_pay_threshold']
X['total_studies'] = X['n_rcts'] + X['n_observational_studies']
X['composite_score'] = (X['cost_effectiveness_score'] +
                        X['clinical_benefit_score'] +
                        X['innovation_score']) / 3

# Target variable
y = df['decision'].copy()

print(f"✅ Features: {len(X.columns)}")
print(f"   Feature names: {list(X.columns)}")

# ============================================================================
# 4. TRAIN-TEST SPLIT
# ============================================================================
print("\n📊 Splitting data...")

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"✅ Training set: {len(X_train)} samples")
print(f"✅ Test set: {len(X_test)} samples")

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# ============================================================================
# 5. MODEL TRAINING
# ============================================================================
print("\n🤖 Training Models...")
print("-" * 80)

models = {
    'Random Forest': RandomForestClassifier(
        n_estimators=200,
        max_depth=10,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1
    ),
    'Gradient Boosting': GradientBoostingClassifier(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=5,
        random_state=42
    ),
    'Logistic Regression': LogisticRegression(
        max_iter=1000,
        random_state=42,
        multi_class='multinomial'
    )
}

results = {}

for name, model in models.items():
    print(f"\n🔄 Training {name}...")

    # Use scaled data for Logistic Regression, original for tree-based
    if 'Logistic' in name:
        model.fit(X_train_scaled, y_train)
        y_pred = model.predict(X_test_scaled)
        y_pred_proba = model.predict_proba(X_test_scaled)
    else:
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)
        y_pred_proba = model.predict_proba(X_test)

    # Evaluate
    accuracy = accuracy_score(y_test, y_pred)
    f1_weighted = f1_score(y_test, y_pred, average='weighted')

    # Cross-validation
    if 'Logistic' in name:
        cv_scores = cross_val_score(model, X_train_scaled, y_train, cv=5)
    else:
        cv_scores = cross_val_score(model, X_train, y_train, cv=5)

    results[name] = {
        'model': model,
        'accuracy': accuracy,
        'f1_score': f1_weighted,
        'cv_mean': cv_scores.mean(),
        'cv_std': cv_scores.std(),
        'predictions': y_pred,
        'probabilities': y_pred_proba
    }

    print(f"   ✅ Test Accuracy: {accuracy:.3f}")
    print(f"   ✅ F1 Score (weighted): {f1_weighted:.3f}")
    print(f"   ✅ CV Accuracy: {cv_scores.mean():.3f} (+/- {cv_scores.std():.3f})")

# ============================================================================
# 6. SELECT BEST MODEL
# ============================================================================
print("\n" + "=" * 80)
print("MODEL COMPARISON")
print("=" * 80)

comparison_df = pd.DataFrame({
    'Model': results.keys(),
    'Test Accuracy': [r['accuracy'] for r in results.values()],
    'F1 Score': [r['f1_score'] for r in results.values()],
    'CV Mean': [r['cv_mean'] for r in results.values()],
    'CV Std': [r['cv_std'] for r in results.values()]
})

print(comparison_df.to_string(index=False))

# Select best model (highest test accuracy)
best_model_name = max(results, key=lambda x: results[x]['accuracy'])
best_model = results[best_model_name]['model']
best_predictions = results[best_model_name]['predictions']
best_accuracy = results[best_model_name]['accuracy']

print(f"\n🏆 Best Model: {best_model_name}")
print(f"   Accuracy: {best_accuracy:.3f} ({best_accuracy*100:.1f}%)")

# ============================================================================
# 7. DETAILED EVALUATION
# ============================================================================
print("\n" + "=" * 80)
print(f"DETAILED EVALUATION: {best_model_name}")
print("=" * 80)

print("\n📊 Classification Report:")
print(classification_report(y_test, best_predictions))

print("\n📊 Confusion Matrix:")
cm = confusion_matrix(y_test, best_predictions)
print(cm)

# ============================================================================
# 8. FEATURE IMPORTANCE
# ============================================================================
print("\n" + "=" * 80)
print("FEATURE IMPORTANCE")
print("=" * 80)

if 'Logistic' not in best_model_name:
    # Tree-based models have feature_importances_
    feature_importance = pd.DataFrame({
        'feature': X.columns,
        'importance': best_model.feature_importances_
    }).sort_values('importance', ascending=False)
else:
    # For Logistic Regression, use coefficient magnitudes
    coef_mean = np.mean(np.abs(best_model.coef_), axis=0)
    feature_importance = pd.DataFrame({
        'feature': X.columns,
        'importance': coef_mean
    }).sort_values('importance', ascending=False)

print(feature_importance.to_string(index=False))

# ============================================================================
# 9. VISUALIZATIONS
# ============================================================================
print("\n📊 Generating visualizations...")

# Create output directory
import os
os.makedirs('outputs/hta_predictor', exist_ok=True)

# 9.1 Confusion Matrix Heatmap
fig, ax = plt.subplots(figsize=(10, 8))
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=sorted(y_test.unique()),
            yticklabels=sorted(y_test.unique()))
plt.title(f'Confusion Matrix - {best_model_name}\nAccuracy: {best_accuracy:.3f}',
          fontsize=14, fontweight='bold')
plt.ylabel('True Label', fontsize=12)
plt.xlabel('Predicted Label', fontsize=12)
plt.tight_layout()
plt.savefig('outputs/hta_predictor/confusion_matrix.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/hta_predictor/confusion_matrix.png")
plt.close()

# 9.2 Feature Importance Plot
fig, ax = plt.subplots(figsize=(12, 8))
top_features = feature_importance.head(15)
sns.barplot(data=top_features, x='importance', y='feature', palette='viridis')
plt.title(f'Top 15 Feature Importances - {best_model_name}',
          fontsize=14, fontweight='bold')
plt.xlabel('Importance', fontsize=12)
plt.ylabel('Feature', fontsize=12)
plt.tight_layout()
plt.savefig('outputs/hta_predictor/feature_importance.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/hta_predictor/feature_importance.png")
plt.close()

# 9.3 Model Comparison Bar Chart
fig, ax = plt.subplots(figsize=(10, 6))
comparison_df_plot = comparison_df.set_index('Model')
comparison_df_plot[['Test Accuracy', 'F1 Score', 'CV Mean']].plot(kind='bar', ax=ax)
plt.title('Model Performance Comparison', fontsize=14, fontweight='bold')
plt.ylabel('Score', fontsize=12)
plt.xlabel('Model', fontsize=12)
plt.legend(['Test Accuracy', 'F1 Score', 'CV Mean'], loc='lower right')
plt.ylim([0.5, 1.0])
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.savefig('outputs/hta_predictor/model_comparison.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/hta_predictor/model_comparison.png")
plt.close()

# 9.4 Decision Distribution
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

# True distribution
y_test.value_counts().sort_index().plot(kind='bar', ax=ax1, color='steelblue')
ax1.set_title('True Decision Distribution (Test Set)', fontsize=12, fontweight='bold')
ax1.set_xlabel('Decision', fontsize=10)
ax1.set_ylabel('Count', fontsize=10)
ax1.tick_params(axis='x', rotation=45)

# Predicted distribution
pd.Series(best_predictions).value_counts().sort_index().plot(kind='bar', ax=ax2, color='coral')
ax2.set_title('Predicted Decision Distribution', fontsize=12, fontweight='bold')
ax2.set_xlabel('Decision', fontsize=10)
ax2.set_ylabel('Count', fontsize=10)
ax2.tick_params(axis='x', rotation=45)

plt.tight_layout()
plt.savefig('outputs/hta_predictor/decision_distribution.png', dpi=300, bbox_inches='tight')
print("   ✅ Saved: outputs/hta_predictor/decision_distribution.png")
plt.close()

# ============================================================================
# 10. SAVE MODEL AND ARTIFACTS
# ============================================================================
print("\n💾 Saving model and artifacts...")

# Save best model
joblib.dump(best_model, 'outputs/hta_predictor/best_model.pkl')
print("   ✅ Saved: outputs/hta_predictor/best_model.pkl")

# Save scaler
joblib.dump(scaler, 'outputs/hta_predictor/scaler.pkl')
print("   ✅ Saved: outputs/hta_predictor/scaler.pkl")

# Save feature names
feature_names = {'features': list(X.columns)}
import json
with open('outputs/hta_predictor/feature_names.json', 'w') as f:
    json.dump(feature_names, f, indent=2)
print("   ✅ Saved: outputs/hta_predictor/feature_names.json")

# Save results summary
results_summary = {
    'best_model': best_model_name,
    'test_accuracy': float(best_accuracy),
    'f1_score': float(results[best_model_name]['f1_score']),
    'cv_mean': float(results[best_model_name]['cv_mean']),
    'cv_std': float(results[best_model_name]['cv_std']),
    'n_train': len(X_train),
    'n_test': len(X_test),
    'n_features': len(X.columns),
    'feature_importance': feature_importance.head(10).to_dict('records')
}

with open('outputs/hta_predictor/results_summary.json', 'w') as f:
    json.dump(results_summary, f, indent=2)
print("   ✅ Saved: outputs/hta_predictor/results_summary.json")

# ============================================================================
# 11. EXAMPLE PREDICTIONS
# ============================================================================
print("\n" + "=" * 80)
print("EXAMPLE PREDICTIONS")
print("=" * 80)

# Show 5 example predictions
example_indices = np.random.choice(len(X_test), 5, replace=False)
examples = X_test.iloc[example_indices]
example_true = y_test.iloc[example_indices]
example_pred = best_predictions[example_indices]

print("\n📋 Sample Predictions:")
for i, idx in enumerate(example_indices):
    print(f"\nExample {i+1}:")
    print(f"   True Decision: {example_true.iloc[i]}")
    print(f"   Predicted: {example_pred[i]}")
    print(f"   ICER: ${examples.iloc[i]['icer_per_qaly']:,.0f}")
    print(f"   Effect Size: {examples.iloc[i]['effect_size']:.3f}")
    print(f"   Cost-Effectiveness Score: {examples.iloc[i]['cost_effectiveness_score']:.2f}")
    print(f"   Clinical Benefit Score: {examples.iloc[i]['clinical_benefit_score']:.2f}")

# ============================================================================
# FINAL SUMMARY
# ============================================================================
print("\n" + "=" * 80)
print("✅ TRAINING COMPLETE!")
print("=" * 80)

print(f"\n🏆 Best Model: {best_model_name}")
print(f"   Test Accuracy: {best_accuracy:.3f} ({best_accuracy*100:.1f}%)")
print(f"   F1 Score: {results[best_model_name]['f1_score']:.3f}")
print(f"   Cross-validation: {results[best_model_name]['cv_mean']:.3f} (+/- {results[best_model_name]['cv_std']:.3f})")

print(f"\n📊 Top 5 Important Features:")
for i, row in feature_importance.head(5).iterrows():
    print(f"   {row['feature']:30s} {row['importance']:.4f}")

print(f"\n💾 Saved Artifacts:")
print(f"   - Model: outputs/hta_predictor/best_model.pkl")
print(f"   - Scaler: outputs/hta_predictor/scaler.pkl")
print(f"   - Features: outputs/hta_predictor/feature_names.json")
print(f"   - Results: outputs/hta_predictor/results_summary.json")
print(f"   - Visualizations: outputs/hta_predictor/*.png")

print("\n🎉 HTA Reimbursement Predictor is ready for deployment!")
print("=" * 80)
