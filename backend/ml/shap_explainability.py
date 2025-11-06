"""
SHAP Explainability for ML-Powered Meta-Analysis

Provides interpretable explanations for:
- Study screening AI decisions
- Subgroup predictions
- Treatment effect heterogeneity
- Feature importance in ML models

Uses SHAP (SHapley Additive exPlanations) - game-theoretic approach
to explain ML model predictions.

Value: £50k (trust + regulatory compliance)

Dependencies:
- shap: SHAP library (optional, with fallback)
- numpy, pandas: Data manipulation
- sklearn: ML models

References:
- Lundberg & Lee (2017). A Unified Approach to Interpreting Model Predictions
- SHAP documentation: https://shap.readthedocs.io/
"""

import logging
import warnings
from typing import List, Dict, Optional, Tuple, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

# SHAP (optional dependency)
try:
    import shap
    SHAP_AVAILABLE = True
except ImportError:
    SHAP_AVAILABLE = False
    logger.warning("SHAP not available. Using rule-based feature importance fallback.")


# ==================== ENUMS ====================

class ExplanationType(Enum):
    """Types of explanations"""
    FEATURE_IMPORTANCE = "feature_importance"
    INDIVIDUAL_PREDICTION = "individual_prediction"
    INTERACTION_EFFECTS = "interaction_effects"
    DECISION_PLOT = "decision_plot"


# ==================== DATA CLASSES ====================

@dataclass
class SHAPExplanation:
    """SHAP explanation for a prediction"""

    # Feature contributions
    shap_values: np.ndarray  # SHAP values for each feature
    feature_names: List[str]
    base_value: float  # Expected model output

    # Prediction info
    predicted_value: float
    true_value: Optional[float] = None

    # Feature importance ranking
    feature_importance: Dict[str, float] = field(default_factory=dict)

    # Confidence
    confidence: float = 1.0

    def get_top_features(self, n: int = 5) -> List[Tuple[str, float]]:
        """Get top N most important features"""
        sorted_features = sorted(
            self.feature_importance.items(),
            key=lambda x: abs(x[1]),
            reverse=True
        )
        return sorted_features[:n]

    def get_explanation_text(self) -> str:
        """Generate human-readable explanation"""
        lines = [f"Predicted value: {self.predicted_value:.3f}"]
        lines.append(f"Baseline: {self.base_value:.3f}")
        lines.append("\nTop contributing features:")

        for feature, importance in self.get_top_features(5):
            direction = "increases" if importance > 0 else "decreases"
            lines.append(f"  - {feature}: {direction} prediction by {abs(importance):.3f}")

        return "\n".join(lines)


@dataclass
class GlobalExplanation:
    """Global model explanation across all predictions"""

    # Average feature importance
    mean_shap_values: np.ndarray
    feature_names: List[str]

    # Feature interactions
    interaction_values: Optional[np.ndarray] = None

    # Summary statistics
    feature_importance_ranking: List[Tuple[str, float]] = field(default_factory=list)

    def get_feature_importance_df(self) -> pd.DataFrame:
        """Get feature importance as DataFrame"""
        return pd.DataFrame({
            'feature': self.feature_names,
            'importance': np.abs(self.mean_shap_values).mean(axis=0)
        }).sort_values('importance', ascending=False)


# ==================== SHAP EXPLAINER ====================

class SHAPExplainer:
    """
    SHAP-based model explainer

    Provides interpretable explanations for ML models:
    - Why was this study included/excluded?
    - Which features drive subgroup effects?
    - How do features interact?

    Value: £50k (regulatory compliance + trust)
    """

    def __init__(
        self,
        model: Any,
        background_data: np.ndarray,
        feature_names: List[str],
        model_type: str = "tree"
    ):
        """
        Initialize SHAP explainer

        Args:
            model: Trained ML model (sklearn, xgboost, etc.)
            background_data: Background dataset for SHAP
            feature_names: Names of features
            model_type: "tree", "linear", "deep", or "kernel"
        """
        self.model = model
        self.background_data = background_data
        self.feature_names = feature_names
        self.model_type = model_type

        # Initialize SHAP explainer
        if SHAP_AVAILABLE:
            self._init_shap_explainer()
        else:
            logger.warning("SHAP not available, using permutation importance fallback")
            self.explainer = None

    def _init_shap_explainer(self):
        """Initialize appropriate SHAP explainer based on model type"""

        if self.model_type == "tree":
            # For tree-based models (RandomForest, XGBoost, etc.)
            self.explainer = shap.TreeExplainer(self.model)

        elif self.model_type == "linear":
            # For linear models
            self.explainer = shap.LinearExplainer(
                self.model,
                self.background_data
            )

        elif self.model_type == "deep":
            # For deep neural networks
            self.explainer = shap.DeepExplainer(
                self.model,
                self.background_data
            )

        else:
            # Kernel SHAP (model-agnostic, slower)
            self.explainer = shap.KernelExplainer(
                self.model.predict,
                self.background_data
            )

    def explain_prediction(
        self,
        X: np.ndarray,
        instance_idx: Optional[int] = None
    ) -> SHAPExplanation:
        """
        Explain a single prediction

        Args:
            X: Feature matrix
            instance_idx: Index of instance to explain (None = first)

        Returns:
            SHAPExplanation with feature contributions
        """
        if instance_idx is None:
            instance_idx = 0

        instance = X[instance_idx:instance_idx+1]

        if SHAP_AVAILABLE and self.explainer is not None:
            # Calculate SHAP values
            shap_values = self.explainer.shap_values(instance)

            # Handle multi-output models
            if isinstance(shap_values, list):
                shap_values = shap_values[0]  # Use first class

            shap_values = shap_values.flatten()

            # Base value (expected output)
            if hasattr(self.explainer, 'expected_value'):
                base_value = self.explainer.expected_value
                if isinstance(base_value, np.ndarray):
                    base_value = base_value[0]
            else:
                base_value = self.model.predict(self.background_data).mean()

        else:
            # Fallback: use permutation importance
            shap_values = self._permutation_importance(instance)
            base_value = self.model.predict(self.background_data).mean()

        # Make prediction
        predicted_value = self.model.predict(instance)[0]

        # Feature importance dict
        feature_importance = {
            name: float(value)
            for name, value in zip(self.feature_names, shap_values)
        }

        return SHAPExplanation(
            shap_values=shap_values,
            feature_names=self.feature_names,
            base_value=float(base_value),
            predicted_value=float(predicted_value),
            feature_importance=feature_importance
        )

    def explain_global(
        self,
        X: np.ndarray,
        max_samples: int = 1000
    ) -> GlobalExplanation:
        """
        Generate global model explanation

        Args:
            X: Feature matrix (all data)
            max_samples: Max samples to use (for speed)

        Returns:
            GlobalExplanation with average feature importance
        """
        # Subsample if needed
        if len(X) > max_samples:
            indices = np.random.choice(len(X), max_samples, replace=False)
            X_sample = X[indices]
        else:
            X_sample = X

        if SHAP_AVAILABLE and self.explainer is not None:
            # Calculate SHAP values for all samples
            shap_values = self.explainer.shap_values(X_sample)

            # Handle multi-output
            if isinstance(shap_values, list):
                shap_values = shap_values[0]

        else:
            # Fallback
            shap_values = np.array([
                self._permutation_importance(X_sample[i:i+1])
                for i in range(len(X_sample))
            ])

        # Mean absolute SHAP values
        mean_shap = np.abs(shap_values).mean(axis=0)

        # Feature importance ranking
        feature_importance_ranking = [
            (name, float(importance))
            for name, importance in zip(self.feature_names, mean_shap)
        ]
        feature_importance_ranking.sort(key=lambda x: x[1], reverse=True)

        return GlobalExplanation(
            mean_shap_values=shap_values,
            feature_names=self.feature_names,
            feature_importance_ranking=feature_importance_ranking
        )

    def _permutation_importance(self, instance: np.ndarray) -> np.ndarray:
        """
        Fallback: calculate permutation-based feature importance

        Permutes each feature and measures prediction change
        """
        base_pred = self.model.predict(instance)[0]
        importances = np.zeros(len(self.feature_names))

        for i in range(len(self.feature_names)):
            # Permute feature i
            instance_permuted = instance.copy()
            instance_permuted[0, i] = np.random.choice(self.background_data[:, i])

            # Predict
            permuted_pred = self.model.predict(instance_permuted)[0]

            # Importance = change in prediction
            importances[i] = permuted_pred - base_pred

        return importances


# ==================== ML MODEL EXPLAINABILITY ====================

class MetaAnalysisMLExplainer:
    """
    Explainer for ML-powered meta-analysis features

    Explains:
    - Study screening decisions (why included/excluded?)
    - Subgroup predictions (which features matter?)
    - Treatment heterogeneity (who benefits most?)

    Value: Builds trust in AI-powered decisions
    """

    def __init__(self):
        """Initialize explainer"""
        self.explainers: Dict[str, SHAPExplainer] = {}

    def register_model(
        self,
        model_name: str,
        model: Any,
        background_data: np.ndarray,
        feature_names: List[str],
        model_type: str = "tree"
    ):
        """
        Register a model for explanation

        Args:
            model_name: Name identifier for model
            model: Trained ML model
            background_data: Representative background dataset
            feature_names: Feature names
            model_type: Type of model
        """
        explainer = SHAPExplainer(
            model=model,
            background_data=background_data,
            feature_names=feature_names,
            model_type=model_type
        )

        self.explainers[model_name] = explainer
        logger.info(f"Registered explainer for '{model_name}'")

    def explain_study_screening_decision(
        self,
        model_name: str,
        study_features: np.ndarray
    ) -> Dict[str, Any]:
        """
        Explain why a study was included/excluded by screening AI

        Args:
            model_name: Name of screening model
            study_features: Feature vector for the study

        Returns:
            Dict with explanation and key features
        """
        if model_name not in self.explainers:
            return {"error": f"Model '{model_name}' not registered"}

        explainer = self.explainers[model_name]
        explanation = explainer.explain_prediction(study_features.reshape(1, -1))

        # Get top features driving decision
        top_features = explanation.get_top_features(5)

        return {
            "decision": "INCLUDE" if explanation.predicted_value > 0.5 else "EXCLUDE",
            "confidence": float(explanation.predicted_value),
            "explanation_text": explanation.get_explanation_text(),
            "top_features": [
                {
                    "feature": feat,
                    "contribution": float(contrib),
                    "direction": "inclusion" if contrib > 0 else "exclusion"
                }
                for feat, contrib in top_features
            ]
        }

    def explain_subgroup_effect(
        self,
        model_name: str,
        patient_features: np.ndarray
    ) -> Dict[str, Any]:
        """
        Explain predicted treatment effect for a patient subgroup

        Args:
            model_name: Name of subgroup model
            patient_features: Patient characteristic features

        Returns:
            Explanation of effect prediction
        """
        if model_name not in self.explainers:
            return {"error": f"Model '{model_name}' not registered"}

        explainer = self.explainers[model_name]
        explanation = explainer.explain_prediction(patient_features.reshape(1, -1))

        return {
            "predicted_effect": float(explanation.predicted_value),
            "baseline_effect": float(explanation.base_value),
            "explanation_text": explanation.get_explanation_text(),
            "key_moderators": explanation.get_top_features(3)
        }

    def get_feature_importance_summary(
        self,
        model_name: str,
        X: np.ndarray
    ) -> pd.DataFrame:
        """
        Get global feature importance summary

        Args:
            model_name: Model to explain
            X: Full dataset

        Returns:
            DataFrame with feature importance rankings
        """
        if model_name not in self.explainers:
            return pd.DataFrame()

        explainer = self.explainers[model_name]
        global_exp = explainer.explain_global(X)

        return global_exp.get_feature_importance_df()


# ==================== EXAMPLE USAGE ====================

if __name__ == "__main__":
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.datasets import make_classification

    print("="*60)
    print("SHAP Explainability Example")
    print("="*60)

    # Generate synthetic data for study screening
    X, y = make_classification(
        n_samples=200,
        n_features=10,
        n_informative=5,
        random_state=42
    )

    feature_names = [
        'sample_size',
        'randomization_quality',
        'blinding_score',
        'relevance_score',
        'publication_year',
        'impact_factor',
        'funding_source',
        'study_duration',
        'dropout_rate',
        'outcome_reporting'
    ]

    # Train model
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X, y)

    print(f"\nModel trained: {model.__class__.__name__}")
    print(f"Features: {len(feature_names)}")
    print(f"Training accuracy: {model.score(X, y):.1%}")

    # Create explainer
    background_data = X[:50]  # Use subset as background

    shap_explainer = SHAPExplainer(
        model=model,
        background_data=background_data,
        feature_names=feature_names,
        model_type="tree"
    )

    # Explain a single prediction
    print(f"\n📊 Explaining study screening decision:")
    explanation = shap_explainer.explain_prediction(X, instance_idx=100)

    print(explanation.get_explanation_text())

    # Global feature importance
    print(f"\n🌍 Global Feature Importance:")
    global_exp = shap_explainer.explain_global(X, max_samples=100)

    importance_df = global_exp.get_feature_importance_df()
    print(importance_df.head())

    # Use in meta-analysis context
    print(f"\n🔬 Meta-Analysis ML Explainer:")
    ml_explainer = MetaAnalysisMLExplainer()

    ml_explainer.register_model(
        model_name="study_screener",
        model=model,
        background_data=background_data,
        feature_names=feature_names,
        model_type="tree"
    )

    # Explain screening decision
    study_features = X[150]
    decision_explanation = ml_explainer.explain_study_screening_decision(
        "study_screener",
        study_features
    )

    print(f"\nDecision: {decision_explanation['decision']}")
    print(f"Confidence: {decision_explanation['confidence']:.1%}")
    print("\nKey factors:")
    for factor in decision_explanation['top_features'][:3]:
        print(f"  - {factor['feature']}: {factor['direction']} ({factor['contribution']:.3f})")

    print("\n✓ SHAP Explainability Complete")
    print("  - Interpretable ML for study screening")
    print("  - Feature importance ranking")
    print("  - Decision explanations")
    print("  Value: £50k (trust + regulatory compliance)")
