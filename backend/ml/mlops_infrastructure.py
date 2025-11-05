"""
MLOps Infrastructure for Production ML Models
Implements experiment tracking, model versioning, drift detection
Based on 2025 healthcare ML best practices
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime
import logging
import json
import hashlib
from pathlib import Path
import pickle

logger = logging.getLogger(__name__)

# MLflow for experiment tracking
try:
    import mlflow
    import mlflow.sklearn
    MLFLOW_AVAILABLE = True
except ImportError:
    MLFLOW_AVAILABLE = False
    logger.warning("MLflow not installed. Install with: pip install mlflow")

# Evidently for drift detection
try:
    from evidently.test_suite import TestSuite
    from evidently.tests import (
        TestNumberOfColumnsWithMissingValues,
        TestNumberOfRowsWithMissingValues,
        TestNumberOfConstantColumns,
        TestNumberOfDuplicatedRows,
        TestNumberOfDuplicatedColumns,
        TestColumnsType,
        TestNumberOfDriftedColumns,
    )
    from evidently.report import Report
    from evidently.metrics import (
        DataDriftTable,
        DatasetDriftMetric,
        DatasetMissingValuesMetric,
    )
    EVIDENTLY_AVAILABLE = True
except ImportError:
    EVIDENTLY_AVAILABLE = False
    logger.warning("Evidently not installed. Install with: pip install evidently")

# Statistical drift detection
from scipy import stats
from sklearn.metrics import roc_auc_score, accuracy_score


@dataclass
class ExperimentMetrics:
    """Metrics for an ML experiment"""
    experiment_id: str
    run_id: str
    timestamp: str
    model_name: str
    parameters: Dict[str, Any]
    metrics: Dict[str, float]
    tags: Dict[str, str]


@dataclass
class ModelVersion:
    """Model version information"""
    version_id: str
    model_name: str
    timestamp: str
    performance: Dict[str, float]
    metadata: Dict[str, Any]
    model_path: str
    is_production: bool = False


@dataclass
class DriftReport:
    """Drift detection report"""
    timestamp: str
    n_features: int
    n_features_drifted: int
    drift_detected: bool
    drift_score: float
    feature_drift: Dict[str, Dict[str, Any]]
    prediction_drift: Optional[Dict[str, Any]]
    recommendation: str


class ExperimentTracker:
    """
    Experiment tracking for ML models
    Supports MLflow or fallback to local JSON storage
    """

    def __init__(self, tracking_uri: Optional[str] = None,
                 experiment_name: str = "meta_analysis_ml",
                 local_storage_path: str = "./data/experiments"):
        """
        Initialize experiment tracker

        Args:
            tracking_uri: MLflow tracking server URI
            experiment_name: Name of experiment
            local_storage_path: Path for local JSON storage (fallback)
        """
        self.experiment_name = experiment_name
        self.local_storage_path = Path(local_storage_path)
        self.local_storage_path.mkdir(parents=True, exist_ok=True)

        # Initialize MLflow if available
        if MLFLOW_AVAILABLE:
            try:
                if tracking_uri:
                    mlflow.set_tracking_uri(tracking_uri)

                mlflow.set_experiment(experiment_name)
                self.mlflow_enabled = True
                logger.info(f"✓ MLflow experiment tracking enabled: {experiment_name}")
            except Exception as e:
                logger.error(f"Failed to initialize MLflow: {str(e)}")
                self.mlflow_enabled = False
        else:
            self.mlflow_enabled = False
            logger.info("Using local JSON storage for experiments")

    def start_run(self, run_name: Optional[str] = None,
                  tags: Optional[Dict[str, str]] = None) -> str:
        """
        Start experiment run

        Args:
            run_name: Name for this run
            tags: Tags for the run

        Returns:
            Run ID
        """
        tags = tags or {}
        timestamp = datetime.now().isoformat()

        if self.mlflow_enabled:
            mlflow.start_run(run_name=run_name)
            run_id = mlflow.active_run().info.run_id

            # Log tags
            for key, value in tags.items():
                mlflow.set_tag(key, value)

            logger.info(f"✓ MLflow run started: {run_id}")
            return run_id
        else:
            # Generate local run ID
            run_id = hashlib.md5(f"{run_name}_{timestamp}".encode()).hexdigest()[:8]
            logger.info(f"✓ Local run started: {run_id}")
            return run_id

    def log_params(self, params: Dict[str, Any]):
        """Log hyperparameters"""
        if self.mlflow_enabled:
            mlflow.log_params(params)
        else:
            # Store locally
            run_id = self._get_current_run_id()
            self._save_to_local(run_id, 'params', params)

    def log_metrics(self, metrics: Dict[str, float], step: Optional[int] = None):
        """Log metrics"""
        if self.mlflow_enabled:
            mlflow.log_metrics(metrics, step=step)
        else:
            run_id = self._get_current_run_id()
            self._save_to_local(run_id, 'metrics', metrics)

    def log_model(self, model: Any, model_name: str):
        """Log trained model"""
        if self.mlflow_enabled:
            mlflow.sklearn.log_model(model, model_name)
        else:
            run_id = self._get_current_run_id()
            model_path = self.local_storage_path / f"run_{run_id}" / f"{model_name}.pkl"
            model_path.parent.mkdir(parents=True, exist_ok=True)

            with open(model_path, 'wb') as f:
                pickle.dump(model, f)

            logger.info(f"Model saved to {model_path}")

    def log_artifact(self, artifact_path: str, artifact_name: Optional[str] = None):
        """Log artifact file"""
        if self.mlflow_enabled:
            mlflow.log_artifact(artifact_path)
        else:
            run_id = self._get_current_run_id()
            # Copy artifact to run directory
            import shutil
            artifact_name = artifact_name or Path(artifact_path).name
            dest = self.local_storage_path / f"run_{run_id}" / "artifacts" / artifact_name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(artifact_path, dest)

    def end_run(self):
        """End experiment run"""
        if self.mlflow_enabled:
            mlflow.end_run()
        logger.info("Run ended")

    def _get_current_run_id(self) -> str:
        """Get current run ID"""
        if self.mlflow_enabled and mlflow.active_run():
            return mlflow.active_run().info.run_id
        else:
            return datetime.now().strftime("%Y%m%d_%H%M%S")

    def _save_to_local(self, run_id: str, data_type: str, data: Any):
        """Save data to local JSON"""
        run_dir = self.local_storage_path / f"run_{run_id}"
        run_dir.mkdir(parents=True, exist_ok=True)

        file_path = run_dir / f"{data_type}.json"

        # Load existing data
        if file_path.exists():
            with open(file_path, 'r') as f:
                existing = json.load(f)
        else:
            existing = {}

        # Merge
        existing.update(data)

        # Save
        with open(file_path, 'w') as f:
            json.dump(existing, f, indent=2, default=str)

    def get_best_run(self, metric_name: str = "auc",
                     ascending: bool = False) -> Optional[ExperimentMetrics]:
        """
        Get best run based on metric

        Args:
            metric_name: Metric to optimize
            ascending: If True, lower is better

        Returns:
            Best run metrics
        """
        if self.mlflow_enabled:
            try:
                experiment = mlflow.get_experiment_by_name(self.experiment_name)
                runs = mlflow.search_runs(
                    experiment_ids=[experiment.experiment_id],
                    order_by=[f"metrics.{metric_name} {'ASC' if ascending else 'DESC'}"],
                    max_results=1
                )

                if not runs.empty:
                    run = runs.iloc[0]
                    return ExperimentMetrics(
                        experiment_id=run['experiment_id'],
                        run_id=run['run_id'],
                        timestamp=run['start_time'],
                        model_name=run.get('tags.model_name', 'unknown'),
                        parameters={k.replace('params.', ''): v for k, v in run.items() if k.startswith('params.')},
                        metrics={k.replace('metrics.', ''): v for k, v in run.items() if k.startswith('metrics.')},
                        tags={k.replace('tags.', ''): v for k, v in run.items() if k.startswith('tags.')}
                    )
            except Exception as e:
                logger.error(f"Failed to get best run: {str(e)}")

        return None


class ModelRegistry:
    """
    Model version management and registry
    Tracks model versions, performance, and production status
    """

    def __init__(self, registry_path: str = "./data/model_registry"):
        """
        Initialize model registry

        Args:
            registry_path: Path to registry storage
        """
        self.registry_path = Path(registry_path)
        self.registry_path.mkdir(parents=True, exist_ok=True)
        self.models_path = self.registry_path / "models"
        self.models_path.mkdir(parents=True, exist_ok=True)

        self.registry_file = self.registry_path / "registry.json"
        self.registry = self._load_registry()

    def _load_registry(self) -> Dict[str, List[ModelVersion]]:
        """Load registry from file"""
        if self.registry_file.exists():
            with open(self.registry_file, 'r') as f:
                data = json.load(f)
                # Convert to ModelVersion objects
                registry = {}
                for model_name, versions in data.items():
                    registry[model_name] = [
                        ModelVersion(**v) for v in versions
                    ]
                return registry
        return {}

    def _save_registry(self):
        """Save registry to file"""
        data = {}
        for model_name, versions in self.registry.items():
            data[model_name] = [asdict(v) for v in versions]

        with open(self.registry_file, 'w') as f:
            json.dump(data, f, indent=2)

    def register_model(self, model_name: str, model: Any,
                      performance: Dict[str, float],
                      metadata: Optional[Dict[str, Any]] = None) -> ModelVersion:
        """
        Register new model version

        Args:
            model_name: Name of model
            model: Trained model object
            performance: Performance metrics
            metadata: Additional metadata

        Returns:
            ModelVersion object
        """
        metadata = metadata or {}
        timestamp = datetime.now().isoformat()

        # Generate version ID
        version_id = f"v{len(self.registry.get(model_name, [])) + 1}_{timestamp[:10]}"

        # Save model
        model_path = self.models_path / f"{model_name}_{version_id}.pkl"
        with open(model_path, 'wb') as f:
            pickle.dump(model, f)

        # Create version
        version = ModelVersion(
            version_id=version_id,
            model_name=model_name,
            timestamp=timestamp,
            performance=performance,
            metadata=metadata,
            model_path=str(model_path),
            is_production=False
        )

        # Add to registry
        if model_name not in self.registry:
            self.registry[model_name] = []
        self.registry[model_name].append(version)

        self._save_registry()

        logger.info(f"✓ Model registered: {model_name} {version_id} (AUC: {performance.get('auc', 'N/A')})")

        return version

    def promote_to_production(self, model_name: str, version_id: str):
        """Promote model version to production"""
        if model_name not in self.registry:
            raise ValueError(f"Model {model_name} not found")

        # Demote all versions
        for version in self.registry[model_name]:
            version.is_production = False

        # Promote specified version
        version_to_promote = None
        for version in self.registry[model_name]:
            if version.version_id == version_id:
                version.is_production = True
                version_to_promote = version
                break

        if not version_to_promote:
            raise ValueError(f"Version {version_id} not found")

        self._save_registry()

        logger.info(f"✓ Promoted to production: {model_name} {version_id}")

    def get_production_model(self, model_name: str) -> Optional[Any]:
        """Load production model"""
        if model_name not in self.registry:
            return None

        for version in self.registry[model_name]:
            if version.is_production:
                with open(version.model_path, 'rb') as f:
                    return pickle.load(f)

        return None

    def list_versions(self, model_name: str) -> List[ModelVersion]:
        """List all versions of a model"""
        return self.registry.get(model_name, [])


class DriftDetector:
    """
    Drift detection for ML models in production
    Detects concept drift, data drift, and prediction drift
    """

    def __init__(self):
        """Initialize drift detector"""
        self.reference_data = None
        self.reference_predictions = None
        self.feature_names = None

    def set_reference(self, X: np.ndarray, y_pred: Optional[np.ndarray] = None,
                     feature_names: Optional[List[str]] = None):
        """
        Set reference data (training or baseline production data)

        Args:
            X: Feature matrix
            y_pred: Model predictions (optional)
            feature_names: Feature names
        """
        self.reference_data = X
        self.reference_predictions = y_pred
        self.feature_names = feature_names or [f"feature_{i}" for i in range(X.shape[1])]

        logger.info(f"✓ Reference data set: {X.shape[0]} samples, {X.shape[1]} features")

    def detect_drift(self, X_new: np.ndarray, y_pred_new: Optional[np.ndarray] = None,
                    threshold: float = 0.05) -> DriftReport:
        """
        Detect drift between reference and new data

        Args:
            X_new: New feature data
            y_pred_new: New predictions (optional)
            threshold: P-value threshold for drift detection

        Returns:
            DriftReport with detailed drift information
        """
        if self.reference_data is None:
            raise ValueError("Reference data not set. Call set_reference() first.")

        timestamp = datetime.now().isoformat()

        # Feature drift detection
        feature_drift = self._detect_feature_drift(X_new, threshold)

        n_drifted = sum(1 for f in feature_drift.values() if f['drift_detected'])
        drift_score = n_drifted / len(feature_drift) if feature_drift else 0

        # Prediction drift detection
        prediction_drift = None
        if self.reference_predictions is not None and y_pred_new is not None:
            prediction_drift = self._detect_prediction_drift(y_pred_new)

        # Overall drift assessment
        drift_detected = drift_score > 0.2  # More than 20% of features drifted

        # Recommendation
        recommendation = self._generate_recommendation(drift_score, prediction_drift)

        report = DriftReport(
            timestamp=timestamp,
            n_features=len(self.feature_names),
            n_features_drifted=n_drifted,
            drift_detected=drift_detected,
            drift_score=drift_score,
            feature_drift=feature_drift,
            prediction_drift=prediction_drift,
            recommendation=recommendation
        )

        if drift_detected:
            logger.warning(f"⚠️ Drift detected! {n_drifted}/{len(feature_drift)} features drifted")
        else:
            logger.info(f"✓ No significant drift detected ({n_drifted}/{len(feature_drift)} features)")

        return report

    def _detect_feature_drift(self, X_new: np.ndarray, threshold: float) -> Dict[str, Dict[str, Any]]:
        """Detect drift for each feature using Kolmogorov-Smirnov test"""
        feature_drift = {}

        for i, feature_name in enumerate(self.feature_names):
            ref_values = self.reference_data[:, i]
            new_values = X_new[:, i]

            # KS test
            ks_statistic, p_value = stats.ks_2samp(ref_values, new_values)

            # Drift detected if p-value < threshold
            drift_detected = p_value < threshold

            # Compute distribution statistics
            ref_mean, ref_std = ref_values.mean(), ref_values.std()
            new_mean, new_std = new_values.mean(), new_values.std()

            feature_drift[feature_name] = {
                'drift_detected': bool(drift_detected),
                'ks_statistic': float(ks_statistic),
                'p_value': float(p_value),
                'ref_mean': float(ref_mean),
                'ref_std': float(ref_std),
                'new_mean': float(new_mean),
                'new_std': float(new_std),
                'mean_shift': float(abs(new_mean - ref_mean) / ref_std if ref_std > 0 else 0)
            }

        return feature_drift

    def _detect_prediction_drift(self, y_pred_new: np.ndarray) -> Dict[str, Any]:
        """Detect drift in prediction distribution"""
        # Compare prediction distributions
        ks_statistic, p_value = stats.ks_2samp(self.reference_predictions, y_pred_new)

        ref_mean = self.reference_predictions.mean()
        new_mean = y_pred_new.mean()

        return {
            'ks_statistic': float(ks_statistic),
            'p_value': float(p_value),
            'drift_detected': bool(p_value < 0.05),
            'ref_mean_prediction': float(ref_mean),
            'new_mean_prediction': float(new_mean),
            'shift': float(new_mean - ref_mean)
        }

    def _generate_recommendation(self, drift_score: float,
                                 prediction_drift: Optional[Dict[str, Any]]) -> str:
        """Generate recommendation based on drift analysis"""
        recommendations = []

        if drift_score > 0.5:
            recommendations.append(
                "CRITICAL: Major drift detected (>50% features). "
                "Model retraining strongly recommended."
            )
        elif drift_score > 0.2:
            recommendations.append(
                "WARNING: Moderate drift detected (>20% features). "
                "Consider model retraining soon."
            )
        else:
            recommendations.append(
                "INFO: Minimal drift detected. Continue monitoring."
            )

        if prediction_drift and prediction_drift['drift_detected']:
            recommendations.append(
                f"Prediction distribution has shifted (mean: "
                f"{prediction_drift['ref_mean_prediction']:.3f} → "
                f"{prediction_drift['new_mean_prediction']:.3f}). "
                "Validate model performance on new data."
            )

        return " ".join(recommendations)


# Global instances
_experiment_tracker: Optional[ExperimentTracker] = None
_model_registry: Optional[ModelRegistry] = None
_drift_detector: Optional[DriftDetector] = None


def get_experiment_tracker() -> ExperimentTracker:
    """Get or create global experiment tracker"""
    global _experiment_tracker
    if _experiment_tracker is None:
        _experiment_tracker = ExperimentTracker()
    return _experiment_tracker


def get_model_registry() -> ModelRegistry:
    """Get or create global model registry"""
    global _model_registry
    if _model_registry is None:
        _model_registry = ModelRegistry()
    return _model_registry


def get_drift_detector() -> DriftDetector:
    """Get or create global drift detector"""
    global _drift_detector
    if _drift_detector is None:
        _drift_detector = DriftDetector()
    return _drift_detector
