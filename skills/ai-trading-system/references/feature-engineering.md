# Feature Engineering Reference for Gold & Forex

## Feature Categories (250+ Total)

### Category 1: Price Action (25 features)

| Feature | Formula | Signal |
|---------|---------|--------|
| return_N | (close - close[N]) / close[N] | Momentum |
| log_return_N | ln(close / close[N]) | Normalized momentum |
| hl_ratio | (high - low) / close | Volatility proxy |
| oc_ratio | (close - open) / close | Candle direction |
| upper_shadow | (high - max(open,close)) / close | Rejection signal |
| lower_shadow | (min(open,close) - low) / close | Buying pressure |
| body_size | abs(close - open) / close | Conviction |
| is_bullish | close > open | Binary direction |
| gap | (open - prev_close) / prev_close | Gap direction |

### Category 2: Trend (40+ features)

- SMA/EMA at periods: 5, 10, 20, 50, 100, 200
- Price vs MA ratio (normalized distance)
- MA crossover signals (fast vs slow)
- ADX + DI+/DI- (trend strength)
- MACD + Signal + Histogram
- Ichimoku Cloud (5 lines + cloud position)
- Supertrend (ATR-based trend)

### Category 3: Momentum (30+ features)

- RSI at 6, 14, 21 periods
- Stochastic %K/%D + crossover
- Williams %R
- CCI
- ROC at 5, 10, 20 periods
- MFI (volume-weighted momentum)
- Ultimate Oscillator
- RSI Divergence (bullish/bearish)

### Category 4: Volatility (25+ features)

- ATR at 7, 14, 21 periods (absolute + percentage)
- Bollinger Bands (width, %B, squeeze)
- Keltner Channel
- Historical volatility at 5, 10, 20, 60 periods
- Parkinson volatility (high-low based)
- Volatility ratio (short/long term)
- Squeeze detection (BB inside KC)

### Category 5: Volume (20+ features)

- Volume MA ratio at 5, 10, 20 periods
- OBV + trend
- VWAP + distance
- Accumulation/Distribution
- Force Index

### Category 6: Statistical (30+ features)

- Rolling skewness & kurtosis (20, 60)
- Rolling Sharpe ratio
- Hurst exponent (trend/mean-reversion)
- Z-score at 20, 50 periods
- Autocorrelation at lag 1, 5, 10

### Category 7: Microstructure (25+ features)

- Support/Resistance levels (20-period)
- Pivot points (P, R1, S1)
- Fibonacci retracement (23.6%, 38.2%, 50%, 61.8%)
- Distance to nearest Fib level

### Category 8: Calendar (15+ features)

- Hour, day of week, month
- Session flags (London, New York, Asian, Overlap)
- Monday/Friday flags
- Days to month end

### Category 9: Multi-Timeframe (20+ features)

- Higher TF RSI (4H, D1)
- Higher TF ATR (4H, D1)
- Higher TF trend direction (4H, D1)

## Gold (XAUUSD) Specific Features

```python
def gold_specific_features(df, dxy_df=None, spx_df=None):
    f = {}
    # Gold-specific volatility (gold moves $10-50/day)
    f['gold_daily_range_usd'] = df['high'] - df['low']
    f['gold_range_pct'] = f['gold_daily_range_usd'] / df['close']

    # Round number proximity (gold respects $50 levels)
    f['dist_to_50'] = df['close'] % 50
    f['near_round_50'] = (f['dist_to_50'] < 5) | (f['dist_to_50'] > 45)

    # $100 level proximity (major S/R)
    f['dist_to_100'] = df['close'] % 100
    f['near_round_100'] = (f['dist_to_100'] < 10) | (f['dist_to_100'] > 90)

    # DXY correlation (if available)
    if dxy_df is not None:
        f['dxy_change'] = dxy_df['close'].pct_change()
        f['gold_dxy_corr_20'] = df['close'].pct_change().rolling(20).corr(f['dxy_change'])

    # SPX correlation (risk-on/risk-off)
    if spx_df is not None:
        f['spx_change'] = spx_df['close'].pct_change()
        f['gold_spx_corr_20'] = df['close'].pct_change().rolling(20).corr(f['spx_change'])

    return pd.DataFrame(f, index=df.index)
```

## Feature Selection Best Practices

### Method 1: Importance-Based (Top N)
```python
importance = gbm_ensemble.get_feature_importance(feature_names)
top_features = importance.head(80).index.tolist()
```

### Method 2: Recursive Feature Elimination
```python
from sklearn.feature_selection import RFECV
selector = RFECV(estimator, step=5, cv=TimeSeriesSplit(5))
selector.fit(X_train, y_train)
selected = X_train.columns[selector.support_]
```

### Method 3: Correlation Filter
```python
def remove_correlated(df, threshold=0.95):
    corr = df.corr().abs()
    upper = corr.where(np.triu(np.ones(corr.shape), k=1).astype(bool))
    to_drop = [col for col in upper.columns if any(upper[col] > threshold)]
    return df.drop(to_drop, axis=1)
```

## Critical: Avoid Look-Ahead Bias

```python
# WRONG - uses future data
df['future_high'] = df['high'].shift(-5)  # NEVER!

# CORRECT - only use past data
df['past_high_5'] = df['high'].rolling(5).max()
df['fwd_return'] = df['close'].pct_change(5).shift(-5)  # target only, drop before prediction
```
