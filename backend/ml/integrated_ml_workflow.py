"""
Integrated ML Workflow for Systematic Reviews

Combines all ML models into a comprehensive automation pipeline.

Complete automation from abstract to meta-analysis:
1. PICO extraction from abstracts
2. Risk of Bias prediction
3. Heterogeneity prediction for meta-analysis planning
4. Effect size prediction for sample size calculations

V2.8 ENHANCEMENT - Complete ML Automation

Author: EvidenceOS PRIME
License: MIT
"""

from typing import List, Dict, Optional
from dataclasses import dataclass
import json
from pathlib import Path
import warnings

try:
    from .pico_extractor_ml import MLPICOExtractor, PICOElements
    from .risk_of_bias_classifier import MLRiskOfBiasClassifier, RiskOfBiasAssessment
    from .heterogeneity_predictor import MLHeterogeneityPredictor, HeterogeneityPrediction
    from .effect_size_estimator import MLEffectSizeEstimator, EffectSizeEstimate
except ImportError:
    # For direct execution
    from pico_extractor_ml import MLPICOExtractor, PICOElements
    from risk_of_bias_classifier import MLRiskOfBiasClassifier, RiskOfBiasAssessment
    from heterogeneity_predictor import MLHeterogeneityPredictor, HeterogeneityPrediction
    from effect_size_estimator import MLEffectSizeEstimator, EffectSizeEstimate


@dataclass
class ProcessedStudy:
    """Fully processed study with all ML predictions"""
    pmid: str
    title: str
    abstract: str

    # ML predictions
    pico: PICOElements
    risk_of_bias: RiskOfBiasAssessment
    predicted_effect: EffectSizeEstimate

    # Metadata
    include_in_ma: bool
    confidence_score: float
    automation_level: float  # % automated


@dataclass
class MetaAnalysisPlan:
    """Complete meta-analysis plan from ML predictions"""
    n_studies: int
    included_studies: List[ProcessedStudy]

    # Predictions
    predicted_heterogeneity: HeterogeneityPrediction
    pooled_effect_estimate: float
    recommended_model: str

    # Quality
    overall_rob: str
    high_quality_studies: int
    automation_achieved: float


class IntegratedMLWorkflow:
    """
    Integrated ML workflow for complete systematic review automation

    Automates:
    - Data extraction (PICO)
    - Quality assessment (RoB)
    - Meta-analysis planning (heterogeneity)
    - Effect prediction

    Examples:
        >>> workflow = IntegratedMLWorkflow()
        >>> workflow.load_models('models/')
        >>>
        >>> # Process abstracts
        >>> abstracts = [
        >>>     {'pmid': '12345', 'title': '...', 'abstract': '...'},
        >>>     {'pmid': '67890', 'title': '...', 'abstract': '...'}
        >>> ]
        >>>
        >>> studies = workflow.process_abstracts(abstracts)
        >>> ma_plan = workflow.plan_meta_analysis(studies)
        >>>
        >>> print(f"Automation: {ma_plan.automation_achieved:.1%}")
        >>> print(f"Predicted I²: {ma_plan.predicted_heterogeneity.i_squared:.1f}%")
    """

    def __init__(self):
        self.pico_extractor = None
        self.rob_classifier = None
        self.heterogeneity_predictor = None
        self.effect_size_estimator = None

        self.models_loaded = False

    def load_models(self, model_dir: str = 'models'):
        """
        Load all trained ML models

        Args:
            model_dir: Directory containing saved models
        """
        print(f"📁 Loading ML models from {model_dir}...")

        try:
            # Load PICO extractor
            self.pico_extractor = MLPICOExtractor()
            pico_path = f"{model_dir}/pico_extractor.pkl"
            if Path(pico_path).exists():
                self.pico_extractor.load_model(pico_path)
            else:
                print(f"   ⚠️  {pico_path} not found, using untrained model")

            # Load RoB classifier
            self.rob_classifier = MLRiskOfBiasClassifier()
            rob_path = f"{model_dir}/rob_classifier.pkl"
            if Path(rob_path).exists():
                self.rob_classifier.load_model(rob_path)
            else:
                print(f"   ⚠️  {rob_path} not found, using untrained model")

            # Load heterogeneity predictor
            self.heterogeneity_predictor = MLHeterogeneityPredictor()
            het_path = f"{model_dir}/heterogeneity_predictor.pkl"
            if Path(het_path).exists():
                self.heterogeneity_predictor.load_model(het_path)
            else:
                print(f"   ⚠️  {het_path} not found, using untrained model")

            # Load effect size estimator
            self.effect_size_estimator = MLEffectSizeEstimator()
            eff_path = f"{model_dir}/effect_size_estimator.pkl"
            if Path(eff_path).exists():
                self.effect_size_estimator.load_model(eff_path)
            else:
                print(f"   ⚠️  {eff_path} not found, using untrained model")

            self.models_loaded = True
            print("   ✅ Models loaded successfully\n")

        except Exception as e:
            print(f"   ❌ Failed to load models: {e}")
            self.models_loaded = False

    def process_abstract(self, abstract_data: Dict) -> ProcessedStudy:
        """
        Process single abstract through complete ML pipeline

        Args:
            abstract_data: Dictionary with 'pmid', 'title', 'abstract'

        Returns:
            Fully processed study with all ML predictions
        """
        pmid = abstract_data.get('pmid', 'unknown')
        title = abstract_data.get('title', '')
        abstract = abstract_data.get('abstract', '')

        # 1. Extract PICO
        pico = self.pico_extractor.extract(abstract) if self.pico_extractor else None

        # 2. Predict Risk of Bias (if we have enough metadata)
        study_features = {
            'year': abstract_data.get('year', 2020),
            'n_intervention': pico.sample_size // 2 if pico and pico.sample_size else 250,
            'n_comparator': pico.sample_size // 2 if pico and pico.sample_size else 250,
            'follow_up_months': 24,  # Default
            'journal': abstract_data.get('journal', 'Other')
        }

        rob = self.rob_classifier.predict(study_features) if self.rob_classifier else None

        # 3. Predict effect size
        effect = self.effect_size_estimator.predict(study_features, effect_type='HR') if self.effect_size_estimator else None

        # 4. Determine inclusion
        include = self._should_include(pico, rob)

        # 5. Calculate confidence score
        confidences = []
        if pico:
            confidences.append(pico.confidence)
        if rob:
            confidences.append(rob.confidence)
        if effect:
            confidences.append(effect.confidence)

        confidence_score = sum(confidences) / len(confidences) if confidences else 0.5

        # 6. Calculate automation level
        automation = self._calculate_automation(pico, rob, effect)

        return ProcessedStudy(
            pmid=pmid,
            title=title,
            abstract=abstract,
            pico=pico,
            risk_of_bias=rob,
            predicted_effect=effect,
            include_in_ma=include,
            confidence_score=confidence_score,
            automation_level=automation
        )

    def process_abstracts(self, abstracts: List[Dict]) -> List[ProcessedStudy]:
        """
        Process multiple abstracts through ML pipeline

        Args:
            abstracts: List of dictionaries with abstract data

        Returns:
            List of processed studies
        """
        print(f"\n🔄 Processing {len(abstracts)} abstracts through ML pipeline...")

        processed = []
        for i, abstract_data in enumerate(abstracts):
            print(f"   Processing {i+1}/{len(abstracts)}: PMID {abstract_data.get('pmid', 'unknown')}")
            study = self.process_abstract(abstract_data)
            processed.append(study)

            # Print brief summary
            include_status = "✅ INCLUDE" if study.include_in_ma else "❌ EXCLUDE"
            print(f"      {include_status} (confidence: {study.confidence_score:.1%}, automation: {study.automation_level:.1%})")

        print(f"\n✅ Processed {len(processed)} studies")
        print(f"   Included: {sum(1 for s in processed if s.include_in_ma)}")
        print(f"   Excluded: {sum(1 for s in processed if not s.include_in_ma)}")

        return processed

    def plan_meta_analysis(self, studies: List[ProcessedStudy]) -> MetaAnalysisPlan:
        """
        Plan meta-analysis from processed studies

        Args:
            studies: List of processed studies

        Returns:
            Complete meta-analysis plan with predictions
        """
        print(f"\n📊 Planning meta-analysis...")

        # Filter to included studies
        included = [s for s in studies if s.include_in_ma]

        if len(included) < 2:
            print("   ⚠️  Too few studies for meta-analysis")
            return None

        # Predict heterogeneity
        meta_features = self._extract_meta_features(included)
        het_pred = self.heterogeneity_predictor.predict(meta_features) if self.heterogeneity_predictor else None

        # Calculate pooled effect (simple average for demo)
        effect_estimates = [s.predicted_effect.point_estimate for s in included if s.predicted_effect]
        pooled_effect = sum(effect_estimates) / len(effect_estimates) if effect_estimates else 0.75

        # Assess overall RoB
        rob_levels = [s.risk_of_bias.overall_risk for s in included if s.risk_of_bias]
        if 'high' in rob_levels:
            overall_rob = 'high'
        elif rob_levels.count('low') >= len(rob_levels) * 0.75:
            overall_rob = 'low'
        else:
            overall_rob = 'unclear'

        high_quality = sum(1 for s in included if s.risk_of_bias and s.risk_of_bias.overall_risk == 'low')

        # Calculate overall automation
        automation_achieved = sum(s.automation_level for s in included) / len(included) if included else 0

        plan = MetaAnalysisPlan(
            n_studies=len(included),
            included_studies=included,
            predicted_heterogeneity=het_pred,
            pooled_effect_estimate=pooled_effect,
            recommended_model=het_pred.recommended_model if het_pred else 'random',
            overall_rob=overall_rob,
            high_quality_studies=high_quality,
            automation_achieved=automation_achieved
        )

        # Print summary
        print(f"   ✅ Meta-analysis planned")
        print(f"   Studies: {plan.n_studies}")
        if het_pred:
            print(f"   Predicted I²: {het_pred.i_squared:.1f}%")
        print(f"   Recommended model: {plan.recommended_model}")
        print(f"   Overall RoB: {plan.overall_rob}")
        print(f"   Automation achieved: {plan.automation_achieved:.1%}")

        return plan

    def _should_include(self, pico: PICOElements, rob: RiskOfBiasAssessment) -> bool:
        """Determine if study should be included in meta-analysis"""
        # Include if:
        # 1. PICO elements extracted with confidence > 0.5
        # 2. RoB is not high

        if not pico or pico.confidence < 0.5:
            return False

        if rob and rob.overall_risk == 'high':
            return False

        return True

    def _calculate_automation(self, pico, rob, effect) -> float:
        """Calculate automation level achieved"""
        automated = 0
        total = 3

        if pico and pico.confidence >= 0.7:
            automated += 1
        if rob and rob.method == 'ml':
            automated += 1
        if effect and effect.method == 'ml':
            automated += 1

        return automated / total

    def _extract_meta_features(self, studies: List[ProcessedStudy]) -> Dict:
        """Extract meta-analysis features for heterogeneity prediction"""
        sample_sizes = []
        ages = []
        interventions = set()

        for s in studies:
            if s.pico and s.pico.sample_size:
                sample_sizes.append(s.pico.sample_size)
            if s.pico:
                interventions.update(s.pico.intervention)

        return {
            'n_studies': len(studies),
            'n_total_min': min(sample_sizes) if sample_sizes else 100,
            'n_total_max': max(sample_sizes) if sample_sizes else 500,
            'intervention_types': len(interventions),
            'age_range': 20,  # Default
            'follow_up_range': 24,  # Default
            'rob_variance': 0.3,  # Default
            'geographic_diversity': 5  # Default
        }

    def export_to_json(self, plan: MetaAnalysisPlan, output_path: str):
        """Export meta-analysis plan to JSON"""
        export_data = {
            'n_studies': plan.n_studies,
            'predicted_heterogeneity': {
                'i_squared': plan.predicted_heterogeneity.i_squared,
                'recommended_model': plan.predicted_heterogeneity.recommended_model,
                'confidence': plan.predicted_heterogeneity.confidence
            } if plan.predicted_heterogeneity else None,
            'pooled_effect': plan.pooled_effect_estimate,
            'overall_rob': plan.overall_rob,
            'automation_achieved': f"{plan.automation_achieved:.1%}",
            'studies': [
                {
                    'pmid': s.pmid,
                    'title': s.title[:100],
                    'pico': {
                        'population': s.pico.population if s.pico else [],
                        'intervention': s.pico.intervention if s.pico else [],
                        'confidence': s.pico.confidence if s.pico else 0
                    },
                    'rob': {
                        'overall': s.risk_of_bias.overall_risk if s.risk_of_bias else 'unclear',
                        'confidence': s.risk_of_bias.confidence if s.risk_of_bias else 0
                    },
                    'predicted_effect': s.predicted_effect.point_estimate if s.predicted_effect else None
                }
                for s in plan.included_studies[:10]  # First 10 studies
            ]
        }

        with open(output_path, 'w') as f:
            json.dump(export_data, f, indent=2)

        print(f"\n✅ Exported to {output_path}")


# Example usage
if __name__ == "__main__":
    print("=== INTEGRATED ML WORKFLOW DEMO ===\n")

    workflow = IntegratedMLWorkflow()

    # Note: Models need to be trained first using train_all_models.py
    # workflow.load_models('models/')

    # Demo with sample abstracts
    sample_abstracts = [
        {
            'pmid': '31234567',
            'title': 'Pembrolizumab vs chemotherapy in advanced NSCLC',
            'abstract': 'BACKGROUND: Advanced non-small cell lung cancer... METHODS: 594 patients randomized to pembrolizumab 200mg every 3 weeks vs chemotherapy... RESULTS: Overall survival HR 0.71 (95% CI 0.58-0.87, p<0.001)...',
            'year': 2019,
            'journal': 'NEJM'
        },
        {
            'pmid': '32345678',
            'title': 'Nivolumab in melanoma: randomized trial',
            'abstract': 'OBJECTIVE: Evaluate nivolumab in advanced melanoma... METHODS: 450 patients... RESULTS: Progression-free survival improved (HR 0.68)...',
            'year': 2020,
            'journal': 'Lancet'
        }
    ]

    print("This workflow combines all ML models:")
    print("  1. PICO Extractor (NLP)")
    print("  2. Risk of Bias Classifier (ML)")
    print("  3. Heterogeneity Predictor (ML)")
    print("  4. Effect Size Estimator (ML)")
    print("\nTo use:")
    print("  1. Train models: python backend/ml/train_all_models.py")
    print("  2. Load and run: workflow.load_models('models/')")
    print("  3. Process: workflow.process_abstracts(abstracts)")
    print("  4. Plan MA: workflow.plan_meta_analysis(studies)")
