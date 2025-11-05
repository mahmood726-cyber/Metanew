"""
Automated Risk of Bias (ROB) Assessment for Systematic Reviews
Uses ML to classify studies according to Cochrane ROB 2.0 criteria
"""
import logging
from typing import Dict, List, Any, Tuple
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.multioutput import MultiOutputClassifier

logger = logging.getLogger(__name__)


class RiskOfBiasAssessor:
    """
    Automated ROB assessment using ML
    Implements Cochrane ROB 2.0 domains
    """

    # ROB 2.0 domains
    DOMAINS = [
        'randomization',  # Bias arising from randomization process
        'deviations',    # Bias due to deviations from intended interventions
        'missing_data',  # Bias due to missing outcome data
        'measurement',   # Bias in measurement of the outcome
        'selection'      # Bias in selection of the reported result
    ]

    JUDGEMENTS = ['Low', 'Some concerns', 'High']

    def __init__(self):
        """Initialize ROB assessor"""
        self.vectorizer = TfidfVectorizer(max_features=1000, ngram_range=(1, 3))
        self.classifier = None
        self.is_trained = False
        logger.info("✓ Risk of Bias assessor initialized")

    def train(self, training_data: List[Dict[str, Any]]) -> Dict[str, float]:
        """
        Train ROB classifier on labeled data

        Args:
            training_data: List of dicts with 'text' and 'labels' (dict of domain: judgment)

        Returns:
            Training metrics
        """
        logger.info(f"Training ROB classifier on {len(training_data)} studies...")

        # Extract texts and labels
        texts = [item['text'] for item in training_data]
        labels_matrix = []

        for item in training_data:
            # Convert judgements to numeric (0=Low, 1=Some concerns, 2=High)
            domain_labels = [
                self.JUDGEMENTS.index(item['labels'].get(domain, 'Some concerns'))
                for domain in self.DOMAINS
            ]
            labels_matrix.append(domain_labels)

        # Vectorize texts
        X = self.vectorizer.fit_transform(texts)
        y = np.array(labels_matrix)

        # Train multi-output classifier
        base_clf = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
        self.classifier = MultiOutputClassifier(base_clf)
        self.classifier.fit(X, y)

        self.is_trained = True
        logger.info("✓ ROB classifier trained")

        return {'status': 'trained', 'n_training_samples': len(training_data)}

    def assess_study(
        self,
        study_text: str,
        study_metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Assess risk of bias for a single study

        Args:
            study_text: Full text or abstract of the study
            study_metadata: Optional metadata (design, etc.)

        Returns:
            ROB assessment with domain judgements and confidence scores
        """
        if not self.is_trained:
            return self._rule_based_assessment(study_text, study_metadata)

        # Vectorize
        X = self.vectorizer.transform([study_text])

        # Predict
        predictions = self.classifier.predict(X)[0]
        probabilities = [clf.predict_proba(X)[0] for clf in self.classifier.estimators_]

        # Build result
        assessment = {}
        for i, domain in enumerate(self.DOMAINS):
            judgment_idx = predictions[i]
            confidence = probabilities[i][judgment_idx]

            assessment[domain] = {
                'judgment': self.JUDGEMENTS[judgment_idx],
                'confidence': float(confidence),
                'probabilities': {
                    self.JUDGEMENTS[j]: float(probabilities[i][j])
                    for j in range(len(self.JUDGEMENTS))
                }
            }

        # Overall judgment (most conservative)
        judgment_indices = list(predictions)
        overall_idx = max(judgment_indices)  # Worst domain determines overall
        overall_confidence = np.mean([probabilities[i][predictions[i]] for i in range(len(self.DOMAINS))])

        return {
            'overall_rob': self.JUDGEMENTS[overall_idx],
            'overall_confidence': float(overall_confidence),
            'domains': assessment,
            'method': 'ml',
            'study_metadata': study_metadata or {}
        }

    def _rule_based_assessment(
        self,
        study_text: str,
        study_metadata: Optional[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Rule-based fallback when ML model not trained
        Uses keyword matching and heuristics
        """
        text_lower = study_text.lower()

        assessment = {}

        # Randomization
        if any(kw in text_lower for kw in ['random', 'randomized', 'randomised', 'rct']):
            if any(kw in text_lower for kw in ['allocation concealment', 'central randomization']):
                assessment['randomization'] = {'judgment': 'Low', 'confidence': 0.7}
            else:
                assessment['randomization'] = {'judgment': 'Some concerns', 'confidence': 0.6}
        else:
            assessment['randomization'] = {'judgment': 'High', 'confidence': 0.8}

        # Deviations
        if any(kw in text_lower for kw in ['intention to treat', 'itt', 'protocol']):
            assessment['deviations'] = {'judgment': 'Low', 'confidence': 0.6}
        else:
            assessment['deviations'] = {'judgment': 'Some concerns', 'confidence': 0.5}

        # Missing data
        if 'loss to follow' in text_lower or 'dropout' in text_lower:
            if any(num in study_text for num in ['<5%', '<10%']):
                assessment['missing_data'] = {'judgment': 'Low', 'confidence': 0.6}
            else:
                assessment['missing_data'] = {'judgment': 'Some concerns', 'confidence': 0.6}
        else:
            assessment['missing_data'] = {'judgment': 'Some concerns', 'confidence': 0.5}

        # Measurement
        if any(kw in text_lower for kw in ['blinded', 'masked', 'objective outcome']):
            assessment['measurement'] = {'judgment': 'Low', 'confidence': 0.7}
        else:
            assessment['measurement'] = {'judgment': 'Some concerns', 'confidence': 0.5}

        # Selection
        if 'pre-registered' in text_lower or 'protocol registered' in text_lower:
            assessment['selection'] = {'judgment': 'Low', 'confidence': 0.6}
        else:
            assessment['selection'] = {'judgment': 'Some concerns', 'confidence': 0.5}

        # Overall
        judgments = [v['judgment'] for v in assessment.values()]
        if 'High' in judgments:
            overall = 'High'
        elif 'Some concerns' in judgments:
            overall = 'Some concerns'
        else:
            overall = 'Low'

        return {
            'overall_rob': overall,
            'overall_confidence': 0.5,
            'domains': assessment,
            'method': 'rule_based',
            'note': 'Rule-based assessment. Train ML model for better accuracy.',
            'study_metadata': study_metadata or {}
        }

    def batch_assess(
        self,
        studies: List[Dict[str, str]]
    ) -> List[Dict[str, Any]]:
        """
        Assess multiple studies in batch

        Args:
            studies: List of dicts with 'id', 'text', and optional 'metadata'

        Returns:
            List of ROB assessments
        """
        logger.info(f"Assessing ROB for {len(studies)} studies...")

        assessments = []
        for study in studies:
            assessment = self.assess_study(
                study['text'],
                study.get('metadata')
            )
            assessment['study_id'] = study['id']
            assessments.append(assessment)

        logger.info(f"✓ Assessed {len(assessments)} studies")
        return assessments


# Example usage and training data generator
def generate_synthetic_training_data(n_samples: int = 100) -> List[Dict[str, Any]]:
    """Generate synthetic training data for demonstration"""
    import random

    templates = {
        'Low': "This randomized controlled trial with allocation concealment and blinding used intention-to-treat analysis with minimal missing data (<5%).",
        'Some concerns': "This randomized study reported results but did not clearly describe allocation concealment or blinding procedures.",
        'High': "This non-randomized study had high dropout rates (>20%) and unclear outcome assessment procedures."
    }

    training_data = []
    for i in range(n_samples):
        overall_quality = random.choice(['Low', 'Some concerns', 'High'])
        text = templates[overall_quality]

        # Assign domain judgments
        if overall_quality == 'Low':
            labels = {domain: 'Low' for domain in RiskOfBiasAssessor.DOMAINS}
        elif overall_quality == 'High':
            labels = {domain: random.choice(['Some concerns', 'High']) for domain in RiskOfBiasAssessor.DOMAINS}
        else:
            labels = {domain: random.choice(['Low', 'Some concerns']) for domain in RiskOfBiasAssessor.DOMAINS}

        training_data.append({'text': text, 'labels': labels})

    return training_data
