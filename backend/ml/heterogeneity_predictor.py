"""
ML-Powered Heterogeneity Predictor

Predicts I² and τ² from study characteristics before conducting meta-analysis.

Features:
- Predict I² (heterogeneity statistic) from study features
- Guide random effects vs fixed effects model selection
- Identify factors contributing to heterogeneity
- Support meta-regression planning
- Gradient Boosting Regression for continuous I² prediction

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
    from sklearn.preprocessing import StandardScaler
    from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    warnings.warn("scikit-learn not available. ML heterogeneity predictor disabled.")


@dataclass
class HeterogeneityPrediction:
    """Predicted heterogeneity metrics"""
    i_squared: float  # I² statistic (0-100%)
    tau_squared: float  # τ² between-study variance
    recommended_model: str  # 'fixed' or 'random'
    confidence: float  # Prediction confidence
    contributing_factors: Dict[str, float]  # Feature importance
    method: str  # 'ml' or 'rule-based'


class MLHeterogeneityPredictor:
    """
    Machine Learning predictor for meta-analysis heterogeneity

    Predicts I² from:
    - Number of studies
    - Study sample sizes (range, total)
    - Intervention heterogeneity (different drugs/doses)
    - Population heterogeneity (age range, disease severity)
    - Methodological quality variation (RoB scores)
    - Follow-up duration variation
    - Geographic diversity

    Examples:
        >>> predictor = MLHeterogeneityPredictor()
        >>>
        >>> # Train on meta-analysis data
        >>> predictor.train_from_simulated_data()
        >>>
        >>> # Predict for planned meta-analysis
        >>> meta_features = {
        >>>     'n_studies': 10,
        >>>     'n_total_min': 100,
        >>>     'n_total_max': 500,
        >>>     'intervention_types': 3,
        >>>     'age_range': 20,
        >>>     'rob_variance': 0.3
        >>> }
        >>> het = predictor.predict(meta_features)
        >>> print(f"Predicted I²: {het.i_squared:.1f}%")
        >>> print(f"Recommended: {het.recommended_model} effects model")
    """

    def __init__(self):
        self.model = None
        self.scaler = StandardScaler() if SKLEARN_AVAILABLE else None
        self.is_trained = False
        self.feature_names = [
            'n_studies',
            'n_total_range',  # max - min sample size
            'intervention_types',  # Number of different interventions
            'age_range',  # max_age - min_age
            'follow_up_range',  # max - min follow-up
            'rob_variance',  # Variance in RoB scores
            'geographic_diversity'  # Number of countries/regions
        ]

    def train_from_simulated_data(self, n_samples: int = 1000):
        """
        Train on simulated meta-analysis data

        Simulates realistic heterogeneity patterns based on meta-epidemiology
        research showing typical I² distributions
        """
        if not SKLEARN_AVAILABLE:
            print("❌ scikit-learn not available")
            return {}

        print(f"📚 Generating {n_samples} simulated meta-analyses...")

        # Simulate meta-analysis characteristics
        np.random.seed(42)

        X = []
        y = []

        for _ in range(n_samples):
            # Simulate meta-analysis features
            n_studies = np.random.randint(5, 50)
            n_total_range = np.random.randint(50, 1000)
            intervention_types = np.random.randint(1, 5)
            age_range = np.random.randint(5, 30)
            follow_up_range = np.random.randint(6, 60)
            rob_variance = np.random.uniform(0, 1)
            geographic_diversity = np.random.randint(1, 20)

            # Simulate I² based on these features
            # I² tends to increase with:
            # - More intervention heterogeneity
            # - Greater sample size variation
            # - Higher RoB variance
            # - More geographic diversity

            base_i2 = 30  # Baseline heterogeneity

            # Add contributions from each factor
            i2 = base_i2
            i2 += intervention_types * 10  # More interventions → more heterogeneity
            i2 += (n_total_range / 100) * 5  # Sample size variation
            i2 += rob_variance * 20  # Quality variation
            i2 += (geographic_diversity / 20) * 15  # Geographic diversity
            i2 += (age_range / 30) * 10  # Population heterogeneity

            # Add random noise
            i2 += np.random.normal(0, 10)

            # Constrain to 0-100%
            i2 = max(0, min(100, i2))

            X.append([
                n_studies, n_total_range, intervention_types,
                age_range, follow_up_range, rob_variance, geographic_diversity
            ])
            y.append(i2)

        X = np.array(X)
        y = np.array(y)

        print(f"   Generated I² range: {y.min():.1f}% - {y.max():.1f}%")
        print(f"   Mean I²: {y.mean():.1f}%")

        # Train/test split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        # Train Gradient Boosting Regressor
        print(f"\n🎯 Training Gradient Boosting Regressor...")

        self.model = GradientBoostingRegressor(
            n_estimators=200,
            max_depth=5,
            learning_rate=0.1,
            min_samples_split=10,
            random_state=42
        )

        self.model.fit(X_train_scaled, y_train)

        # Evaluate
        y_pred = self.model.predict(X_test_scaled)

        mse = mean_squared_error(y_test, y_pred)
        rmse = np.sqrt(mse)
        mae = mean_absolute_error(y_test, y_pred)
        r2 = r2_score(y_test, y_pred)

        print(f"   ✅ RMSE: {rmse:.2f}%")
        print(f"   ✅ MAE: {mae:.2f}%")
        print(f"   ✅ R²: {r2:.3f}")

        # Cross-validation
        cv_scores = cross_val_score(
            self.model, X_train_scaled, y_train,
            cv=5, scoring='neg_mean_squared_error'
        )
        cv_rmse = np.sqrt(-cv_scores.mean())
        print(f"   📊 Cross-val RMSE: {cv_rmse:.2f}%")

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
            'cv_rmse': cv_rmse
        }

    def predict(self, meta_features: Dict) -> HeterogeneityPrediction:
        """
        Predict heterogeneity for a planned meta-analysis

        Args:
            meta_features: Dictionary with meta-analysis characteristics

        Returns:
            Heterogeneity prediction
        """
        if not self.is_trained or not SKLEARN_AVAILABLE:
            print("⚠️  Model not trained, using rule-based fallback")
            return self._rule_based_fallback(meta_features)

        try:
            # Prepare features
            X = self._prepare_features(meta_features)

            # Predict I²
            i_squared = float(self.model.predict(X)[0])
            i_squared = max(0, min(100, i_squared))  # Constrain to 0-100%

            # Estimate τ² from I² (rough approximation)
            # τ² ≈ (I² / (100 - I²)) * typical within-study variance
            typical_variance = 0.01  # Typical within-study variance for log-scale effects
            if i_squared < 99:
                tau_squared = (i_squared / (100 - i_squared)) * typical_variance
            else:
                tau_squared = 0.1  # High heterogeneity

            # Recommend model
            if i_squared < 25:
                recommended = 'fixed'
            elif i_squared < 50:
                recommended = 'random (moderate heterogeneity)'
            else:
                recommended = 'random (high heterogeneity - consider meta-regression)'

            # Confidence based on feature quality
            confidence = self._estimate_confidence(meta_features)

            # Feature importance
            contributing_factors = {
                feat: float(imp)
                for feat, imp in zip(self.feature_names, self.model.feature_importances_)
            }

            return HeterogeneityPrediction(
                i_squared=i_squared,
                tau_squared=tau_squared,
                recommended_model=recommended,
                confidence=confidence,
                contributing_factors=contributing_factors,
                method='ml'
            )

        except Exception as e:
            print(f"⚠️  Prediction failed: {e}, using rule-based fallback")
            import traceback
            traceback.print_exc()
            return self._rule_based_fallback(meta_features)

    def _prepare_features(self, meta_features: Dict) -> np.ndarray:
        """Prepare features for prediction"""
        feat = [
            meta_features.get('n_studies', 10),
            meta_features.get('n_total_max', 500) - meta_features.get('n_total_min', 100),
            meta_features.get('intervention_types', 2),
            meta_features.get('age_range', 15),
            meta_features.get('follow_up_range', 24),
            meta_features.get('rob_variance', 0.3),
            meta_features.get('geographic_diversity', 5)
        ]

        X = np.array([feat])

        if self.scaler:
            X = self.scaler.transform(X)

        return X

    def _estimate_confidence(self, meta_features: Dict) -> float:
        """Estimate prediction confidence based on feature quality"""
        # More studies → higher confidence
        n_studies = meta_features.get('n_studies', 10)

        if n_studies >= 20:
            return 0.85
        elif n_studies >= 10:
            return 0.75
        elif n_studies >= 5:
            return 0.65
        else:
            return 0.50

    def _rule_based_fallback(self, meta_features: Dict) -> HeterogeneityPrediction:
        """Rule-based prediction when ML unavailable"""
        # Simple heuristics
        intervention_types = meta_features.get('intervention_types', 2)
        n_studies = meta_features.get('n_studies', 10)

        # More intervention types → more heterogeneity
        if intervention_types >= 3:
            i_squared = 60.0
            recommended = 'random (high heterogeneity)'
        elif intervention_types == 2:
            i_squared = 40.0
            recommended = 'random (moderate heterogeneity)'
        else:
            i_squared = 20.0
            recommended = 'fixed'

        tau_squared = (i_squared / (100 - i_squared)) * 0.01 if i_squared < 99 else 0.1

        return HeterogeneityPrediction(
            i_squared=i_squared,
            tau_squared=tau_squared,
            recommended_model=recommended,
            confidence=0.5,
            contributing_factors={},
            method='rule-based'
        )

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
            self.feature_names = model_data['feature_names']
            self.is_trained = True

            print(f"✅ Model loaded from {filepath}")
        except Exception as e:
            print(f"❌ Failed to load model: {e}")


# Example usage
if __name__ == "__main__":
    print("=== ML HETEROGENEITY PREDICTOR ===\n")

    predictor = MLHeterogeneityPredictor()

    # Train on simulated data
    print("Training on simulated meta-analysis data...\n")
    metrics = predictor.train_from_simulated_data(n_samples=1000)

    if metrics:
        print(f"\n{'='*60}\n")
        print("PREDICTION TESTS:\n")

        # Test 1: Homogeneous meta-analysis
        print("Test 1: Homogeneous MA (same drug, similar populations)")
        test1 = {
            'n_studies': 10,
            'n_total_min': 200,
            'n_total_max': 300,
            'intervention_types': 1,  # Same drug
            'age_range': 5,  # Similar ages
            'follow_up_range': 6,  # Similar follow-up
            'rob_variance': 0.1,  # Similar quality
            'geographic_diversity': 2  # 2 countries
        }

        het1 = predictor.predict(test1)
        print(f"  Predicted I²: {het1.i_squared:.1f}%")
        print(f"  Recommended: {het1.recommended_model}")
        print(f"  Confidence: {het1.confidence:.1%}\n")

        # Test 2: Heterogeneous meta-analysis
        print("Test 2: Heterogeneous MA (different drugs, diverse populations)")
        test2 = {
            'n_studies': 15,
            'n_total_min': 100,
            'n_total_max': 800,
            'intervention_types': 4,  # Different drugs
            'age_range': 25,  # Wide age range
            'follow_up_range': 48,  # Variable follow-up
            'rob_variance': 0.6,  # Quality variation
            'geographic_diversity': 15  # 15 countries
        }

        het2 = predictor.predict(test2)
        print(f"  Predicted I²: {het2.i_squared:.1f}%")
        print(f"  Recommended: {het2.recommended_model}")
        print(f"  Confidence: {het2.confidence:.1%}")

        if het2.contributing_factors:
            print(f"\n  Top contributing factors:")
            for feat, imp in sorted(het2.contributing_factors.items(), key=lambda x: x[1], reverse=True)[:3]:
                print(f"    {feat}: {imp:.3f}")

        # Save model
        predictor.save_model('models/heterogeneity_predictor.pkl')
