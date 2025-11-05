"""
GRADE Assessment Module

Grading of Recommendations Assessment, Development and Evaluation (GRADE) framework
for assessing certainty of evidence in systematic reviews and HTA submissions.

The GRADE approach evaluates 5 domains:
1. Risk of Bias - Study limitations that reduce confidence
2. Inconsistency - Unexplained heterogeneity across studies
3. Indirectness - Differences in PICO elements vs research question
4. Imprecision - Wide confidence intervals or small sample sizes
5. Publication Bias - Selective reporting of favorable results

Starting Rating:
- RCTs: High certainty
- Observational: Low certainty

Downgrading Factors (each domain can downgrade -1 or -2 levels):
- Serious limitation: -1 level
- Very serious limitation: -2 levels

Upgrading Factors (for observational studies only):
- Large effect: +1 or +2
- Dose-response gradient: +1
- All plausible confounding would reduce effect: +1

Final Certainty Levels:
- High: Very confident that true effect is close to estimate
- Moderate: Moderately confident; true effect likely close but may be substantially different
- Low: Limited confidence; true effect may be substantially different
- Very Low: Very little confidence; true effect likely substantially different

Author: EvidenceOS PRIME
License: MIT
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass, field
from enum import Enum


class CertaintyLevel(Enum):
    """GRADE certainty levels"""
    HIGH = 4
    MODERATE = 3
    LOW = 2
    VERY_LOW = 1


class DowngradeLevel(Enum):
    """Downgrade severity"""
    NONE = 0
    SERIOUS = -1
    VERY_SERIOUS = -2


class UpgradeLevel(Enum):
    """Upgrade factors (observational only)"""
    NONE = 0
    PRESENT = 1
    STRONG = 2


@dataclass
class RiskOfBiasAssessment:
    """Risk of bias assessment"""
    domain: str
    judgment: str  # "Low", "Some concerns", "High"
    justification: str
    studies_affected: List[str] = field(default_factory=list)


@dataclass
class GRADEDomainAssessment:
    """Assessment for a single GRADE domain"""
    domain: str
    downgrade: DowngradeLevel
    rationale: str
    supporting_evidence: Dict[str, Any] = field(default_factory=dict)


@dataclass
class GRADEResult:
    """Complete GRADE assessment result"""
    outcome: str
    starting_certainty: CertaintyLevel
    final_certainty: CertaintyLevel

    # Domain assessments
    risk_of_bias: GRADEDomainAssessment
    inconsistency: GRADEDomainAssessment
    indirectness: GRADEDomainAssessment
    imprecision: GRADEDomainAssessment
    publication_bias: GRADEDomainAssessment

    # Upgrade factors (observational only)
    large_effect: UpgradeLevel = UpgradeLevel.NONE
    dose_response: UpgradeLevel = UpgradeLevel.NONE
    confounding: UpgradeLevel = UpgradeLevel.NONE

    # Summary
    net_adjustment: int = 0
    confidence_statement: str = ""

    # Evidence profile data
    n_studies: int = 0
    n_participants: int = 0
    effect_estimate: Optional[float] = None
    ci_lower: Optional[float] = None
    ci_upper: Optional[float] = None


class GRADEAssessor:
    """
    GRADE Assessment Engine

    Automates GRADE certainty assessment based on meta-analysis results
    and study characteristics.

    Examples:
        >>> assessor = GRADEAssessor()
        >>>
        >>> # Prepare meta-analysis results
        >>> ma_result = {
        ...     'effect': 0.75,
        ...     'ci_lower': 0.60,
        ...     'ci_upper': 0.93,
        ...     'i_squared': 45.0,
        ...     'tau_squared': 0.05,
        ...     'n_studies': 8,
        ...     'n_total': 2400
        ... }
        >>>
        >>> # Assess certainty
        >>> result = assessor.assess(
        ...     outcome="Mortality",
        ...     study_design="RCT",
        ...     ma_result=ma_result,
        ...     rob_assessments=rob_data
        ... )
        >>>
        >>> print(f"Final certainty: {result.final_certainty.name}")
    """

    def __init__(self):
        self.thresholds = self._set_default_thresholds()

    def _set_default_thresholds(self) -> Dict[str, float]:
        """Set default thresholds for automated assessment"""
        return {
            # Risk of bias thresholds
            'rob_serious_pct': 0.25,      # >25% high RoB = serious
            'rob_very_serious_pct': 0.50, # >50% high RoB = very serious

            # Inconsistency thresholds
            'i_squared_serious': 50.0,      # I² > 50% = serious
            'i_squared_very_serious': 75.0, # I² > 75% = very serious
            'ci_overlap_threshold': 0.5,    # Poor overlap = serious

            # Imprecision thresholds
            'optimal_information_size': 400, # OIS for binary outcomes
            'ci_width_ratio': 1.5,           # CI crosses appreciable benefit/harm

            # Publication bias thresholds
            'egger_p_value': 0.10,          # Egger's test p < 0.10
            'min_studies_for_pb': 10,       # Need ≥10 studies for funnel plot

            # Large effect thresholds (for upgrading)
            'large_effect_rr': 2.0,         # RR > 2 or < 0.5
            'very_large_effect_rr': 5.0     # RR > 5 or < 0.2
        }

    def assess(
        self,
        outcome: str,
        study_design: str,  # "RCT" or "observational"
        ma_result: Dict[str, Any],
        rob_assessments: Optional[List[RiskOfBiasAssessment]] = None,
        indirectness_concerns: Optional[str] = None,
        publication_bias_tests: Optional[Dict[str, float]] = None
    ) -> GRADEResult:
        """
        Perform complete GRADE assessment

        Args:
            outcome: Outcome name
            study_design: "RCT" or "observational"
            ma_result: Meta-analysis results dict with keys:
                - effect: pooled effect estimate
                - ci_lower, ci_upper: confidence interval
                - i_squared: heterogeneity statistic
                - tau_squared: between-study variance
                - n_studies: number of studies
                - n_total: total participants
            rob_assessments: List of RoB assessments per study
            indirectness_concerns: Text description of indirectness issues
            publication_bias_tests: Dict with 'egger_p', 'begg_p', etc.

        Returns:
            GRADEResult with complete assessment
        """

        # Step 1: Determine starting certainty
        if study_design.upper() == "RCT":
            starting_certainty = CertaintyLevel.HIGH
        else:
            starting_certainty = CertaintyLevel.LOW

        # Step 2: Assess each domain
        rob = self._assess_risk_of_bias(rob_assessments)
        inconsistency = self._assess_inconsistency(ma_result)
        indirectness = self._assess_indirectness(indirectness_concerns)
        imprecision = self._assess_imprecision(ma_result)
        pub_bias = self._assess_publication_bias(ma_result, publication_bias_tests)

        # Step 3: Calculate net adjustment
        net_adjustment = (
            rob.downgrade.value +
            inconsistency.downgrade.value +
            indirectness.downgrade.value +
            imprecision.downgrade.value +
            pub_bias.downgrade.value
        )

        # Step 4: Apply upgrades (observational only)
        large_effect = UpgradeLevel.NONE
        dose_response = UpgradeLevel.NONE
        confounding = UpgradeLevel.NONE

        if study_design.lower() == "observational":
            large_effect = self._assess_large_effect(ma_result)
            net_adjustment += large_effect.value
            # Note: dose_response and confounding require additional data
            # that would need to be passed as parameters

        # Step 5: Calculate final certainty
        final_certainty_value = max(
            1,  # Minimum: VERY_LOW
            min(4, starting_certainty.value + net_adjustment)  # Maximum: HIGH
        )
        final_certainty = CertaintyLevel(final_certainty_value)

        # Step 6: Generate confidence statement
        confidence_statement = self._generate_confidence_statement(
            final_certainty, outcome
        )

        return GRADEResult(
            outcome=outcome,
            starting_certainty=starting_certainty,
            final_certainty=final_certainty,
            risk_of_bias=rob,
            inconsistency=inconsistency,
            indirectness=indirectness,
            imprecision=imprecision,
            publication_bias=pub_bias,
            large_effect=large_effect,
            dose_response=dose_response,
            confounding=confounding,
            net_adjustment=net_adjustment,
            confidence_statement=confidence_statement,
            n_studies=ma_result.get('n_studies', 0),
            n_participants=ma_result.get('n_total', 0),
            effect_estimate=ma_result.get('effect'),
            ci_lower=ma_result.get('ci_lower'),
            ci_upper=ma_result.get('ci_upper')
        )

    def _assess_risk_of_bias(
        self, rob_assessments: Optional[List[RiskOfBiasAssessment]]
    ) -> GRADEDomainAssessment:
        """Assess risk of bias domain"""

        if not rob_assessments:
            return GRADEDomainAssessment(
                domain="Risk of Bias",
                downgrade=DowngradeLevel.NONE,
                rationale="No risk of bias assessment provided",
                supporting_evidence={}
            )

        # Count high risk studies
        high_risk_count = sum(
            1 for rob in rob_assessments
            if rob.judgment.lower() in ["high", "high risk"]
        )

        total_studies = len(rob_assessments)
        high_risk_pct = high_risk_count / total_studies if total_studies > 0 else 0

        # Determine downgrade level
        if high_risk_pct > self.thresholds['rob_very_serious_pct']:
            downgrade = DowngradeLevel.VERY_SERIOUS
            rationale = f"Very serious risk of bias: {high_risk_pct:.0%} of studies at high risk"
        elif high_risk_pct > self.thresholds['rob_serious_pct']:
            downgrade = DowngradeLevel.SERIOUS
            rationale = f"Serious risk of bias: {high_risk_pct:.0%} of studies at high risk"
        else:
            downgrade = DowngradeLevel.NONE
            rationale = f"No serious risk of bias concerns: {high_risk_pct:.0%} of studies at high risk"

        return GRADEDomainAssessment(
            domain="Risk of Bias",
            downgrade=downgrade,
            rationale=rationale,
            supporting_evidence={
                'high_risk_count': high_risk_count,
                'total_studies': total_studies,
                'high_risk_pct': high_risk_pct
            }
        )

    def _assess_inconsistency(
        self, ma_result: Dict[str, Any]
    ) -> GRADEDomainAssessment:
        """Assess inconsistency domain based on heterogeneity"""

        i_squared = ma_result.get('i_squared', 0)
        tau_squared = ma_result.get('tau_squared', 0)

        # Determine downgrade based on I²
        if i_squared > self.thresholds['i_squared_very_serious']:
            downgrade = DowngradeLevel.VERY_SERIOUS
            rationale = f"Very serious inconsistency: I² = {i_squared:.1f}% (substantial heterogeneity)"
        elif i_squared > self.thresholds['i_squared_serious']:
            downgrade = DowngradeLevel.SERIOUS
            rationale = f"Serious inconsistency: I² = {i_squared:.1f}% (moderate heterogeneity)"
        else:
            downgrade = DowngradeLevel.NONE
            rationale = f"No serious inconsistency: I² = {i_squared:.1f}% (low heterogeneity)"

        return GRADEDomainAssessment(
            domain="Inconsistency",
            downgrade=downgrade,
            rationale=rationale,
            supporting_evidence={
                'i_squared': i_squared,
                'tau_squared': tau_squared
            }
        )

    def _assess_indirectness(
        self, indirectness_concerns: Optional[str]
    ) -> GRADEDomainAssessment:
        """Assess indirectness domain"""

        if not indirectness_concerns or indirectness_concerns.strip() == "":
            return GRADEDomainAssessment(
                domain="Indirectness",
                downgrade=DowngradeLevel.NONE,
                rationale="No indirectness concerns identified",
                supporting_evidence={}
            )

        # If concerns provided, assume serious indirectness
        # (In practice, this requires clinical judgment)
        return GRADEDomainAssessment(
            domain="Indirectness",
            downgrade=DowngradeLevel.SERIOUS,
            rationale=f"Serious indirectness: {indirectness_concerns}",
            supporting_evidence={'concerns': indirectness_concerns}
        )

    def _assess_imprecision(
        self, ma_result: Dict[str, Any]
    ) -> GRADEDomainAssessment:
        """Assess imprecision domain"""

        n_total = ma_result.get('n_total', 0)
        ci_lower = ma_result.get('ci_lower')
        ci_upper = ma_result.get('ci_upper')
        effect = ma_result.get('effect')

        concerns = []
        downgrade = DowngradeLevel.NONE

        # Check sample size (Optimal Information Size)
        if n_total < self.thresholds['optimal_information_size']:
            concerns.append(f"Small sample size (n={n_total} < OIS={self.thresholds['optimal_information_size']})")
            downgrade = DowngradeLevel.SERIOUS

        # Check confidence interval width
        if ci_lower is not None and ci_upper is not None and effect is not None:
            ci_width = ci_upper - ci_lower
            effect_magnitude = abs(effect)

            if effect_magnitude > 0:
                ci_width_ratio = ci_width / effect_magnitude

                if ci_width_ratio > self.thresholds['ci_width_ratio']:
                    concerns.append(f"Wide confidence interval (ratio={ci_width_ratio:.2f})")
                    if downgrade == DowngradeLevel.SERIOUS:
                        downgrade = DowngradeLevel.VERY_SERIOUS
                    else:
                        downgrade = DowngradeLevel.SERIOUS

        if concerns:
            rationale = f"Imprecision concerns: {'; '.join(concerns)}"
        else:
            rationale = "No serious imprecision concerns"

        return GRADEDomainAssessment(
            domain="Imprecision",
            downgrade=downgrade,
            rationale=rationale,
            supporting_evidence={
                'n_total': n_total,
                'ci_lower': ci_lower,
                'ci_upper': ci_upper
            }
        )

    def _assess_publication_bias(
        self,
        ma_result: Dict[str, Any],
        publication_bias_tests: Optional[Dict[str, float]]
    ) -> GRADEDomainAssessment:
        """Assess publication bias domain"""

        n_studies = ma_result.get('n_studies', 0)

        # Need at least 10 studies for meaningful assessment
        if n_studies < self.thresholds['min_studies_for_pb']:
            return GRADEDomainAssessment(
                domain="Publication Bias",
                downgrade=DowngradeLevel.NONE,
                rationale=f"Too few studies (n={n_studies}) to assess publication bias",
                supporting_evidence={'n_studies': n_studies}
            )

        # Check test results if provided
        if publication_bias_tests:
            egger_p = publication_bias_tests.get('egger_p')

            if egger_p is not None and egger_p < self.thresholds['egger_p_value']:
                return GRADEDomainAssessment(
                    domain="Publication Bias",
                    downgrade=DowngradeLevel.SERIOUS,
                    rationale=f"Serious publication bias: Egger's test p={egger_p:.3f}",
                    supporting_evidence=publication_bias_tests
                )

        return GRADEDomainAssessment(
            domain="Publication Bias",
            downgrade=DowngradeLevel.NONE,
            rationale="No strong evidence of publication bias",
            supporting_evidence=publication_bias_tests or {}
        )

    def _assess_large_effect(
        self, ma_result: Dict[str, Any]
    ) -> UpgradeLevel:
        """Assess large effect upgrade (observational only)"""

        effect = ma_result.get('effect')

        if effect is None:
            return UpgradeLevel.NONE

        # Check for large effect (RR > 2 or < 0.5)
        if effect > self.thresholds['very_large_effect_rr'] or effect < (1 / self.thresholds['very_large_effect_rr']):
            return UpgradeLevel.STRONG  # +2 levels
        elif effect > self.thresholds['large_effect_rr'] or effect < (1 / self.thresholds['large_effect_rr']):
            return UpgradeLevel.PRESENT  # +1 level
        else:
            return UpgradeLevel.NONE

    def _generate_confidence_statement(
        self, certainty: CertaintyLevel, outcome: str
    ) -> str:
        """Generate confidence statement for evidence profile"""

        statements = {
            CertaintyLevel.HIGH: (
                f"We are very confident that the true effect on {outcome} "
                "lies close to the estimate of effect."
            ),
            CertaintyLevel.MODERATE: (
                f"We are moderately confident in the effect on {outcome}: "
                "the true effect is likely close to the estimate, but may be substantially different."
            ),
            CertaintyLevel.LOW: (
                f"Our confidence in the effect on {outcome} is limited: "
                "the true effect may be substantially different from the estimate."
            ),
            CertaintyLevel.VERY_LOW: (
                f"We have very little confidence in the effect on {outcome}: "
                "the true effect is likely substantially different from the estimate."
            )
        }

        return statements[certainty]

    def generate_evidence_profile(
        self, results: List[GRADEResult]
    ) -> pd.DataFrame:
        """
        Generate GRADE evidence profile table

        Args:
            results: List of GRADEResult objects for multiple outcomes

        Returns:
            DataFrame with evidence profile
        """

        rows = []

        for result in results:
            row = {
                'Outcome': result.outcome,
                'Studies (n)': result.n_studies,
                'Participants (n)': result.n_participants,
                'Effect Estimate': f"{result.effect_estimate:.2f}" if result.effect_estimate else "N/A",
                '95% CI': f"({result.ci_lower:.2f}, {result.ci_upper:.2f})" if result.ci_lower and result.ci_upper else "N/A",
                'Risk of Bias': self._format_assessment(result.risk_of_bias),
                'Inconsistency': self._format_assessment(result.inconsistency),
                'Indirectness': self._format_assessment(result.indirectness),
                'Imprecision': self._format_assessment(result.imprecision),
                'Publication Bias': self._format_assessment(result.publication_bias),
                'Certainty': result.final_certainty.name.replace('_', ' ').title()
            }
            rows.append(row)

        return pd.DataFrame(rows)

    def _format_assessment(self, assessment: GRADEDomainAssessment) -> str:
        """Format domain assessment for display"""
        if assessment.downgrade == DowngradeLevel.NONE:
            return "No serious concerns"
        elif assessment.downgrade == DowngradeLevel.SERIOUS:
            return "Serious concerns (-1)"
        else:
            return "Very serious concerns (-2)"


# Example usage
if __name__ == "__main__":
    # Sample meta-analysis result
    ma_result = {
        'effect': 0.75,
        'ci_lower': 0.60,
        'ci_upper': 0.93,
        'i_squared': 45.0,
        'tau_squared': 0.05,
        'n_studies': 8,
        'n_total': 2400
    }

    # Sample risk of bias assessments
    rob_assessments = [
        RiskOfBiasAssessment(
            domain="Overall",
            judgment="Low",
            justification="Adequate randomization and blinding",
            studies_affected=["Study1", "Study2"]
        ),
        RiskOfBiasAssessment(
            domain="Overall",
            judgment="Some concerns",
            justification="Unclear allocation concealment",
            studies_affected=["Study3"]
        )
    ]

    # Create assessor and evaluate
    assessor = GRADEAssessor()
    result = assessor.assess(
        outcome="All-cause mortality",
        study_design="RCT",
        ma_result=ma_result,
        rob_assessments=rob_assessments,
        publication_bias_tests={'egger_p': 0.25}
    )

    print("\n=== GRADE ASSESSMENT RESULTS ===")
    print(f"\nOutcome: {result.outcome}")
    print(f"Starting certainty: {result.starting_certainty.name}")
    print(f"Final certainty: {result.final_certainty.name}")
    print(f"\nNet adjustment: {result.net_adjustment}")
    print(f"\n{result.confidence_statement}")

    print("\n=== DOMAIN ASSESSMENTS ===")
    for domain in [result.risk_of_bias, result.inconsistency, result.indirectness,
                   result.imprecision, result.publication_bias]:
        print(f"\n{domain.domain}: {domain.downgrade.name}")
        print(f"  {domain.rationale}")

    # Generate evidence profile
    evidence_profile = assessor.generate_evidence_profile([result])
    print("\n=== EVIDENCE PROFILE ===")
    print(evidence_profile.to_string(index=False))
