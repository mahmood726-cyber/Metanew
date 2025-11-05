"""
Study Screening Assistant for Systematic Reviews
Uses NLP/ML to automatically screen titles and abstracts
"""
import logging
from typing import Dict, List, Any, Tuple
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.calibration import CalibratedClassifierCV

logger = logging.getLogger(__name__)


class StudyScreeningAssistant:
    """
    Automated study screening for systematic reviews
    Classifies studies as include/exclude based on title/abstract
    """

    def __init__(self):
        """Initialize screening assistant"""
        self.vectorizer = TfidfVectorizer(
            max_features=5000,
            ngram_range=(1, 3),
            min_df=2,
            stop_words='english'
        )
        self.classifier = None
        self.is_trained = False
        self.inclusion_criteria = []
        logger.info("✓ Study screening assistant initialized")

    def set_inclusion_criteria(self, criteria: List[str]):
        """
        Set inclusion/exclusion criteria

        Args:
            criteria: List of inclusion criteria strings
        """
        self.inclusion_criteria = criteria
        logger.info(f"✓ Set {len(criteria)} inclusion criteria")

    def train(
        self,
        training_data: List[Dict[str, Any]],
        validation_split: float = 0.2
    ) -> Dict[str, Any]:
        """
        Train screening classifier

        Args:
            training_data: List of dicts with 'title', 'abstract', 'label' (1=include, 0=exclude)
            validation_split: Fraction for validation

        Returns:
            Training metrics including accuracy, precision, recall
        """
        logger.info(f"Training screening classifier on {len(training_data)} studies...")

        # Combine title and abstract
        texts = [
            f"{item['title']} {item.get('abstract', '')}"
            for item in training_data
        ]
        labels = np.array([item['label'] for item in training_data])

        # Train/validation split
        n_val = int(len(texts) * validation_split)
        X_train_text, X_val_text = texts[:-n_val], texts[-n_val:]
        y_train, y_val = labels[:-n_val], labels[-n_val:]

        # Vectorize
        X_train = self.vectorizer.fit_transform(X_train_text)
        X_val = self.vectorizer.transform(X_val_text)

        # Train calibrated classifier for reliable probabilities
        base_clf = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=5,
            learning_rate=0.1,
            random_state=42
        )
        self.classifier = CalibratedClassifierCV(base_clf, cv=3)
        self.classifier.fit(X_train, y_train)

        self.is_trained = True

        # Validation metrics
        y_pred = self.classifier.predict(X_val)
        y_prob = self.classifier.predict_proba(X_val)[:, 1]

        accuracy = np.mean(y_pred == y_val)
        precision = np.sum((y_pred == 1) & (y_val == 1)) / max(np.sum(y_pred == 1), 1)
        recall = np.sum((y_pred == 1) & (y_val == 1)) / max(np.sum(y_val == 1), 1)
        f1 = 2 * precision * recall / max(precision + recall, 0.001)

        logger.info(f"✓ Classifier trained (Acc={accuracy:.3f}, F1={f1:.3f})")

        return {
            'accuracy': float(accuracy),
            'precision': float(precision),
            'recall': float(recall),
            'f1_score': float(f1),
            'n_training': len(X_train_text),
            'n_validation': len(X_val_text)
        }

    def screen_study(
        self,
        title: str,
        abstract: str = "",
        threshold: float = 0.5
    ) -> Dict[str, Any]:
        """
        Screen a single study

        Args:
            title: Study title
            abstract: Study abstract
            threshold: Decision threshold (default 0.5)

        Returns:
            Screening decision with confidence scores
        """
        if not self.is_trained:
            return self._rule_based_screening(title, abstract)

        # Combine and vectorize
        text = f"{title} {abstract}"
        X = self.vectorizer.transform([text])

        # Predict
        prob_include = self.classifier.predict_proba(X)[0, 1]
        decision = 'include' if prob_include >= threshold else 'exclude'

        # Calculate confidence
        confidence = prob_include if decision == 'include' else (1 - prob_include)

        return {
            'decision': decision,
            'confidence': float(confidence),
            'probability_include': float(prob_include),
            'probability_exclude': float(1 - prob_include),
            'method': 'ml',
            'threshold': threshold,
            'requires_manual_review': confidence < 0.7  # Flag uncertain cases
        }

    def _rule_based_screening(self, title: str, abstract: str) -> Dict[str, Any]:
        """
        Rule-based fallback using keyword matching
        """
        text = f"{title} {abstract}".lower()

        if not self.inclusion_criteria:
            return {
                'decision': 'manual_review',
                'confidence': 0.0,
                'method': 'rule_based',
                'note': 'No inclusion criteria set. Set criteria for better screening.'
            }

        # Count criteria matches
        matches = sum(1 for criterion in self.inclusion_criteria if criterion.lower() in text)
        match_ratio = matches / len(self.inclusion_criteria) if self.inclusion_criteria else 0

        if match_ratio >= 0.7:
            decision = 'include'
            confidence = match_ratio
        elif match_ratio <= 0.3:
            decision = 'exclude'
            confidence = 1 - match_ratio
        else:
            decision = 'manual_review'
            confidence = 0.5

        return {
            'decision': decision,
            'confidence': float(confidence),
            'matches': matches,
            'total_criteria': len(self.inclusion_criteria),
            'method': 'rule_based',
            'requires_manual_review': decision == 'manual_review'
        }

    def batch_screen(
        self,
        studies: List[Dict[str, str]],
        threshold: float = 0.5,
        return_uncertain: bool = True
    ) -> Dict[str, Any]:
        """
        Screen multiple studies in batch

        Args:
            studies: List of dicts with 'id', 'title', 'abstract'
            threshold: Decision threshold
            return_uncertain: If True, flag uncertain cases for manual review

        Returns:
            Screening results with statistics
        """
        logger.info(f"Screening {len(studies)} studies...")

        results = []
        for study in studies:
            result = self.screen_study(
                study['title'],
                study.get('abstract', ''),
                threshold
            )
            result['study_id'] = study['id']
            results.append(result)

        # Statistics
        decisions = [r['decision'] for r in results]
        n_include = decisions.count('include')
        n_exclude = decisions.count('exclude')
        n_uncertain = sum(1 for r in results if r.get('requires_manual_review', False))

        logger.info(f"✓ Screened: {n_include} include, {n_exclude} exclude, {n_uncertain} uncertain")

        return {
            'results': results,
            'summary': {
                'total': len(studies),
                'include': n_include,
                'exclude': n_exclude,
                'manual_review': n_uncertain,
                'inclusion_rate': n_include / len(studies) if studies else 0
            }
        }

    def get_active_learning_candidates(
        self,
        studies: List[Dict[str, str]],
        n_candidates: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Get most uncertain studies for active learning

        Args:
            studies: List of unscreened studies
            n_candidates: Number of candidates to return

        Returns:
            Studies ranked by uncertainty for manual review
        """
        if not self.is_trained:
            logger.warning("Classifier not trained, cannot suggest active learning candidates")
            return []

        # Screen all
        results = []
        for study in studies:
            result = self.screen_study(study['title'], study.get('abstract', ''))
            result['study'] = study
            result['uncertainty'] = 1 - abs(result['probability_include'] - 0.5) * 2
            results.append(result)

        # Sort by uncertainty (studies near decision boundary)
        results.sort(key=lambda x: x['uncertainty'], reverse=True)

        return results[:n_candidates]
