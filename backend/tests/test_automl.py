"""
Unit Tests for AutoML Module
Tests for automated hyperparameter optimization with Optuna
"""

import pytest
import pandas as pd
import numpy as np
from dataclasses import asdict
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.automl import (
    OptimizationResult,
    AutoMLOptimizer,
    SimpleAutoML,
    create_automl,
    OPTUNA_AVAILABLE,
    XGBOOST_AVAILABLE,
    LIGHTGBM_AVAILABLE,
    CATBOOST_AVAILABLE
)
from sklearn.datasets import make_classification, make_regression


# =====================================================================
# FIXTURES - Test Data
# =====================================================================

@pytest.fixture
def classification_data():
    """Create sample classification dataset"""
    X, y = make_classification(
        n_samples=200,
        n_features=10,
        n_informative=8,
        n_redundant=2,
        n_classes=2,
        random_state=42
    )
    return X, y


@pytest.fixture
def regression_data():
    """Create sample regression dataset"""
    X, y = make_regression(
        n_samples=200,
        n_features=10,
        n_informative=8,
        random_state=42
    )
    return X, y


@pytest.fixture
def small_classification_data():
    """Small dataset for faster tests"""
    X, y = make_classification(
        n_samples=50,
        n_features=5,
        n_informative=4,
        n_classes=2,
        random_state=42
    )
    return X, y


# =====================================================================
# TEST: OptimizationResult Dataclass
# =====================================================================

class TestOptimizationResult:
    """Test OptimizationResult dataclass"""

    def test_optimization_result_creation(self):
        """Test creating OptimizationResult"""
        model = Mock()
        result = OptimizationResult(
            best_model=model,
            best_params={'n_estimators': 100, 'max_depth': 5},
            best_score=0.85,
            n_trials=20,
            optimization_time=45.2,
            trial_history=[{"trial": 1, "score": 0.80}],
            model_type="XGBoost"
        )

        assert result.best_model is model
        assert result.best_params == {'n_estimators': 100, 'max_depth': 5}
        assert result.best_score == 0.85
        assert result.n_trials == 20
        assert result.optimization_time == 45.2
        assert len(result.trial_history) == 1
        assert result.model_type == "XGBoost"

    def test_optimization_result_to_dict(self):
        """Test converting OptimizationResult to dict"""
        model = Mock()
        result = OptimizationResult(
            best_model=model,
            best_params={'learning_rate': 0.1},
            best_score=0.92,
            n_trials=10,
            optimization_time=30.0,
            trial_history=[],
            model_type="LightGBM"
        )

        result_dict = asdict(result)
        assert result_dict['best_score'] == 0.92
        assert result_dict['model_type'] == "LightGBM"


# =====================================================================
# TEST: AutoMLOptimizer Initialization
# =====================================================================

class TestAutoMLOptimizerInitialization:
    """Test AutoMLOptimizer initialization"""

    def test_initialization_default(self):
        """Test default initialization"""
        optimizer = AutoMLOptimizer()

        assert optimizer.task == "classification"
        assert optimizer.metric == "roc_auc"
        assert optimizer.n_trials == 50
        assert optimizer.cv_folds == 5
        assert optimizer.random_state == 42
        assert optimizer.use_gpu == False

    def test_initialization_custom(self):
        """Test initialization with custom parameters"""
        optimizer = AutoMLOptimizer(
            task="regression",
            metric="rmse",
            n_trials=100,
            cv_folds=10,
            random_state=123,
            use_gpu=True
        )

        assert optimizer.task == "regression"
        assert optimizer.metric == "rmse"
        assert optimizer.n_trials == 100
        assert optimizer.cv_folds == 10
        assert optimizer.random_state == 123
        assert optimizer.use_gpu == True

    def test_initialization_state(self):
        """Test that initial state is unoptimized"""
        optimizer = AutoMLOptimizer()

        assert optimizer.best_model is None
        assert optimizer.best_params is None
        assert optimizer.best_score is None
        assert optimizer.study is None


# =====================================================================
# TEST: AutoMLOptimizer - XGBoost Optimization
# =====================================================================

class TestAutoMLOptimizerXGBoost:
    """Test XGBoost optimization"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not XGBOOST_AVAILABLE,
                        reason="Optuna or XGBoost not available")
    @pytest.mark.slow
    def test_optimize_xgboost_basic(self, small_classification_data):
        """Test basic XGBoost optimization"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(
            task="classification",
            metric="accuracy",
            n_trials=5,  # Small number for speed
            cv_folds=3
        )

        result = optimizer.optimize_xgboost(X, y)

        assert isinstance(result, OptimizationResult)
        assert result.best_model is not None
        assert result.best_params is not None
        assert isinstance(result.best_score, float)
        assert 0 <= result.best_score <= 1
        assert result.n_trials == 5
        assert result.model_type == "XGBoost"
        assert len(result.trial_history) == 5

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not XGBOOST_AVAILABLE,
                        reason="Optuna or XGBoost not available")
    def test_optimize_xgboost_parameters(self, small_classification_data):
        """Test that optimized parameters are valid"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(n_trials=3, cv_folds=2)
        result = optimizer.optimize_xgboost(X, y)

        # Check parameter types and ranges
        params = result.best_params
        assert 'n_estimators' in params
        assert 'max_depth' in params
        assert 'learning_rate' in params

        assert 50 <= params['n_estimators'] <= 300
        assert 3 <= params['max_depth'] <= 10
        assert 0.01 <= params['learning_rate'] <= 0.3

    def test_optimize_xgboost_without_xgboost(self):
        """Test error when XGBoost not available"""
        X = np.random.rand(10, 5)
        y = np.random.randint(0, 2, 10)

        optimizer = AutoMLOptimizer()

        if not XGBOOST_AVAILABLE:
            with pytest.raises(ImportError):
                optimizer.optimize_xgboost(X, y)


# =====================================================================
# TEST: AutoMLOptimizer - LightGBM Optimization
# =====================================================================

class TestAutoMLOptimizerLightGBM:
    """Test LightGBM optimization"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not LIGHTGBM_AVAILABLE,
                        reason="Optuna or LightGBM not available")
    @pytest.mark.slow
    def test_optimize_lightgbm_basic(self, small_classification_data):
        """Test basic LightGBM optimization"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(
            task="classification",
            n_trials=5,
            cv_folds=3
        )

        result = optimizer.optimize_lightgbm(X, y)

        assert isinstance(result, OptimizationResult)
        assert result.best_model is not None
        assert result.model_type == "LightGBM"
        assert 0 <= result.best_score <= 1


# =====================================================================
# TEST: AutoMLOptimizer - CatBoost Optimization
# =====================================================================

class TestAutoMLOptimizerCatBoost:
    """Test CatBoost optimization"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not CATBOOST_AVAILABLE,
                        reason="Optuna or CatBoost not available")
    @pytest.mark.slow
    def test_optimize_catboost_basic(self, small_classification_data):
        """Test basic CatBoost optimization"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(
            task="classification",
            n_trials=5,
            cv_folds=3
        )

        result = optimizer.optimize_catboost(X, y)

        assert isinstance(result, OptimizationResult)
        assert result.best_model is not None
        assert result.model_type == "CatBoost"


# =====================================================================
# TEST: AutoMLOptimizer - Optimize All Models
# =====================================================================

class TestAutoMLOptimizerOptimizeAll:
    """Test optimizing all available models"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE,
                        reason="Optuna not available")
    @pytest.mark.slow
    def test_optimize_all_basic(self, small_classification_data):
        """Test optimizing all models"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(n_trials=3, cv_folds=2)

        results = optimizer.optimize_all(X, y)

        assert isinstance(results, list)
        assert len(results) > 0  # At least one model available

        # All results should be OptimizationResult objects
        for result in results:
            assert isinstance(result, OptimizationResult)
            assert result.best_model is not None
            assert result.best_score is not None

    @pytest.mark.skipif(not OPTUNA_AVAILABLE,
                        reason="Optuna not available")
    def test_optimize_all_scores_ordered(self, small_classification_data):
        """Test that results are ordered by score"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(n_trials=3, cv_folds=2)
        results = optimizer.optimize_all(X, y)

        # Scores should be in descending order (best first)
        scores = [r.best_score for r in results]
        assert scores == sorted(scores, reverse=True)


# =====================================================================
# TEST: AutoMLOptimizer - Get Best Model
# =====================================================================

class TestAutoMLOptimizerGetBestModel:
    """Test getting best model across all optimizers"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE,
                        reason="Optuna not available")
    @pytest.mark.slow
    def test_get_best_model_basic(self, small_classification_data):
        """Test getting best model"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(n_trials=3, cv_folds=2)

        best_model, best_info = optimizer.get_best_model(X, y)

        assert best_model is not None
        assert isinstance(best_info, dict)
        assert 'model_type' in best_info
        assert 'best_score' in best_info
        assert 'best_params' in best_info
        assert 'optimization_time' in best_info

    @pytest.mark.skipif(not OPTUNA_AVAILABLE,
                        reason="Optuna not available")
    def test_get_best_model_can_predict(self, small_classification_data):
        """Test that best model can make predictions"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(n_trials=3, cv_folds=2)
        best_model, best_info = optimizer.get_best_model(X, y)

        # Model should be able to predict
        predictions = best_model.predict(X[:10])
        assert len(predictions) == 10
        assert all(pred in [0, 1] for pred in predictions)


# =====================================================================
# TEST: SimpleAutoML
# =====================================================================

class TestSimpleAutoML:
    """Test SimpleAutoML (fallback without Optuna)"""

    def test_initialization_default(self):
        """Test SimpleAutoML initialization"""
        automl = SimpleAutoML()

        assert automl.task == "classification"
        assert automl.random_state == 42

    def test_initialization_custom(self):
        """Test SimpleAutoML with custom parameters"""
        automl = SimpleAutoML(
            task="regression",
            random_state=123
        )

        assert automl.task == "regression"
        assert automl.random_state == 123

    def test_get_best_model_classification(self, small_classification_data):
        """Test SimpleAutoML for classification"""
        X, y = small_classification_data

        automl = SimpleAutoML(task="classification")
        model, info = automl.get_best_model(X, y)

        assert model is not None
        assert isinstance(info, dict)
        assert 'model_type' in info
        assert 'cv_score' in info

        # Model should work
        predictions = model.predict(X[:10])
        assert len(predictions) == 10

    def test_get_best_model_regression(self, regression_data):
        """Test SimpleAutoML for regression"""
        X, y = regression_data

        automl = SimpleAutoML(task="regression")
        model, info = automl.get_best_model(X, y)

        assert model is not None
        assert isinstance(info, dict)

        # Model should work
        predictions = model.predict(X[:10])
        assert len(predictions) == 10


# =====================================================================
# TEST: Factory Function
# =====================================================================

class TestFactoryFunction:
    """Test create_automl factory function"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE, reason="Optuna not available")
    def test_create_automl_with_optuna(self):
        """Test creating AutoML with Optuna"""
        automl = create_automl(use_optuna=True)

        assert isinstance(automl, AutoMLOptimizer)

    def test_create_automl_without_optuna(self):
        """Test creating SimpleAutoML"""
        automl = create_automl(use_optuna=False)

        assert isinstance(automl, SimpleAutoML)

    def test_create_automl_with_kwargs(self):
        """Test factory function with kwargs"""
        automl = create_automl(
            use_optuna=False,
            task="regression",
            random_state=999
        )

        assert automl.task == "regression"
        assert automl.random_state == 999


# =====================================================================
# TEST: Different Metrics
# =====================================================================

class TestDifferentMetrics:
    """Test AutoML with different optimization metrics"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not XGBOOST_AVAILABLE,
                        reason="Optuna or XGBoost not available")
    def test_optimize_with_f1_score(self, small_classification_data):
        """Test optimization with F1 score"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(
            metric="f1",
            n_trials=3,
            cv_folds=2
        )

        result = optimizer.optimize_xgboost(X, y)

        assert isinstance(result, OptimizationResult)
        assert result.best_score >= 0

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not XGBOOST_AVAILABLE,
                        reason="Optuna or XGBoost not available")
    def test_optimize_with_accuracy(self, small_classification_data):
        """Test optimization with accuracy"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(
            metric="accuracy",
            n_trials=3,
            cv_folds=2
        )

        result = optimizer.optimize_xgboost(X, y)

        assert isinstance(result, OptimizationResult)
        assert 0 <= result.best_score <= 1


# =====================================================================
# TEST: Edge Cases
# =====================================================================

class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_very_small_dataset(self):
        """Test with very small dataset"""
        X = np.random.rand(10, 3)
        y = np.random.randint(0, 2, 10)

        automl = SimpleAutoML()

        # Should handle gracefully
        model, info = automl.get_best_model(X, y)
        assert model is not None

    def test_single_feature(self):
        """Test with single feature"""
        X = np.random.rand(50, 1)
        y = np.random.randint(0, 2, 50)

        automl = SimpleAutoML()
        model, info = automl.get_best_model(X, y)

        assert model is not None
        predictions = model.predict(X[:5])
        assert len(predictions) == 5

    def test_imbalanced_classes(self):
        """Test with imbalanced dataset"""
        X = np.random.rand(100, 5)
        y = np.array([0] * 90 + [1] * 10)  # 90-10 split

        automl = SimpleAutoML()
        model, info = automl.get_best_model(X, y)

        assert model is not None

    @pytest.mark.skipif(not OPTUNA_AVAILABLE, reason="Optuna not available")
    def test_zero_trials(self):
        """Test with zero trials (edge case)"""
        X, y = make_classification(n_samples=50, n_features=5, random_state=42)

        optimizer = AutoMLOptimizer(n_trials=0)

        # Should handle gracefully or raise error
        try:
            result = optimizer.optimize_xgboost(X, y)
            # If it succeeds, check it's valid
            assert isinstance(result, OptimizationResult)
        except Exception:
            # If it fails, that's also acceptable
            pass


# =====================================================================
# TEST: Integration Tests
# =====================================================================

class TestAutoMLIntegration:
    """Integration tests for AutoML"""

    @pytest.mark.slow
    def test_end_to_end_workflow_simple(self, classification_data):
        """Test complete workflow with SimpleAutoML"""
        X, y = classification_data

        # Split data
        split_idx = int(0.8 * len(X))
        X_train, X_test = X[:split_idx], X[split_idx:]
        y_train, y_test = y[:split_idx], y[split_idx:]

        # Train
        automl = SimpleAutoML()
        model, info = automl.get_best_model(X_train, y_train)

        # Predict
        predictions = model.predict(X_test)

        # Validate
        assert len(predictions) == len(y_test)
        assert all(pred in [0, 1] for pred in predictions)

        # Check accuracy is reasonable
        accuracy = (predictions == y_test).mean()
        assert accuracy > 0.5  # Should be better than random

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not XGBOOST_AVAILABLE,
                        reason="Optuna or XGBoost not available")
    @pytest.mark.slow
    def test_end_to_end_workflow_optuna(self, classification_data):
        """Test complete workflow with Optuna optimization"""
        X, y = classification_data

        # Split data
        split_idx = int(0.8 * len(X))
        X_train, X_test = X[:split_idx], X[split_idx:]
        y_train, y_test = y[:split_idx], y[split_idx:]

        # Optimize
        optimizer = AutoMLOptimizer(n_trials=5, cv_folds=3)
        best_model, best_info = optimizer.get_best_model(X_train, y_train)

        # Predict
        predictions = best_model.predict(X_test)

        # Validate
        assert len(predictions) == len(y_test)
        accuracy = (predictions == y_test).mean()
        assert accuracy > 0.5


# =====================================================================
# TEST: Performance and Timing
# =====================================================================

class TestPerformance:
    """Test performance characteristics"""

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not XGBOOST_AVAILABLE,
                        reason="Optuna or XGBoost not available")
    def test_optimization_time_recorded(self, small_classification_data):
        """Test that optimization time is recorded"""
        X, y = small_classification_data

        optimizer = AutoMLOptimizer(n_trials=3, cv_folds=2)
        result = optimizer.optimize_xgboost(X, y)

        assert result.optimization_time > 0
        assert result.optimization_time < 300  # Should finish in 5 minutes

    @pytest.mark.skipif(not OPTUNA_AVAILABLE or not XGBOOST_AVAILABLE,
                        reason="Optuna or XGBoost not available")
    def test_trial_history_length(self, small_classification_data):
        """Test that trial history has correct length"""
        X, y = small_classification_data

        n_trials = 5
        optimizer = AutoMLOptimizer(n_trials=n_trials, cv_folds=2)
        result = optimizer.optimize_xgboost(X, y)

        assert len(result.trial_history) == n_trials


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "--cov=ml.automl", "--cov-report=term-missing"])
