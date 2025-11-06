"""
RMST-Based Network Meta-Analysis
=================================

Network meta-analysis using Restricted Mean Survival Time (RMST) instead
of hazard ratios for time-to-event outcomes.

RMST represents the mean survival time up to a prespecified time τ (tau)
and corresponds to the area under the survival curve.

Advantages over Hazard Ratios:
- More intuitive (measured in time units: months, years)
- No proportional hazards assumption required
- Robust to non-proportional hazards
- Directly clinically meaningful: "Treatment A gives X more months than B"

References:
- Hua et al. (2025) "NMA of Time-to-Event Endpoints With IPD Using RMST Regression"
  Biometrical Journal 67(1), e70037
- Royston & Parmar (2013) "Restricted mean survival time" BMC Med Res Methodol 13:152

Applications:
- Oncology trials (overall survival, progression-free survival)
- Cardiovascular outcomes
- Any time-to-event outcome with non-proportional hazards
"""

from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
import numpy as np
from scipy import stats
import logging

logger = logging.getLogger(__name__)


@dataclass
class RMSTStudy:
    """Study with RMST data"""
    study_id: str
    treatment: str
    rmst: float  # Restricted mean survival time
    rmst_se: float  # Standard error
    tau: float  # Restriction time
    n_patients: int
    n_events: int


@dataclass
class RMSTDifference:
    """RMST difference between two treatments"""
    treatment: str
    comparison: str
    difference: float  # In time units (e.g., months)
    se: float
    lower_95ci: float
    upper_95ci: float
    p_value: float
    significant: bool


@dataclass
class RMSTNMAResults:
    """Results from RMST-based NMA"""
    tau: float  # Restriction time
    reference_treatment: str

    # RMST estimates
    rmst_estimates: Dict[str, Tuple[float, float]]  # treatment: (rmst, se)

    # Pairwise differences
    rmst_differences: List[RMSTDifference]

    # Rankings
    treatment_ranking: List[Tuple[str, int]]  # (treatment, rank)

    # Model info
    method: str = "frequentist"
    n_studies: int = 0
    n_treatments: int = 0

    interpretation: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)

    def summary(self) -> str:
        """Generate summary"""
        lines = [
            "=" * 70,
            "RMST-BASED NETWORK META-ANALYSIS RESULTS",
            "=" * 70,
            "",
            f"Restriction time (τ): {self.tau} time units",
            f"Reference: {self.reference_treatment}",
            f"Studies: {self.n_studies}, Treatments: {self.n_treatments}",
            "",
            "RMST ESTIMATES (Mean survival time up to τ):",
            "-" * 70
        ]

        for trt, (rmst, se) in sorted(
            self.rmst_estimates.items(),
            key=lambda x: x[1][0],
            reverse=True
        ):
            ci_lower = rmst - 1.96 * se
            ci_upper = rmst + 1.96 * se
            lines.append(
                f"{trt:20s}: {rmst:7.2f} (SE: {se:.2f}, "
                f"95% CI: [{ci_lower:.2f}, {ci_upper:.2f}])"
            )

        lines.extend([
            "",
            "PAIRWISE RMST DIFFERENCES (vs reference):",
            "-" * 70
        ])

        for diff in self.rmst_differences:
            sig = "*" if diff.significant else " "
            lines.append(
                f"{sig} {diff.treatment:20s}: {diff.difference:+7.2f} time units "
                f"(SE: {diff.se:.2f}, 95% CI: [{diff.lower_95ci:+.2f}, "
                f"{diff.upper_95ci:+.2f}]) p={diff.p_value:.4f}"
            )

        lines.extend([
            "",
            "TREATMENT RANKING (by RMST):",
            "-" * 70
        ])

        for trt, rank in self.treatment_ranking:
            lines.append(f"#{rank}: {trt}")

        if self.interpretation:
            lines.extend([
                "",
                "CLINICAL INTERPRETATION:",
                "-" * 70
            ])
            for interp in self.interpretation:
                lines.append(f"• {interp}")

        if self.warnings:
            lines.extend(["", "WARNINGS:", "-" * 70])
            for w in self.warnings:
                lines.append(f"⚠ {w}")

        lines.append("=" * 70)
        return "\n".join(lines)


class RMSTNetworkMetaAnalysis:
    """
    RMST-based Network Meta-Analysis

    Analyzes time-to-event outcomes using Restricted Mean Survival Time
    instead of hazard ratios.

    Parameters
    ----------
    studies : List[RMSTStudy]
        Studies with RMST estimates
    tau : float
        Restriction time (should be common across studies)
    """

    def __init__(self, studies: List[RMSTStudy], tau: float):
        self.studies = studies
        self.tau = tau

        self.treatments = list(set(s.treatment for s in studies))
        self.n_treatments = len(self.treatments)
        self.n_studies = len(set(s.study_id for s in studies))

        # Validate tau
        study_taus = set(s.tau for s in studies)
        if len(study_taus) > 1:
            logger.warning(
                f"Multiple tau values found: {study_taus}. "
                f"Using specified tau={tau}"
            )

        logger.info(
            f"RMST NMA initialized: {self.n_studies} studies, "
            f"{self.n_treatments} treatments, τ={tau}"
        )

        self.results: Optional[RMSTNMAResults] = None

    def analyze(self, reference_treatment: Optional[str] = None) -> RMSTNMAResults:
        """
        Run RMST-based network meta-analysis

        Parameters
        ----------
        reference_treatment : Optional[str]
            Reference treatment for comparisons

        Returns
        -------
        RMSTNMAResults
            Analysis results
        """
        logger.info("Running RMST-based NMA...")

        if reference_treatment is None:
            reference_treatment = self.treatments[0]

        # Calculate treatment-specific RMST estimates (pooled across studies)
        rmst_estimates = self._pool_rmst_estimates()

        # Calculate pairwise differences
        rmst_differences = self._calculate_differences(
            rmst_estimates,
            reference_treatment
        )

        # Rank treatments
        ranking = self._rank_treatments(rmst_estimates)

        # Generate interpretation
        interpretation = self._generate_interpretation(
            rmst_differences,
            reference_treatment
        )

        warnings = []
        if self.n_studies < 3:
            warnings.append("Small network (< 3 studies) - results may be imprecise")

        self.results = RMSTNMAResults(
            tau=self.tau,
            reference_treatment=reference_treatment,
            rmst_estimates=rmst_estimates,
            rmst_differences=rmst_differences,
            treatment_ranking=ranking,
            method="frequentist",
            n_studies=self.n_studies,
            n_treatments=self.n_treatments,
            interpretation=interpretation,
            warnings=warnings
        )

        logger.info("RMST NMA complete")
        return self.results

    def _pool_rmst_estimates(self) -> Dict[str, Tuple[float, float]]:
        """Pool RMST estimates across studies for each treatment"""

        pooled = {}

        for treatment in self.treatments:
            # Get all studies with this treatment
            trt_studies = [s for s in self.studies if s.treatment == treatment]

            if not trt_studies:
                continue

            # Meta-analysis (inverse variance weighting)
            rmst_values = np.array([s.rmst for s in trt_studies])
            ses = np.array([s.rmst_se for s in trt_studies])

            weights = 1 / ses**2
            pooled_rmst = np.sum(weights * rmst_values) / np.sum(weights)
            pooled_se = np.sqrt(1 / np.sum(weights))

            pooled[treatment] = (float(pooled_rmst), float(pooled_se))

        return pooled

    def _calculate_differences(
        self,
        rmst_estimates: Dict[str, Tuple[float, float]],
        reference: str
    ) -> List[RMSTDifference]:
        """Calculate pairwise RMST differences vs reference"""

        if reference not in rmst_estimates:
            raise ValueError(f"Reference treatment '{reference}' not found")

        ref_rmst, ref_se = rmst_estimates[reference]

        differences = []

        for trt, (rmst, se) in rmst_estimates.items():
            if trt == reference:
                continue

            # Difference
            diff = rmst - ref_rmst
            diff_se = np.sqrt(se**2 + ref_se**2)

            # Confidence interval
            ci_lower = diff - 1.96 * diff_se
            ci_upper = diff + 1.96 * diff_se

            # p-value
            z = diff / diff_se if diff_se > 0 else 0
            p_value = 2 * stats.norm.sf(abs(z))

            differences.append(RMSTDifference(
                treatment=trt,
                comparison=reference,
                difference=float(diff),
                se=float(diff_se),
                lower_95ci=float(ci_lower),
                upper_95ci=float(ci_upper),
                p_value=float(p_value),
                significant=p_value < 0.05
            ))

        return sorted(differences, key=lambda x: x.difference, reverse=True)

    def _rank_treatments(
        self,
        rmst_estimates: Dict[str, Tuple[float, float]]
    ) -> List[Tuple[str, int]]:
        """Rank treatments by RMST (higher is better)"""

        sorted_trts = sorted(
            rmst_estimates.items(),
            key=lambda x: x[1][0],
            reverse=True
        )

        return [(trt, i+1) for i, (trt, _) in enumerate(sorted_trts)]

    def _generate_interpretation(
        self,
        differences: List[RMSTDifference],
        reference: str
    ) -> List[str]:
        """Generate clinical interpretation"""

        interp = [
            f"All comparisons are vs reference treatment: {reference}",
            f"RMST represents mean survival time up to τ={self.tau} time units"
        ]

        # Find best treatment
        if differences:
            best = max(differences, key=lambda x: x.difference)
            if best.significant:
                interp.append(
                    f"{best.treatment} provides {best.difference:.1f} additional "
                    f"time units vs {reference} (p={best.p_value:.4f})"
                )

        # Significant differences
        sig_diffs = [d for d in differences if d.significant]
        if sig_diffs:
            interp.append(
                f"{len(sig_diffs)} treatment(s) show significant difference "
                f"from {reference}"
            )

        return interp


def rmst_nma_quick_analysis(
    studies: List[RMSTStudy],
    tau: float,
    reference: Optional[str] = None
) -> RMSTNMAResults:
    """
    Quick RMST NMA analysis

    Parameters
    ----------
    studies : List[RMSTStudy]
        Studies with RMST data
    tau : float
        Restriction time
    reference : Optional[str]
        Reference treatment

    Returns
    -------
    RMSTNMAResults
        Analysis results
    """
    analysis = RMSTNetworkMetaAnalysis(studies=studies, tau=tau)
    return analysis.analyze(reference_treatment=reference)
