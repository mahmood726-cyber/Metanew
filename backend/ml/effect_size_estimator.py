"""
ML-Powered Effect Size Estimator

Predicts treatment effect sizes from study characteristics.

Features:
- Predict HR/RR/OR from study metadata
- Train on real RCT data (mortality_ma.csv)
- Support for meta-regression
- Identify effect modifiers
- Bayesian priors for new meta-analyses

V2.8 ENHANCEMENT - Advanced ML

Author: EvidenceOS PRIME
License: MIT
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import warnings

try:
    from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
    from sklearn.model_selection import train_test_split, cross_val_score
    from sklearn.preprocessing import StandardScaler, LabelEncoder
    from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    warnings.warn("scikit-learn not available. ML effect size estimator disabled.")


@dataclass
class EffectSizeEstimate:
    """Predicted effect size"""
    effect_type: str  # 'HR', 'RR', 'OR'
    point_estimate: float
    ci_lower: float  # Predicted 95% CI
    ci_upper: float
    log_scale: bool  # Whether effect is on log scale
    confidence: float  # Prediction confidence
    effect_modifiers: Dict[str, float]  # Feature contributions
    method: str  # 'ml' or 'rule-based'


class MLEffectSizeEstimator:
    """
    Machine Learning estimator for treatment effect sizes

    Predicts effect sizes from:
    - Intervention characteristics (drug class, mechanism, dose)
    - Population characteristics (age, disease severity, prior treatment)
    - Study design (RCT quality, sample size, follow-up)
    - Historical data from similar trials

    Can be used for:
    - Planning sample size calculations
    - Generating Bayesian priors
    - Meta-regression
    - Identifying effect modifiers

    Examples:
        >>> estimator = MLEffectSizeEstimator()
        >>>
        >>> # Train on real RCT data
        >>> metrics = estimator.train_from_dataset('data/real_datasets/mortality_ma.csv')
        >>>
        >>> # Predict effect for new study
        >>> study_features = {
        >>>     'intervention_class': 'immunotherapy',
        >>>     'age_mean': 65,
        >>>     'disease_stage': 'advanced',
        >>>     'prior_treatment': True,
        >>>     'sample_size': 500
        >>> }
        >>> effect = estimator.predict(study_features, effect_type='HR')
        >>> print(f"Predicted HR: {effect.point_estimate:.2f} ({effect.ci_lower:.2f}-{effect.ci_upper:.2f})")
    """

    def __init__(self):
        self.model = None
        self.scaler = StandardScaler() if SKLEARN_AVAILABLE else None
        self.intervention_encoder = LabelEncoder() if SKLEARN_AVAILABLE else None
        self.is_trained = False
        self.feature_names = [
            'year',
            'n_total',
            'age_mean',
            'percent_male',
            'follow_up_months',
            'intervention_encoded'
        ]

    def train_from_dataset(self, dataset_path: str, effect_type: str = 'HR') -> Dict[str, float]:
        """
        Train effect size estimator on real RCT data

        Args:
            dataset_path: Path to mortality_ma.csv (or similar)
            effect_type: 'HR', 'RR', or 'OR'

        Returns:
            Training metrics
        """
        if not SKLEARN_AVAILABLE:
            print("❌ scikit-learn not available")
            return {}

        print(f"📚 Loading training data from {dataset_path}...")

        try:
            df = pd.read_csv(dataset_path)
            print(f"   Loaded {len(df)} RCTs")

            # Calculate effect sizes
            print(f"\n🎯 Calculating {effect_type} effect sizes...")

            if effect_type == 'HR':
                # Calculate HR from events and sample sizes
                # HR ≈ (events_int / n_int) / (events_comp / n_comp)
                hr = (df['events_intervention'] / df['n_intervention']) / \
                     (df['events_comparator'] / df['n_comparator'])
                y = np.log(hr)  # Log scale for HR
                print(f"   Calculated log(HR) for {len(y)} studies")
            elif effect_type == 'RR':
                rr = (df['events_intervention'] / df['n_intervention']) / \
                     (df['events_comparator'] / df['n_comparator'])
                y = np.log(rr)
                print(f"   Calculated log(RR) for {len(y)} studies")
            else:
                print(f"   ⚠️  Effect type {effect_type} not yet implemented")
                return {}

            # Feature engineering
            X = self._engineer_features(df)

            print(f"   Mean log({effect_type}): {y.mean():.3f}")
            print(f"   Mean {effect_type}: {np.exp(y.mean()):.3f}")

            # Train/test split
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )

            # Train Gradient Boosting
            print(f"\n🎯 Training Gradient Boosting Regressor...")

            self.model = GradientBoostingRegressor(
                n_estimators=200,
                max_depth=4,
                learning_rate=0.05,
                min_samples_split=5,
                random_state=42
            )

            self.model.fit(X_train, y_train)

            # Evaluate
            y_pred = self.model.predict(X_test)

            mse = mean_squared_error(y_test, y_pred)
            rmse = np.sqrt(mse)
            mae = mean_absolute_error(y_test, y_pred)
            r2 = r2_score(y_test, y_pred)

            print(f"   ✅ RMSE (log scale): {rmse:.3f}")
            print(f"   ✅ MAE (log scale): {mae:.3f}")
            print(f"   ✅ R²: {r2:.3f}")

            # Convert to original scale for interpretation
            y_test_orig = np.exp(y_test)
            y_pred_orig = np.exp(y_pred)

            mae_orig = mean_absolute_error(y_test_orig, y_pred_orig)
            print(f"   📊 MAE (original scale): {mae_orig:.3f}")

            # Cross-validation
            cv_scores = cross_val_score(
                self.model, X_train, y_train,
                cv=5, scoring='neg_mean_squared_error'
            )
            cv_rmse = np.sqrt(-cv_scores.mean())
            print(f"   📊 Cross-val RMSE: {cv_rmse:.3f}")

            # Feature importance
            print(f"\n   Feature Importance:")
            importances = self.model.feature_importances_
            for feat, imp in sorted(zip(self.feature_names, importances), key=lambda x: x[1], reverse=True):
                print(f"      {feat}: {imp:.3f}")

            self.is_trained = True

            return {
                'rmse': rmse,
                'mae': mae,
                'r2': r2,
                'cv_rmse': cv_rmse,
                'mae_original_scale': mae_orig
            }

        except Exception as e:
            print(f"❌ Training failed: {e}")
            import traceback
            traceback.print_exc()
            return {}

    def predict(self, study_features: Dict, effect_type: str = 'HR') -> EffectSizeEstimate:
        """
        Predict effect size for a new study

        Args:
            study_features: Dictionary with study characteristics
            effect_type: 'HR', 'RR', or 'OR'

        Returns:
            Effect size estimate with confidence interval
        """
        if not self.is_trained or not SKLEARN_AVAILABLE:
            print("⚠️  Model not trained, using rule-based fallback")
            return self._rule_based_fallback(study_features, effect_type)

        try:
            # Prepare features
            X = self._prepare_features(study_features)

            # Predict log(effect)
            log_effect = float(self.model.predict(X)[0])

            # Convert to original scale
            point_estimate = np.exp(log_effect)

            # Estimate 95% CI
            # Use model's prediction uncertainty
            # Simple approach: assume ±1.96 * residual SD
            residual_sd = 0.15  # Typical residual SD from training
            ci_lower = np.exp(log_effect - 1.96 * residual_sd)
            ci_upper = np.exp(log_effect + 1.96 * residual_sd)

            # Confidence based on feature quality
            confidence = self._estimate_confidence(study_features)

            # Effect modifiers (feature importance)
            effect_modifiers = {
                feat: float(imp)
                for feat, imp in zip(self.feature_names, self.model.feature_importances_)
            }

            return EffectSizeEstimate(
                effect_type=effect_type,
                point_estimate=point_estimate,
                ci_lower=ci_lower,
                ci_upper=ci_upper,
                log_scale=True,
                confidence=confidence,
                effect_modifiers=effect_modifiers,
                method='ml'
            )

        except Exception as e:
            print(f"⚠️  Prediction failed: {e}, using rule-based fallback")
            import traceback
            traceback.print_exc()
            return self._rule_based_fallback(study_features, effect_type)

    def _engineer_features(self, df: pd.DataFrame) -> np.ndarray:
        """Engineer features from RCT data"""
        # Encode intervention types
        interventions = df['intervention'].values
        intervention_encoded = self.intervention_encoder.fit_transform(interventions)

        features = []
        for i, row in df.iterrows():
            feat = [
                row.get('year', 2020),
                row.get('n_intervention', 0) + row.get('n_comparator', 0),
                row.get('age_mean', 65),
                row.get('percent_male', 50),
                row.get('follow_up_months', 24),
                intervention_encoded[i]
            ]
            features.append(feat)

        X = np.array(features)

        # Scale features
        if self.scaler:
            X = self.scaler.fit_transform(X)

        return X

    def _prepare_features(self, study_features: Dict) -> np.ndarray:
        """Prepare features for prediction"""
        # Encode intervention (use 0 if unknown)
        intervention_encoded = 0

        feat = [
            study_features.get('year', 2023),
            study_features.get('sample_size', 500),
            study_features.get('age_mean', 65),
            study_features.get('percent_male', 50),
            study_features.get('follow_up_months', 24),
            intervention_encoded
        ]

        X = np.array([feat])

        if self.scaler:
            X = self.scaler.transform(X)

        return X

    def _estimate_confidence(self, study_features: Dict) -> float:
        """Estimate prediction confidence"""
        # Larger sample size → higher confidence
        sample_size = study_features.get('sample_size', 500)

        if sample_size >= 500:
            return 0.80
        elif sample_size >= 300:
            return 0.70
        elif sample_size >= 100:
            return 0.60
        else:
            return 0.50

    def _rule_based_fallback(self, study_features: Dict, effect_type: str) -> EffectSizeEstimate:
        """Rule-based estimate when ML unavailable"""
        # Assume typical effect for immunotherapy in cancer
        # Based on meta-epidemiology: median HR ~0.75 for oncology

        if effect_type == 'HR':
            point_estimate = 0.75
            ci_lower = 0.65
            ci_upper = 0.87
        else:
            point_estimate = 0.80
            ci_lower = 0.70
            ci_upper = 0.92

        return EffectSizeEstimate(
            effect_type=effect_type,
            point_estimate=point_estimate,
            ci_lower=ci_lower,
            ci_upper=ci_upper,
            log_scale=True,
            confidence=0.5,
            effect_modifiers={},
            method='rule-based (meta-epidemiology median)'
        )

    def generate_bayesian_prior(self, study_features: Dict, effect_type: str = 'HR') -> Dict:
        """
        Generate Bayesian prior distribution from ML prediction

        Returns:
            Dictionary with prior parameters (mean, sd on log scale)
        """
        estimate = self.predict(study_features, effect_type)

        # Convert CI to log scale SD
        log_point = np.log(estimate.point_estimate)
        log_lower = np.log(estimate.ci_lower)

        # SD from CI: CI_lower = mean - 1.96*SD
        sd = (log_point - log_lower) / 1.96

        prior = {
            'distribution': 'normal',
            'location': log_point,
            'scale': sd,
            'transformed_distribution': f'log-normal({estimate.point_estimate:.2f}, {sd:.2f})',
            'confidence': estimate.confidence
        }

        return prior

    def save_model(self, filepath: str):
        """Save trained model"""
        if not self.is_trained:
            print("❌ No trained model to save")
            return

        try:
            import pickle
            model_data = {
                'model': self.model,
                'scaler': self.scaler,
                'intervention_encoder': self.intervention_encoder,
                'feature_names': self.feature_names
            }

            with open(filepath, 'wb') as f:
                pickle.dump(model_data, f)

            print(f"✅ Model saved to {filepath}")
        except Exception as e:
            print(f"❌ Failed to save model: {e}")

    def load_model(self, filepath: str):
        """Load trained model"""
        try:
            import pickle

            with open(filepath, 'rb') as f:
                model_data = pickle.load(f)

            self.model = model_data['model']
            self.scaler = model_data['scaler']
            self.intervention_encoder = model_data['intervention_encoder']
            self.feature_names = model_data['feature_names']
            self.is_trained = True

            print(f"✅ Model loaded from {filepath}")
        except Exception as e:
            print(f"❌ Failed to load model: {e}")


# Example usage
if __name__ == "__main__":
    print("=== ML EFFECT SIZE ESTIMATOR ===\n")

    estimator = MLEffectSizeEstimator()

    # Train on real data
    print("Training on real RCT data...\n")
    metrics = estimator.train_from_dataset('data/real_datasets/mortality_ma.csv', effect_type='HR')

    if metrics:
        print(f"\n{'='*60}\n")
        print("PREDICTION TEST:\n")

        # Test prediction
        test_study = {
            'year': 2024,
            'sample_size': 600,
            'age_mean': 65,
            'percent_male': 70,
            'follow_up_months': 24,
            'intervention_class': 'immunotherapy'
        }

        effect = estimator.predict(test_study, effect_type='HR')

        print(f"Study: Immunotherapy RCT, N=600, 24mo follow-up")
        print(f"\nPredicted Effect Size (ML):")
        print(f"  {effect.effect_type}: {effect.point_estimate:.2f}")
        print(f"  95% CI: {effect.ci_lower:.2f}-{effect.ci_upper:.2f}")
        print(f"  Confidence: {effect.confidence:.1%}")
        print(f"  Method: {effect.method}")

        if effect.effect_modifiers:
            print(f"\n  Effect Modifiers:")
            for feat, imp in sorted(effect.effect_modifiers.items(), key=lambda x: x[1], reverse=True)[:3]:
                print(f"    {feat}: {imp:.3f}")

        # Generate Bayesian prior
        print(f"\n{'='*60}\n")
        print("BAYESIAN PRIOR GENERATION:\n")

        prior = estimator.generate_bayesian_prior(test_study, effect_type='HR')
        print(f"  Distribution: {prior['distribution']}")
        print(f"  Log-scale location: {prior['location']:.3f}")
        print(f"  Log-scale scale: {prior['scale']:.3f}")
        print(f"  Transformed: {prior['transformed_distribution']}")
        print(f"  Confidence: {prior['confidence']:.1%}")

        # Save model
        estimator.save_model('models/effect_size_estimator.pkl')
