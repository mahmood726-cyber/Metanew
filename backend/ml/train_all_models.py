"""
Integrated ML Training Pipeline

Train all EvidenceOS ML models with one command.

Features:
- Train all 4 ML models sequentially
- Save trained models to disk
- Generate training reports
- Cross-validation and evaluation
- Model comparison

Usage:
    python backend/ml/train_all_models.py

V2.8 ENHANCEMENT - Training Infrastructure

Author: EvidenceOS PRIME
License: MIT
"""

import sys
from pathlib import Path
import json
from datetime import datetime
import warnings

# Suppress sklearn warnings during training
warnings.filterwarnings('ignore', category=UserWarning)

try:
    from .pico_extractor_ml import MLPICOExtractor
    from .risk_of_bias_classifier import MLRiskOfBiasClassifier
    from .heterogeneity_predictor import MLHeterogeneityPredictor
    from .effect_size_estimator import MLEffectSizeEstimator
except ImportError:
    # For direct execution
    from pico_extractor_ml import MLPICOExtractor
    from risk_of_bias_classifier import MLRiskOfBiasClassifier
    from heterogeneity_predictor import MLHeterogeneityPredictor
    from effect_size_estimator import MLEffectSizeEstimator


class IntegratedMLTrainingPipeline:
    """
    Integrated training pipeline for all EvidenceOS ML models

    Trains:
    1. PICO Extractor (NLP + TF-IDF)
    2. Risk of Bias Classifier (RF + GB ensemble)
    3. Heterogeneity Predictor (GB regression)
    4. Effect Size Estimator (GB regression)

    Examples:
        >>> pipeline = IntegratedMLTrainingPipeline()
        >>> results = pipeline.train_all()
        >>> pipeline.save_models('models/')
        >>> pipeline.generate_report('training_report.json')
    """

    def __init__(self, verbose: bool = True):
        self.verbose = verbose
        self.models = {}
        self.training_results = {}
        self.timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    def train_all(self) -> dict:
        """
        Train all ML models sequentially

        Returns:
            Dictionary with training results for each model
        """
        print("=" * 80)
        print("EVIDENCEOS ML TRAINING PIPELINE")
        print("=" * 80)
        print(f"Started: {self.timestamp}\n")

        # Create models directory
        Path('models').mkdir(exist_ok=True)

        # Train each model
        self._train_pico_extractor()
        self._train_rob_classifier()
        self._train_heterogeneity_predictor()
        self._train_effect_size_estimator()

        # Summary
        self._print_summary()

        return self.training_results

    def _train_pico_extractor(self):
        """Train PICO Extractor"""
        if self.verbose:
            print("\n" + "=" * 80)
            print("1/4: TRAINING PICO EXTRACTOR")
            print("=" * 80 + "\n")

        try:
            model = MLPICOExtractor()
            metrics = model.train_from_dataset('data/real_datasets/pico_training.json')

            self.models['pico_extractor'] = model
            self.training_results['pico_extractor'] = {
                'status': 'success',
                'metrics': metrics,
                'training_data': 'pico_training.json (100 abstracts)'
            }

            if self.verbose:
                print("\n✅ PICO Extractor trained successfully")
                if metrics:
                    print(f"   Accuracy: {metrics.get('accuracy', 'N/A')}")

        except Exception as e:
            print(f"\n❌ PICO Extractor training failed: {e}")
            self.training_results['pico_extractor'] = {
                'status': 'failed',
                'error': str(e)
            }

    def _train_rob_classifier(self):
        """Train Risk of Bias Classifier"""
        if self.verbose:
            print("\n" + "=" * 80)
            print("2/4: TRAINING RISK OF BIAS CLASSIFIER")
            print("=" * 80 + "\n")

        try:
            model = MLRiskOfBiasClassifier()
            metrics = model.train_from_dataset('data/real_datasets/mortality_ma.csv')

            self.models['rob_classifier'] = model
            self.training_results['rob_classifier'] = {
                'status': 'success',
                'metrics': metrics,
                'training_data': 'mortality_ma.csv (50 RCTs)'
            }

            if self.verbose:
                print(f"\n✅ Risk of Bias Classifier trained successfully")
                if metrics:
                    print(f"   Overall accuracy: {metrics.get('overall_accuracy', 'N/A'):.1%}")

        except Exception as e:
            print(f"\n❌ Risk of Bias Classifier training failed: {e}")
            import traceback
            traceback.print_exc()
            self.training_results['rob_classifier'] = {
                'status': 'failed',
                'error': str(e)
            }

    def _train_heterogeneity_predictor(self):
        """Train Heterogeneity Predictor"""
        if self.verbose:
            print("\n" + "=" * 80)
            print("3/4: TRAINING HETEROGENEITY PREDICTOR")
            print("=" * 80 + "\n")

        try:
            model = MLHeterogeneityPredictor()
            metrics = model.train_from_simulated_data(n_samples=1000)

            self.models['heterogeneity_predictor'] = model
            self.training_results['heterogeneity_predictor'] = {
                'status': 'success',
                'metrics': metrics,
                'training_data': '1,000 simulated meta-analyses'
            }

            if self.verbose:
                print(f"\n✅ Heterogeneity Predictor trained successfully")
                if metrics:
                    print(f"   RMSE: {metrics.get('rmse', 'N/A'):.2f}%")
                    print(f"   R²: {metrics.get('r2', 'N/A'):.3f}")

        except Exception as e:
            print(f"\n❌ Heterogeneity Predictor training failed: {e}")
            import traceback
            traceback.print_exc()
            self.training_results['heterogeneity_predictor'] = {
                'status': 'failed',
                'error': str(e)
            }

    def _train_effect_size_estimator(self):
        """Train Effect Size Estimator"""
        if self.verbose:
            print("\n" + "=" * 80)
            print("4/4: TRAINING EFFECT SIZE ESTIMATOR")
            print("=" * 80 + "\n")

        try:
            model = MLEffectSizeEstimator()
            metrics = model.train_from_dataset('data/real_datasets/mortality_ma.csv', effect_type='HR')

            self.models['effect_size_estimator'] = model
            self.training_results['effect_size_estimator'] = {
                'status': 'success',
                'metrics': metrics,
                'training_data': 'mortality_ma.csv (50 RCTs)'
            }

            if self.verbose:
                print(f"\n✅ Effect Size Estimator trained successfully")
                if metrics:
                    print(f"   RMSE (log scale): {metrics.get('rmse', 'N/A'):.3f}")
                    print(f"   R²: {metrics.get('r2', 'N/A'):.3f}")

        except Exception as e:
            print(f"\n❌ Effect Size Estimator training failed: {e}")
            import traceback
            traceback.print_exc()
            self.training_results['effect_size_estimator'] = {
                'status': 'failed',
                'error': str(e)
            }

    def save_models(self, output_dir: str = 'models'):
        """
        Save all trained models to disk

        Args:
            output_dir: Directory to save models
        """
        print("\n" + "=" * 80)
        print("SAVING TRAINED MODELS")
        print("=" * 80 + "\n")

        Path(output_dir).mkdir(exist_ok=True)

        for model_name, model in self.models.items():
            try:
                filepath = f"{output_dir}/{model_name}.pkl"
                model.save_model(filepath)
                print(f"   ✅ Saved: {filepath}")
            except Exception as e:
                print(f"   ❌ Failed to save {model_name}: {e}")

    def generate_report(self, output_path: str = 'training_report.json'):
        """
        Generate comprehensive training report

        Args:
            output_path: Path to save report
        """
        print("\n" + "=" * 80)
        print("GENERATING TRAINING REPORT")
        print("=" * 80 + "\n")

        report = {
            'timestamp': self.timestamp,
            'models_trained': len(self.models),
            'models': self.training_results,
            'summary': self._generate_summary()
        }

        with open(output_path, 'w') as f:
            json.dump(report, f, indent=2)

        print(f"   ✅ Report saved: {output_path}")

    def _generate_summary(self) -> dict:
        """Generate summary statistics"""
        successful = sum(1 for r in self.training_results.values() if r['status'] == 'success')
        failed = len(self.training_results) - successful

        return {
            'total_models': len(self.training_results),
            'successful': successful,
            'failed': failed,
            'success_rate': f"{(successful / len(self.training_results)) * 100:.0f}%"
        }

    def _print_summary(self):
        """Print training summary"""
        print("\n" + "=" * 80)
        print("TRAINING SUMMARY")
        print("=" * 80 + "\n")

        summary = self._generate_summary()
        print(f"Total models: {summary['total_models']}")
        print(f"Successful: {summary['successful']}")
        print(f"Failed: {summary['failed']}")
        print(f"Success rate: {summary['success_rate']}\n")

        print("Model Details:")
        for model_name, result in self.training_results.items():
            status_icon = "✅" if result['status'] == 'success' else "❌"
            print(f"  {status_icon} {model_name}: {result['status']}")
            if result['status'] == 'success':
                print(f"     Training data: {result['training_data']}")

        print("\n" + "=" * 80)
        print("TRAINING COMPLETE")
        print("=" * 80)


def main():
    """Main training function"""
    pipeline = IntegratedMLTrainingPipeline(verbose=True)

    # Train all models
    results = pipeline.train_all()

    # Save models
    pipeline.save_models('models/')

    # Generate report
    pipeline.generate_report('training_report.json')

    # Print final status
    print("\n🎉 All models trained and saved!")
    print("\nNext steps:")
    print("  1. Review training_report.json for detailed metrics")
    print("  2. Load models with: model.load_model('models/model_name.pkl')")
    print("  3. Use models in production workflows")


if __name__ == "__main__":
    main()
