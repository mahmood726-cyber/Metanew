"""
World-Class Ensemble ML Models for Meta-Analysis
Implements XGBoost, LightGBM, CatBoost with ensemble stacking
Based on 2025 healthcare ML best practices
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional, Any, Union
from dataclasses import dataclass
import logging

# Core ML
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import cross_val_score, StratifiedKFold, KFold
from sklearn.metrics import (
    roc_auc_score, f1_score, accuracy_score, precision_score,
    recall_score, mean_squared_error, r2_score, mean_absolute_error
)

# Advanced Gradient Boosting
try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError:
    XGBOOST_AVAILABLE = False

try:
    import lightgbm as lgb
    LIGHTGBM_AVAILABLE = True
except ImportError:
    LIGHTGBM_AVAILABLE = False

try:
    import catboost as cb
    CATBOOST_AVAILABLE = True
except ImportError:
    CATBOOST_AVAILABLE = False

# Ensemble methods
from sklearn.ensemble import (
    VotingClassifier, VotingRegressor,
    StackingClassifier, StackingRegressor,
    RandomForestClassifier, GradientBoostingClassifier
)
from sklearn.linear_model import LogisticRegression, Ridge

import joblib

logger = logging.getLogger(__name__)


@dataclass
class ModelPerformance:
    """Comprehensive model performance metrics"""
    model_name: str
    metrics: Dict[str, float]  # accuracy, auc, f1, precision, recall
    cv_scores: List[float]
    cv_mean: float
    cv_std: float
    training_time: float
    prediction_time: float
    feature_importance: Optional[Dict[str, float]] = None
    calibration_score: Optional[float] = None


@dataclass
class EnsembleConfig:
    """Configuration for ensemble models"""
    use_xgboost: bool = True
    use_lightgbm: bool = True
    use_catboost: bool = True
    use_random_forest: bool = True
    ensemble_method: str = "stacking"  # "voting", "stacking", "weighted"
    cv_folds: int = 5
    optimize_hyperparams: bool = False
    random_state: int = 42


class AdvancedHeterogeneityPredictor:
    """
    World-class heterogeneity prediction using ensemble of XGBoost, LightGBM, CatBoost
    Follows 2025 healthcare ML best practices
    """

    def __init__(self, config: Optional[EnsembleConfig] = None):
        self.config = config or EnsembleConfig()
        self.base_models = {}
        self.ensemble_model = None
        self.scaler = StandardScaler()
        self.label_encoder = LabelEncoder()
        self.feature_names = []
        self.is_trained = False
        self.performance_history: List[ModelPerformance] = []

    def _create_base_models(self) -> Dict[str, Any]:
        """Create base models based on availability and config"""
        models = {}

        # XGBoost - Best for regularization and handling missing values
        if self.config.use_xgboost and XGBOOST_AVAILABLE:
            models['xgboost'] = xgb.XGBClassifier(
                n_estimators=100,
                max_depth=5,
                learning_rate=0.1,
                subsample=0.8,
                colsample_bytree=0.8,
                reg_alpha=0.1,  # L1 regularization
                reg_lambda=1.0,  # L2 regularization
                random_state=self.config.random_state,
                eval_metric='logloss',
                use_label_encoder=False
            )
            logger.info("✓ XGBoost added to ensemble")

        # LightGBM - Best for large datasets and speed
        if self.config.use_lightgbm and LIGHTGBM_AVAILABLE:
            models['lightgbm'] = lgb.LGBMClassifier(
                n_estimators=100,
                max_depth=5,
                learning_rate=0.1,
                subsample=0.8,
                colsample_bytree=0.8,
                num_leaves=31,
                min_child_samples=20,
                random_state=self.config.random_state,
                verbose=-1
            )
            logger.info("✓ LightGBM added to ensemble")

        # CatBoost - Best for categorical features
        if self.config.use_catboost and CATBOOST_AVAILABLE:
            models['catboost'] = cb.CatBoostClassifier(
                iterations=100,
                depth=5,
                learning_rate=0.1,
                l2_leaf_reg=3,
                random_state=self.config.random_state,
                verbose=False,
                allow_writing_files=False
            )
            logger.info("✓ CatBoost added to ensemble")

        # Random Forest - Robust baseline
        if self.config.use_random_forest:
            models['random_forest'] = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=self.config.random_state,
                n_jobs=-1
            )
            logger.info("✓ Random Forest added to ensemble")

        # Fallback to GradientBoosting if no advanced models available
        if not models:
            models['gradient_boosting'] = GradientBoostingClassifier(
                n_estimators=100,
                max_depth=5,
                learning_rate=0.1,
                random_state=self.config.random_state
            )
            logger.warning("⚠ No advanced boosting libraries available, using sklearn GradientBoosting")

        return models

    def _create_ensemble(self, base_models: Dict[str, Any]) -> Any:
        """Create ensemble model using stacking or voting"""
        if self.config.ensemble_method == "stacking":
            # Stacking with logistic regression meta-learner
            estimators = [(name, model) for name, model in base_models.items()]
            ensemble = StackingClassifier(
                estimators=estimators,
                final_estimator=LogisticRegression(max_iter=1000),
                cv=self.config.cv_folds,
                n_jobs=-1
            )
            logger.info(f"✓ Stacking ensemble created with {len(estimators)} base models")
        elif self.config.ensemble_method == "voting":
            # Soft voting ensemble
            estimators = [(name, model) for name, model in base_models.items()]
            ensemble = VotingClassifier(
                estimators=estimators,
                voting='soft',
                n_jobs=-1
            )
            logger.info(f"✓ Voting ensemble created with {len(estimators)} base models")
        else:
            # Use best single model
            ensemble = list(base_models.values())[0]
            logger.info("✓ Using single best model (no ensemble)")

        return ensemble

    def extract_features(self, studies_df: pd.DataFrame) -> Tuple[np.ndarray, List[str]]:
        """
        Extract comprehensive features for heterogeneity prediction
        Enhanced feature engineering based on meta-analysis domain knowledge
        """
        features = []
        feature_names = []

        # 1. Study characteristics
        n_studies = len(studies_df)
        features.append(n_studies)
        feature_names.append('n_studies')
        features.append(np.log1p(n_studies))  # Log-transformed
        feature_names.append('log_n_studies')

        # 2. Sample size features
        if 'n' in studies_df.columns:
            total_n = studies_df['n'].sum()
            mean_n = studies_df['n'].mean()
            median_n = studies_df['n'].median()
            std_n = studies_df['n'].std()
            cv_n = std_n / mean_n if mean_n > 0 else 0

            features.extend([
                total_n, np.log1p(total_n), mean_n, median_n,
                std_n, cv_n, studies_df['n'].min(), studies_df['n'].max(),
                studies_df['n'].skew(), studies_df['n'].kurtosis()
            ])
            feature_names.extend([
                'total_sample_size', 'log_total_n', 'mean_n', 'median_n',
                'std_n', 'cv_n', 'min_n', 'max_n', 'skew_n', 'kurtosis_n'
            ])
        else:
            features.extend([0] * 10)
            feature_names.extend([
                'total_sample_size', 'log_total_n', 'mean_n', 'median_n',
                'std_n', 'cv_n', 'min_n', 'max_n', 'skew_n', 'kurtosis_n'
            ])

        # 3. Temporal features
        if 'year' in studies_df.columns:
            year_range = studies_df['year'].max() - studies_df['year'].min()
            mean_year = studies_df['year'].mean()
            year_std = studies_df['year'].std()

            features.extend([year_range, mean_year, year_std])
            feature_names.extend(['year_range', 'mean_year', 'year_std'])
        else:
            features.extend([0, 2020, 0])
            feature_names.extend(['year_range', 'mean_year', 'year_std'])

        # 4. Risk of bias features
        if 'risk_of_bias' in studies_df.columns:
            rob_counts = studies_df['risk_of_bias'].value_counts()
            high_rob_pct = rob_counts.get('high', 0) / n_studies
            unclear_rob_pct = rob_counts.get('unclear', 0) / n_studies

            features.extend([high_rob_pct, unclear_rob_pct])
            feature_names.extend(['high_rob_pct', 'unclear_rob_pct'])
        else:
            features.extend([0, 0])
            feature_names.extend(['high_rob_pct', 'unclear_rob_pct'])

        # 5. Effect size variability (if available)
        if 'effect_size' in studies_df.columns:
            es_mean = studies_df['effect_size'].mean()
            es_std = studies_df['effect_size'].std()
            es_range = studies_df['effect_size'].max() - studies_df['effect_size'].min()
            es_cv = es_std / abs(es_mean) if es_mean != 0 else 0

            features.extend([es_mean, es_std, es_range, es_cv])
            feature_names.extend(['es_mean', 'es_std', 'es_range', 'es_cv'])
        else:
            features.extend([0, 0, 0, 0])
            feature_names.extend(['es_mean', 'es_std', 'es_range', 'es_cv'])

        # 6. Study design diversity
        if 'study_design' in studies_df.columns:
            n_designs = studies_df['study_design'].nunique()
            design_diversity = n_designs / n_studies
            features.extend([n_designs, design_diversity])
            feature_names.extend(['n_designs', 'design_diversity'])
        else:
            features.extend([1, 0])
            feature_names.extend(['n_designs', 'design_diversity'])

        # 7. Population diversity
        if 'population' in studies_df.columns:
            n_populations = studies_df['population'].nunique()
            pop_diversity = n_populations / n_studies
            features.extend([n_populations, pop_diversity])
            feature_names.extend(['n_populations', 'pop_diversity'])
        else:
            features.extend([1, 0])
            feature_names.extend(['n_populations', 'pop_diversity'])

        # 8. Intervention diversity
        if 'intervention' in studies_df.columns:
            n_interventions = studies_df['intervention'].nunique()
            int_diversity = n_interventions / n_studies
            features.extend([n_interventions, int_diversity])
            feature_names.extend(['n_interventions', 'int_diversity'])
        else:
            features.extend([1, 0])
            feature_names.extend(['n_interventions', 'int_diversity'])

        self.feature_names = feature_names
        return np.array(features).reshape(1, -1), feature_names

    def train(self, X: np.ndarray, y: np.ndarray) -> Dict[str, ModelPerformance]:
        """
        Train ensemble model with cross-validation and performance tracking
        Returns detailed performance metrics for each base model
        """
        import time

        logger.info("Training world-class ensemble model...")

        # Scale features
        X_scaled = self.scaler.fit_transform(X)

        # Encode labels if necessary
        if y.dtype == 'object':
            y_encoded = self.label_encoder.fit_transform(y)
        else:
            y_encoded = y

        # Create base models
        self.base_models = self._create_base_models()

        # Evaluate each base model
        performance_results = {}
        cv = StratifiedKFold(n_splits=self.config.cv_folds, shuffle=True,
                            random_state=self.config.random_state)

        for name, model in self.base_models.items():
            logger.info(f"Evaluating {name}...")

            # Cross-validation
            start_time = time.time()
            cv_scores = cross_val_score(model, X_scaled, y_encoded,
                                       cv=cv, scoring='roc_auc', n_jobs=-1)
            training_time = time.time() - start_time

            # Train on full dataset for predictions
            model.fit(X_scaled, y_encoded)

            # Test prediction time
            start_time = time.time()
            y_pred = model.predict(X_scaled)
            prediction_time = (time.time() - start_time) / len(X_scaled)

            # Compute metrics
            y_pred_proba = model.predict_proba(X_scaled)[:, 1]

            performance = ModelPerformance(
                model_name=name,
                metrics={
                    'accuracy': accuracy_score(y_encoded, y_pred),
                    'auc': roc_auc_score(y_encoded, y_pred_proba),
                    'f1': f1_score(y_encoded, y_pred, average='weighted'),
                    'precision': precision_score(y_encoded, y_pred, average='weighted'),
                    'recall': recall_score(y_encoded, y_pred, average='weighted')
                },
                cv_scores=cv_scores.tolist(),
                cv_mean=cv_scores.mean(),
                cv_std=cv_scores.std(),
                training_time=training_time,
                prediction_time=prediction_time * 1000  # Convert to ms
            )

            performance_results[name] = performance
            self.performance_history.append(performance)

            logger.info(f"  {name}: AUC={performance.metrics['auc']:.4f} "
                       f"(CV: {performance.cv_mean:.4f} ± {performance.cv_std:.4f})")

        # Create and train ensemble
        logger.info(f"Creating {self.config.ensemble_method} ensemble...")
        self.ensemble_model = self._create_ensemble(self.base_models)
        self.ensemble_model.fit(X_scaled, y_encoded)

        # Evaluate ensemble
        y_pred = self.ensemble_model.predict(X_scaled)
        y_pred_proba = self.ensemble_model.predict_proba(X_scaled)[:, 1]

        cv_scores = cross_val_score(self.ensemble_model, X_scaled, y_encoded,
                                   cv=cv, scoring='roc_auc', n_jobs=-1)

        ensemble_performance = ModelPerformance(
            model_name='ensemble',
            metrics={
                'accuracy': accuracy_score(y_encoded, y_pred),
                'auc': roc_auc_score(y_encoded, y_pred_proba),
                'f1': f1_score(y_encoded, y_pred, average='weighted'),
                'precision': precision_score(y_encoded, y_pred, average='weighted'),
                'recall': recall_score(y_encoded, y_pred, average='weighted')
            },
            cv_scores=cv_scores.tolist(),
            cv_mean=cv_scores.mean(),
            cv_std=cv_scores.std(),
            training_time=0,
            prediction_time=0
        )

        performance_results['ensemble'] = ensemble_performance
        self.performance_history.append(ensemble_performance)

        logger.info(f"✓ Ensemble trained: AUC={ensemble_performance.metrics['auc']:.4f} "
                   f"(CV: {ensemble_performance.cv_mean:.4f} ± {ensemble_performance.cv_std:.4f})")

        self.is_trained = True
        return performance_results

    def predict(self, studies_df: pd.DataFrame) -> Dict[str, Any]:
        """
        Predict heterogeneity with comprehensive output
        """
        features, feature_names = self.extract_features(studies_df)

        if not self.is_trained:
            # Rule-based fallback
            return self._rule_based_prediction(studies_df, features, feature_names)

        # ML prediction
        features_scaled = self.scaler.transform(features)

        prediction = self.ensemble_model.predict(features_scaled)[0]
        probabilities = self.ensemble_model.predict_proba(features_scaled)[0]

        # Get predictions from all base models for uncertainty estimation
        base_predictions = {}
        for name, model in self.base_models.items():
            pred_proba = model.predict_proba(features_scaled)[0]
            base_predictions[name] = {
                'prediction': model.predict(features_scaled)[0],
                'probability': pred_proba[1]
            }

        # Decode prediction
        if hasattr(self.label_encoder, 'classes_'):
            prediction_label = self.label_encoder.inverse_transform([prediction])[0]
        else:
            prediction_label = "high" if prediction == 1 else "low"

        return {
            'prediction': prediction_label,
            'probability': float(probabilities[1]),
            'confidence': float(max(probabilities)),
            'probabilities': {
                'low': float(probabilities[0]),
                'high': float(probabilities[1])
            },
            'base_model_predictions': base_predictions,
            'uncertainty': float(np.std([p['probability'] for p in base_predictions.values()])),
            'features_used': dict(zip(feature_names, features[0])),
            'ensemble_method': self.config.ensemble_method,
            'n_base_models': len(self.base_models),
            'explanation': self._generate_explanation(prediction_label, probabilities[1],
                                                     features[0], feature_names)
        }

    def _rule_based_prediction(self, studies_df: pd.DataFrame,
                               features: np.ndarray,
                               feature_names: List[str]) -> Dict[str, Any]:
        """Rule-based fallback when model not trained"""
        n_studies = len(studies_df)

        # Rules for high heterogeneity
        high_het_score = 0

        if n_studies < 5:
            high_het_score += 0.2
        elif n_studies > 20:
            high_het_score += 0.1

        if 'n' in studies_df.columns:
            cv_n = studies_df['n'].std() / studies_df['n'].mean()
            if cv_n > 0.5:
                high_het_score += 0.3

        if 'year' in studies_df.columns:
            year_range = studies_df['year'].max() - studies_df['year'].min()
            if year_range > 10:
                high_het_score += 0.2

        if 'risk_of_bias' in studies_df.columns:
            high_rob = (studies_df['risk_of_bias'] == 'high').sum()
            if high_rob > n_studies * 0.3:
                high_het_score += 0.2

        prediction = "high" if high_het_score > 0.5 else "low"
        probability = min(high_het_score, 1.0)

        return {
            'prediction': prediction,
            'probability': probability,
            'confidence': abs(probability - 0.5) * 2,
            'probabilities': {
                'low': 1 - probability,
                'high': probability
            },
            'base_model_predictions': {},
            'uncertainty': 0.0,
            'features_used': dict(zip(feature_names, features[0])),
            'ensemble_method': 'rule_based',
            'n_base_models': 0,
            'explanation': f"Rule-based prediction: {prediction} heterogeneity (score: {high_het_score:.2f})"
        }

    def _generate_explanation(self, prediction: str, probability: float,
                             features: np.ndarray, feature_names: List[str]) -> str:
        """Generate human-readable explanation"""
        explanations = []

        # Number of studies
        n_studies = int(features[0])
        if n_studies < 5:
            explanations.append(f"Very few studies (n={n_studies}) increases uncertainty")
        elif n_studies > 20:
            explanations.append(f"Large number of studies (n={n_studies}) detected")

        # Sample size variability
        cv_n_idx = feature_names.index('cv_n') if 'cv_n' in feature_names else None
        if cv_n_idx and features[cv_n_idx] > 0.5:
            explanations.append(f"High sample size variability (CV={features[cv_n_idx]:.2f})")

        # Year range
        year_range_idx = feature_names.index('year_range') if 'year_range' in feature_names else None
        if year_range_idx and features[year_range_idx] > 10:
            explanations.append(f"Studies span {int(features[year_range_idx])} years")

        explanation = f"Predicted {prediction} heterogeneity (probability: {probability:.2%}). "
        if explanations:
            explanation += "Key factors: " + "; ".join(explanations)

        return explanation

    def save(self, path: str):
        """Save trained model"""
        if not self.is_trained:
            raise ValueError("Model not trained yet")

        joblib.dump({
            'ensemble_model': self.ensemble_model,
            'base_models': self.base_models,
            'scaler': self.scaler,
            'label_encoder': self.label_encoder,
            'feature_names': self.feature_names,
            'config': self.config,
            'performance_history': self.performance_history
        }, path)
        logger.info(f"Model saved to {path}")

    def load(self, path: str):
        """Load trained model"""
        data = joblib.load(path)
        self.ensemble_model = data['ensemble_model']
        self.base_models = data['base_models']
        self.scaler = data['scaler']
        self.label_encoder = data['label_encoder']
        self.feature_names = data['feature_names']
        self.config = data['config']
        self.performance_history = data.get('performance_history', [])
        self.is_trained = True
        logger.info(f"Model loaded from {path}")


# Global instance
advanced_heterogeneity_predictor = AdvancedHeterogeneityPredictor()
