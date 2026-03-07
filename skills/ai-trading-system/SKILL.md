---
name: ai-trading-system
description: |
  Professional AI-powered algorithmic trading system for Gold (XAUUSD) and
  Forex (EURUSD, GBPUSD, USDJPY, etc.). Combines Machine Learning (XGBoost,
  LightGBM, CatBoost), Deep Learning (LSTM, Transformer, Temporal Fusion
  Transformer, CNN-LSTM), Reinforcement Learning (DQN, PPO, SAC), and
  Optimization Algorithms (Genetic Algorithm, PSO, Bayesian Optimization)
  into a unified multi-model ensemble with real-time AI decision engine.
  Features include: multi-timeframe feature engineering, market regime
  detection (HMM), dynamic position sizing (Kelly), adaptive strategy
  selection, sentiment analysis, and Monte Carlo risk simulation.
  Use when building professional AI trading bots for gold/forex, designing
  ML/DL trading algorithms, optimizing strategy parameters with evolutionary
  algorithms, or creating live AI-driven execution systems.
version: 1.0.0
tags: [Trading, AI, ML, DL, XAUUSD, Forex, XGBoost, LSTM, Transformer, RL, DQN, PPO, Genetic Algorithm, PSO, HMM, Ensemble]
dependencies: [numpy, pandas, scikit-learn, xgboost, lightgbm, catboost, torch, tensorflow, optuna, deap, hmmlearn, ta, MetaTrader5, ccxt, vectorbt, plotly, joblib, onnxruntime]
---

# Goal

Design and deploy a professional AI-powered trading system for Gold (XAUUSD)
and Forex that achieves consistent risk-adjusted returns through multi-model
ensemble intelligence, adaptive regime detection, and real-time optimization.
Target metrics: Sharpe Ratio > 1.5, Max Drawdown < 15%, Win Rate > 55%.

# Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI TRADING SYSTEM v1.0                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌──────────────┐  │
│  │  Market   │→│  Feature   │→│  Model    │→│  Decision    │  │
│  │  Data     │  │  Engine    │  │  Ensemble │  │  Engine      │  │
│  │  Feed     │  │  (250+     │  │  (ML+DL+  │  │  (AI-driven  │  │
│  │  (MT5/    │  │  features) │  │   RL)     │  │   execution) │  │
│  │  CCXT)    │  │            │  │           │  │              │  │
│  └──────────┘  └───────────┘  └──────────┘  └──────────────┘  │
│       ↑                            │               │            │
│       │         ┌──────────────────┤               │            │
│       │         ↓                  ↓               ↓            │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌──────────────┐  │
│  │  Regime   │  │  Risk     │  │  Backtest │  │  Performance │  │
│  │  Detector │  │  Manager  │  │  Engine   │  │  Monitor     │  │
│  │  (HMM)   │  │  (Kelly+  │  │  (Walk-   │  │  (Real-time  │  │
│  │           │  │  MC Sim)  │  │  Forward) │  │  dashboard)  │  │
│  └──────────┘  └───────────┘  └──────────┘  └──────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Optimizer: GA + PSO + Bayesian (Optuna)                  │  │
│  │  Continuously evolves strategy parameters                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

# Instructions

## Phase 1: Data Pipeline & Feature Engineering

### 1.1 Multi-Timeframe Data Acquisition

```python
import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

class MarketDataPipeline:
    """Multi-timeframe, multi-source data pipeline."""

    TIMEFRAMES = {
        'M1': mt5.TIMEFRAME_M1,   'M5': mt5.TIMEFRAME_M5,
        'M15': mt5.TIMEFRAME_M15, 'M30': mt5.TIMEFRAME_M30,
        'H1': mt5.TIMEFRAME_H1,   'H4': mt5.TIMEFRAME_H4,
        'D1': mt5.TIMEFRAME_D1,   'W1': mt5.TIMEFRAME_W1,
    }

    SYMBOLS = {
        'gold': 'XAUUSD',
        'eurusd': 'EURUSD',
        'gbpusd': 'GBPUSD',
        'usdjpy': 'USDJPY',
    }

    def __init__(self):
        if not mt5.initialize():
            raise RuntimeError(f"MT5 init failed: {mt5.last_error()}")

    def fetch_ohlcv(self, symbol: str, timeframe: str,
                    bars: int = 10000) -> pd.DataFrame:
        tf = self.TIMEFRAMES[timeframe]
        rates = mt5.copy_rates_from_pos(symbol, tf, 0, bars)
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        df.rename(columns={'tick_volume': 'volume'}, inplace=True)
        return df[['open', 'high', 'low', 'close', 'volume']]

    def fetch_multi_timeframe(self, symbol: str,
                               timeframes: list = None) -> dict:
        if timeframes is None:
            timeframes = ['M15', 'H1', 'H4', 'D1']
        return {tf: self.fetch_ohlcv(symbol, tf) for tf in timeframes}

    def fetch_tick_data(self, symbol: str, n_ticks: int = 100000):
        ticks = mt5.copy_ticks_from_pos(symbol, 0, n_ticks, mt5.COPY_TICKS_ALL)
        df = pd.DataFrame(ticks)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        return df
```

### 1.2 Feature Engineering Engine (250+ Features)

```python
import ta
from scipy import stats

class FeatureEngine:
    """Generate 250+ features across multiple categories."""

    def __init__(self, df: pd.DataFrame):
        self.df = df.copy()
        self.features = pd.DataFrame(index=df.index)

    def build_all(self) -> pd.DataFrame:
        self._price_features()
        self._trend_features()
        self._momentum_features()
        self._volatility_features()
        self._volume_features()
        self._statistical_features()
        self._microstructure_features()
        self._calendar_features()
        self._multi_timeframe_features()
        self._target_engineering()
        return self.features.dropna()

    def _price_features(self):
        df = self.df
        f = self.features

        # Returns at multiple horizons
        for period in [1, 2, 3, 5, 10, 20, 60]:
            f[f'return_{period}'] = df['close'].pct_change(period)
            f[f'log_return_{period}'] = np.log(df['close'] / df['close'].shift(period))

        # Price ratios
        f['hl_ratio'] = (df['high'] - df['low']) / df['close']
        f['oc_ratio'] = (df['close'] - df['open']) / df['close']
        f['upper_shadow'] = (df['high'] - df[['open', 'close']].max(axis=1)) / df['close']
        f['lower_shadow'] = (df[['open', 'close']].min(axis=1) - df['low']) / df['close']
        f['body_size'] = abs(df['close'] - df['open']) / df['close']
        f['is_bullish'] = (df['close'] > df['open']).astype(int)

        # Gap
        f['gap'] = (df['open'] - df['close'].shift(1)) / df['close'].shift(1)

    def _trend_features(self):
        df = self.df
        f = self.features

        # Moving averages
        for period in [5, 10, 20, 50, 100, 200]:
            f[f'sma_{period}'] = df['close'].rolling(period).mean()
            f[f'ema_{period}'] = df['close'].ewm(span=period).mean()
            f[f'price_vs_sma_{period}'] = (df['close'] - f[f'sma_{period}']) / f[f'sma_{period}']

        # MA crossovers
        f['sma_5_20_cross'] = (f['sma_5'] > f['sma_20']).astype(int)
        f['sma_10_50_cross'] = (f['sma_10'] > f['sma_50']).astype(int)
        f['sma_20_200_cross'] = (f['sma_20'] > f['sma_200']).astype(int)

        # Trend strength
        f['adx'] = ta.trend.adx(df['high'], df['low'], df['close'])
        f['di_plus'] = ta.trend.adx_pos(df['high'], df['low'], df['close'])
        f['di_minus'] = ta.trend.adx_neg(df['high'], df['low'], df['close'])
        f['di_diff'] = f['di_plus'] - f['di_minus']

        # Ichimoku
        ichi = ta.trend.IchimokuIndicator(df['high'], df['low'])
        f['ichi_a'] = ichi.ichimoku_a()
        f['ichi_b'] = ichi.ichimoku_b()
        f['ichi_base'] = ichi.ichimoku_base_line()
        f['ichi_conv'] = ichi.ichimoku_conversion_line()
        f['price_vs_cloud'] = np.where(
            df['close'] > f[['ichi_a', 'ichi_b']].max(axis=1), 1,
            np.where(df['close'] < f[['ichi_a', 'ichi_b']].min(axis=1), -1, 0)
        )

        # MACD
        f['macd'] = ta.trend.macd(df['close'])
        f['macd_signal'] = ta.trend.macd_signal(df['close'])
        f['macd_hist'] = ta.trend.macd_diff(df['close'])
        f['macd_cross'] = (f['macd'] > f['macd_signal']).astype(int)

        # Supertrend proxy via ATR bands
        atr = ta.volatility.average_true_range(df['high'], df['low'], df['close'])
        f['upper_band_3atr'] = df['close'].rolling(10).mean() + 3 * atr
        f['lower_band_3atr'] = df['close'].rolling(10).mean() - 3 * atr

    def _momentum_features(self):
        df = self.df
        f = self.features

        # RSI at multiple periods
        for period in [6, 14, 21]:
            f[f'rsi_{period}'] = ta.momentum.rsi(df['close'], window=period)

        # Stochastic
        f['stoch_k'] = ta.momentum.stoch(df['high'], df['low'], df['close'])
        f['stoch_d'] = ta.momentum.stoch_signal(df['high'], df['low'], df['close'])
        f['stoch_cross'] = (f['stoch_k'] > f['stoch_d']).astype(int)

        # Williams %R
        f['williams_r'] = ta.momentum.williams_r(df['high'], df['low'], df['close'])

        # CCI
        f['cci'] = ta.trend.cci(df['high'], df['low'], df['close'])

        # ROC
        for period in [5, 10, 20]:
            f[f'roc_{period}'] = ta.momentum.roc(df['close'], window=period)

        # Money Flow Index
        f['mfi'] = ta.volume.money_flow_index(
            df['high'], df['low'], df['close'], df['volume']
        )

        # Ultimate Oscillator
        f['uo'] = ta.momentum.ultimate_oscillator(df['high'], df['low'], df['close'])

        # RSI divergence detection
        f['rsi_divergence'] = self._detect_divergence(
            df['close'], f['rsi_14'], lookback=14
        )

    def _volatility_features(self):
        df = self.df
        f = self.features

        # ATR
        for period in [7, 14, 21]:
            f[f'atr_{period}'] = ta.volatility.average_true_range(
                df['high'], df['low'], df['close'], window=period
            )
            f[f'atr_pct_{period}'] = f[f'atr_{period}'] / df['close']

        # Bollinger Bands
        bb = ta.volatility.BollingerBands(df['close'])
        f['bb_upper'] = bb.bollinger_hband()
        f['bb_lower'] = bb.bollinger_lband()
        f['bb_mid'] = bb.bollinger_mavg()
        f['bb_width'] = (f['bb_upper'] - f['bb_lower']) / f['bb_mid']
        f['bb_pctb'] = bb.bollinger_pband()

        # Keltner Channel
        kc = ta.volatility.KeltnerChannel(df['high'], df['low'], df['close'])
        f['kc_upper'] = kc.keltner_channel_hband()
        f['kc_lower'] = kc.keltner_channel_lband()

        # Squeeze detection (BB inside KC)
        f['squeeze'] = ((f['bb_upper'] < f['kc_upper']) &
                         (f['bb_lower'] > f['kc_lower'])).astype(int)

        # Historical volatility
        for period in [5, 10, 20, 60]:
            f[f'hvol_{period}'] = df['close'].pct_change().rolling(period).std() * np.sqrt(252)

        # Volatility ratio
        f['vol_ratio'] = f['hvol_5'] / f['hvol_20']

        # Parkinson volatility
        f['parkinson_vol'] = np.sqrt(
            (1 / (4 * np.log(2))) *
            (np.log(df['high'] / df['low']) ** 2).rolling(20).mean()
        )

    def _volume_features(self):
        df = self.df
        f = self.features

        # Volume ratios
        for period in [5, 10, 20]:
            f[f'vol_sma_{period}'] = df['volume'].rolling(period).mean()
            f[f'vol_ratio_{period}'] = df['volume'] / f[f'vol_sma_{period}']

        # OBV
        f['obv'] = ta.volume.on_balance_volume(df['close'], df['volume'])
        f['obv_sma'] = f['obv'].rolling(20).mean()
        f['obv_trend'] = (f['obv'] > f['obv_sma']).astype(int)

        # VWAP (intraday)
        typical = (df['high'] + df['low'] + df['close']) / 3
        f['vwap'] = (typical * df['volume']).cumsum() / df['volume'].cumsum()
        f['price_vs_vwap'] = (df['close'] - f['vwap']) / f['vwap']

        # Accumulation/Distribution
        f['ad_line'] = ta.volume.acc_dist_index(
            df['high'], df['low'], df['close'], df['volume']
        )

        # Force Index
        f['force_index'] = ta.volume.force_index(df['close'], df['volume'])

    def _statistical_features(self):
        df = self.df
        f = self.features
        returns = df['close'].pct_change()

        for period in [20, 60]:
            r = returns.rolling(period)
            f[f'skewness_{period}'] = r.skew()
            f[f'kurtosis_{period}'] = r.kurt()
            f[f'mean_return_{period}'] = r.mean()
            f[f'sharpe_rolling_{period}'] = r.mean() / r.std() * np.sqrt(252)

        # Hurst exponent (trend vs mean-reversion detection)
        f['hurst'] = returns.rolling(100).apply(self._hurst_exponent, raw=True)

        # Z-score of price relative to rolling mean
        for period in [20, 50]:
            mu = df['close'].rolling(period).mean()
            sigma = df['close'].rolling(period).std()
            f[f'zscore_{period}'] = (df['close'] - mu) / sigma

        # Autocorrelation
        for lag in [1, 5, 10]:
            f[f'autocorr_{lag}'] = returns.rolling(50).apply(
                lambda x: x.autocorr(lag=lag), raw=False
            )

    def _microstructure_features(self):
        df = self.df
        f = self.features

        # Support / Resistance levels
        f['resistance_20'] = df['high'].rolling(20).max()
        f['support_20'] = df['low'].rolling(20).min()
        f['price_vs_resistance'] = (df['close'] - f['resistance_20']) / f['resistance_20']
        f['price_vs_support'] = (df['close'] - f['support_20']) / f['support_20']

        # Pivot points
        f['pivot'] = (df['high'].shift(1) + df['low'].shift(1) + df['close'].shift(1)) / 3
        f['r1'] = 2 * f['pivot'] - df['low'].shift(1)
        f['s1'] = 2 * f['pivot'] - df['high'].shift(1)
        f['price_vs_pivot'] = (df['close'] - f['pivot']) / f['pivot']

        # Fibonacci retracement levels
        swing_high = df['high'].rolling(50).max()
        swing_low = df['low'].rolling(50).min()
        swing_range = swing_high - swing_low
        f['fib_236'] = swing_high - 0.236 * swing_range
        f['fib_382'] = swing_high - 0.382 * swing_range
        f['fib_500'] = swing_high - 0.500 * swing_range
        f['fib_618'] = swing_high - 0.618 * swing_range

        # Distance to nearest Fib level
        fibs = f[['fib_236', 'fib_382', 'fib_500', 'fib_618']]
        f['nearest_fib_dist'] = fibs.sub(df['close'], axis=0).abs().min(axis=1) / df['close']

    def _calendar_features(self):
        df = self.df
        f = self.features
        idx = df.index

        f['hour'] = idx.hour
        f['day_of_week'] = idx.dayofweek
        f['month'] = idx.month
        f['is_london'] = ((idx.hour >= 8) & (idx.hour < 16)).astype(int)
        f['is_newyork'] = ((idx.hour >= 13) & (idx.hour < 21)).astype(int)
        f['is_overlap'] = ((idx.hour >= 13) & (idx.hour < 16)).astype(int)
        f['is_asian'] = ((idx.hour >= 0) & (idx.hour < 8)).astype(int)

        # Day-of-week seasonality
        f['is_monday'] = (idx.dayofweek == 0).astype(int)
        f['is_friday'] = (idx.dayofweek == 4).astype(int)

        # Month-end effect
        f['days_to_month_end'] = pd.Series(
            [(idx[i] + pd.offsets.MonthEnd(0) - idx[i]).days for i in range(len(idx))],
            index=idx
        )

    def _multi_timeframe_features(self):
        """Add higher-timeframe context via resampling."""
        df = self.df
        f = self.features

        for tf_label, rule in [('4h', '4h'), ('1d', '1D')]:
            resampled = df.resample(rule).agg({
                'open': 'first', 'high': 'max', 'low': 'min',
                'close': 'last', 'volume': 'sum'
            }).dropna()

            htf_rsi = ta.momentum.rsi(resampled['close'], window=14)
            htf_atr = ta.volatility.average_true_range(
                resampled['high'], resampled['low'], resampled['close']
            )
            htf_trend = (resampled['close'] > resampled['close'].rolling(20).mean()).astype(int)

            # Forward-fill to align with base timeframe
            f[f'htf_{tf_label}_rsi'] = htf_rsi.reindex(df.index, method='ffill')
            f[f'htf_{tf_label}_atr'] = htf_atr.reindex(df.index, method='ffill')
            f[f'htf_{tf_label}_trend'] = htf_trend.reindex(df.index, method='ffill')

    def _target_engineering(self):
        df = self.df
        f = self.features

        # Forward returns for supervised learning
        for horizon in [1, 5, 10, 20]:
            f[f'fwd_return_{horizon}'] = df['close'].pct_change(horizon).shift(-horizon)

        # Classification targets
        f['target_direction'] = np.where(f['fwd_return_5'] > 0.001, 1,
                                 np.where(f['fwd_return_5'] < -0.001, -1, 0))

        # Regression target (risk-adjusted)
        f['target_return'] = f['fwd_return_5']

    @staticmethod
    def _hurst_exponent(ts, max_lag=20):
        lags = range(2, min(max_lag, len(ts)))
        tau = [np.std(np.subtract(ts[lag:], ts[:-lag])) for lag in lags]
        if not all(t > 0 for t in tau):
            return 0.5
        reg = np.polyfit(np.log(list(lags)), np.log(tau), 1)
        return reg[0]

    @staticmethod
    def _detect_divergence(price, indicator, lookback=14):
        result = pd.Series(0, index=price.index)
        for i in range(lookback, len(price)):
            p_curr, p_prev = price.iloc[i], price.iloc[i - lookback]
            i_curr, i_prev = indicator.iloc[i], indicator.iloc[i - lookback]
            if p_curr > p_prev and i_curr < i_prev:
                result.iloc[i] = -1  # bearish divergence
            elif p_curr < p_prev and i_curr > i_prev:
                result.iloc[i] = 1   # bullish divergence
        return result
```

## Phase 2: Market Regime Detection

### 2.1 Hidden Markov Model (HMM) Regime Detector

```python
from hmmlearn.hmm import GaussianHMM

class RegimeDetector:
    """Detect market regimes: Trending, Ranging, Volatile, Crisis."""

    REGIME_NAMES = {0: 'low_vol_range', 1: 'trend_up', 2: 'trend_down', 3: 'high_vol_crisis'}

    def __init__(self, n_regimes: int = 4, lookback: int = 252):
        self.n_regimes = n_regimes
        self.lookback = lookback
        self.model = GaussianHMM(
            n_components=n_regimes,
            covariance_type='full',
            n_iter=200,
            random_state=42
        )

    def fit_predict(self, df: pd.DataFrame) -> pd.Series:
        features = self._prepare_features(df)
        self.model.fit(features[-self.lookback:])
        regimes = self.model.predict(features)
        return pd.Series(regimes, index=df.index[-len(regimes):], name='regime')

    def _prepare_features(self, df):
        returns = df['close'].pct_change().dropna()
        vol = returns.rolling(20).std().dropna()
        trend = (df['close'].rolling(20).mean() - df['close'].rolling(50).mean()).dropna()

        aligned = pd.concat([returns, vol, trend], axis=1).dropna()
        aligned.columns = ['return', 'volatility', 'trend']
        return aligned.values

    def get_regime_params(self) -> dict:
        """Get learned regime characteristics."""
        params = {}
        for i in range(self.n_regimes):
            params[self.REGIME_NAMES.get(i, f'regime_{i}')] = {
                'mean_return': float(self.model.means_[i][0]),
                'mean_volatility': float(self.model.means_[i][1]),
                'probability': float(self.model.startprob_[i]),
            }
        return params

    def get_transition_matrix(self) -> pd.DataFrame:
        return pd.DataFrame(
            self.model.transmat_,
            index=[self.REGIME_NAMES[i] for i in range(self.n_regimes)],
            columns=[self.REGIME_NAMES[i] for i in range(self.n_regimes)]
        )
```

## Phase 3: ML Model Suite

### 3.1 Gradient Boosting Ensemble (XGBoost + LightGBM + CatBoost)

```python
import xgboost as xgb
import lightgbm as lgb
from catboost import CatBoostClassifier
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import accuracy_score, f1_score, classification_report
import joblib

class GBMEnsemble:
    """Ensemble of gradient boosting models with walk-forward validation."""

    def __init__(self):
        self.models = {
            'xgb': xgb.XGBClassifier(
                n_estimators=500, max_depth=6, learning_rate=0.05,
                subsample=0.8, colsample_bytree=0.8,
                reg_alpha=0.1, reg_lambda=1.0,
                use_label_encoder=False, eval_metric='mlogloss',
                tree_method='hist', random_state=42
            ),
            'lgb': lgb.LGBMClassifier(
                n_estimators=500, max_depth=6, learning_rate=0.05,
                subsample=0.8, colsample_bytree=0.8,
                reg_alpha=0.1, reg_lambda=1.0,
                verbose=-1, random_state=42
            ),
            'cat': CatBoostClassifier(
                iterations=500, depth=6, learning_rate=0.05,
                l2_leaf_reg=3, random_seed=42, verbose=0
            ),
        }
        self.weights = {'xgb': 0.4, 'lgb': 0.35, 'cat': 0.25}
        self.feature_importance = {}

    def walk_forward_train(self, X: pd.DataFrame, y: pd.Series,
                           n_splits: int = 5, test_size: int = 500):
        tscv = TimeSeriesSplit(n_splits=n_splits, test_size=test_size)
        scores = {name: [] for name in self.models}

        for fold, (train_idx, test_idx) in enumerate(tscv.split(X)):
            X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
            y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]

            for name, model in self.models.items():
                model.fit(X_train, y_train)
                pred = model.predict(X_test)
                score = f1_score(y_test, pred, average='weighted')
                scores[name].append(score)

            print(f"Fold {fold+1}: " +
                  " | ".join(f"{n}: {s[-1]:.4f}" for n, s in scores.items()))

        # Update weights based on performance
        avg_scores = {n: np.mean(s) for n, s in scores.items()}
        total = sum(avg_scores.values())
        self.weights = {n: s / total for n, s in avg_scores.items()}
        return scores

    def predict_ensemble(self, X: pd.DataFrame) -> tuple:
        """Weighted probability ensemble."""
        probas = {}
        for name, model in self.models.items():
            probas[name] = model.predict_proba(X) * self.weights[name]

        ensemble_proba = sum(probas.values())
        predictions = np.argmax(ensemble_proba, axis=1)
        confidence = np.max(ensemble_proba, axis=1)
        return predictions, confidence

    def get_feature_importance(self, feature_names: list) -> pd.DataFrame:
        importance = pd.DataFrame(index=feature_names)
        for name, model in self.models.items():
            if hasattr(model, 'feature_importances_'):
                importance[name] = model.feature_importances_
        importance['ensemble'] = importance.mean(axis=1)
        return importance.sort_values('ensemble', ascending=False)

    def save(self, path: str):
        joblib.dump({'models': self.models, 'weights': self.weights}, path)

    def load(self, path: str):
        data = joblib.load(path)
        self.models = data['models']
        self.weights = data['weights']
```

### 3.2 Deep Learning Models (LSTM + Transformer)

```python
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader

class TimeSeriesDataset(Dataset):
    def __init__(self, X, y, seq_len=60):
        self.X = torch.FloatTensor(X)
        self.y = torch.LongTensor(y)
        self.seq_len = seq_len

    def __len__(self):
        return len(self.X) - self.seq_len

    def __getitem__(self, idx):
        return (self.X[idx:idx + self.seq_len],
                self.y[idx + self.seq_len])


class LSTMTrader(nn.Module):
    """Bidirectional LSTM with attention for trading signals."""

    def __init__(self, input_dim, hidden_dim=128, n_layers=3,
                 n_classes=3, dropout=0.3):
        super().__init__()
        self.lstm = nn.LSTM(
            input_dim, hidden_dim, n_layers,
            batch_first=True, dropout=dropout, bidirectional=True
        )
        self.attention = nn.MultiheadAttention(hidden_dim * 2, num_heads=8)
        self.classifier = nn.Sequential(
            nn.LayerNorm(hidden_dim * 2),
            nn.Linear(hidden_dim * 2, 64),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(64, n_classes)
        )

    def forward(self, x):
        lstm_out, _ = self.lstm(x)
        attn_out, _ = self.attention(lstm_out, lstm_out, lstm_out)
        pooled = attn_out.mean(dim=1)
        return self.classifier(pooled)


class TransformerTrader(nn.Module):
    """Temporal Fusion Transformer for trading."""

    def __init__(self, input_dim, d_model=128, nhead=8, n_layers=4,
                 n_classes=3, dropout=0.2, seq_len=60):
        super().__init__()
        self.input_proj = nn.Linear(input_dim, d_model)
        self.pos_enc = nn.Parameter(torch.randn(1, seq_len, d_model) * 0.02)

        encoder_layer = nn.TransformerEncoderLayer(
            d_model=d_model, nhead=nhead,
            dim_feedforward=d_model * 4, dropout=dropout,
            activation='gelu', batch_first=True
        )
        self.transformer = nn.TransformerEncoder(encoder_layer, n_layers)
        self.classifier = nn.Sequential(
            nn.LayerNorm(d_model),
            nn.Linear(d_model, 64),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(64, n_classes)
        )

    def forward(self, x):
        x = self.input_proj(x) + self.pos_enc[:, :x.size(1), :]
        x = self.transformer(x)
        pooled = x.mean(dim=1)
        return self.classifier(pooled)


class CNNLSTMTrader(nn.Module):
    """CNN for local patterns + LSTM for temporal dependencies."""

    def __init__(self, input_dim, n_classes=3, dropout=0.3):
        super().__init__()
        self.cnn = nn.Sequential(
            nn.Conv1d(input_dim, 64, kernel_size=3, padding=1),
            nn.BatchNorm1d(64), nn.GELU(),
            nn.Conv1d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm1d(128), nn.GELU(),
            nn.MaxPool1d(2),
        )
        self.lstm = nn.LSTM(128, 64, num_layers=2, batch_first=True, dropout=dropout)
        self.classifier = nn.Sequential(
            nn.Linear(64, 32), nn.GELU(), nn.Dropout(dropout),
            nn.Linear(32, n_classes)
        )

    def forward(self, x):
        x = x.permute(0, 2, 1)
        x = self.cnn(x)
        x = x.permute(0, 2, 1)
        lstm_out, _ = self.lstm(x)
        return self.classifier(lstm_out[:, -1, :])


class DLTrainer:
    """Train and evaluate deep learning trading models."""

    def __init__(self, model, device='cuda'):
        self.device = torch.device(device if torch.cuda.is_available() else 'cpu')
        self.model = model.to(self.device)

    def train(self, train_loader, val_loader, epochs=100, lr=1e-3):
        optimizer = torch.optim.AdamW(self.model.parameters(), lr=lr, weight_decay=1e-4)
        scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
        criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
        best_val_loss = float('inf')

        for epoch in range(epochs):
            self.model.train()
            train_loss = 0
            for X_batch, y_batch in train_loader:
                X_batch, y_batch = X_batch.to(self.device), y_batch.to(self.device)
                optimizer.zero_grad()
                output = self.model(X_batch)
                loss = criterion(output, y_batch)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(self.model.parameters(), 1.0)
                optimizer.step()
                train_loss += loss.item()

            scheduler.step()

            # Validation
            val_loss, val_acc = self.evaluate(val_loader, criterion)
            if val_loss < best_val_loss:
                best_val_loss = val_loss
                torch.save(self.model.state_dict(), 'best_model.pt')

            if (epoch + 1) % 10 == 0:
                print(f"Epoch {epoch+1}: train_loss={train_loss/len(train_loader):.4f} "
                      f"val_loss={val_loss:.4f} val_acc={val_acc:.4f}")

    def evaluate(self, loader, criterion=None):
        if criterion is None:
            criterion = nn.CrossEntropyLoss()
        self.model.eval()
        total_loss, correct, total = 0, 0, 0
        with torch.no_grad():
            for X_batch, y_batch in loader:
                X_batch, y_batch = X_batch.to(self.device), y_batch.to(self.device)
                output = self.model(X_batch)
                total_loss += criterion(output, y_batch).item()
                correct += (output.argmax(1) == y_batch).sum().item()
                total += len(y_batch)
        return total_loss / len(loader), correct / total

    def predict(self, X: np.ndarray, seq_len=60) -> tuple:
        self.model.eval()
        dataset = TimeSeriesDataset(X, np.zeros(len(X)), seq_len)
        loader = DataLoader(dataset, batch_size=64)
        preds, confs = [], []
        with torch.no_grad():
            for X_batch, _ in loader:
                X_batch = X_batch.to(self.device)
                output = torch.softmax(self.model(X_batch), dim=1)
                preds.extend(output.argmax(1).cpu().numpy())
                confs.extend(output.max(1).values.cpu().numpy())
        return np.array(preds), np.array(confs)
```

## Phase 4: Reinforcement Learning Trading Agent

```python
class TradingEnvironment:
    """Custom OpenAI-Gym-like environment for RL trading."""

    def __init__(self, df: pd.DataFrame, features: pd.DataFrame,
                 initial_balance=10000, commission=0.0001, leverage=100):
        self.df = df
        self.features = features.values
        self.initial_balance = initial_balance
        self.commission = commission
        self.leverage = leverage
        self.reset()

    def reset(self):
        self.balance = self.initial_balance
        self.position = 0  # -1=short, 0=flat, 1=long
        self.position_price = 0
        self.current_step = 60
        self.total_pnl = 0
        self.trades = []
        self.peak_balance = self.initial_balance
        return self._get_obs()

    def _get_obs(self):
        market = self.features[self.current_step - 60:self.current_step]
        account = np.array([self.position, self.balance / self.initial_balance,
                           self.total_pnl / self.initial_balance])
        return {'market': market, 'account': account}

    def step(self, action):
        # action: 0=hold, 1=buy, 2=sell, 3=close
        current_price = self.df['close'].iloc[self.current_step]
        reward = 0

        if action == 3 and self.position != 0:
            reward = self._close_position(current_price)
        elif action == 1 and self.position <= 0:
            if self.position == -1:
                reward += self._close_position(current_price)
            self._open_position(1, current_price)
        elif action == 2 and self.position >= 0:
            if self.position == 1:
                reward += self._close_position(current_price)
            self._open_position(-1, current_price)

        # Unrealized PnL as partial reward
        if self.position != 0:
            unrealized = self.position * (current_price - self.position_price) / self.position_price
            reward += unrealized * 0.1

        # Drawdown penalty
        self.peak_balance = max(self.peak_balance, self.balance)
        drawdown = (self.peak_balance - self.balance) / self.peak_balance
        if drawdown > 0.1:
            reward -= drawdown * 2

        self.current_step += 1
        done = (self.current_step >= len(self.df) - 1 or
                self.balance <= self.initial_balance * 0.5)

        return self._get_obs(), reward, done, {'balance': self.balance}

    def _open_position(self, direction, price):
        self.position = direction
        self.position_price = price
        self.balance -= abs(price * self.commission)

    def _close_position(self, price):
        pnl = self.position * (price - self.position_price) / self.position_price
        pnl_amount = pnl * self.balance * 0.02 * self.leverage
        self.balance += pnl_amount - abs(price * self.commission)
        self.total_pnl += pnl_amount
        self.trades.append({
            'direction': self.position, 'entry': self.position_price,
            'exit': price, 'pnl': pnl_amount
        })
        self.position = 0
        self.position_price = 0
        return pnl


class DQNAgent:
    """Deep Q-Network for trading decisions."""

    def __init__(self, state_dim, action_dim=4, hidden=256, lr=1e-4):
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.action_dim = action_dim
        self.gamma = 0.99
        self.epsilon = 1.0
        self.epsilon_min = 0.01
        self.epsilon_decay = 0.995

        self.q_net = self._build_network(state_dim, action_dim, hidden).to(self.device)
        self.target_net = self._build_network(state_dim, action_dim, hidden).to(self.device)
        self.target_net.load_state_dict(self.q_net.state_dict())
        self.optimizer = torch.optim.Adam(self.q_net.parameters(), lr=lr)
        self.memory = []
        self.batch_size = 64

    def _build_network(self, state_dim, action_dim, hidden):
        return nn.Sequential(
            nn.Linear(state_dim, hidden), nn.ReLU(),
            nn.Linear(hidden, hidden), nn.ReLU(),
            nn.Linear(hidden, hidden // 2), nn.ReLU(),
            nn.Linear(hidden // 2, action_dim)
        )

    def act(self, state):
        if np.random.random() < self.epsilon:
            return np.random.randint(self.action_dim)
        with torch.no_grad():
            state_t = torch.FloatTensor(state).unsqueeze(0).to(self.device)
            q_values = self.q_net(state_t)
            return q_values.argmax().item()

    def train_step(self):
        if len(self.memory) < self.batch_size:
            return

        batch = [self.memory[i] for i in
                 np.random.choice(len(self.memory), self.batch_size, replace=False)]

        states = torch.FloatTensor([b[0] for b in batch]).to(self.device)
        actions = torch.LongTensor([b[1] for b in batch]).to(self.device)
        rewards = torch.FloatTensor([b[2] for b in batch]).to(self.device)
        next_states = torch.FloatTensor([b[3] for b in batch]).to(self.device)
        dones = torch.FloatTensor([b[4] for b in batch]).to(self.device)

        q_values = self.q_net(states).gather(1, actions.unsqueeze(1))
        next_q = self.target_net(next_states).max(1).values.detach()
        targets = rewards + self.gamma * next_q * (1 - dones)

        loss = nn.MSELoss()(q_values.squeeze(), targets)
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)

    def update_target(self):
        self.target_net.load_state_dict(self.q_net.state_dict())
```

## Phase 5: Multi-Model AI Decision Engine

```python
class AIDecisionEngine:
    """
    Unified AI engine combining ML, DL, RL models with regime-aware weighting.
    Final signal = weighted average with confidence-based filtering.
    """

    def __init__(self):
        self.gbm_ensemble = None    # Phase 3.1
        self.dl_models = {}         # Phase 3.2 (LSTM, Transformer, CNN-LSTM)
        self.rl_agent = None        # Phase 4
        self.regime_detector = None # Phase 2
        self.feature_engine = None  # Phase 1

        # Model weights per regime
        self.regime_weights = {
            'low_vol_range': {'gbm': 0.5, 'dl': 0.2, 'rl': 0.3},
            'trend_up':      {'gbm': 0.3, 'dl': 0.4, 'rl': 0.3},
            'trend_down':    {'gbm': 0.3, 'dl': 0.4, 'rl': 0.3},
            'high_vol_crisis': {'gbm': 0.6, 'dl': 0.1, 'rl': 0.3},
        }

        self.min_confidence = 0.6
        self.signal_history = []

    def generate_signal(self, df: pd.DataFrame, features: pd.DataFrame) -> dict:
        """Generate trading signal from all models."""
        regime = self._detect_regime(df)
        weights = self.regime_weights[regime]

        signals = {}

        # GBM signal
        if self.gbm_ensemble:
            pred, conf = self.gbm_ensemble.predict_ensemble(features.tail(1))
            signals['gbm'] = {'signal': int(pred[0]) - 1, 'confidence': float(conf[0])}

        # DL signals
        dl_signals = []
        for name, trainer in self.dl_models.items():
            pred, conf = trainer.predict(features.values)
            dl_signals.append({'signal': int(pred[-1]) - 1, 'confidence': float(conf[-1])})
        if dl_signals:
            avg_signal = np.mean([s['signal'] for s in dl_signals])
            avg_conf = np.mean([s['confidence'] for s in dl_signals])
            signals['dl'] = {'signal': np.sign(avg_signal), 'confidence': avg_conf}

        # RL signal
        if self.rl_agent:
            state = features.values[-60:].flatten()
            action = self.rl_agent.act(state)
            action_to_signal = {0: 0, 1: 1, 2: -1, 3: 0}
            signals['rl'] = {'signal': action_to_signal[action], 'confidence': 0.7}

        # Weighted ensemble
        final_signal = 0
        total_weight = 0
        for model_type, sig_data in signals.items():
            w = weights.get(model_type, 0) * sig_data['confidence']
            final_signal += sig_data['signal'] * w
            total_weight += w

        if total_weight > 0:
            final_signal /= total_weight

        confidence = abs(final_signal)
        direction = np.sign(final_signal) if confidence >= self.min_confidence else 0

        result = {
            'direction': int(direction),     # -1=SELL, 0=HOLD, 1=BUY
            'confidence': round(confidence, 4),
            'regime': regime,
            'model_signals': signals,
            'timestamp': df.index[-1],
        }

        self.signal_history.append(result)
        return result

    def _detect_regime(self, df):
        if self.regime_detector:
            regimes = self.regime_detector.fit_predict(df)
            return self.regime_detector.REGIME_NAMES.get(regimes.iloc[-1], 'unknown')
        return 'trend_up'

    def adapt_weights(self, performance_log: list, lookback: int = 100):
        """Adapt model weights based on recent prediction accuracy."""
        if len(performance_log) < lookback:
            return

        recent = performance_log[-lookback:]
        for regime in self.regime_weights:
            regime_trades = [t for t in recent if t.get('regime') == regime]
            if len(regime_trades) < 10:
                continue

            for model_type in ['gbm', 'dl', 'rl']:
                correct = sum(1 for t in regime_trades
                             if t.get(f'{model_type}_correct', False))
                accuracy = correct / len(regime_trades)
                self.regime_weights[regime][model_type] = max(0.05, accuracy)

            total = sum(self.regime_weights[regime].values())
            self.regime_weights[regime] = {
                k: v / total for k, v in self.regime_weights[regime].items()
            }
```

## Phase 6: Optimization Engine

### 6.1 Genetic Algorithm for Strategy Evolution

```python
from deap import base, creator, tools, algorithms
import random

class StrategyOptimizer:
    """Evolve trading strategy parameters using GA + PSO + Bayesian."""

    PARAM_RANGES = {
        'rsi_period': (6, 30),
        'rsi_oversold': (15, 35),
        'rsi_overbought': (65, 85),
        'ma_fast': (5, 30),
        'ma_slow': (20, 200),
        'atr_multiplier': (1.0, 4.0),
        'stop_loss_atr': (1.0, 3.0),
        'take_profit_atr': (1.5, 5.0),
        'confidence_threshold': (0.5, 0.9),
        'position_size_pct': (0.5, 5.0),
    }

    def optimize_ga(self, backtest_func, n_generations=50, pop_size=100):
        """Genetic Algorithm optimization."""
        creator.create("FitnessMax", base.Fitness, weights=(1.0,))
        creator.create("Individual", list, fitness=creator.FitnessMax)

        toolbox = base.Toolbox()
        param_names = list(self.PARAM_RANGES.keys())

        for i, (name, (lo, hi)) in enumerate(self.PARAM_RANGES.items()):
            toolbox.register(f"attr_{i}", random.uniform, lo, hi)

        def create_individual():
            return creator.Individual(
                [random.uniform(*self.PARAM_RANGES[n]) for n in param_names]
            )

        toolbox.register("individual", create_individual)
        toolbox.register("population", tools.initRepeat, list, toolbox.individual)

        def evaluate(individual):
            params = dict(zip(param_names, individual))
            result = backtest_func(params)
            # Fitness = Sharpe Ratio * (1 - max_drawdown) * win_rate
            fitness = (result['sharpe'] *
                      (1 - result['max_drawdown']) *
                      result['win_rate'])
            return (fitness,)

        toolbox.register("evaluate", evaluate)
        toolbox.register("mate", tools.cxBlend, alpha=0.5)
        toolbox.register("mutate", tools.mutGaussian, mu=0, sigma=0.2, indpb=0.2)
        toolbox.register("select", tools.selTournament, tournsize=3)

        pop = toolbox.population(n=pop_size)
        hof = tools.HallOfFame(5)

        pop, log = algorithms.eaSimple(
            pop, toolbox, cxpb=0.7, mutpb=0.2,
            ngen=n_generations, halloffame=hof, verbose=True
        )

        best_params = dict(zip(param_names, hof[0]))
        return best_params, hof

    def optimize_bayesian(self, backtest_func, n_trials=200):
        """Bayesian optimization with Optuna."""
        import optuna

        def objective(trial):
            params = {}
            for name, (lo, hi) in self.PARAM_RANGES.items():
                if isinstance(lo, int):
                    params[name] = trial.suggest_int(name, lo, hi)
                else:
                    params[name] = trial.suggest_float(name, lo, hi)

            result = backtest_func(params)
            return result['sharpe'] * (1 - result['max_drawdown'])

        study = optuna.create_study(
            direction='maximize',
            sampler=optuna.samplers.TPESampler(seed=42),
            pruner=optuna.pruners.MedianPruner(n_warmup_steps=20)
        )
        study.optimize(objective, n_trials=n_trials, show_progress_bar=True)

        return study.best_params, study

    def optimize_pso(self, backtest_func, n_particles=30, n_iterations=100):
        """Particle Swarm Optimization."""
        param_names = list(self.PARAM_RANGES.keys())
        n_dims = len(param_names)
        lo = np.array([self.PARAM_RANGES[n][0] for n in param_names])
        hi = np.array([self.PARAM_RANGES[n][1] for n in param_names])

        positions = np.random.uniform(lo, hi, (n_particles, n_dims))
        velocities = np.random.uniform(-1, 1, (n_particles, n_dims)) * (hi - lo) * 0.1
        p_best = positions.copy()
        p_best_scores = np.full(n_particles, -np.inf)
        g_best = positions[0].copy()
        g_best_score = -np.inf

        w, c1, c2 = 0.7, 1.5, 1.5

        for iteration in range(n_iterations):
            for i in range(n_particles):
                params = dict(zip(param_names, positions[i]))
                result = backtest_func(params)
                score = result['sharpe'] * (1 - result['max_drawdown']) * result['win_rate']

                if score > p_best_scores[i]:
                    p_best_scores[i] = score
                    p_best[i] = positions[i].copy()
                if score > g_best_score:
                    g_best_score = score
                    g_best = positions[i].copy()

            r1, r2 = np.random.random((n_particles, n_dims)), np.random.random((n_particles, n_dims))
            velocities = (w * velocities +
                         c1 * r1 * (p_best - positions) +
                         c2 * r2 * (g_best - positions))
            positions = np.clip(positions + velocities, lo, hi)

            if (iteration + 1) % 10 == 0:
                print(f"PSO Iter {iteration+1}: Best Score = {g_best_score:.4f}")

        return dict(zip(param_names, g_best)), g_best_score
```

## Phase 7: Risk Management & Position Sizing

```python
class AIRiskManager:
    """AI-enhanced risk management with Kelly criterion and Monte Carlo."""

    def __init__(self, initial_capital: float = 10000, max_risk_pct: float = 2.0,
                 max_drawdown_pct: float = 15.0, max_daily_loss_pct: float = 5.0):
        self.initial_capital = initial_capital
        self.max_risk_pct = max_risk_pct / 100
        self.max_drawdown_pct = max_drawdown_pct / 100
        self.max_daily_loss_pct = max_daily_loss_pct / 100
        self.daily_pnl = 0
        self.peak_equity = initial_capital
        self.current_equity = initial_capital

    def kelly_position_size(self, win_rate: float, avg_win: float,
                            avg_loss: float) -> float:
        if avg_loss == 0:
            return 0
        b = avg_win / abs(avg_loss)
        kelly = (win_rate * b - (1 - win_rate)) / b
        # Half-Kelly for safety
        return max(0, min(kelly * 0.5, self.max_risk_pct))

    def calculate_lot_size(self, symbol: str, stop_loss_pips: float,
                           confidence: float, regime: str) -> float:
        pip_values = {'XAUUSD': 0.1, 'EURUSD': 10, 'GBPUSD': 10, 'USDJPY': 1000/130}
        pip_value = pip_values.get(symbol, 10)

        risk_amount = self.current_equity * self.max_risk_pct

        # Regime adjustment
        regime_multipliers = {
            'low_vol_range': 1.0, 'trend_up': 1.2,
            'trend_down': 1.2, 'high_vol_crisis': 0.5,
        }
        risk_amount *= regime_multipliers.get(regime, 1.0)

        # Confidence scaling
        risk_amount *= min(confidence, 1.0)

        lot_size = risk_amount / (stop_loss_pips * pip_value)
        return round(max(0.01, min(lot_size, 10.0)), 2)

    def check_trade_allowed(self, current_equity: float) -> dict:
        self.current_equity = current_equity
        drawdown = (self.peak_equity - current_equity) / self.peak_equity

        return {
            'allowed': (drawdown < self.max_drawdown_pct and
                       abs(self.daily_pnl) < self.max_daily_loss_pct * self.peak_equity),
            'drawdown': drawdown,
            'daily_loss': self.daily_pnl,
            'reason': ('OK' if drawdown < self.max_drawdown_pct
                      else f'Drawdown {drawdown:.1%} exceeds limit')
        }

    def monte_carlo_risk(self, trade_results: list, n_simulations=10000,
                          n_trades=252) -> dict:
        """Monte Carlo simulation for risk assessment."""
        returns = np.array([t['pnl_pct'] for t in trade_results])
        simulations = np.random.choice(returns, (n_simulations, n_trades), replace=True)
        equity_curves = self.initial_capital * (1 + simulations).cumprod(axis=1)

        max_drawdowns = []
        for curve in equity_curves:
            peak = np.maximum.accumulate(curve)
            dd = (peak - curve) / peak
            max_drawdowns.append(dd.max())

        final_equity = equity_curves[:, -1]
        return {
            'median_return': float(np.median(final_equity / self.initial_capital - 1)),
            'p5_return': float(np.percentile(final_equity / self.initial_capital - 1, 5)),
            'p95_return': float(np.percentile(final_equity / self.initial_capital - 1, 95)),
            'prob_profit': float(np.mean(final_equity > self.initial_capital)),
            'median_max_dd': float(np.median(max_drawdowns)),
            'p95_max_dd': float(np.percentile(max_drawdowns, 95)),
            'prob_ruin_20pct': float(np.mean(np.array(max_drawdowns) > 0.2)),
            'expected_sharpe': float(
                np.mean(final_equity / self.initial_capital - 1) /
                np.std(final_equity / self.initial_capital - 1) * np.sqrt(252)
            ),
        }

    def dynamic_stop_loss(self, entry_price: float, atr: float,
                          direction: int, regime: str) -> dict:
        atr_multipliers = {
            'low_vol_range': {'sl': 1.5, 'tp': 2.0},
            'trend_up': {'sl': 2.0, 'tp': 3.5},
            'trend_down': {'sl': 2.0, 'tp': 3.5},
            'high_vol_crisis': {'sl': 2.5, 'tp': 1.5},
        }
        m = atr_multipliers.get(regime, {'sl': 2.0, 'tp': 2.5})

        if direction == 1:  # Long
            sl = entry_price - m['sl'] * atr
            tp = entry_price + m['tp'] * atr
        else:  # Short
            sl = entry_price + m['sl'] * atr
            tp = entry_price - m['tp'] * atr

        return {
            'stop_loss': round(sl, 5),
            'take_profit': round(tp, 5),
            'risk_reward': round(m['tp'] / m['sl'], 2),
            'trailing_start': round(abs(tp - entry_price) * 0.5, 5),
        }
```

## Phase 8: Live Trading Pipeline

```python
class LiveTradingSystem:
    """
    Complete live trading pipeline with AI decision engine.
    Orchestrates: Data → Features → Regime → Models → Risk → Execution.
    """

    def __init__(self, symbol='XAUUSD', timeframe='M15'):
        self.symbol = symbol
        self.timeframe = timeframe
        self.pipeline = MarketDataPipeline()
        self.feature_engine = None
        self.decision_engine = AIDecisionEngine()
        self.risk_manager = AIRiskManager()
        self.is_running = False

    def load_models(self, model_dir: str):
        """Load pre-trained models."""
        self.decision_engine.gbm_ensemble = GBMEnsemble()
        self.decision_engine.gbm_ensemble.load(f'{model_dir}/gbm_ensemble.pkl')

        self.decision_engine.regime_detector = RegimeDetector()

        for model_name in ['lstm', 'transformer', 'cnn_lstm']:
            model_path = f'{model_dir}/{model_name}.pt'
            # Load based on architecture...

    def run_cycle(self) -> dict:
        """Single trading cycle: analyze → decide → execute."""
        # 1. Fetch latest data
        df = self.pipeline.fetch_ohlcv(self.symbol, self.timeframe, bars=500)

        # 2. Generate features
        self.feature_engine = FeatureEngine(df)
        features = self.feature_engine.build_all()

        # Remove target columns for prediction
        pred_features = features.drop(
            [c for c in features.columns if c.startswith(('fwd_', 'target_'))],
            axis=1, errors='ignore'
        )

        # 3. Get AI signal
        signal = self.decision_engine.generate_signal(df, pred_features)

        # 4. Risk check
        account_info = mt5.account_info()
        risk_check = self.risk_manager.check_trade_allowed(account_info.equity)

        if not risk_check['allowed']:
            return {'action': 'BLOCKED', 'reason': risk_check['reason'], **signal}

        # 5. Execute if signal is strong enough
        if signal['direction'] != 0 and signal['confidence'] >= 0.6:
            atr = features['atr_14'].iloc[-1]
            sl_tp = self.risk_manager.dynamic_stop_loss(
                df['close'].iloc[-1], atr, signal['direction'], signal['regime']
            )
            lot = self.risk_manager.calculate_lot_size(
                self.symbol,
                abs(df['close'].iloc[-1] - sl_tp['stop_loss']) * 10,
                signal['confidence'], signal['regime']
            )

            order = self._execute_order(signal['direction'], lot, sl_tp)
            return {'action': 'EXECUTED', 'order': order, **signal, **sl_tp}

        return {'action': 'HOLD', **signal}

    def _execute_order(self, direction, lot, sl_tp):
        order_type = mt5.ORDER_TYPE_BUY if direction == 1 else mt5.ORDER_TYPE_SELL
        price = mt5.symbol_info_tick(self.symbol)
        price = price.ask if direction == 1 else price.bid

        request = {
            'action': mt5.TRADE_ACTION_DEAL,
            'symbol': self.symbol,
            'volume': lot,
            'type': order_type,
            'price': price,
            'sl': sl_tp['stop_loss'],
            'tp': sl_tp['take_profit'],
            'deviation': 20,
            'magic': 123456,
            'comment': f'AI Signal conf={sl_tp.get("risk_reward", 0)}',
            'type_time': mt5.ORDER_TIME_GTC,
        }
        result = mt5.order_send(request)
        return result

    def run(self, interval_seconds=60):
        """Main trading loop."""
        import time
        self.is_running = True
        print(f"AI Trading System started: {self.symbol} @ {self.timeframe}")

        while self.is_running:
            try:
                result = self.run_cycle()
                print(f"[{result.get('timestamp')}] "
                      f"Action={result['action']} "
                      f"Direction={result.get('direction')} "
                      f"Confidence={result.get('confidence')}")
                time.sleep(interval_seconds)
            except Exception as e:
                print(f"Error: {e}")
                time.sleep(30)
```

# Examples

## Example 1: Full Pipeline — Train & Optimize XAUUSD Bot

```
Step 1: Fetch 2 years H1 data for XAUUSD
Step 2: Generate 250+ features → select top 80 by importance
Step 3: Train GBM Ensemble (walk-forward 5 folds) → F1 = 0.62
Step 4: Train LSTM + Transformer (100 epochs) → Val Acc = 59%
Step 5: Train DQN Agent (500 episodes) → Avg Reward = +1.8
Step 6: Optimize params with GA (50 gen) → Sharpe = 2.1
Step 7: Monte Carlo simulation → 92% prob profit, median DD = 8%
Step 8: Deploy live on MT5 with M15 interval
```

## Example 2: Regime-Aware Multi-Pair Trading

```
Active Regimes:
  XAUUSD: trend_up → Weight: GBM=30%, DL=40%, RL=30%
  EURUSD: low_vol_range → Weight: GBM=50%, DL=20%, RL=30%
  USDJPY: high_vol_crisis → Weight: GBM=60%, DL=10%, RL=30%

Signals Generated:
  XAUUSD: BUY  (conf=0.78) → Lot=0.15, SL=2040.50, TP=2085.30
  EURUSD: HOLD (conf=0.42) → Below threshold
  USDJPY: SELL (conf=0.65) → Lot=0.05, SL=152.80, TP=150.20
```

# Constraints

- NEVER trade without stop-loss — every position MUST have SL/TP
- NEVER risk more than 2% of equity per trade
- NEVER override risk manager decisions — if blocked, DO NOT trade
- ALL models MUST be validated with walk-forward (NOT random split)
- NEVER use future data in features (strict look-ahead bias prevention)
- Minimum 2 years of data for training, 6 months for validation
- Retrain models monthly or when regime changes significantly
- Maximum daily loss: 5% of equity → auto-stop trading
- Maximum drawdown: 15% → reduce position sizes by 50%
- Maximum drawdown: 25% → halt all trading, require manual review
- Always log every trade with full signal details for post-analysis
- NEVER deploy live without minimum 3 months of paper trading validation
- Monte Carlo ruin probability MUST be < 5% before going live
