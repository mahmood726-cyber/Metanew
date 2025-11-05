"""
AutoML with Hyperparameter Optimization
Automated model selection and tuning using Optuna
Based on 2025 healthcare ML best practices
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Any, Callable, Tuple
from dataclasses import dataclass
import logging
import time

logger = logging.getLogger(__name__)

# Optuna for hyperparameter optimization
try:
    import optuna
    from optuna.samplers import TPESampler
    from optuna.pruners import MedianPruner
    OPTUNA_AVAILABLE = True
except ImportError:
    OPTUNA_AVAILABLE = False
    logger.warning("Optuna not installed. Install with: pip install optuna")

# ML libraries
from sklearn.model_selection import cross_val_score, StratifiedKFold
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import roc_auc_score, f1_score, accuracy_score

# Advanced gradient boosting
try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError:
    XGBOOST_AVAILABLE = False

try:
    import lightgbm as lgb
    LIGHTGBM_AVAILABLE = True
except ImportError:
    LIGHTGBM_AVAILABLE = False

try:
    import catboost as cb
    CATBOOST_AVAILABLE = True
except ImportError:
    CATBOOST_AVAILABLE = False


@dataclass
class OptimizationResult:
    """Results from hyperparameter optimization"""
    best_model: Any
    best_params: Dict[str, Any]
    best_score: float
    n_trials: int
    optimization_time: float
    trial_history: List[Dict[str, Any]]
    model_type: str


class AutoMLOptimizer:
    """
    Automated ML with hyperparameter optimization
    Finds best model and hyperparameters for your data
    """

    def __init__(self, task: str = "classification",
                 metric: str = "roc_auc",
                 n_trials: int = 50,
                 cv_folds: int = 5,
                 random_state: int = 42,
                 use_gpu: bool = False):
        """
        Initialize AutoML optimizer

        Args:
            task: "classification" or "regression"
            metric: Optimization metric ("roc_auc", "f1", "accuracy", "rmse", "mae")
            n_trials: Number of optimization trials
            cv_folds: Number of cross-validation folds
            random_state: Random seed
            use_gpu: Use GPU acceleration if available
        """
        self.task = task
        self.metric = metric
        self.n_trials = n_trials
        self.cv_folds = cv_folds
        self.random_state = random_state
        self.use_gpu = use_gpu

        self.best_model = None
        self.best_params = None
        self.best_score = None
        self.study = None

    def optimize_xgboost(self, X: np.ndarray, y: np.ndarray) -> OptimizationResult:
        """
        Optimize XGBoost hyperparameters

        Args:
            X: Feature matrix
            y: Target labels

        Returns:
            OptimizationResult with best model and parameters
        """
        if not XGBOOST_AVAILABLE:
            raise ImportError("XGBoost not installed")

        logger.info("Optimizing XGBoost hyperparameters...")
        start_time = time.time()

        def objective(trial: optuna.Trial) -> float:
            params = {
                'n_estimators': trial.suggest_int('n_estimators', 50, 300),
                'max_depth': trial.suggest_int('max_depth', 3, 10),
                'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3, log=True),
                'subsample': trial.suggest_float('subsample', 0.6, 1.0),
                'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
                'reg_alpha': trial.suggest_float('reg_alpha', 1e-8, 10.0, log=True),
                'reg_lambda': trial.suggest_float('reg_lambda', 1e-8, 10.0, log=True),
                'min_child_weight': trial.suggest_int('min_child_weight', 1, 10),
                'random_state': self.random_state,
                'eval_metric': 'logloss',
                'use_label_encoder': False
            }

            if self.use_gpu:
                params['tree_method'] = 'gpu_hist'
                params['predictor'] = 'gpu_predictor'

            if self.task == "classification":
                model = xgb.XGBClassifier(**params)
            else:
                model = xgb.XGBRegressor(**params)

            cv_scores = cross_val_score(
                model, X, y,
                cv=StratifiedKFold(n_splits=self.cv_folds, shuffle=True, random_state=self.random_state),
                scoring=self.metric,
                n_jobs=-1
            )

            return cv_scores.mean()

        study = optuna.create_study(
            direction='maximize' if self.metric in ['roc_auc', 'f1', 'accuracy', 'r2'] else 'minimize',
            sampler=TPESampler(seed=self.random_state),
            pruner=MedianPruner()
        )

        study.optimize(objective, n_trials=self.n_trials, show_progress_bar=True)

        # Train best model
        best_params = study.best_params
        if self.task == "classification":
            best_model = xgb.XGBClassifier(**best_params, random_state=self.random_state,
                                          use_label_encoder=False, eval_metric='logloss')
        else:
            best_model = xgb.XGBRegressor(**best_params, random_state=self.random_state)

        best_model.fit(X, y)

        optimization_time = time.time() - start_time

        logger.info(f"✓ XGBoost optimized: {self.metric}={study.best_value:.4f} ({self.n_trials} trials, {optimization_time:.1f}s)")

        return OptimizationResult(
            best_model=best_model,
            best_params=best_params,
            best_score=study.best_value,
            n_trials=self.n_trials,
            optimization_time=optimization_time,
            trial_history=[
                {'number': t.number, 'value': t.value, 'params': t.params}
                for t in study.trials
            ],
            model_type='xgboost'
        )

    def optimize_lightgbm(self, X: np.ndarray, y: np.ndarray) -> OptimizationResult:
        """Optimize LightGBM hyperparameters"""
        if not LIGHTGBM_AVAILABLE:
            raise ImportError("LightGBM not installed")

        logger.info("Optimizing LightGBM hyperparameters...")
        start_time = time.time()

        def objective(trial: optuna.Trial) -> float:
            params = {
                'n_estimators': trial.suggest_int('n_estimators', 50, 300),
                'max_depth': trial.suggest_int('max_depth', 3, 10),
                'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3, log=True),
                'num_leaves': trial.suggest_int('num_leaves', 20, 100),
                'subsample': trial.suggest_float('subsample', 0.6, 1.0),
                'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
                'reg_alpha': trial.suggest_float('reg_alpha', 1e-8, 10.0, log=True),
                'reg_lambda': trial.suggest_float('reg_lambda', 1e-8, 10.0, log=True),
                'min_child_samples': trial.suggest_int('min_child_samples', 5, 50),
                'random_state': self.random_state,
                'verbose': -1
            }

            if self.use_gpu:
                params['device'] = 'gpu'

            if self.task == "classification":
                model = lgb.LGBMClassifier(**params)
            else:
                model = lgb.LGBMRegressor(**params)

            cv_scores = cross_val_score(
                model, X, y,
                cv=StratifiedKFold(n_splits=self.cv_folds, shuffle=True, random_state=self.random_state),
                scoring=self.metric,
                n_jobs=-1
            )

            return cv_scores.mean()

        study = optuna.create_study(
            direction='maximize' if self.metric in ['roc_auc', 'f1', 'accuracy', 'r2'] else 'minimize',
            sampler=TPESampler(seed=self.random_state),
            pruner=MedianPruner()
        )

        study.optimize(objective, n_trials=self.n_trials, show_progress_bar=True)

        # Train best model
        best_params = study.best_params
        if self.task == "classification":
            best_model = lgb.LGBMClassifier(**best_params, random_state=self.random_state, verbose=-1)
        else:
            best_model = lgb.LGBMRegressor(**best_params, random_state=self.random_state, verbose=-1)

        best_model.fit(X, y)

        optimization_time = time.time() - start_time

        logger.info(f"✓ LightGBM optimized: {self.metric}={study.best_value:.4f} ({self.n_trials} trials, {optimization_time:.1f}s)")

        return OptimizationResult(
            best_model=best_model,
            best_params=best_params,
            best_score=study.best_value,
            n_trials=self.n_trials,
            optimization_time=optimization_time,
            trial_history=[
                {'number': t.number, 'value': t.value, 'params': t.params}
                for t in study.trials
            ],
            model_type='lightgbm'
        )

    def optimize_catboost(self, X: np.ndarray, y: np.ndarray) -> OptimizationResult:
        """Optimize CatBoost hyperparameters"""
        if not CATBOOST_AVAILABLE:
            raise ImportError("CatBoost not installed")

        logger.info("Optimizing CatBoost hyperparameters...")
        start_time = time.time()

        def objective(trial: optuna.Trial) -> float:
            params = {
                'iterations': trial.suggest_int('iterations', 50, 300),
                'depth': trial.suggest_int('depth', 3, 10),
                'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3, log=True),
                'l2_leaf_reg': trial.suggest_float('l2_leaf_reg', 1e-8, 10.0, log=True),
                'border_count': trial.suggest_int('border_count', 32, 255),
                'random_state': self.random_state,
                'verbose': False,
                'allow_writing_files': False
            }

            if self.use_gpu:
                params['task_type'] = 'GPU'

            if self.task == "classification":
                model = cb.CatBoostClassifier(**params)
            else:
                model = cb.CatBoostRegressor(**params)

            cv_scores = cross_val_score(
                model, X, y,
                cv=StratifiedKFold(n_splits=self.cv_folds, shuffle=True, random_state=self.random_state),
                scoring=self.metric,
                n_jobs=-1
            )

            return cv_scores.mean()

        study = optuna.create_study(
            direction='maximize' if self.metric in ['roc_auc', 'f1', 'accuracy', 'r2'] else 'minimize',
            sampler=TPESampler(seed=self.random_state),
            pruner=MedianPruner()
        )

        study.optimize(objective, n_trials=self.n_trials, show_progress_bar=True)

        # Train best model
        best_params = study.best_params
        if self.task == "classification":
            best_model = cb.CatBoostClassifier(**best_params, random_state=self.random_state,
                                              verbose=False, allow_writing_files=False)
        else:
            best_model = cb.CatBoostRegressor(**best_params, random_state=self.random_state,
                                             verbose=False, allow_writing_files=False)

        best_model.fit(X, y)

        optimization_time = time.time() - start_time

        logger.info(f"✓ CatBoost optimized: {self.metric}={study.best_value:.4f} ({self.n_trials} trials, {optimization_time:.1f}s)")

        return OptimizationResult(
            best_model=best_model,
            best_params=best_params,
            best_score=study.best_value,
            n_trials=self.n_trials,
            optimization_time=optimization_time,
            trial_history=[
                {'number': t.number, 'value': t.value, 'params': t.params}
                for t in study.trials
            ],
            model_type='catboost'
        )

    def optimize_all(self, X: np.ndarray, y: np.ndarray) -> List[OptimizationResult]:
        """
        Optimize all available models and compare

        Args:
            X: Feature matrix
            y: Target labels

        Returns:
            List of OptimizationResult, sorted by performance
        """
        results = []

        # XGBoost
        if XGBOOST_AVAILABLE:
            try:
                result = self.optimize_xgboost(X, y)
                results.append(result)
            except Exception as e:
                logger.error(f"XGBoost optimization failed: {str(e)}")

        # LightGBM
        if LIGHTGBM_AVAILABLE:
            try:
                result = self.optimize_lightgbm(X, y)
                results.append(result)
            except Exception as e:
                logger.error(f"LightGBM optimization failed: {str(e)}")

        # CatBoost
        if CATBOOST_AVAILABLE:
            try:
                result = self.optimize_catboost(X, y)
                results.append(result)
            except Exception as e:
                logger.error(f"CatBoost optimization failed: {str(e)}")

        # Sort by score
        results.sort(key=lambda x: x.best_score, reverse=True)

        if results:
            best = results[0]
            logger.info(f"🏆 Best model: {best.model_type} ({self.metric}={best.best_score:.4f})")

        return results

    def get_best_model(self, X: np.ndarray, y: np.ndarray) -> Tuple[Any, Dict[str, Any]]:
        """
        Get best model across all algorithms

        Args:
            X: Feature matrix
            y: Target labels

        Returns:
            Tuple of (best_model, metadata)
        """
        results = self.optimize_all(X, y)

        if not results:
            raise RuntimeError("No models could be optimized")

        best_result = results[0]

        metadata = {
            'model_type': best_result.model_type,
            'best_params': best_result.best_params,
            'best_score': best_result.best_score,
            'optimization_time': best_result.optimization_time,
            'n_trials': best_result.n_trials,
            'all_results': [
                {
                    'model_type': r.model_type,
                    'score': r.best_score,
                    'params': r.best_params
                }
                for r in results
            ]
        }

        return best_result.best_model, metadata


class SimpleAutoML:
    """
    Simplified AutoML without Optuna dependency
    Uses grid search over predefined hyperparameter ranges
    """

    def __init__(self, task: str = "classification",
                 metric: str = "roc_auc",
                 cv_folds: int = 5,
                 random_state: int = 42):
        """Initialize simple AutoML"""
        self.task = task
        self.metric = metric
        self.cv_folds = cv_folds
        self.random_state = random_state

    def get_best_model(self, X: np.ndarray, y: np.ndarray) -> Tuple[Any, Dict[str, Any]]:
        """
        Get best model using simple search

        Args:
            X: Feature matrix
            y: Target labels

        Returns:
            Tuple of (best_model, metadata)
        """
        logger.info("Running simple AutoML (grid search)...")

        candidates = []

        # Random Forest
        for n_estimators in [50, 100, 200]:
            for max_depth in [5, 10, None]:
                model = RandomForestClassifier(
                    n_estimators=n_estimators,
                    max_depth=max_depth,
                    random_state=self.random_state,
                    n_jobs=-1
                )
                score = cross_val_score(
                    model, X, y,
                    cv=StratifiedKFold(n_splits=self.cv_folds, shuffle=True,
                                     random_state=self.random_state),
                    scoring=self.metric
                ).mean()

                candidates.append({
                    'model': model,
                    'type': 'random_forest',
                    'params': {'n_estimators': n_estimators, 'max_depth': max_depth},
                    'score': score
                })

        # Gradient Boosting
        for n_estimators in [50, 100]:
            for learning_rate in [0.01, 0.1]:
                model = GradientBoostingClassifier(
                    n_estimators=n_estimators,
                    learning_rate=learning_rate,
                    random_state=self.random_state
                )
                score = cross_val_score(
                    model, X, y,
                    cv=StratifiedKFold(n_splits=self.cv_folds, shuffle=True,
                                     random_state=self.random_state),
                    scoring=self.metric
                ).mean()

                candidates.append({
                    'model': model,
                    'type': 'gradient_boosting',
                    'params': {'n_estimators': n_estimators, 'learning_rate': learning_rate},
                    'score': score
                })

        # Find best
        best = max(candidates, key=lambda x: x['score'])
        best['model'].fit(X, y)

        logger.info(f"✓ Best model: {best['type']} ({self.metric}={best['score']:.4f})")

        metadata = {
            'model_type': best['type'],
            'best_params': best['params'],
            'best_score': best['score'],
            'n_candidates': len(candidates)
        }

        return best['model'], metadata


def create_automl(use_optuna: bool = True, **kwargs) -> Union[AutoMLOptimizer, SimpleAutoML]:
    """
    Factory function to create appropriate AutoML instance

    Args:
        use_optuna: Use Optuna if available
        **kwargs: Arguments for AutoML

    Returns:
        AutoML instance
    """
    if use_optuna and OPTUNA_AVAILABLE:
        return AutoMLOptimizer(**kwargs)
    else:
        return SimpleAutoML(**kwargs)
