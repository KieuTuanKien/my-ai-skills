---
name: ml-trading-models
description: Machine Learning models for trading - XGBoost, Random Forest, LightGBM, SVM for price prediction, trend classification, and signal generation. Covers feature engineering from OHLCV, walk-forward validation, hyperparameter optimization (Optuna/Bayesian), ensemble methods, and production ML pipelines for FX/crypto/commodities. Use when building predictive trading models, engineering features from price data, or creating ML-based trading signals.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Machine Learning, XGBoost, Random Forest, LightGBM, SVM, Feature Engineering, Trading, Prediction, Optuna]
dependencies: [scikit-learn, xgboost, lightgbm, optuna, pandas, numpy, ta, shap, joblib]
---

# Machine Learning Trading Models

## When to Use

- Building predictive models for price direction/magnitude
- Feature engineering from OHLCV + technical indicators
- Trend classification (bull/bear/range)
- ML-based entry/exit signal generation
- Hyperparameter optimization with Optuna
- Ensemble models combining multiple classifiers
- Feature importance analysis with SHAP

## Installation

```bash
pip install scikit-learn xgboost lightgbm optuna shap ta pandas numpy joblib
```

## Feature Engineering Pipeline

```python
import pandas as pd
import numpy as np
import ta

def build_features(df: pd.DataFrame, target_horizon: int = 5) -> pd.DataFrame:
    """Build 80+ features from OHLCV data."""
    f = df.copy()

    # === Price-based ===
    for w in [5, 10, 20, 50, 100]:
        f[f'sma_{w}'] = f['close'].rolling(w).mean()
        f[f'ema_{w}'] = f['close'].ewm(span=w).mean()
        f[f'close_vs_sma_{w}'] = (f['close'] - f[f'sma_{w}']) / f[f'sma_{w}']
        f[f'vol_sma_{w}'] = f['volume'].rolling(w).mean()

    # === Momentum ===
    f['rsi_14'] = ta.momentum.rsi(f['close'], window=14)
    f['rsi_7'] = ta.momentum.rsi(f['close'], window=7)
    f['stoch_k'] = ta.momentum.stoch(f['high'], f['low'], f['close'])
    f['stoch_d'] = ta.momentum.stoch_signal(f['high'], f['low'], f['close'])
    f['macd'] = ta.trend.macd_diff(f['close'])
    f['macd_signal'] = ta.trend.macd_signal(f['close'])
    f['williams_r'] = ta.momentum.williams_r(f['high'], f['low'], f['close'])
    f['roc_10'] = ta.momentum.roc(f['close'], window=10)
    f['cci'] = ta.trend.cci(f['high'], f['low'], f['close'])

    # === Volatility ===
    f['atr_14'] = ta.volatility.average_true_range(f['high'], f['low'], f['close'])
    f['bb_width'] = ta.volatility.bollinger_wband(f['close'])
    f['bb_pct'] = ta.volatility.bollinger_pband(f['close'])
    f['keltner_width'] = ta.volatility.keltner_channel_wband(f['high'], f['low'], f['close'])

    for w in [5, 10, 20]:
        f[f'volatility_{w}'] = f['close'].pct_change().rolling(w).std()
        f[f'return_{w}'] = f['close'].pct_change(w)

    # === Volume ===
    f['obv'] = ta.volume.on_balance_volume(f['close'], f['volume'])
    f['obv_slope'] = f['obv'].diff(5) / f['obv'].shift(5)
    f['volume_ratio'] = f['volume'] / f['volume'].rolling(20).mean()
    f['mfi'] = ta.volume.money_flow_index(f['high'], f['low'], f['close'], f['volume'])

    # === Trend ===
    f['adx'] = ta.trend.adx(f['high'], f['low'], f['close'])
    f['di_plus'] = ta.trend.adx_pos(f['high'], f['low'], f['close'])
    f['di_minus'] = ta.trend.adx_neg(f['high'], f['low'], f['close'])
    f['aroon_up'] = ta.trend.aroon_up(f['close'])
    f['aroon_down'] = ta.trend.aroon_down(f['close'])

    # === Candlestick ===
    f['body_ratio'] = abs(f['close'] - f['open']) / (f['high'] - f['low'] + 1e-10)
    f['upper_shadow'] = (f['high'] - f[['close', 'open']].max(axis=1)) / (f['high'] - f['low'] + 1e-10)
    f['lower_shadow'] = (f[['close', 'open']].min(axis=1) - f['low']) / (f['high'] - f['low'] + 1e-10)

    # === Lag features ===
    for lag in [1, 2, 3, 5]:
        f[f'return_lag_{lag}'] = f['close'].pct_change().shift(lag)
        f[f'volume_lag_{lag}'] = f['volume_ratio'].shift(lag)

    # === Time features ===
    if isinstance(f.index, pd.DatetimeIndex):
        f['hour'] = f.index.hour
        f['day_of_week'] = f.index.dayofweek
        f['month'] = f.index.month

    # === Target ===
    future_return = f['close'].shift(-target_horizon) / f['close'] - 1
    f['target_direction'] = (future_return > 0).astype(int)
    f['target_return'] = future_return

    return f.dropna()

df = build_features(ohlcv_data, target_horizon=5)
```

## XGBoost Classifier (Best for Tabular Trading Data)

```python
import xgboost as xgb
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import classification_report, accuracy_score
import numpy as np

def train_xgboost(df: pd.DataFrame, feature_cols: list,
                   target_col: str = 'target_direction') -> dict:
    X = df[feature_cols].values
    y = df[target_col].values

    tscv = TimeSeriesSplit(n_splits=5)
    scores = []
    models = []

    for train_idx, test_idx in tscv.split(X):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]

        model = xgb.XGBClassifier(
            n_estimators=500,
            max_depth=6,
            learning_rate=0.01,
            subsample=0.8,
            colsample_bytree=0.8,
            reg_alpha=0.1,
            reg_lambda=1.0,
            scale_pos_weight=len(y_train[y_train==0]) / max(len(y_train[y_train==1]), 1),
            eval_metric='logloss',
            early_stopping_rounds=50,
            random_state=42,
        )
        model.fit(X_train, y_train,
                  eval_set=[(X_test, y_test)],
                  verbose=False)
        pred = model.predict(X_test)
        scores.append(accuracy_score(y_test, pred))
        models.append(model)

    best_model = models[np.argmax(scores)]
    return {
        'model': best_model,
        'cv_scores': scores,
        'mean_accuracy': np.mean(scores),
        'std_accuracy': np.std(scores),
    }

feature_cols = [c for c in df.columns if c not in ['target_direction', 'target_return',
                'open', 'high', 'low', 'close', 'volume']]
result = train_xgboost(df, feature_cols)
print(f"CV Accuracy: {result['mean_accuracy']:.3f} ± {result['std_accuracy']:.3f}")
```

## LightGBM (Faster, Handles Categoricals)

```python
import lightgbm as lgb

def train_lightgbm(X_train, y_train, X_val, y_val):
    train_data = lgb.Dataset(X_train, label=y_train)
    val_data = lgb.Dataset(X_val, label=y_val, reference=train_data)

    params = {
        'objective': 'binary',
        'metric': 'binary_logloss',
        'boosting_type': 'gbdt',
        'num_leaves': 31,
        'learning_rate': 0.01,
        'feature_fraction': 0.8,
        'bagging_fraction': 0.8,
        'bagging_freq': 5,
        'lambda_l1': 0.1,
        'lambda_l2': 1.0,
        'verbose': -1,
    }

    model = lgb.train(params, train_data, num_boost_round=1000,
                      valid_sets=[val_data],
                      callbacks=[lgb.early_stopping(50), lgb.log_evaluation(0)])
    return model
```

## Random Forest Ensemble

```python
from sklearn.ensemble import RandomForestClassifier, VotingClassifier
from sklearn.svm import SVC
import xgboost as xgb

def build_ensemble(X_train, y_train):
    rf = RandomForestClassifier(
        n_estimators=300, max_depth=10, min_samples_leaf=20,
        class_weight='balanced', random_state=42, n_jobs=-1
    )
    xgb_clf = xgb.XGBClassifier(
        n_estimators=300, max_depth=6, learning_rate=0.01,
        subsample=0.8, random_state=42
    )
    svm = SVC(kernel='rbf', C=1.0, gamma='scale', probability=True)

    ensemble = VotingClassifier(
        estimators=[('rf', rf), ('xgb', xgb_clf), ('svm', svm)],
        voting='soft',
        weights=[1, 2, 1],
    )
    ensemble.fit(X_train, y_train)
    return ensemble
```

## Optuna Hyperparameter Optimization

```python
import optuna

def optimize_xgboost(X, y, n_trials=100):
    tscv = TimeSeriesSplit(n_splits=3)

    def objective(trial):
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 100, 1000),
            'max_depth': trial.suggest_int('max_depth', 3, 10),
            'learning_rate': trial.suggest_float('learning_rate', 0.001, 0.1, log=True),
            'subsample': trial.suggest_float('subsample', 0.6, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
            'reg_alpha': trial.suggest_float('reg_alpha', 1e-8, 10.0, log=True),
            'reg_lambda': trial.suggest_float('reg_lambda', 1e-8, 10.0, log=True),
            'min_child_weight': trial.suggest_int('min_child_weight', 1, 10),
            'gamma': trial.suggest_float('gamma', 0, 5),
        }

        scores = []
        for train_idx, val_idx in tscv.split(X):
            model = xgb.XGBClassifier(**params, eval_metric='logloss',
                                       early_stopping_rounds=30, random_state=42)
            model.fit(X[train_idx], y[train_idx],
                      eval_set=[(X[val_idx], y[val_idx])], verbose=False)
            pred = model.predict(X[val_idx])
            scores.append(accuracy_score(y[val_idx], pred))
        return np.mean(scores)

    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=n_trials, show_progress_bar=True)
    return study.best_params, study.best_value
```

## SHAP Feature Importance

```python
import shap

def explain_model(model, X_test, feature_names):
    explainer = shap.TreeExplainer(model)
    shap_values = explainer.shap_values(X_test)

    # Top features
    importance = np.abs(shap_values).mean(axis=0)
    top_features = sorted(zip(feature_names, importance),
                          key=lambda x: x[1], reverse=True)[:15]

    shap.summary_plot(shap_values, X_test, feature_names=feature_names)
    return top_features
```

## Walk-Forward ML Pipeline

```python
def walk_forward_ml(df, feature_cols, target_col='target_direction',
                     train_window=500, test_window=50, step=50):
    """Production walk-forward: train on window, predict next period, slide."""
    predictions = []

    for start in range(0, len(df) - train_window - test_window, step):
        train = df.iloc[start:start + train_window]
        test = df.iloc[start + train_window:start + train_window + test_window]

        X_train = train[feature_cols].values
        y_train = train[target_col].values
        X_test = test[feature_cols].values
        y_test = test[target_col].values

        model = xgb.XGBClassifier(
            n_estimators=300, max_depth=6, learning_rate=0.01,
            eval_metric='logloss', early_stopping_rounds=30, random_state=42
        )
        model.fit(X_train, y_train,
                  eval_set=[(X_test, y_test)], verbose=False)

        proba = model.predict_proba(X_test)[:, 1]
        pred = model.predict(X_test)

        for i in range(len(test)):
            predictions.append({
                'date': test.index[i],
                'actual': y_test[i],
                'predicted': pred[i],
                'confidence': max(proba[i], 1 - proba[i]),
            })

    return pd.DataFrame(predictions)
```

## ML Signal to Trading Signal

```python
def ml_to_trade_signal(model, df, feature_cols, confidence_threshold=0.65):
    """Convert ML prediction to actionable trade signal."""
    X = df[feature_cols].iloc[-1:].values
    proba = model.predict_proba(X)[0]
    pred_class = model.predict(X)[0]
    confidence = max(proba)

    atr = df['atr_14'].iloc[-1]
    price = df['close'].iloc[-1]

    if confidence < confidence_threshold:
        return {'signal': 'HOLD', 'confidence': confidence, 'reason': 'Low confidence'}

    if pred_class == 1:  # Bullish
        return {
            'signal': 'BUY', 'confidence': round(confidence, 3),
            'entry': price, 'sl': price - 2 * atr, 'tp': price + 3 * atr,
            'features_used': len(feature_cols),
        }
    else:
        return {
            'signal': 'SELL', 'confidence': round(confidence, 3),
            'entry': price, 'sl': price + 2 * atr, 'tp': price - 3 * atr,
            'features_used': len(feature_cols),
        }
```

## Model Comparison

| Model | Speed | Accuracy | Interpretability | Best For |
|-------|-------|----------|-----------------|----------|
| XGBoost | Fast | High | Medium (SHAP) | General purpose, tabular |
| LightGBM | Fastest | High | Medium (SHAP) | Large datasets, categoricals |
| Random Forest | Medium | Medium-High | High (feature importance) | Baseline, robust |
| SVM (RBF) | Slow | Medium | Low | Small datasets, non-linear |
| Ensemble | Slow | Highest | Low | Production, consensus |

## Anti-Overfitting Checklist

- Always use `TimeSeriesSplit`, never random split
- Walk-forward validation is mandatory for production
- Minimum 500 training samples, 100 test samples
- Feature importance: drop features with near-zero SHAP
- Retrain model weekly/monthly, never set-and-forget
- Out-of-sample accuracy > 52% is already useful for trading
- Use confidence threshold to filter low-quality signals
