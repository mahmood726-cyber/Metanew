"""
Advanced Machine Learning Models for Meta-Analysis
Predictive models for heterogeneity, publication bias, study quality, and effect sizes
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass
from sklearn.ensemble import (
    RandomForestClassifier,
    RandomForestRegressor,
    GradientBoostingClassifier,
    GradientBoostingRegressor
)
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import cross_val_score
import joblib
import logging

logger = logging.getLogger(__name__)


@dataclass
class PredictionResult:
    """Prediction result with confidence and explanation"""
    prediction: Any
    confidence: float
    probability: Optional[float]
    explanation: str
    features_used: List[str]
    model_name: str


class HeterogeneityPredictor:
    """
    Predict whether meta-analysis will show high heterogeneity
    before running the analysis
    """

    def __init__(self):
        self.model = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=5,
            random_state=42
        )
        self.scaler = StandardScaler()
        self.is_trained = False

    def extract_features(self, studies_df: pd.DataFrame) -> Tuple[np.ndarray, List[str]]:
        """
        Extract features from studies data for heterogeneity prediction

        Features:
        - Number of studies
        - Total sample size
        - Sample size variability (CV)
        - Study year range
        - Risk of bias distribution
        - Effect size variability (if available)
        - Intervention type diversity
        - Population diversity
        """
        features = []
        feature_names = []

        # Number of studies
        n_studies = len(studies_df)
        features.append(n_studies)
        feature_names.append('n_studies')

        # Total sample size
        if 'n' in studies_df.columns:
            total_n = studies_df['n'].sum()
            features.append(total_n)
            feature_names.append('total_sample_size')

            # SECURITY FIX: Sample size variability with comprehensive division-by-zero checks
            mean_n = studies_df['n'].mean()
            std_n = studies_df['n'].std()
            if mean_n > 0 and std_n > 0 and not np.isnan(mean_n) and not np.isnan(std_n):
                cv_n = std_n / mean_n
            else:
                cv_n = 0
            features.append(cv_n)
            feature_names.append('sample_size_cv')

            # Min and max sample sizes
            features.append(studies_df['n'].min())
            feature_names.append('min_sample_size')
            features.append(studies_df['n'].max())
            feature_names.append('max_sample_size')
        else:
            features.extend([0, 0, 0, 0])
            feature_names.extend(['total_sample_size', 'sample_size_cv', 'min_sample_size', 'max_sample_size'])

        # Study year range
        if 'year' in studies_df.columns:
            year_range = studies_df['year'].max() - studies_df['year'].min()
            features.append(year_range)
            feature_names.append('year_range')
            features.append(studies_df['year'].mean())
            feature_names.append('mean_year')
        else:
            features.extend([0, 2020])
            feature_names.extend(['year_range', 'mean_year'])

        # Risk of bias distribution
        if 'risk_of_bias' in studies_df.columns:
            rob_counts = studies_df['risk_of_bias'].value_counts()
            pct_low = rob_counts.get('Low', 0) / n_studies
            pct_high = rob_counts.get('High', 0) / n_studies
            features.extend([pct_low, pct_high])
            feature_names.extend(['pct_low_rob', 'pct_high_rob'])
        else:
            features.extend([0, 0])
            feature_names.extend(['pct_low_rob', 'pct_high_rob'])

        # Effect size variability (if yi available)
        if 'yi' in studies_df.columns:
            yi_range = studies_df['yi'].max() - studies_df['yi'].min()
            yi_std = studies_df['yi'].std()
            features.extend([yi_range, yi_std])
            feature_names.extend(['yi_range', 'yi_std'])
        else:
            features.extend([0, 0])
            feature_names.extend(['yi_range', 'yi_std'])

        # Intervention diversity
        if 'treatment' in studies_df.columns:
            n_interventions = studies_df['treatment'].nunique()
            features.append(n_interventions)
            feature_names.append('n_interventions')
        else:
            features.append(1)
            feature_names.append('n_interventions')

        return np.array(features).reshape(1, -1), feature_names

    def train_from_historical_data(self, historical_analyses: List[Dict]):
        """
        Train model from historical meta-analyses

        Args:
            historical_analyses: List of dicts with keys:
                - studies_df: DataFrame of study data
                - i_squared: Observed I² statistic
        """
        X_list = []
        y_list = []

        for analysis in historical_analyses:
            features, _ = self.extract_features(analysis['studies_df'])
            X_list.append(features[0])

            # Label as high heterogeneity if I² > 50%
            y_list.append(1 if analysis['i_squared'] > 50 else 0)

        X = np.array(X_list)
        y = np.array(y_list)

        # Scale features
        X_scaled = self.scaler.fit_transform(X)

        # Train model
        self.model.fit(X_scaled, y)
        self.is_trained = True

        # Cross-validation score
        cv_scores = cross_val_score(self.model, X_scaled, y, cv=5)
        logger.info(f"Heterogeneity predictor trained. CV accuracy: {cv_scores.mean():.3f}")

        return cv_scores.mean()

    def predict(self, studies_df: pd.DataFrame) -> PredictionResult:
        """
        Predict whether meta-analysis will have high heterogeneity

        Returns:
            PredictionResult with prediction, confidence, and explanation
        """
        # Extract features
        X, feature_names = self.extract_features(studies_df)

        # If not trained, use rule-based heuristic
        if not self.is_trained:
            return self._heuristic_prediction(studies_df, feature_names)

        # Scale features
        X_scaled = self.scaler.transform(X)

        # Predict
        prediction = self.model.predict(X_scaled)[0]
        probability = self.model.predict_proba(X_scaled)[0][1]

        # Generate explanation
        if prediction == 1:
            explanation = f"High heterogeneity predicted (probability: {probability:.1%}). "
            explanation += "Factors: "

            # Feature importance
            importances = self.model.feature_importances_
            top_features = np.argsort(importances)[-3:][::-1]

            for idx in top_features:
                explanation += f"{feature_names[idx]}, "
            explanation = explanation.rstrip(', ')
        else:
            explanation = f"Low heterogeneity predicted (probability: {1-probability:.1%}). "
            explanation += "Studies appear relatively homogeneous."

        return PredictionResult(
            prediction='High' if prediction == 1 else 'Low',
            confidence=max(probability, 1-probability),
            probability=probability,
            explanation=explanation,
            features_used=feature_names,
            model_name='GradientBoostingClassifier'
        )

    def _heuristic_prediction(self, studies_df: pd.DataFrame, feature_names: List[str]) -> PredictionResult:
        """Rule-based fallback when ML model not trained"""
        n_studies = len(studies_df)

        # Heuristic rules
        high_het_factors = []

        if n_studies >= 10:
            high_het_factors.append("large number of studies")

        if 'year' in studies_df.columns:
            year_range = studies_df['year'].max() - studies_df['year'].min()
            if year_range > 10:
                high_het_factors.append("wide publication year range")

        if 'n' in studies_df.columns:
            # SECURITY FIX: Safe division with zero checks
            mean_n = studies_df['n'].mean()
            std_n = studies_df['n'].std()
            if mean_n > 0 and std_n > 0:
                cv_n = std_n / mean_n
                if cv_n > 0.5:
                    high_het_factors.append("high sample size variability")

        if 'risk_of_bias' in studies_df.columns:
            if studies_df['risk_of_bias'].nunique() >= 2:
                high_het_factors.append("mixed risk of bias")

        # Prediction
        prediction = 'High' if len(high_het_factors) >= 2 else 'Low'
        confidence = min(0.5 + 0.1 * len(high_het_factors), 0.9)

        if high_het_factors:
            explanation = f"Heterogeneity likely due to: {', '.join(high_het_factors)}"
        else:
            explanation = "Studies appear relatively homogeneous"

        return PredictionResult(
            prediction=prediction,
            confidence=confidence,
            probability=None,
            explanation=explanation + " (rule-based heuristic)",
            features_used=feature_names,
            model_name='RuleBasedHeuristic'
        )

    def save_model(self, path: str):
        """Save trained model"""
        if self.is_trained:
            joblib.dump({
                'model': self.model,
                'scaler': self.scaler
            }, path)
            logger.info(f"Heterogeneity predictor saved to {path}")

    def load_model(self, path: str):
        """Load trained model"""
        data = joblib.load(path)
        self.model = data['model']
        self.scaler = data['scaler']
        self.is_trained = True
        logger.info(f"Heterogeneity predictor loaded from {path}")


class PublicationBiasDetector:
    """
    Machine learning-based publication bias detection
    More sophisticated than traditional Egger's test
    """

    def __init__(self):
        self.model = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=4,
            random_state=42
        )
        self.scaler = StandardScaler()
        self.is_trained = False

    def extract_features(self, studies_df: pd.DataFrame) -> Tuple[np.ndarray, List[str]]:
        """
        Extract features for publication bias detection

        Features:
        - Funnel plot asymmetry metrics
        - Small study effects
        - Excess significance test
        - P-value distribution
        - Effect size-precision correlation
        """
        features = []
        feature_names = []

        if 'yi' not in studies_df.columns or 'sei' not in studies_df.columns:
            # Cannot assess without effect sizes
            return np.array([[0] * 10]), ['dummy'] * 10

        yi = studies_df['yi'].values
        sei = studies_df['sei'].values
        vi = sei ** 2

        # 1. Funnel plot asymmetry (regression of yi on 1/sei)
        if len(yi) >= 3:
            precision = 1 / sei
            from scipy.stats import linregress
            slope, intercept, r_value, p_value, std_err = linregress(precision, yi)
            features.extend([slope, intercept, abs(r_value), p_value])
            feature_names.extend(['funnel_slope', 'funnel_intercept', 'funnel_r', 'funnel_p'])
        else:
            features.extend([0, 0, 0, 1])
            feature_names.extend(['funnel_slope', 'funnel_intercept', 'funnel_r', 'funnel_p'])

        # 2. Small study correlation (Spearman correlation between |yi| and sei)
        if len(yi) >= 3:
            from scipy.stats import spearmanr
            corr, p_val = spearmanr(np.abs(yi), sei)
            features.extend([corr, p_val])
            feature_names.extend(['small_study_corr', 'small_study_p'])
        else:
            features.extend([0, 1])
            feature_names.extend(['small_study_corr', 'small_study_p'])

        # 3. Excess significance (are there more significant studies than expected?)
        z_scores = np.abs(yi / sei)
        n_significant = np.sum(z_scores > 1.96)
        pct_significant = n_significant / len(yi)
        features.extend([n_significant, pct_significant])
        feature_names.extend(['n_significant', 'pct_significant'])

        # 4. Skewness of effect sizes
        from scipy.stats import skew
        yi_skewness = skew(yi) if len(yi) >= 3 else 0
        features.append(yi_skewness)
        feature_names.append('yi_skewness')

        # 5. Ratio of large to small studies
        median_n = studies_df.get('n', pd.Series([100]*len(studies_df))).median()
        large_studies = studies_df[studies_df.get('n', pd.Series([100]*len(studies_df))) >= median_n]
        pct_large = len(large_studies) / len(studies_df) if len(studies_df) > 0 else 0.5
        features.append(pct_large)
        feature_names.append('pct_large_studies')

        return np.array(features).reshape(1, -1), feature_names

    def predict(self, studies_df: pd.DataFrame) -> PredictionResult:
        """
        Predict presence of publication bias

        Returns:
            PredictionResult with bias assessment
        """
        X, feature_names = self.extract_features(studies_df)

        # If not trained, use rule-based approach
        if not self.is_trained:
            return self._rule_based_bias_detection(studies_df, X, feature_names)

        X_scaled = self.scaler.transform(X)
        prediction = self.model.predict(X_scaled)[0]
        probability = self.model.predict_proba(X_scaled)[0][1]

        explanation = self._generate_bias_explanation(X[0], feature_names, probability)

        return PredictionResult(
            prediction='Likely' if prediction == 1 else 'Unlikely',
            confidence=max(probability, 1-probability),
            probability=probability,
            explanation=explanation,
            features_used=feature_names,
            model_name='PublicationBiasML'
        )

    def _rule_based_bias_detection(self, studies_df: pd.DataFrame, X: np.ndarray,
                                   feature_names: List[str]) -> PredictionResult:
        """Rule-based publication bias detection"""
        bias_indicators = []

        # Check funnel plot asymmetry
        if len(feature_names) > 3:
            funnel_p = X[0][3]
            if funnel_p < 0.10:
                bias_indicators.append("funnel plot asymmetry")

        # Check small study effects
        if len(feature_names) > 5:
            small_study_p = X[0][5]
            if small_study_p < 0.10:
                bias_indicators.append("small study effects")

        # Check excess significance
        if len(feature_names) > 7:
            pct_sig = X[0][7]
            if pct_sig > 0.8:  # >80% significant studies is suspicious
                bias_indicators.append("excess significance")

        # Prediction
        prediction = 'Likely' if len(bias_indicators) >= 2 else 'Unlikely'
        confidence = min(0.5 + 0.15 * len(bias_indicators), 0.9)

        if bias_indicators:
            explanation = f"Publication bias indicated by: {', '.join(bias_indicators)}"
        else:
            explanation = "No strong evidence of publication bias"

        return PredictionResult(
            prediction=prediction,
            confidence=confidence,
            probability=None,
            explanation=explanation + " (rule-based)",
            features_used=feature_names,
            model_name='RuleBasedBiasDetection'
        )

    def _generate_bias_explanation(self, features: np.ndarray, feature_names: List[str],
                                   probability: float) -> str:
        """Generate detailed explanation of bias assessment"""
        explanation = f"Publication bias probability: {probability:.1%}. "

        # Analyze key features
        key_features = {
            'funnel_p': 3,
            'small_study_p': 5,
            'pct_significant': 7
        }

        concerns = []
        for feat_name, idx in key_features.items():
            if idx < len(features):
                val = features[idx]
                if feat_name.endswith('_p') and val < 0.10:
                    concerns.append(feat_name.replace('_p', ''))
                elif feat_name == 'pct_significant' and val > 0.75:
                    concerns.append('excess significance')

        if concerns:
            explanation += f"Concerns: {', '.join(concerns)}. "

        explanation += "Consider trim-and-fill or selection models."

        return explanation


class StudyQualityPredictor:
    """
    Predict study quality/risk of bias from study characteristics
    """

    def __init__(self):
        self.model = RandomForestClassifier(
            n_estimators=100,
            max_depth=6,
            random_state=42
        )
        self.is_trained = False

    def extract_features(self, study: Dict) -> Tuple[np.ndarray, List[str]]:
        """
        Extract features for quality prediction

        Features:
        - Sample size
        - Year (newer studies generally higher quality)
        - Funding source (if available)
        - Study design (RCT vs observational)
        - Blinding status
        - Allocation concealment
        - Completeness of outcome data
        """
        features = []
        feature_names = []

        # Sample size
        n = study.get('n', 100)
        features.append(n)
        features.append(1 if n >= 100 else 0)
        feature_names.extend(['sample_size', 'large_sample'])

        # Publication year
        year = study.get('year', 2020)
        features.append(year)
        features.append(1 if year >= 2015 else 0)
        feature_names.extend(['year', 'recent_study'])

        # Study design
        design = study.get('study_design', 'RCT')
        features.append(1 if design == 'RCT' else 0)
        feature_names.append('is_rct')

        # Multi-center
        features.append(1 if study.get('multicenter', False) else 0)
        feature_names.append('multicenter')

        # Registered
        features.append(1 if study.get('registered', False) else 0)
        feature_names.append('registered')

        # Industry funded (may introduce bias)
        features.append(1 if study.get('industry_funded', False) else 0)
        feature_names.append('industry_funded')

        return np.array(features).reshape(1, -1), feature_names

    def predict(self, study: Dict) -> PredictionResult:
        """Predict study quality/risk of bias"""
        X, feature_names = self.extract_features(study)

        # Rule-based prediction (no historical data needed)
        return self._rule_based_quality(study, X[0], feature_names)

    def _rule_based_quality(self, study: Dict, features: np.ndarray,
                           feature_names: List[str]) -> PredictionResult:
        """Rule-based quality assessment"""
        quality_points = 0
        max_points = 0
        explanations = []

        # Sample size (0-2 points)
        n = features[0]
        if n >= 500:
            quality_points += 2
            explanations.append("large sample (n≥500)")
        elif n >= 100:
            quality_points += 1
            explanations.append("adequate sample (n≥100)")
        max_points += 2

        # Recent study (0-1 point)
        if features[3] == 1:
            quality_points += 1
            explanations.append("recent study (≥2015)")
        max_points += 1

        # RCT (0-2 points)
        if features[4] == 1:
            quality_points += 2
            explanations.append("randomized controlled trial")
        max_points += 2

        # Multicenter (0-1 point)
        if features[5] == 1:
            quality_points += 1
            explanations.append("multicenter study")
        max_points += 1

        # Registered (0-1 point)
        if features[6] == 1:
            quality_points += 1
            explanations.append("pre-registered")
        max_points += 1

        # Industry funding (subtract if present)
        if features[7] == 1:
            quality_points -= 1
            explanations.append("industry funded (potential bias)")

        # Calculate quality score
        quality_score = max(quality_points, 0) / max_points if max_points > 0 else 0.5

        if quality_score >= 0.75:
            prediction = 'Low Risk'
            confidence = 0.85
        elif quality_score >= 0.5:
            prediction = 'Moderate Risk'
            confidence = 0.70
        else:
            prediction = 'High Risk'
            confidence = 0.75

        explanation = f"Quality score: {quality_score:.2f}. " + ", ".join(explanations)

        return PredictionResult(
            prediction=prediction,
            confidence=confidence,
            probability=quality_score,
            explanation=explanation,
            features_used=feature_names,
            model_name='RuleBasedQuality'
        )


class EffectSizePredictor:
    """
    Predict likely effect size range before conducting meta-analysis
    Based on study characteristics
    """

    def __init__(self):
        self.model = RandomForestRegressor(
            n_estimators=100,
            max_depth=6,
            random_state=42
        )
        self.is_trained = False

    def predict_effect_direction(self, studies_df: pd.DataFrame) -> PredictionResult:
        """
        Predict whether treatment effect is likely beneficial, harmful, or neutral
        """
        if 'yi' not in studies_df.columns:
            return PredictionResult(
                prediction='Unknown',
                confidence=0.0,
                probability=None,
                explanation="Effect sizes not yet computed",
                features_used=[],
                model_name='EffectDirectionPredictor'
            )

        # Analyze available effect sizes
        yi = studies_df['yi'].values
        sei = studies_df['sei'].values

        # Weight by inverse variance
        weights = 1 / (sei ** 2)
        weighted_mean = np.average(yi, weights=weights)

        # Confidence interval
        se_pooled = np.sqrt(1 / np.sum(weights))
        ci_lower = weighted_mean - 1.96 * se_pooled
        ci_upper = weighted_mean + 1.96 * se_pooled

        # Prediction
        if ci_lower > 0:
            prediction = 'Beneficial'
            confidence = 0.95
            explanation = f"Pooled effect favors treatment (weighted mean: {weighted_mean:.3f}, 95% CI: [{ci_lower:.3f}, {ci_upper:.3f}])"
        elif ci_upper < 0:
            prediction = 'Harmful'
            confidence = 0.95
            explanation = f"Pooled effect favors control (weighted mean: {weighted_mean:.3f}, 95% CI: [{ci_lower:.3f}, {ci_upper:.3f}])"
        elif abs(weighted_mean) < 0.1:
            prediction = 'Null'
            confidence = 0.70
            explanation = f"Effect size very close to null (weighted mean: {weighted_mean:.3f})"
        else:
            prediction = 'Uncertain'
            confidence = 0.50
            explanation = f"Confidence interval crosses null (weighted mean: {weighted_mean:.3f}, 95% CI: [{ci_lower:.3f}, {ci_upper:.3f}])"

        return PredictionResult(
            prediction=prediction,
            confidence=confidence,
            probability=None,
            explanation=explanation,
            features_used=['yi', 'sei'],
            model_name='EffectDirectionPredictor'
        )


# Initialize global predictors
heterogeneity_predictor = HeterogeneityPredictor()
publication_bias_detector = PublicationBiasDetector()
study_quality_predictor = StudyQualityPredictor()
effect_size_predictor = EffectSizePredictor()
