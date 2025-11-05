"""
World-Class Machine Learning Module for EvidenceOS PRIME
Implements 2025 best practices for healthcare ML/AI
"""
# Original models
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

# Rules-based systems
from .rules_engine import (
    AnalysisRecommender,
    SensitivityAnalysisEngine,
    QualityAssessmentEngine,
    analysis_recommender,
)

# Knowledge graph
from .knowledge_graph import (
    StudyDeduplicator,
    EvidenceKnowledgeGraph,
    study_deduplicator,
)

# World-class ensemble models
from .ensemble_models import (
    AdvancedHeterogeneityPredictor,
    EnsembleConfig,
    ModelPerformance,
    advanced_heterogeneity_predictor,
)

# Explainable AI
from .explainable_ai import (
    ModelExplainer,
    ExplanationResult,
    create_explainer_for_model,
    explain_heterogeneity_prediction,
    explain_publication_bias_prediction,
)

# RAG system
from .rag_system import (
    MedicalKnowledgeBase,
    RAGSystem,
    Document,
    RetrievalResult,
    get_knowledge_base,
    get_rag_system,
)

# MLOps infrastructure
from .mlops_infrastructure import (
    ExperimentTracker,
    ModelRegistry,
    DriftDetector,
    ExperimentMetrics,
    ModelVersion,
    DriftReport,
    get_experiment_tracker,
    get_model_registry,
    get_drift_detector,
)

# AutoML
from .automl import (
    AutoMLOptimizer,
    SimpleAutoML,
    OptimizationResult,
    create_automl,
)

# NEW: Advanced AI Features (2025)
from .report_generation import (
    NaturalLanguageReportGenerator,
    ReportSection,
)

from .risk_of_bias_assessment import (
    RiskOfBiasAssessor,
)

from .study_screening import (
    StudyScreeningAssistant,
)

from .pdf_extraction import (
    PDFDataExtractor,
)

from .bayesian_nma import (
    BayesianNMA,
)

__all__ = [
    # Original models
    "HeterogeneityPredictor",
    "PublicationBiasDetector",
    "StudyQualityPredictor",
    "EffectSizePredictor",
    "PredictionResult",
    "heterogeneity_predictor",
    "publication_bias_detector",
    "study_quality_predictor",
    "effect_size_predictor",
    # Rules engine
    "AnalysisRecommender",
    "SensitivityAnalysisEngine",
    "QualityAssessmentEngine",
    "analysis_recommender",
    # Knowledge graph
    "StudyDeduplicator",
    "EvidenceKnowledgeGraph",
    "study_deduplicator",
    # Ensemble models
    "AdvancedHeterogeneityPredictor",
    "EnsembleConfig",
    "ModelPerformance",
    "advanced_heterogeneity_predictor",
    # Explainable AI
    "ModelExplainer",
    "ExplanationResult",
    "create_explainer_for_model",
    "explain_heterogeneity_prediction",
    "explain_publication_bias_prediction",
    # RAG system
    "MedicalKnowledgeBase",
    "RAGSystem",
    "Document",
    "RetrievalResult",
    "get_knowledge_base",
    "get_rag_system",
    # MLOps
    "ExperimentTracker",
    "ModelRegistry",
    "DriftDetector",
    "ExperimentMetrics",
    "ModelVersion",
    "DriftReport",
    "get_experiment_tracker",
    "get_model_registry",
    "get_drift_detector",
    # AutoML
    "AutoMLOptimizer",
    "SimpleAutoML",
    "OptimizationResult",
    "create_automl",
    # NEW: Advanced AI Features
    "NaturalLanguageReportGenerator",
    "ReportSection",
    "RiskOfBiasAssessor",
    "StudyScreeningAssistant",
    "PDFDataExtractor",
    "BayesianNMA",
]
