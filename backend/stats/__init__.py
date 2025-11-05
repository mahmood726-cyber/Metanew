"""
Advanced Statistical Methods Package

Production-ready HTA and causal inference methods.
"""

from .maic_engine import MAICEngine, MAICConfig, MAICResult
from .target_trial import TargetTrialEmulator, TargetTrialProtocol, TargetTrialResult
from .multistate import MultiStateEngine, MultiStateModel, MultiStateResult
from .propensity import PropensityScoreAnalyzer, PropensityScoreResult
from .ipd_ma import IPDMetaAnalyzer, IPDMetaAnalysisResult
from .threshold_analysis import ThresholdAnalyzer, ThresholdAnalysisResult
from .component_nma import ComponentNMAEngine, ComponentNMAResult

__all__ = [
    "MAICEngine",
    "MAICConfig",
    "MAICResult",
    "TargetTrialEmulator",
    "TargetTrialProtocol",
    "TargetTrialResult",
    "MultiStateEngine",
    "MultiStateModel",
    "MultiStateResult",
    "PropensityScoreAnalyzer",
    "PropensityScoreResult",
    "IPDMetaAnalyzer",
    "IPDMetaAnalysisResult",
    "ThresholdAnalyzer",
    "ThresholdAnalysisResult",
    "ComponentNMAEngine",
    "ComponentNMAResult",
]
