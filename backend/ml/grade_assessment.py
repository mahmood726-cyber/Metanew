"""
GRADE (Grading of Recommendations Assessment, Development and Evaluation) System
Automated quality of evidence assessment for systematic reviews

GRADE assesses quality of evidence based on:
- Study design (starting point: RCTs = High, Observational = Low)
- Risk of bias
- Inconsistency (heterogeneity)
- Indirectness
- Imprecision
- Publication bias

Can be upgraded for:
- Large effect size
- Dose-response gradient
- All plausible confounding would reduce effect

Final ratings: High, Moderate, Low, Very Low
"""
import logging
from typing import Dict, List, Any, Optional, Tuple
from enum import Enum
import numpy as np
import pandas as pd
from dataclasses import dataclass

logger = logging.getLogger(__name__)


class EvidenceQuality(Enum):
    """GRADE evidence quality levels"""
    HIGH = "High"
    MODERATE = "Moderate"
    LOW = "Low"
    VERY_LOW = "Very Low"


class StudyDesign(Enum):
    """Study design types"""
    RCT = "Randomized Controlled Trial"
    OBSERVATIONAL = "Observational Study"
    CASE_SERIES = "Case Series"
    EXPERT_OPINION = "Expert Opinion"


@dataclass
class GRADEDomain:
    """Single GRADE assessment domain"""
    name: str
    rating: str  # "No serious", "Serious", "Very serious"
    downgrade: int  # 0, -1, or -2
    rationale: str
    evidence: Dict[str, Any]


@dataclass
class GRADEAssessment:
    """Complete GRADE assessment"""
    outcome: str
    study_design: StudyDesign
    starting_quality: EvidenceQuality

    # Downgrading factors
    risk_of_bias: GRADEDomain
    inconsistency: GRADEDomain
    indirectness: GRADEDomain
    imprecision: GRADEDomain
    publication_bias: GRADEDomain

    # Upgrading factors
    large_effect: Optional[GRADEDomain] = None
    dose_response: Optional[GRADEDomain] = None
    plausible_confounding: Optional[GRADEDomain] = None

    # Final assessment
    final_quality: EvidenceQuality = None
    overall_downgrade: int = 0
    overall_upgrade: int = 0
    confidence: float = 0.0
    summary: str = ""


class GRADEAssessor:
    """
    Automated GRADE assessment for systematic reviews

    Implements GRADE methodology with automated evidence quality rating
    based on meta-analysis results and study characteristics.
    """

    def __init__(self):
        """Initialize GRADE assessor"""
        logger.info("✓ GRADE assessor initialized")

    def assess_outcome(
        self,
        outcome: str,
        meta_analysis_results: Dict[str, Any],
        study_data: pd.DataFrame,
        rob_assessments: Optional[List[Dict]] = None,
        study_design: StudyDesign = StudyDesign.RCT
    ) -> GRADEAssessment:
        """
        Perform complete GRADE assessment for an outcome

        Args:
            outcome: Outcome being assessed
            meta_analysis_results: Meta-analysis results (pooled effect, I², etc.)
            study_data: Study-level data
            rob_assessments: Risk of bias assessments (optional)
            study_design: Predominant study design

        Returns:
            Complete GRADE assessment
        """
        logger.info(f"Performing GRADE assessment for outcome: {outcome}")

        # Determine starting quality
        starting_quality = self._determine_starting_quality(study_design)

        # Assess each domain
        risk_of_bias = self._assess_risk_of_bias(study_data, rob_assessments)
        inconsistency = self._assess_inconsistency(meta_analysis_results)
        indirectness = self._assess_indirectness(study_data, outcome)
        imprecision = self._assess_imprecision(meta_analysis_results, study_data)
        publication_bias = self._assess_publication_bias(meta_analysis_results, study_data)

        # Calculate total downgrade
        total_downgrade = sum([
            risk_of_bias.downgrade,
            inconsistency.downgrade,
            indirectness.downgrade,
            imprecision.downgrade,
            publication_bias.downgrade
        ])

        # Check for upgrading factors (only for observational studies)
        large_effect = None
        dose_response = None
        plausible_confounding = None
        total_upgrade = 0

        if study_design == StudyDesign.OBSERVATIONAL:
            large_effect = self._assess_large_effect(meta_analysis_results)
            dose_response = self._assess_dose_response(study_data)
            plausible_confounding = self._assess_plausible_confounding(study_data)

            if large_effect:
                total_upgrade += large_effect.downgrade  # Actually upgrade (positive)
            if dose_response:
                total_upgrade += dose_response.downgrade
            if plausible_confounding:
                total_upgrade += plausible_confounding.downgrade

        # Calculate final quality
        final_quality = self._calculate_final_quality(
            starting_quality,
            total_downgrade,
            total_upgrade
        )

        # Generate summary
        summary = self._generate_summary(
            starting_quality,
            final_quality,
            risk_of_bias,
            inconsistency,
            indirectness,
            imprecision,
            publication_bias,
            large_effect,
            dose_response,
            plausible_confounding
        )

        # Calculate confidence (0-1 scale)
        confidence = self._calculate_confidence(
            final_quality,
            risk_of_bias,
            inconsistency,
            imprecision
        )

        assessment = GRADEAssessment(
            outcome=outcome,
            study_design=study_design,
            starting_quality=starting_quality,
            risk_of_bias=risk_of_bias,
            inconsistency=inconsistency,
            indirectness=indirectness,
            imprecision=imprecision,
            publication_bias=publication_bias,
            large_effect=large_effect,
            dose_response=dose_response,
            plausible_confounding=plausible_confounding,
            final_quality=final_quality,
            overall_downgrade=total_downgrade,
            overall_upgrade=total_upgrade,
            confidence=confidence,
            summary=summary
        )

        logger.info(f"GRADE assessment complete: {final_quality.value} quality evidence")

        return assessment

    def _determine_starting_quality(self, study_design: StudyDesign) -> EvidenceQuality:
        """Determine starting quality based on study design"""
        if study_design == StudyDesign.RCT:
            return EvidenceQuality.HIGH
        elif study_design == StudyDesign.OBSERVATIONAL:
            return EvidenceQuality.LOW
        else:
            return EvidenceQuality.VERY_LOW

    def _assess_risk_of_bias(
        self,
        study_data: pd.DataFrame,
        rob_assessments: Optional[List[Dict]]
    ) -> GRADEDomain:
        """Assess risk of bias domain"""

        if rob_assessments:
            # Use provided ROB assessments
            high_risk_count = sum(1 for rob in rob_assessments
                                 if rob.get('overall_judgment') == 'High')
            some_concerns_count = sum(1 for rob in rob_assessments
                                     if rob.get('overall_judgment') == 'Some concerns')

            high_risk_pct = high_risk_count / len(rob_assessments) if rob_assessments else 0
            some_concerns_pct = some_concerns_count / len(rob_assessments) if rob_assessments else 0

            if high_risk_pct > 0.25:  # >25% high risk
                rating = "Very serious"
                downgrade = -2
                rationale = f"{high_risk_pct*100:.0f}% of studies at high risk of bias"
            elif high_risk_pct > 0 or some_concerns_pct > 0.5:  # Any high risk or >50% some concerns
                rating = "Serious"
                downgrade = -1
                rationale = f"{high_risk_pct*100:.0f}% high risk, {some_concerns_pct*100:.0f}% some concerns"
            else:
                rating = "No serious"
                downgrade = 0
                rationale = "Low risk of bias across studies"

            evidence = {
                "high_risk_count": high_risk_count,
                "some_concerns_count": some_concerns_count,
                "low_risk_count": len(rob_assessments) - high_risk_count - some_concerns_count,
                "high_risk_pct": high_risk_pct,
                "some_concerns_pct": some_concerns_pct
            }
        else:
            # Heuristic assessment based on study characteristics
            rating = "Serious"
            downgrade = -1
            rationale = "Risk of bias not formally assessed"
            evidence = {"method": "heuristic"}

        return GRADEDomain(
            name="Risk of Bias",
            rating=rating,
            downgrade=downgrade,
            rationale=rationale,
            evidence=evidence
        )

    def _assess_inconsistency(self, meta_analysis_results: Dict[str, Any]) -> GRADEDomain:
        """Assess inconsistency (heterogeneity) domain"""

        i_squared = meta_analysis_results.get('i_squared', 0)
        p_heterogeneity = meta_analysis_results.get('p_heterogeneity', 1.0)

        # GRADE criteria for inconsistency
        if i_squared > 75 and p_heterogeneity < 0.05:
            rating = "Very serious"
            downgrade = -2
            rationale = f"Substantial unexplained heterogeneity (I²={i_squared:.1f}%, p={p_heterogeneity:.3f})"
        elif i_squared > 50 and p_heterogeneity < 0.10:
            rating = "Serious"
            downgrade = -1
            rationale = f"Moderate heterogeneity (I²={i_squared:.1f}%, p={p_heterogeneity:.3f})"
        else:
            rating = "No serious"
            downgrade = 0
            rationale = f"Low heterogeneity (I²={i_squared:.1f}%)"

        evidence = {
            "i_squared": i_squared,
            "p_heterogeneity": p_heterogeneity
        }

        return GRADEDomain(
            name="Inconsistency",
            rating=rating,
            downgrade=downgrade,
            rationale=rationale,
            evidence=evidence
        )

    def _assess_indirectness(self, study_data: pd.DataFrame, outcome: str) -> GRADEDomain:
        """Assess indirectness domain"""

        # Check for surrogate outcomes, indirect comparisons, etc.
        # This is typically a manual judgment, but we can provide heuristics

        # For now, assume no serious indirectness if primary outcome
        # In practice, this would require more domain knowledge

        rating = "No serious"
        downgrade = 0
        rationale = "Direct evidence for the outcome of interest"

        evidence = {
            "outcome": outcome,
            "n_studies": len(study_data)
        }

        return GRADEDomain(
            name="Indirectness",
            rating=rating,
            downgrade=downgrade,
            rationale=rationale,
            evidence=evidence
        )

    def _assess_imprecision(
        self,
        meta_analysis_results: Dict[str, Any],
        study_data: pd.DataFrame
    ) -> GRADEDomain:
        """Assess imprecision domain"""

        # Check confidence interval width and sample size
        ci_lower = meta_analysis_results.get('ci_lower')
        ci_upper = meta_analysis_results.get('ci_upper')
        pooled_effect = meta_analysis_results.get('pooled_effect')

        # Total sample size
        total_n = study_data['n_treatment'].sum() + study_data['n_control'].sum() if 'n_treatment' in study_data.columns else 0

        # Assess CI width
        if ci_lower is not None and ci_upper is not None:
            ci_width = ci_upper - ci_lower

            # Wide CI or crosses null
            crosses_null = (ci_lower < 0 < ci_upper) or (ci_lower < 1 < ci_upper)

            if ci_width > 2.0 or (crosses_null and total_n < 400):
                rating = "Very serious"
                downgrade = -2
                rationale = f"Very wide confidence interval ({ci_lower:.2f} to {ci_upper:.2f}), small sample size (n={total_n})"
            elif ci_width > 1.0 or (crosses_null and total_n < 1000):
                rating = "Serious"
                downgrade = -1
                rationale = f"Wide confidence interval ({ci_lower:.2f} to {ci_upper:.2f})"
            else:
                rating = "No serious"
                downgrade = 0
                rationale = f"Adequate precision (95% CI: {ci_lower:.2f} to {ci_upper:.2f}, n={total_n})"
        else:
            rating = "Serious"
            downgrade = -1
            rationale = "Confidence interval not available"

        evidence = {
            "ci_lower": ci_lower,
            "ci_upper": ci_upper,
            "ci_width": ci_upper - ci_lower if ci_lower and ci_upper else None,
            "total_n": total_n
        }

        return GRADEDomain(
            name="Imprecision",
            rating=rating,
            downgrade=downgrade,
            rationale=rationale,
            evidence=evidence
        )

    def _assess_publication_bias(
        self,
        meta_analysis_results: Dict[str, Any],
        study_data: pd.DataFrame
    ) -> GRADEDomain:
        """Assess publication bias domain"""

        n_studies = len(study_data)

        # If we have publication bias detection results
        pub_bias = meta_analysis_results.get('publication_bias_detected', False)

        if n_studies < 10:
            rating = "Undetected"
            downgrade = 0
            rationale = f"Too few studies (n={n_studies}) to assess publication bias"
        elif pub_bias:
            rating = "Serious"
            downgrade = -1
            rationale = "Strong evidence of publication bias detected"
        else:
            rating = "No serious"
            downgrade = 0
            rationale = "No strong evidence of publication bias"

        evidence = {
            "n_studies": n_studies,
            "publication_bias_detected": pub_bias
        }

        return GRADEDomain(
            name="Publication Bias",
            rating=rating,
            downgrade=downgrade,
            rationale=rationale,
            evidence=evidence
        )

    def _assess_large_effect(self, meta_analysis_results: Dict[str, Any]) -> Optional[GRADEDomain]:
        """Assess large effect upgrade (observational studies only)"""

        pooled_effect = abs(meta_analysis_results.get('pooled_effect', 0))
        ci_lower = meta_analysis_results.get('ci_lower')
        ci_upper = meta_analysis_results.get('ci_upper')

        # For odds ratios/risk ratios
        if pooled_effect > 5:  # Very large effect (RR/OR > 5)
            rating = "Very large"
            upgrade = 2
            rationale = f"Very large effect (RR/OR = {pooled_effect:.2f})"
        elif pooled_effect > 2:  # Large effect (RR/OR > 2)
            rating = "Large"
            upgrade = 1
            rationale = f"Large effect (RR/OR = {pooled_effect:.2f})"
        else:
            return None  # No upgrade

        return GRADEDomain(
            name="Large Effect",
            rating=rating,
            downgrade=upgrade,  # Actually upgrade (positive)
            rationale=rationale,
            evidence={"pooled_effect": pooled_effect}
        )

    def _assess_dose_response(self, study_data: pd.DataFrame) -> Optional[GRADEDomain]:
        """Assess dose-response gradient (observational studies only)"""

        # Check if dose-response data available
        # This is typically a manual judgment based on study reports
        # For now, return None (no upgrade)

        return None

    def _assess_plausible_confounding(self, study_data: pd.DataFrame) -> Optional[GRADEDomain]:
        """Assess plausible confounding (observational studies only)"""

        # Check if all plausible confounding would reduce the effect
        # This is a manual judgment based on study design
        # For now, return None (no upgrade)

        return None

    def _calculate_final_quality(
        self,
        starting_quality: EvidenceQuality,
        downgrade: int,
        upgrade: int
    ) -> EvidenceQuality:
        """Calculate final GRADE quality rating"""

        # Map to numeric scale
        quality_map = {
            EvidenceQuality.HIGH: 4,
            EvidenceQuality.MODERATE: 3,
            EvidenceQuality.LOW: 2,
            EvidenceQuality.VERY_LOW: 1
        }

        reverse_map = {v: k for k, v in quality_map.items()}

        starting_level = quality_map[starting_quality]
        final_level = max(1, min(4, starting_level + downgrade + upgrade))

        return reverse_map[final_level]

    def _calculate_confidence(
        self,
        final_quality: EvidenceQuality,
        risk_of_bias: GRADEDomain,
        inconsistency: GRADEDomain,
        imprecision: GRADEDomain
    ) -> float:
        """Calculate confidence score (0-1)"""

        # Base confidence from quality level
        quality_confidence = {
            EvidenceQuality.HIGH: 0.95,
            EvidenceQuality.MODERATE: 0.75,
            EvidenceQuality.LOW: 0.50,
            EvidenceQuality.VERY_LOW: 0.25
        }

        base = quality_confidence[final_quality]

        # Adjust based on specific concerns
        adjustments = 0
        if risk_of_bias.rating == "Very serious":
            adjustments -= 0.15
        elif risk_of_bias.rating == "Serious":
            adjustments -= 0.10

        if inconsistency.rating == "Very serious":
            adjustments -= 0.10
        elif inconsistency.rating == "Serious":
            adjustments -= 0.05

        if imprecision.rating == "Very serious":
            adjustments -= 0.10
        elif imprecision.rating == "Serious":
            adjustments -= 0.05

        return max(0.1, min(1.0, base + adjustments))

    def _generate_summary(
        self,
        starting_quality: EvidenceQuality,
        final_quality: EvidenceQuality,
        risk_of_bias: GRADEDomain,
        inconsistency: GRADEDomain,
        indirectness: GRADEDomain,
        imprecision: GRADEDomain,
        publication_bias: GRADEDomain,
        large_effect: Optional[GRADEDomain],
        dose_response: Optional[GRADEDomain],
        plausible_confounding: Optional[GRADEDomain]
    ) -> str:
        """Generate summary text"""

        summary_parts = [
            f"GRADE Assessment: {final_quality.value} quality evidence",
            f"(started as {starting_quality.value} based on study design)"
        ]

        # Downgrading factors
        downgrades = []
        if risk_of_bias.downgrade < 0:
            downgrades.append(f"Risk of bias ({risk_of_bias.rating.lower()})")
        if inconsistency.downgrade < 0:
            downgrades.append(f"Inconsistency ({inconsistency.rating.lower()})")
        if indirectness.downgrade < 0:
            downgrades.append(f"Indirectness ({indirectness.rating.lower()})")
        if imprecision.downgrade < 0:
            downgrades.append(f"Imprecision ({imprecision.rating.lower()})")
        if publication_bias.downgrade < 0:
            downgrades.append(f"Publication bias ({publication_bias.rating.lower()})")

        if downgrades:
            summary_parts.append(f"Downgraded for: {', '.join(downgrades)}")

        # Upgrading factors
        upgrades = []
        if large_effect and large_effect.downgrade > 0:
            upgrades.append(f"Large effect ({large_effect.rating.lower()})")
        if dose_response and dose_response.downgrade > 0:
            upgrades.append("Dose-response gradient")
        if plausible_confounding and plausible_confounding.downgrade > 0:
            upgrades.append("Plausible confounding")

        if upgrades:
            summary_parts.append(f"Upgraded for: {', '.join(upgrades)}")

        return ". ".join(summary_parts) + "."

    def to_dict(self, assessment: GRADEAssessment) -> Dict[str, Any]:
        """Convert GRADE assessment to dictionary"""

        result = {
            "outcome": assessment.outcome,
            "study_design": assessment.study_design.value,
            "starting_quality": assessment.starting_quality.value,
            "final_quality": assessment.final_quality.value,
            "confidence": assessment.confidence,
            "overall_downgrade": assessment.overall_downgrade,
            "overall_upgrade": assessment.overall_upgrade,
            "summary": assessment.summary,
            "domains": {
                "risk_of_bias": {
                    "rating": assessment.risk_of_bias.rating,
                    "downgrade": assessment.risk_of_bias.downgrade,
                    "rationale": assessment.risk_of_bias.rationale,
                    "evidence": assessment.risk_of_bias.evidence
                },
                "inconsistency": {
                    "rating": assessment.inconsistency.rating,
                    "downgrade": assessment.inconsistency.downgrade,
                    "rationale": assessment.inconsistency.rationale,
                    "evidence": assessment.inconsistency.evidence
                },
                "indirectness": {
                    "rating": assessment.indirectness.rating,
                    "downgrade": assessment.indirectness.downgrade,
                    "rationale": assessment.indirectness.rationale,
                    "evidence": assessment.indirectness.evidence
                },
                "imprecision": {
                    "rating": assessment.imprecision.rating,
                    "downgrade": assessment.imprecision.downgrade,
                    "rationale": assessment.imprecision.rationale,
                    "evidence": assessment.imprecision.evidence
                },
                "publication_bias": {
                    "rating": assessment.publication_bias.rating,
                    "downgrade": assessment.publication_bias.downgrade,
                    "rationale": assessment.publication_bias.rationale,
                    "evidence": assessment.publication_bias.evidence
                }
            }
        }

        # Add upgrading factors if present
        if assessment.large_effect:
            result["domains"]["large_effect"] = {
                "rating": assessment.large_effect.rating,
                "upgrade": assessment.large_effect.downgrade,
                "rationale": assessment.large_effect.rationale,
                "evidence": assessment.large_effect.evidence
            }

        return result


# Example usage
if __name__ == "__main__":
    assessor = GRADEAssessor()

    # Example meta-analysis results
    meta_results = {
        "pooled_effect": 0.75,
        "ci_lower": 0.60,
        "ci_upper": 0.95,
        "i_squared": 45.2,
        "p_heterogeneity": 0.12,
        "p_value": 0.003,
        "publication_bias_detected": False
    }

    # Example study data
    study_data = pd.DataFrame({
        "study_id": ["Study1", "Study2", "Study3"],
        "year": [2020, 2021, 2022],
        "n_treatment": [100, 150, 120],
        "n_control": [100, 150, 120]
    })

    # Perform GRADE assessment
    assessment = assessor.assess_outcome(
        outcome="Mortality",
        meta_analysis_results=meta_results,
        study_data=study_data,
        study_design=StudyDesign.RCT
    )

    print(assessor.to_dict(assessment))
