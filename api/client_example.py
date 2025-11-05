"""
Example client for ML Evidence Synthesis API

This script demonstrates how to use the API from Python
"""

import requests
import json
from typing import Dict, List, Any

class MLEvidenceClient:
    """Python client for ML Evidence Synthesis API"""

    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()

    def health_check(self) -> Dict[str, Any]:
        """Check API health"""
        response = self.session.get(f"{self.base_url}/health")
        response.raise_for_status()
        return response.json()

    def predict_hta(
        self,
        effect_size: float,
        icer_per_qaly: float,
        serious_adverse_events_rate: float,
        discontinuation_rate: float,
        n_rcts: int,
        total_patients_evidence: int,
        cost_effectiveness_score: float,
        clinical_benefit_score: float,
        innovation_score: float,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Predict HTA reimbursement decision

        Args:
            effect_size: Treatment effect size
            icer_per_qaly: ICER per QALY in USD
            serious_adverse_events_rate: SAE rate (0-1)
            discontinuation_rate: Discontinuation rate (0-1)
            n_rcts: Number of RCTs
            total_patients_evidence: Total patients in evidence
            cost_effectiveness_score: CE score (1-10)
            clinical_benefit_score: Clinical benefit score (1-10)
            innovation_score: Innovation score (1-10)
            **kwargs: Additional optional parameters

        Returns:
            Prediction dictionary with decision, probabilities, recommendation
        """

        data = {
            "effect_size": effect_size,
            "icer_per_qaly": icer_per_qaly,
            "serious_adverse_events_rate": serious_adverse_events_rate,
            "discontinuation_rate": discontinuation_rate,
            "n_rcts": n_rcts,
            "total_patients_evidence": total_patients_evidence,
            "cost_effectiveness_score": cost_effectiveness_score,
            "clinical_benefit_score": clinical_benefit_score,
            "innovation_score": innovation_score,
            **kwargs
        }

        response = self.session.post(
            f"{self.base_url}/predict/hta",
            json=data
        )
        response.raise_for_status()
        return response.json()

    def predict_effect_size(
        self,
        experimental_n: int,
        control_n: int,
        experimental_events: int,
        control_events: int,
        study_year: int = 2020
    ) -> Dict[str, Any]:
        """
        Predict treatment effect size

        Args:
            experimental_n: Experimental group sample size
            control_n: Control group sample size
            experimental_events: Events in experimental group
            control_events: Events in control group
            study_year: Publication year

        Returns:
            Prediction dictionary with log OR, OR, CI, interpretation
        """

        data = {
            "experimental_n": experimental_n,
            "control_n": control_n,
            "experimental_events": experimental_events,
            "control_events": control_events,
            "study_year": study_year
        }

        response = self.session.post(
            f"{self.base_url}/predict/effect-size",
            json=data
        )
        response.raise_for_status()
        return response.json()

    def batch_hta_predict(self, assessments: List[Dict]) -> Dict[str, Any]:
        """Batch HTA predictions"""

        response = self.session.post(
            f"{self.base_url}/predict/hta/batch",
            json={"assessments": assessments}
        )
        response.raise_for_status()
        return response.json()

    def batch_effect_size_predict(self, studies: List[Dict]) -> Dict[str, Any]:
        """Batch effect size predictions"""

        response = self.session.post(
            f"{self.base_url}/predict/effect-size/batch",
            json={"studies": studies}
        )
        response.raise_for_status()
        return response.json()


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

def main():
    """Example usage of the ML Evidence API"""

    # Initialize client
    client = MLEvidenceClient(base_url="http://localhost:8000")

    print("=" * 80)
    print("ML EVIDENCE SYNTHESIS API - CLIENT EXAMPLES")
    print("=" * 80)

    # 1. Health Check
    print("\n1️⃣  Health Check")
    print("-" * 80)
    health = client.health_check()
    print(f"Status: {health['status']}")
    print(f"Models Loaded: {health['models_loaded']}")

    # 2. HTA Prediction
    print("\n2️⃣  HTA Reimbursement Prediction")
    print("-" * 80)

    hta_result = client.predict_hta(
        effect_size=0.45,
        icer_per_qaly=75000,
        serious_adverse_events_rate=0.12,
        discontinuation_rate=0.20,
        n_rcts=8,
        n_observational_studies=3,
        total_patients_evidence=2500,
        cost_effectiveness_score=7.5,
        clinical_benefit_score=6.8,
        innovation_score=8.2,
        certainty_of_evidence="Moderate"
    )

    print(f"Decision: {hta_result['decision']}")
    print(f"Confidence: {hta_result['confidence']:.2%}")
    print(f"\nProbabilities:")
    for decision, prob in hta_result['probability'].items():
        print(f"  {decision}: {prob:.2%}")
    print(f"\nRecommendation:")
    print(f"  {hta_result['recommendation']}")

    # 3. Effect Size Prediction
    print("\n3️⃣  Treatment Effect Size Estimation")
    print("-" * 80)

    effect_result = client.predict_effect_size(
        experimental_n=250,
        control_n=250,
        experimental_events=45,
        control_events=62,
        study_year=2020
    )

    print(f"Predicted Odds Ratio: {effect_result['predicted_or']:.3f}")
    print(f"95% CI: [{effect_result['odds_ratio_ci_lower']:.3f}, "
          f"{effect_result['odds_ratio_ci_upper']:.3f}]")
    print(f"Event Rates: {effect_result['event_rate_experimental']:.1%} vs "
          f"{effect_result['event_rate_control']:.1%}")
    print(f"\nInterpretation:")
    print(f"  {effect_result['interpretation']}")

    # 4. Batch Predictions
    print("\n4️⃣  Batch Effect Size Predictions")
    print("-" * 80)

    batch_studies = [
        {"experimental_n": 100, "control_n": 100,
         "experimental_events": 20, "control_events": 30},
        {"experimental_n": 200, "control_n": 200,
         "experimental_events": 45, "control_events": 55},
        {"experimental_n": 150, "control_n": 150,
         "experimental_events": 10, "control_events": 25},
    ]

    batch_results = client.batch_effect_size_predict(batch_studies)

    print(f"Total studies: {batch_results['total']}")
    print(f"Successful: {batch_results['successful']}")
    print(f"\nResults:")
    for result in batch_results['results'][:3]:  # Show first 3
        if result['status'] == 'success':
            pred = result['prediction']
            print(f"  Study {result['index']}: OR = {pred['predicted_or']:.3f}")

    print("\n" + "=" * 80)
    print("✅ ALL EXAMPLES COMPLETED SUCCESSFULLY")
    print("=" * 80)


if __name__ == "__main__":
    main()
