"""
Comprehensive Unit Tests for MLOps Infrastructure
Tests experiment tracking, model registry, and drift detection
"""
import pytest
import numpy as np
import pandas as pd
import tempfile
import shutil
import json
from pathlib import Path
from datetime import datetime
from unittest.mock import Mock, patch, MagicMock

from ml.mlops_infrastructure import (
    ExperimentMetrics,
    ModelVersion,
    DriftReport,
    ExperimentTracker,
    ModelRegistry,
    DriftDetector,
    get_experiment_tracker,
    get_model_registry,
    get_drift_detector,
    MLFLOW_AVAILABLE,
    EVIDENTLY_AVAILABLE
)


# ============================================================================
# Fixtures
# ============================================================================

@pytest.fixture
def temp_storage():
    """Create temporary storage directory"""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir, ignore_errors=True)


@pytest.fixture
def sample_model():
    """Create a simple mock model"""
    from sklearn.linear_model import LogisticRegression
    model = LogisticRegression()
    # Fit with dummy data
    X = np.random.randn(100, 5)
    y = np.random.randint(0, 2, 100)
    model.fit(X, y)
    return model


@pytest.fixture
def sample_data():
    """Create sample reference and new data for drift detection"""
    np.random.seed(42)
    X_ref = np.random.randn(1000, 5)
    X_new = np.random.randn(500, 5)

    y_pred_ref = np.random.rand(1000)
    y_pred_new = np.random.rand(500)

    feature_names = [f"feature_{i}" for i in range(5)]

    return {
        'X_ref': X_ref,
        'X_new': X_new,
        'y_pred_ref': y_pred_ref,
        'y_pred_new': y_pred_new,
        'feature_names': feature_names
    }


@pytest.fixture
def sample_data_with_drift():
    """Create sample data with intentional drift"""
    np.random.seed(42)
    # Reference data: mean=0, std=1
    X_ref = np.random.randn(1000, 5)

    # New data: shifted mean for some features
    X_new = np.random.randn(500, 5)
    X_new[:, 0] += 2.0  # Shift feature 0
    X_new[:, 2] += 1.5  # Shift feature 2

    y_pred_ref = np.random.rand(1000)
    y_pred_new = np.random.rand(500) + 0.2  # Shift predictions

    feature_names = [f"feature_{i}" for i in range(5)]

    return {
        'X_ref': X_ref,
        'X_new': X_new,
        'y_pred_ref': y_pred_ref,
        'y_pred_new': y_pred_new,
        'feature_names': feature_names
    }


# ============================================================================
# Dataclass Tests
# ============================================================================

def test_experiment_metrics_creation():
    """Test ExperimentMetrics dataclass"""
    metrics = ExperimentMetrics(
        experiment_id="exp_123",
        run_id="run_456",
        timestamp="2025-01-05T10:00:00",
        model_name="test_model",
        parameters={"alpha": 0.1, "max_iter": 100},
        metrics={"auc": 0.85, "accuracy": 0.80},
        tags={"env": "test"}
    )

    assert metrics.experiment_id == "exp_123"
    assert metrics.run_id == "run_456"
    assert metrics.parameters["alpha"] == 0.1
    assert metrics.metrics["auc"] == 0.85
    assert metrics.tags["env"] == "test"


def test_model_version_creation():
    """Test ModelVersion dataclass"""
    version = ModelVersion(
        version_id="v1_2025-01-05",
        model_name="test_model",
        timestamp="2025-01-05T10:00:00",
        performance={"auc": 0.85},
        metadata={"author": "test"},
        model_path="/path/to/model.pkl",
        is_production=False
    )

    assert version.version_id == "v1_2025-01-05"
    assert version.is_production is False
    assert version.performance["auc"] == 0.85


def test_drift_report_creation():
    """Test DriftReport dataclass"""
    report = DriftReport(
        timestamp="2025-01-05T10:00:00",
        n_features=5,
        n_features_drifted=2,
        drift_detected=True,
        drift_score=0.4,
        feature_drift={"feature_0": {"drift_detected": True}},
        prediction_drift={"drift_detected": True},
        recommendation="Model retraining recommended"
    )

    assert report.n_features == 5
    assert report.n_features_drifted == 2
    assert report.drift_detected is True
    assert report.drift_score == 0.4


# ============================================================================
# ExperimentTracker Tests
# ============================================================================

def test_experiment_tracker_initialization(temp_storage):
    """Test ExperimentTracker initialization with local storage"""
    tracker = ExperimentTracker(
        experiment_name="test_exp",
        local_storage_path=temp_storage
    )

    assert tracker.experiment_name == "test_exp"
    assert tracker.local_storage_path.exists()
    assert isinstance(tracker.mlflow_enabled, bool)


def test_experiment_tracker_start_run_local(temp_storage):
    """Test starting run with local storage"""
    tracker = ExperimentTracker(
        experiment_name="test_exp",
        local_storage_path=temp_storage
    )
    tracker.mlflow_enabled = False  # Force local storage

    run_id = tracker.start_run(run_name="test_run", tags={"env": "test"})

    assert run_id is not None
    assert isinstance(run_id, str)
    assert len(run_id) > 0


def test_experiment_tracker_log_params_local(temp_storage):
    """Test logging parameters with local storage"""
    tracker = ExperimentTracker(
        experiment_name="test_exp",
        local_storage_path=temp_storage
    )
    tracker.mlflow_enabled = False

    tracker.start_run(run_name="test_run")

    params = {"alpha": 0.1, "max_iter": 100}
    tracker.log_params(params)

    # Find the run directory (use timestamp-based ID)
    run_dirs = list(Path(temp_storage).glob("run_*"))
    assert len(run_dirs) > 0

    params_file = run_dirs[0] / "params.json"
    assert params_file.exists()

    with open(params_file, 'r') as f:
        saved_params = json.load(f)

    assert saved_params["alpha"] == 0.1
    assert saved_params["max_iter"] == 100


def test_experiment_tracker_log_metrics_local(temp_storage):
    """Test logging metrics with local storage"""
    tracker = ExperimentTracker(
        experiment_name="test_exp",
        local_storage_path=temp_storage
    )
    tracker.mlflow_enabled = False

    tracker.start_run(run_name="test_run")

    metrics = {"auc": 0.85, "accuracy": 0.80}
    tracker.log_metrics(metrics)

    # Find the run directory (use timestamp-based ID)
    run_dirs = list(Path(temp_storage).glob("run_*"))
    assert len(run_dirs) > 0

    metrics_file = run_dirs[0] / "metrics.json"
    assert metrics_file.exists()

    with open(metrics_file, 'r') as f:
        saved_metrics = json.load(f)

    assert saved_metrics["auc"] == 0.85
    assert saved_metrics["accuracy"] == 0.80


def test_experiment_tracker_log_model_local(temp_storage, sample_model):
    """Test logging model with local storage"""
    tracker = ExperimentTracker(
        experiment_name="test_exp",
        local_storage_path=temp_storage
    )
    tracker.mlflow_enabled = False

    tracker.start_run(run_name="test_run")
    tracker.log_model(sample_model, "test_model")

    # Find the run directory (use timestamp-based ID)
    run_dirs = list(Path(temp_storage).glob("run_*"))
    assert len(run_dirs) > 0

    model_file = run_dirs[0] / "test_model.pkl"
    assert model_file.exists()


def test_experiment_tracker_end_run(temp_storage):
    """Test ending experiment run"""
    tracker = ExperimentTracker(
        experiment_name="test_exp",
        local_storage_path=temp_storage
    )
    tracker.mlflow_enabled = False

    tracker.start_run(run_name="test_run")
    tracker.end_run()  # Should not raise


@pytest.mark.skipif(not MLFLOW_AVAILABLE, reason="MLflow not installed")
def test_experiment_tracker_with_mlflow(temp_storage):
    """Test ExperimentTracker with MLflow (if available)"""
    with patch('ml.mlops_infrastructure.mlflow') as mock_mlflow:
        mock_run = Mock()
        mock_run.info.run_id = "mlflow_run_123"
        mock_mlflow.active_run.return_value = mock_run

        tracker = ExperimentTracker(
            experiment_name="test_exp",
            local_storage_path=temp_storage
        )

        if tracker.mlflow_enabled:
            run_id = tracker.start_run(run_name="test_run")
            assert run_id is not None


# ============================================================================
# ModelRegistry Tests
# ============================================================================

def test_model_registry_initialization(temp_storage):
    """Test ModelRegistry initialization"""
    registry = ModelRegistry(registry_path=temp_storage)

    assert registry.registry_path.exists()
    assert registry.models_path.exists()
    assert isinstance(registry.registry, dict)


def test_model_registry_register_model(temp_storage, sample_model):
    """Test registering a new model"""
    registry = ModelRegistry(registry_path=temp_storage)

    performance = {"auc": 0.85, "accuracy": 0.80}
    metadata = {"author": "test"}

    version = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance=performance,
        metadata=metadata
    )

    assert version.model_name == "test_model"
    assert version.performance["auc"] == 0.85
    assert version.is_production is False
    assert Path(version.model_path).exists()


def test_model_registry_multiple_versions(temp_storage, sample_model):
    """Test registering multiple versions of same model"""
    registry = ModelRegistry(registry_path=temp_storage)

    # Register v1
    v1 = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.80}
    )

    # Register v2
    v2 = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.85}
    )

    assert v1.version_id != v2.version_id
    assert len(registry.list_versions("test_model")) == 2


def test_model_registry_promote_to_production(temp_storage, sample_model):
    """Test promoting model to production"""
    registry = ModelRegistry(registry_path=temp_storage)

    # Register two versions
    v1 = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.80}
    )

    v2 = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.85}
    )

    # Promote v2
    registry.promote_to_production("test_model", v2.version_id)

    # Check v2 is production
    versions = registry.list_versions("test_model")
    assert not versions[0].is_production  # v1
    assert versions[1].is_production  # v2


def test_model_registry_get_production_model(temp_storage, sample_model):
    """Test loading production model"""
    registry = ModelRegistry(registry_path=temp_storage)

    version = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.85}
    )

    registry.promote_to_production("test_model", version.version_id)

    prod_model = registry.get_production_model("test_model")
    assert prod_model is not None
    assert hasattr(prod_model, 'predict')


def test_model_registry_list_versions(temp_storage, sample_model):
    """Test listing model versions"""
    registry = ModelRegistry(registry_path=temp_storage)

    # Register 3 versions
    for i in range(3):
        registry.register_model(
            model_name="test_model",
            model=sample_model,
            performance={"auc": 0.8 + i * 0.05}
        )

    versions = registry.list_versions("test_model")
    assert len(versions) == 3


def test_model_registry_nonexistent_model(temp_storage):
    """Test accessing non-existent model"""
    registry = ModelRegistry(registry_path=temp_storage)

    versions = registry.list_versions("nonexistent")
    assert len(versions) == 0

    prod_model = registry.get_production_model("nonexistent")
    assert prod_model is None


def test_model_registry_persistence(temp_storage, sample_model):
    """Test registry persistence across instances"""
    # Register model with first instance
    registry1 = ModelRegistry(registry_path=temp_storage)
    version = registry1.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.85}
    )

    # Load registry with second instance
    registry2 = ModelRegistry(registry_path=temp_storage)
    versions = registry2.list_versions("test_model")

    assert len(versions) == 1
    assert versions[0].version_id == version.version_id


# ============================================================================
# DriftDetector Tests
# ============================================================================

def test_drift_detector_initialization():
    """Test DriftDetector initialization"""
    detector = DriftDetector()

    assert detector.reference_data is None
    assert detector.reference_predictions is None
    assert detector.feature_names is None


def test_drift_detector_set_reference(sample_data):
    """Test setting reference data"""
    detector = DriftDetector()

    detector.set_reference(
        X=sample_data['X_ref'],
        y_pred=sample_data['y_pred_ref'],
        feature_names=sample_data['feature_names']
    )

    assert detector.reference_data is not None
    assert detector.reference_data.shape == sample_data['X_ref'].shape
    assert detector.reference_predictions is not None
    assert len(detector.feature_names) == 5


def test_drift_detector_no_drift(sample_data):
    """Test drift detection with no drift (same distribution)"""
    detector = DriftDetector()

    # Use same data as reference and new
    detector.set_reference(
        X=sample_data['X_ref'],
        y_pred=sample_data['y_pred_ref'],
        feature_names=sample_data['feature_names']
    )

    # Detect drift (using same data)
    report = detector.detect_drift(
        X_new=sample_data['X_ref'][:500],  # Subset of same data
        y_pred_new=sample_data['y_pred_ref'][:500]
    )

    assert isinstance(report, DriftReport)
    assert report.n_features == 5
    assert report.drift_detected is False or report.n_features_drifted <= 1  # Minimal drift
    assert 0 <= report.drift_score <= 1


def test_drift_detector_with_drift(sample_data_with_drift):
    """Test drift detection with intentional drift"""
    detector = DriftDetector()

    detector.set_reference(
        X=sample_data_with_drift['X_ref'],
        y_pred=sample_data_with_drift['y_pred_ref'],
        feature_names=sample_data_with_drift['feature_names']
    )

    report = detector.detect_drift(
        X_new=sample_data_with_drift['X_new'],
        y_pred_new=sample_data_with_drift['y_pred_new']
    )

    assert isinstance(report, DriftReport)
    assert report.n_features == 5
    assert report.n_features_drifted >= 2  # We shifted features 0 and 2
    assert report.drift_score > 0.2  # Should detect drift


def test_drift_detector_feature_drift_details(sample_data_with_drift):
    """Test feature drift details"""
    detector = DriftDetector()

    detector.set_reference(
        X=sample_data_with_drift['X_ref'],
        feature_names=sample_data_with_drift['feature_names']
    )

    report = detector.detect_drift(X_new=sample_data_with_drift['X_new'])

    # Check feature drift structure
    assert 'feature_0' in report.feature_drift
    feature_info = report.feature_drift['feature_0']

    assert 'drift_detected' in feature_info
    assert 'ks_statistic' in feature_info
    assert 'p_value' in feature_info
    assert 'ref_mean' in feature_info
    assert 'new_mean' in feature_info
    assert 'mean_shift' in feature_info

    # Feature 0 was shifted by 2.0, so should have high mean_shift
    assert feature_info['mean_shift'] > 1.0


def test_drift_detector_prediction_drift(sample_data_with_drift):
    """Test prediction drift detection"""
    detector = DriftDetector()

    detector.set_reference(
        X=sample_data_with_drift['X_ref'],
        y_pred=sample_data_with_drift['y_pred_ref']
    )

    report = detector.detect_drift(
        X_new=sample_data_with_drift['X_new'],
        y_pred_new=sample_data_with_drift['y_pred_new']
    )

    assert report.prediction_drift is not None
    assert 'ks_statistic' in report.prediction_drift
    assert 'p_value' in report.prediction_drift
    assert 'drift_detected' in report.prediction_drift


def test_drift_detector_recommendation(sample_data_with_drift):
    """Test drift recommendation generation"""
    detector = DriftDetector()

    detector.set_reference(
        X=sample_data_with_drift['X_ref'],
        y_pred=sample_data_with_drift['y_pred_ref']
    )

    report = detector.detect_drift(
        X_new=sample_data_with_drift['X_new'],
        y_pred_new=sample_data_with_drift['y_pred_new']
    )

    assert isinstance(report.recommendation, str)
    assert len(report.recommendation) > 0

    # With significant drift, should recommend retraining
    if report.drift_score > 0.2:
        assert "retraining" in report.recommendation.lower() or "model" in report.recommendation.lower()


def test_drift_detector_without_reference():
    """Test drift detection without setting reference data"""
    detector = DriftDetector()

    X_new = np.random.randn(100, 5)

    with pytest.raises(ValueError, match="Reference data not set"):
        detector.detect_drift(X_new=X_new)


def test_drift_detector_threshold_sensitivity(sample_data_with_drift):
    """Test drift detection with different thresholds"""
    detector = DriftDetector()

    detector.set_reference(X=sample_data_with_drift['X_ref'])

    # Strict threshold (lower p-value threshold means more features flagged as drifted)
    report_strict = detector.detect_drift(
        X_new=sample_data_with_drift['X_new'],
        threshold=0.10  # More lenient p-value
    )

    # Lenient threshold (higher p-value threshold means fewer features flagged)
    report_lenient = detector.detect_drift(
        X_new=sample_data_with_drift['X_new'],
        threshold=0.01  # More strict p-value
    )

    # Stricter p-value threshold should detect less drift (inverse relationship)
    assert report_lenient.n_features_drifted <= report_strict.n_features_drifted


# ============================================================================
# Global Factory Functions
# ============================================================================

def test_get_experiment_tracker():
    """Test global experiment tracker factory"""
    tracker1 = get_experiment_tracker()
    tracker2 = get_experiment_tracker()

    # Should return same instance
    assert tracker1 is tracker2


def test_get_model_registry():
    """Test global model registry factory"""
    registry1 = get_model_registry()
    registry2 = get_model_registry()

    # Should return same instance
    assert registry1 is registry2


def test_get_drift_detector():
    """Test global drift detector factory"""
    detector1 = get_drift_detector()
    detector2 = get_drift_detector()

    # Should return same instance
    assert detector1 is detector2


# ============================================================================
# Integration Tests
# ============================================================================

def test_end_to_end_mlops_workflow(temp_storage, sample_model):
    """Test complete MLOps workflow"""
    # 1. Track experiment
    tracker = ExperimentTracker(
        experiment_name="test_exp",
        local_storage_path=f"{temp_storage}/experiments"
    )
    tracker.mlflow_enabled = False

    run_id = tracker.start_run(run_name="test_run")
    tracker.log_params({"alpha": 0.1})
    tracker.log_metrics({"auc": 0.85})
    tracker.log_model(sample_model, "test_model")
    tracker.end_run()

    # 2. Register model
    registry = ModelRegistry(registry_path=f"{temp_storage}/registry")
    version = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.85}
    )

    # 3. Promote to production
    registry.promote_to_production("test_model", version.version_id)

    # 4. Load production model
    prod_model = registry.get_production_model("test_model")
    assert prod_model is not None

    # 5. Monitor for drift
    detector = DriftDetector()
    X_ref = np.random.randn(1000, 5)
    detector.set_reference(X=X_ref)

    X_new = np.random.randn(500, 5)
    report = detector.detect_drift(X_new=X_new)

    assert isinstance(report, DriftReport)
    assert report.drift_detected in [True, False]


def test_model_versioning_and_rollback(temp_storage, sample_model):
    """Test model versioning with rollback capability"""
    registry = ModelRegistry(registry_path=temp_storage)

    # Register v1 (good performance)
    v1 = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.85}
    )
    registry.promote_to_production("test_model", v1.version_id)

    # Register v2 (better performance)
    v2 = registry.register_model(
        model_name="test_model",
        model=sample_model,
        performance={"auc": 0.90}
    )
    registry.promote_to_production("test_model", v2.version_id)

    # Simulate performance degradation - rollback to v1
    registry.promote_to_production("test_model", v1.version_id)

    # Verify v1 is back in production
    versions = registry.list_versions("test_model")
    assert versions[0].is_production  # v1
    assert not versions[1].is_production  # v2


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
