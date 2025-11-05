"""
Explainable AI (XAI) for Meta-Analysis ML Models
Implements SHAP and LIME for model interpretability
Critical for healthcare/clinical applications (2025 best practices)
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)

# SHAP for global and local explanations
try:
    import shap
    SHAP_AVAILABLE = True
except ImportError:
    SHAP_AVAILABLE = False
    logger.warning("SHAP not installed. Install with: pip install shap")

# LIME for model-agnostic interpretability
try:
    import lime
    import lime.lime_tabular
    LIME_AVAILABLE = True
except ImportError:
    LIME_AVAILABLE = False
    logger.warning("LIME not installed. Install with: pip install lime")


@dataclass
class ExplanationResult:
    """Results from explainable AI analysis"""
    method: str  # "shap", "lime", "feature_importance"
    global_importance: Dict[str, float]  # Feature -> importance score
    local_explanation: Optional[Dict[str, Any]]  # Per-prediction explanation
    explanation_text: str  # Human-readable explanation
    visualization_data: Optional[Dict[str, Any]]  # Data for plots
    confidence_score: float  # How confident is the explanation


class ModelExplainer:
    """
    Unified interface for SHAP and LIME explanations
    Provides both global (model-level) and local (prediction-level) interpretability
    """

    def __init__(self, model: Any, feature_names: List[str], training_data: Optional[np.ndarray] = None):
        """
        Initialize explainer with trained model

        Args:
            model: Trained sklearn-compatible model
            feature_names: Names of features used by model
            training_data: Training data for background distribution (for SHAP)
        """
        self.model = model
        self.feature_names = feature_names
        self.training_data = training_data

        # Initialize explainers
        self.shap_explainer = None
        self.lime_explainer = None

        if SHAP_AVAILABLE and training_data is not None:
            self._init_shap_explainer()

        if LIME_AVAILABLE and training_data is not None:
            self._init_lime_explainer()

    def _init_shap_explainer(self):
        """Initialize SHAP explainer"""
        try:
            # Use TreeExplainer for tree-based models (XGBoost, LightGBM, CatBoost, RF)
            if hasattr(self.model, 'feature_importances_') or \
               hasattr(self.model, 'get_booster'):  # XGBoost
                self.shap_explainer = shap.TreeExplainer(self.model)
                logger.info("✓ SHAP TreeExplainer initialized")
            else:
                # Use KernelExplainer for other models (slower but model-agnostic)
                background = shap.sample(self.training_data, min(100, len(self.training_data)))
                self.shap_explainer = shap.KernelExplainer(
                    self.model.predict_proba,
                    background
                )
                logger.info("✓ SHAP KernelExplainer initialized")
        except Exception as e:
            logger.error(f"Failed to initialize SHAP: {str(e)}")
            self.shap_explainer = None

    def _init_lime_explainer(self):
        """Initialize LIME explainer"""
        try:
            self.lime_explainer = lime.lime_tabular.LimeTabularExplainer(
                training_data=self.training_data,
                feature_names=self.feature_names,
                mode='classification',
                discretize_continuous=True
            )
            logger.info("✓ LIME explainer initialized")
        except Exception as e:
            logger.error(f"Failed to initialize LIME: {str(e)}")
            self.lime_explainer = None

    def explain_prediction_shap(self, X: np.ndarray, instance_idx: int = 0) -> ExplanationResult:
        """
        Explain a single prediction using SHAP
        SHAP provides consistent, theoretically grounded explanations

        Args:
            X: Feature matrix
            instance_idx: Index of instance to explain

        Returns:
            ExplanationResult with SHAP values and explanations
        """
        if not SHAP_AVAILABLE or self.shap_explainer is None:
            return self._fallback_explanation(X, instance_idx)

        try:
            # Compute SHAP values
            shap_values = self.shap_explainer.shap_values(X)

            # For binary classification, shap_values might be list of 2 arrays
            if isinstance(shap_values, list):
                shap_values = shap_values[1]  # Positive class

            # Get values for specific instance
            instance_shap_values = shap_values[instance_idx]

            # Create feature importance dict
            importance_dict = dict(zip(self.feature_names, instance_shap_values))

            # Sort by absolute value
            sorted_importance = sorted(
                importance_dict.items(),
                key=lambda x: abs(x[1]),
                reverse=True
            )

            # Generate explanation text
            top_features = sorted_importance[:5]
            explanation_parts = []

            for feat, value in top_features:
                direction = "increases" if value > 0 else "decreases"
                explanation_parts.append(
                    f"{feat} {direction} prediction by {abs(value):.4f}"
                )

            explanation_text = "Top SHAP contributions: " + "; ".join(explanation_parts)

            # Compute confidence (based on magnitude of SHAP values)
            total_shap = np.sum(np.abs(instance_shap_values))
            top_5_shap = sum(abs(v) for _, v in top_features)
            confidence = top_5_shap / total_shap if total_shap > 0 else 0.0

            return ExplanationResult(
                method="shap",
                global_importance={k: float(v) for k, v in sorted_importance},
                local_explanation={
                    'shap_values': instance_shap_values.tolist(),
                    'base_value': float(self.shap_explainer.expected_value) if hasattr(self.shap_explainer, 'expected_value') else 0.0,
                    'feature_values': X[instance_idx].tolist()
                },
                explanation_text=explanation_text,
                visualization_data={
                    'feature_names': self.feature_names,
                    'shap_values': instance_shap_values.tolist(),
                    'feature_values': X[instance_idx].tolist()
                },
                confidence_score=float(confidence)
            )

        except Exception as e:
            logger.error(f"SHAP explanation failed: {str(e)}")
            return self._fallback_explanation(X, instance_idx)

    def explain_prediction_lime(self, X: np.ndarray, instance_idx: int = 0,
                               num_features: int = 10) -> ExplanationResult:
        """
        Explain a single prediction using LIME
        LIME provides local interpretable model-agnostic explanations

        Args:
            X: Feature matrix
            instance_idx: Index of instance to explain
            num_features: Number of features to include in explanation

        Returns:
            ExplanationResult with LIME explanations
        """
        if not LIME_AVAILABLE or self.lime_explainer is None:
            return self._fallback_explanation(X, instance_idx)

        try:
            # Get explanation for instance
            instance = X[instance_idx]
            explanation = self.lime_explainer.explain_instance(
                instance,
                self.model.predict_proba,
                num_features=num_features
            )

            # Extract feature importance
            lime_features = explanation.as_list()
            importance_dict = {}

            for feat_desc, weight in lime_features:
                # Parse feature name from description
                feat_name = feat_desc.split('<=')[0].split('>')[0].strip()
                importance_dict[feat_name] = weight

            # Generate explanation text
            top_features = lime_features[:5]
            explanation_parts = []

            for feat_desc, weight in top_features:
                direction = "increases" if weight > 0 else "decreases"
                explanation_parts.append(
                    f"{feat_desc} {direction} prediction"
                )

            explanation_text = "Top LIME contributions: " + "; ".join(explanation_parts)

            # Confidence based on prediction probability
            pred_proba = self.model.predict_proba(instance.reshape(1, -1))[0]
            confidence = float(max(pred_proba))

            return ExplanationResult(
                method="lime",
                global_importance=importance_dict,
                local_explanation={
                    'lime_features': lime_features,
                    'intercept': float(explanation.intercept[1]),
                    'prediction': float(pred_proba[1]),
                    'score': float(explanation.score)
                },
                explanation_text=explanation_text,
                visualization_data={
                    'feature_importance': lime_features,
                    'prediction_proba': pred_proba.tolist()
                },
                confidence_score=confidence
            )

        except Exception as e:
            logger.error(f"LIME explanation failed: {str(e)}")
            return self._fallback_explanation(X, instance_idx)

    def get_global_feature_importance(self) -> ExplanationResult:
        """
        Get global feature importance across all predictions
        Uses model's built-in feature importance if available
        """
        try:
            # Try to get feature importance from model
            if hasattr(self.model, 'feature_importances_'):
                importance_values = self.model.feature_importances_
                importance_dict = dict(zip(self.feature_names, importance_values))
            elif hasattr(self.model, 'coef_'):
                # Linear models
                importance_values = np.abs(self.model.coef_[0])
                importance_dict = dict(zip(self.feature_names, importance_values))
            else:
                # For ensemble models, try to get from estimators
                if hasattr(self.model, 'estimators_') and len(self.model.estimators_) > 0:
                    importances = []
                    for estimator in self.model.estimators_:
                        if hasattr(estimator, 'feature_importances_'):
                            importances.append(estimator.feature_importances_)

                    if importances:
                        avg_importance = np.mean(importances, axis=0)
                        importance_dict = dict(zip(self.feature_names, avg_importance))
                    else:
                        raise AttributeError("No feature importance available")
                else:
                    raise AttributeError("No feature importance available")

            # Sort by importance
            sorted_importance = sorted(
                importance_dict.items(),
                key=lambda x: abs(x[1]),
                reverse=True
            )

            # Generate explanation
            top_5 = sorted_importance[:5]
            explanation_text = "Most important features (global): " + ", ".join(
                [f"{name} ({value:.4f})" for name, value in top_5]
            )

            return ExplanationResult(
                method="feature_importance",
                global_importance={k: float(v) for k, v in sorted_importance},
                local_explanation=None,
                explanation_text=explanation_text,
                visualization_data={
                    'feature_names': [k for k, v in sorted_importance],
                    'importance_values': [v for k, v in sorted_importance]
                },
                confidence_score=1.0
            )

        except Exception as e:
            logger.error(f"Failed to get feature importance: {str(e)}")
            return ExplanationResult(
                method="feature_importance",
                global_importance={},
                local_explanation=None,
                explanation_text="Feature importance not available for this model type",
                visualization_data=None,
                confidence_score=0.0
            )

    def explain_comprehensive(self, X: np.ndarray, instance_idx: int = 0) -> Dict[str, ExplanationResult]:
        """
        Generate comprehensive explanations using all available methods
        Best practice: Combine SHAP + LIME + Feature Importance

        Returns:
            Dictionary with all explanation results
        """
        results = {}

        # Global feature importance
        results['global'] = self.get_global_feature_importance()

        # SHAP (if available)
        if SHAP_AVAILABLE and self.shap_explainer is not None:
            results['shap'] = self.explain_prediction_shap(X, instance_idx)

        # LIME (if available)
        if LIME_AVAILABLE and self.lime_explainer is not None:
            results['lime'] = self.explain_prediction_lime(X, instance_idx)

        return results

    def _fallback_explanation(self, X: np.ndarray, instance_idx: int) -> ExplanationResult:
        """Simple fallback explanation when SHAP/LIME unavailable"""
        # Use basic feature importance if available
        global_result = self.get_global_feature_importance()

        if global_result.global_importance:
            return global_result
        else:
            return ExplanationResult(
                method="basic",
                global_importance={},
                local_explanation=None,
                explanation_text="Model explanations require SHAP or LIME installation",
                visualization_data=None,
                confidence_score=0.0
            )

    def generate_patient_specific_explanation(self, X: np.ndarray,
                                             instance_idx: int,
                                             patient_context: Optional[Dict[str, Any]] = None) -> str:
        """
        Generate patient/study-specific explanation for healthcare context
        Follows 2025 clinical ML best practices

        Args:
            X: Feature matrix
            instance_idx: Instance to explain
            patient_context: Additional context (study characteristics, etc.)

        Returns:
            Human-readable, clinician-friendly explanation
        """
        # Get comprehensive explanations
        explanations = self.explain_comprehensive(X, instance_idx)

        # Build patient-specific narrative
        narrative_parts = []

        # Add prediction context
        pred_proba = self.model.predict_proba(X[instance_idx].reshape(1, -1))[0]
        prediction = self.model.predict(X[instance_idx].reshape(1, -1))[0]

        narrative_parts.append(
            f"Prediction: {prediction} (confidence: {max(pred_proba):.1%})"
        )

        # Add SHAP insights if available
        if 'shap' in explanations:
            shap_result = explanations['shap']
            top_3 = list(shap_result.global_importance.items())[:3]

            narrative_parts.append("\nKey contributing factors:")
            for feat, importance in top_3:
                feat_value = X[instance_idx][self.feature_names.index(feat)]
                direction = "increases" if importance > 0 else "decreases"
                narrative_parts.append(
                    f"  • {feat} = {feat_value:.2f} → {direction} risk (contribution: {abs(importance):.3f})"
                )

        # Add patient context if provided
        if patient_context:
            narrative_parts.append("\nStudy/Patient Context:")
            for key, value in patient_context.items():
                narrative_parts.append(f"  • {key}: {value}")

        # Add uncertainty statement
        if 'shap' in explanations and 'lime' in explanations:
            shap_conf = explanations['shap'].confidence_score
            lime_conf = explanations['lime'].confidence_score
            avg_conf = (shap_conf + lime_conf) / 2

            if avg_conf < 0.6:
                narrative_parts.append(
                    "\n⚠️ Note: This prediction has moderate uncertainty. "
                    "Consider additional clinical judgment."
                )

        return "\n".join(narrative_parts)


def create_explainer_for_model(model: Any, feature_names: List[str],
                               training_data: Optional[np.ndarray] = None) -> ModelExplainer:
    """
    Factory function to create appropriate explainer for a model

    Args:
        model: Trained model
        feature_names: Feature names
        training_data: Training data for background distribution

    Returns:
        ModelExplainer instance
    """
    return ModelExplainer(model, feature_names, training_data)


# Utility functions for healthcare-specific explanations

def explain_heterogeneity_prediction(explainer: ModelExplainer, X: np.ndarray,
                                     instance_idx: int = 0,
                                     study_details: Optional[Dict[str, Any]] = None) -> str:
    """
    Generate explanation specifically for heterogeneity prediction
    Tailored for meta-analysis researchers
    """
    explanation = explainer.generate_patient_specific_explanation(X, instance_idx, study_details)

    # Add meta-analysis specific interpretation
    interpretation = """

### Interpretation for Meta-Analysis:
High heterogeneity (I² > 50%) suggests:
  • Consider subgroup analyses to identify sources of variation
  • Use random-effects model instead of fixed-effects
  • Investigate clinical and methodological diversity
  • Report heterogeneity statistics (I², τ², Q-test)

Low heterogeneity (I² < 50%) suggests:
  • Fixed-effects model may be appropriate
  • Studies are relatively homogeneous
  • Pooled effect estimate is more reliable
"""

    return explanation + interpretation


def explain_publication_bias_prediction(explainer: ModelExplainer, X: np.ndarray,
                                        instance_idx: int = 0) -> str:
    """Generate explanation for publication bias detection"""
    explanation = explainer.generate_patient_specific_explanation(X, instance_idx)

    interpretation = """

### Interpretation for Publication Bias:
High risk of bias suggests:
  • Conduct sensitivity analyses (trim-and-fill, Duval & Tweedie)
  • Check for funnel plot asymmetry
  • Consider Egger's test and PET-PEESE
  • Search for unpublished studies (clinical trial registries)

Low risk of bias suggests:
  • Published literature appears representative
  • Pooled estimate likely unbiased
  • Still report bias assessment methods used
"""

    return explanation + interpretation
