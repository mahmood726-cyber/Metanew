"""
Advanced Rules-Based Decision Support Engine
Intelligent recommendations for analysis strategies, sensitivity analyses,
and quality assessment based on comprehensive rule sets
"""
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class RecommendationPriority(Enum):
    """Priority levels for recommendations"""
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INFO = "info"


@dataclass
class Recommendation:
    """A single recommendation with rationale"""
    title: str
    description: str
    rationale: str
    priority: RecommendationPriority
    action_items: List[str]
    estimated_impact: str  # "High", "Medium", "Low"
    category: str  # "sensitivity", "quality", "analysis_choice", etc.


class AnalysisRecommender:
    """
    Recommend optimal analysis strategies based on data characteristics
    """

    def analyze_data_and_recommend(self, studies_df: pd.DataFrame,
                                    outcome_type: str = "binary") -> List[Recommendation]:
        """
        Analyze study data and provide comprehensive recommendations

        Args:
            studies_df: DataFrame with study data
            outcome_type: "binary", "continuous", or "time_to_event"

        Returns:
            List of recommendations sorted by priority
        """
        recommendations = []

        # Data quality checks
        recommendations.extend(self._check_data_quality(studies_df))

        # Sample size recommendations
        recommendations.extend(self._check_sample_sizes(studies_df))

        # Heterogeneity considerations
        recommendations.extend(self._check_heterogeneity_factors(studies_df))

        # Publication bias recommendations
        recommendations.extend(self._check_publication_bias_risk(studies_df))

        # Analysis method recommendations
        recommendations.extend(self._recommend_analysis_methods(studies_df, outcome_type))

        # Sensitivity analysis recommendations
        recommendations.extend(self._recommend_sensitivity_analyses(studies_df))

        # Sort by priority
        priority_order = {
            RecommendationPriority.CRITICAL: 0,
            RecommendationPriority.HIGH: 1,
            RecommendationPriority.MEDIUM: 2,
            RecommendationPriority.LOW: 3,
            RecommendationPriority.INFO: 4
        }
        recommendations.sort(key=lambda x: priority_order[x.priority])

        return recommendations

    def _check_data_quality(self, studies_df: pd.DataFrame) -> List[Recommendation]:
        """Check data quality issues"""
        recs = []

        # Check for missing data
        missing_cols = []
        for col in studies_df.columns:
            missing_pct = studies_df[col].isna().sum() / len(studies_df) * 100
            if missing_pct > 10:
                missing_cols.append(f"{col} ({missing_pct:.1f}%)")

        if missing_cols:
            recs.append(Recommendation(
                title="Missing Data Detected",
                description=f"Significant missing data in: {', '.join(missing_cols)}",
                rationale="Missing data can bias results and reduce statistical power",
                priority=RecommendationPriority.HIGH,
                action_items=[
                    "Attempt to contact study authors for missing data",
                    "Consider sensitivity analysis excluding studies with missing data",
                    "Evaluate if missingness is at random (MAR) or not at random (MNAR)"
                ],
                estimated_impact="High",
                category="data_quality"
            ))

        # Check for duplicates
        if 'study_id' in studies_df.columns:
            duplicates = studies_df['study_id'].duplicated().sum()
            if duplicates > 0:
                recs.append(Recommendation(
                    title="Duplicate Studies Detected",
                    description=f"Found {duplicates} duplicate study IDs",
                    rationale="Duplicate studies will bias pooled estimates",
                    priority=RecommendationPriority.CRITICAL,
                    action_items=[
                        "Review duplicate studies for data entry errors",
                        "Remove true duplicates",
                        "For multiple publications of same trial, use most recent/complete data"
                    ],
                    estimated_impact="High",
                    category="data_quality"
                ))

        # Check for outliers
        if 'yi' in studies_df.columns:
            yi = studies_df['yi'].values
            z_scores = np.abs((yi - np.mean(yi)) / np.std(yi))
            n_outliers = np.sum(z_scores > 3)

            if n_outliers > 0:
                recs.append(Recommendation(
                    title=f"Potential Outlier Studies ({n_outliers})",
                    description="Some studies have extreme effect sizes (|z| > 3)",
                    rationale="Outliers may represent true heterogeneity or data errors",
                    priority=RecommendationPriority.MEDIUM,
                    action_items=[
                        "Verify data extraction for outlier studies",
                        "Conduct sensitivity analysis excluding outliers",
                        "Investigate clinical/methodological reasons for extreme values"
                    ],
                    estimated_impact="Medium",
                    category="data_quality"
                ))

        return recs

    def _check_sample_sizes(self, studies_df: pd.DataFrame) -> List[Recommendation]:
        """Check sample size adequacy"""
        recs = []

        n_studies = len(studies_df)

        # Too few studies
        if n_studies < 5:
            recs.append(Recommendation(
                title="Small Number of Studies",
                description=f"Only {n_studies} studies included",
                rationale="Meta-analyses with <5 studies have limited power and unstable estimates",
                priority=RecommendationPriority.HIGH,
                action_items=[
                    "Consider if meta-analysis is appropriate",
                    "Use fixed-effect model if random-effects is unstable",
                    "Interpret results with caution",
                    "Consider narrative synthesis instead"
                ],
                estimated_impact="High",
                category="sample_size"
            ))

        # Check individual study sample sizes
        if 'n' in studies_df.columns:
            small_studies = studies_df[studies_df['n'] < 50]
            if len(small_studies) > len(studies_df) / 2:
                recs.append(Recommendation(
                    title="Many Small Studies",
                    description=f"{len(small_studies)}/{n_studies} studies have n<50",
                    rationale="Small studies may have publication bias and imprecise estimates",
                    priority=RecommendationPriority.MEDIUM,
                    action_items=[
                        "Assess publication bias with funnel plot and Egger's test",
                        "Consider sensitivity analysis excluding small studies",
                        "Use quality-effects model to down-weight small studies"
                    ],
                    estimated_impact="Medium",
                    category="sample_size"
                ))

        return recs

    def _check_heterogeneity_factors(self, studies_df: pd.DataFrame) -> List[Recommendation]:
        """Check factors that may cause heterogeneity"""
        recs = []

        # Check study year range
        if 'year' in studies_df.columns:
            year_range = studies_df['year'].max() - studies_df['year'].min()
            if year_range > 15:
                recs.append(Recommendation(
                    title="Wide Publication Year Range",
                    description=f"Studies span {year_range} years",
                    rationale="Treatment practices and standards of care may have changed over time",
                    priority=RecommendationPriority.MEDIUM,
                    action_items=[
                        "Consider meta-regression with year as moderator",
                        "Explore temporal trends in effect sizes",
                        "Consider restricting to recent studies in sensitivity analysis"
                    ],
                    estimated_impact="Medium",
                    category="heterogeneity"
                ))

        # Check risk of bias variation
        if 'risk_of_bias' in studies_df.columns:
            rob_levels = studies_df['risk_of_bias'].nunique()
            if rob_levels >= 2:
                rob_distribution = studies_df['risk_of_bias'].value_counts()
                recs.append(Recommendation(
                    title="Mixed Risk of Bias",
                    description=f"Studies have varying quality: {rob_distribution.to_dict()}",
                    rationale="Study quality may be a source of heterogeneity",
                    priority=RecommendationPriority.HIGH,
                    action_items=[
                        "Conduct subgroup analysis by risk of bias",
                        "Perform sensitivity analysis including only low-risk studies",
                        "Use quality-effects model to weight by study quality"
                    ],
                    estimated_impact="High",
                    category="heterogeneity"
                ))

        # Check for different interventions/populations
        if 'treatment' in studies_df.columns and studies_df['treatment'].nunique() > 2:
            recs.append(Recommendation(
                title="Multiple Interventions",
                description=f"{studies_df['treatment'].nunique()} different interventions",
                rationale="Combining different interventions may increase heterogeneity",
                priority=RecommendationPriority.HIGH,
                action_items=[
                    "Consider network meta-analysis instead of pairwise",
                    "Conduct subgroup analysis by intervention type",
                    "Assess if interventions are sufficiently similar to pool"
                ],
                estimated_impact="High",
                category="heterogeneity"
            ))

        return recs

    def _check_publication_bias_risk(self, studies_df: pd.DataFrame) -> List[Recommendation]:
        """Assess risk of publication bias"""
        recs = []

        n_studies = len(studies_df)

        # Small number of studies
        if n_studies < 10:
            recs.append(Recommendation(
                title="Limited Ability to Assess Publication Bias",
                description=f"Only {n_studies} studies (recommend ≥10 for bias assessment)",
                rationale="Funnel plots and statistical tests have low power with few studies",
                priority=RecommendationPriority.MEDIUM,
                action_items=[
                    "Visually inspect funnel plot but interpret cautiously",
                    "Search for unpublished studies and grey literature",
                    "Contact authors for unpublished data"
                ],
                estimated_impact="Medium",
                category="publication_bias"
            ))

        # Check if mostly small studies
        if 'n' in studies_df.columns:
            median_n = studies_df['n'].median()
            if median_n < 100:
                recs.append(Recommendation(
                    title="Predominance of Small Studies",
                    description=f"Median sample size: {median_n}",
                    rationale="Small studies more susceptible to publication bias",
                    priority=RecommendationPriority.HIGH,
                    action_items=[
                        "Conduct comprehensive search for unpublished studies",
                        "Use trim-and-fill method to adjust for potential bias",
                        "Consider contour-enhanced funnel plot",
                        "Assess excess significance test"
                    ],
                    estimated_impact="High",
                    category="publication_bias"
                ))

        # Check for industry funding
        if 'funding' in studies_df.columns or 'industry_funded' in studies_df.columns:
            funding_col = 'funding' if 'funding' in studies_df.columns else 'industry_funded'
            industry_funded = studies_df[funding_col].sum() if studies_df[funding_col].dtype == bool else 0

            if industry_funded > n_studies / 2:
                recs.append(Recommendation(
                    title="High Proportion of Industry-Funded Studies",
                    description=f"{industry_funded}/{n_studies} studies industry-funded",
                    rationale="Industry funding may be associated with favorable results",
                    priority=RecommendationPriority.HIGH,
                    action_items=[
                        "Conduct subgroup analysis by funding source",
                        "Assess if industry-funded studies have larger effects",
                        "Include in risk of bias assessment"
                    ],
                    estimated_impact="High",
                    category="publication_bias"
                ))

        return recs

    def _recommend_analysis_methods(self, studies_df: pd.DataFrame,
                                     outcome_type: str) -> List[Recommendation]:
        """Recommend appropriate analysis methods"""
        recs = []

        n_studies = len(studies_df)

        # Random-effects vs fixed-effect
        if n_studies >= 3:
            recs.append(Recommendation(
                title="Use Random-Effects Model",
                description="Recommend random-effects meta-analysis as primary analysis",
                rationale="Random-effects accounts for between-study heterogeneity",
                priority=RecommendationPriority.HIGH,
                action_items=[
                    "Use REML (Restricted Maximum Likelihood) for tau² estimation",
                    "Report both fixed-effect and random-effects results",
                    "Use Hartung-Knapp-Sidik-Jonkman adjustment for CI if n<10 studies"
                ],
                estimated_impact="High",
                category="analysis_method"
            ))

        # Heterogeneity estimation method
        if n_studies >= 5:
            method_rec = "REML (most commonly recommended)"
        elif n_studies >= 3:
            method_rec = "DerSimonian-Laird (more stable with few studies)"
        else:
            method_rec = "Fixed-effect (not enough studies for random-effects)"

        recs.append(Recommendation(
            title="Heterogeneity Estimation Method",
            description=f"Recommended: {method_rec}",
            rationale="Choice of method affects heterogeneity estimates and CIs",
            priority=RecommendationPriority.MEDIUM,
            action_items=[
                f"Use {method_rec.split()[0]} method",
                "Report I² statistic and 95% CI",
                "Report tau² and 95% prediction interval"
            ],
            estimated_impact="Medium",
            category="analysis_method"
        ))

        # Effect measure selection
        if outcome_type == "binary":
            recs.append(Recommendation(
                title="Effect Measure Selection (Binary Outcomes)",
                description="Choose appropriate effect measure",
                rationale="OR, RR, and RD have different interpretations and statistical properties",
                priority=RecommendationPriority.HIGH,
                action_items=[
                    "Use OR for case-control studies",
                    "Use RR for cohort studies and RCTs (more interpretable)",
                    "Use RD if absolute risk important",
                    "Ensure consistency with protocol/registration"
                ],
                estimated_impact="Medium",
                category="analysis_method"
            ))

        return recs

    def _recommend_sensitivity_analyses(self, studies_df: pd.DataFrame) -> List[Recommendation]:
        """Recommend specific sensitivity analyses"""
        recs = []

        # Risk of bias sensitivity
        if 'risk_of_bias' in studies_df.columns:
            high_rob = (studies_df['risk_of_bias'] == 'High').sum()
            if high_rob > 0:
                recs.append(Recommendation(
                    title="Risk of Bias Sensitivity Analysis",
                    description=f"Exclude {high_rob} high-risk studies",
                    rationale="High-risk studies may bias pooled estimate",
                    priority=RecommendationPriority.HIGH,
                    action_items=[
                        "Run meta-analysis excluding high risk of bias studies",
                        "Compare results to main analysis",
                        "Report both analyses in manuscript"
                    ],
                    estimated_impact="High",
                    category="sensitivity"
                ))

        # Leave-one-out
        if len(studies_df) >= 5:
            recs.append(Recommendation(
                title="Leave-One-Out Sensitivity Analysis",
                description="Iteratively remove each study and re-run analysis",
                rationale="Identify if any single study drives the result",
                priority=RecommendationPriority.MEDIUM,
                action_items=[
                    "Use automated leave-one-out function",
                    "Plot influence of each study on pooled estimate",
                    "Investigate any highly influential studies"
                ],
                estimated_impact="Medium",
                category="sensitivity"
            ))

        # Fixed-effect sensitivity (if using random-effects)
        recs.append(Recommendation(
            title="Fixed-Effect Model Sensitivity",
            description="Compare random-effects with fixed-effect results",
            rationale="Substantial differences may indicate influential heterogeneity",
            priority=RecommendationPriority.MEDIUM,
            action_items=[
                "Run fixed-effect meta-analysis",
                "Compare point estimates and CIs",
                "Interpret differences in context of heterogeneity"
            ],
            estimated_impact="Low",
            category="sensitivity"
        ))

        return recs


class SensitivityAnalysisEngine:
    """
    Engine to automatically run and interpret sensitivity analyses
    """

    def run_comprehensive_sensitivity(self, studies_df: pd.DataFrame,
                                       base_results: Dict) -> Dict[str, Any]:
        """
        Run comprehensive sensitivity analyses and compare to base case

        Args:
            studies_df: Study data
            base_results: Results from base case meta-analysis

        Returns:
            Dictionary with all sensitivity analysis results and interpretation
        """
        results = {
            'base_case': base_results,
            'sensitivity_analyses': [],
            'summary': {}
        }

        # 1. Risk of bias exclusion
        if 'risk_of_bias' in studies_df.columns:
            low_rob_data = studies_df[studies_df['risk_of_bias'] != 'High']
            if len(low_rob_data) >= 3:
                results['sensitivity_analyses'].append({
                    'name': 'Exclude High Risk of Bias',
                    'description': f"Excluded {len(studies_df) - len(low_rob_data)} high-risk studies",
                    'n_studies': len(low_rob_data),
                    'recommendation': 'Run meta-analysis with low_rob_data'
                })

        # 2. Large studies only
        if 'n' in studies_df.columns:
            median_n = studies_df['n'].median()
            large_studies = studies_df[studies_df['n'] >= median_n]
            if len(large_studies) >= 3:
                results['sensitivity_analyses'].append({
                    'name': 'Large Studies Only',
                    'description': f"Include only studies with n≥{median_n}",
                    'n_studies': len(large_studies),
                    'recommendation': 'Run meta-analysis with large_studies'
                })

        # 3. Recent studies only
        if 'year' in studies_df.columns:
            recent_cutoff = studies_df['year'].quantile(0.75)
            recent_studies = studies_df[studies_df['year'] >= recent_cutoff]
            if len(recent_studies) >= 3:
                results['sensitivity_analyses'].append({
                    'name': 'Recent Studies Only',
                    'description': f"Include only studies from {recent_cutoff} onwards",
                    'n_studies': len(recent_studies),
                    'recommendation': 'Run meta-analysis with recent_studies'
                })

        results['summary'] = {
            'n_sensitivity_analyses': len(results['sensitivity_analyses']),
            'recommendation': self._generate_sensitivity_summary(results)
        }

        return results

    def _generate_sensitivity_summary(self, results: Dict) -> str:
        """Generate summary of sensitivity analysis recommendations"""
        n_analyses = results['summary']['n_sensitivity_analyses']

        if n_analyses == 0:
            return "Insufficient data for sensitivity analyses. Report results with caution."
        elif n_analyses <= 2:
            return f"Run {n_analyses} sensitivity analysis to test robustness of findings."
        else:
            return f"Run {n_analyses} sensitivity analyses. Results robust if estimates remain stable across analyses."


class QualityAssessmentEngine:
    """
    Automated quality assessment following AMSTAR-2, GRADE, Cochrane RoB 2.0
    """

    def assess_meta_analysis_quality(self, metadata: Dict) -> Dict[str, Any]:
        """
        Assess overall quality of meta-analysis using AMSTAR-2 criteria

        AMSTAR-2 has 16 criteria for critical appraisal
        """
        assessment = {
            'criteria': [],
            'overall_confidence': 'Unknown',
            'score': 0,
            'max_score': 16
        }

        # Criterion 1: PICO in research question
        if metadata.get('has_pico', False):
            assessment['criteria'].append({
                'item': 'PICO components specified',
                'status': 'Yes',
                'critical': True
            })
            assessment['score'] += 1
        else:
            assessment['criteria'].append({
                'item': 'PICO components specified',
                'status': 'No',
                'critical': True
            })

        # Criterion 2: Protocol registered
        if metadata.get('protocol_registered', False):
            assessment['criteria'].append({
                'item': 'Protocol registered before study',
                'status': 'Yes',
                'critical': True
            })
            assessment['score'] += 1
        else:
            assessment['criteria'].append({
                'item': 'Protocol registered before study',
                'status': 'No/Partial',
                'critical': True
            })

        # Criterion 4: Comprehensive search
        if metadata.get('comprehensive_search', False):
            assessment['criteria'].append({
                'item': 'Comprehensive literature search',
                'status': 'Yes',
                'critical': True
            })
            assessment['score'] += 1
        else:
            assessment['criteria'].append({
                'item': 'Comprehensive literature search',
                'status': 'No',
                'critical': True
            })

        # Criterion 9: Risk of bias assessed
        if metadata.get('rob_assessed', False):
            assessment['criteria'].append({
                'item': 'Risk of bias assessed',
                'status': 'Yes',
                'critical': True
            })
            assessment['score'] += 1
        else:
            assessment['criteria'].append({
                'item': 'Risk of bias assessed',
                'status': 'No',
                'critical': True
            })

        # Criterion 11: Appropriate statistical methods
        if metadata.get('appropriate_methods', True):  # Default to true
            assessment['criteria'].append({
                'item': 'Appropriate meta-analysis methods',
                'status': 'Yes',
                'critical': True
            })
            assessment['score'] += 1

        # Criterion 13: Risk of bias considered in interpretation
        if metadata.get('rob_in_interpretation', False):
            assessment['criteria'].append({
                'item': 'Risk of bias considered in interpretation',
                'status': 'Yes',
                'critical': True
            })
            assessment['score'] += 1

        # Criterion 15: Publication bias assessed
        if metadata.get('pub_bias_assessed', False):
            assessment['criteria'].append({
                'item': 'Publication bias investigated',
                'status': 'Yes',
                'critical': True
            })
            assessment['score'] += 1

        # Overall confidence rating
        if assessment['score'] >= 14:
            assessment['overall_confidence'] = 'High'
        elif assessment['score'] >= 10:
            assessment['overall_confidence'] = 'Moderate'
        elif assessment['score'] >= 6:
            assessment['overall_confidence'] = 'Low'
        else:
            assessment['overall_confidence'] = 'Critically Low'

        return assessment


# Initialize global instances
analysis_recommender = AnalysisRecommender()
sensitivity_engine = SensitivityAnalysisEngine()
quality_engine = QualityAssessmentEngine()
