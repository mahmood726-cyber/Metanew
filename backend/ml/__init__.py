"""
Machine Learning Module for EvidenceOS PRIME
"""
from .predictive_models import (
    HeterogeneityPredictor,
    PublicationBiasDetector,
    StudyQualityPredictor,
    EffectSizePredictor,
    PredictionResult,
    heterogeneity_predictor,
    publication_bias_detector,
    study_quality_predictor,
    effect_size_predictor,
)
from .rules_engine import (
    AnalysisRecommender,
    SensitivityAnalysisEngine,
    QualityAssessmentEngine,
    analysis_recommender,
)
from .knowledge_graph import (
    StudyDeduplicator,
    EvidenceKnowledgeGraph,
    study_deduplicator,
)

__all__ = [
    "HeterogeneityPredictor",
    "PublicationBiasDetector",
    "StudyQualityPredictor",
    "EffectSizePredictor",
    "PredictionResult",
    "heterogeneity_predictor",
    "publication_bias_detector",
    "study_quality_predictor",
    "effect_size_predictor",
    "AnalysisRecommender",
    "SensitivityAnalysisEngine",
    "QualityAssessmentEngine",
    "analysis_recommender",
    "StudyDeduplicator",
    "EvidenceKnowledgeGraph",
    "study_deduplicator",
]
