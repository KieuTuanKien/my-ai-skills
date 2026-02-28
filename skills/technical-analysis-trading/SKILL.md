---
name: technical-analysis-trading
description: Implement technical analysis indicators and trading strategies for FX, gold, bitcoin, oil. Covers moving averages, RSI, MACD, Bollinger Bands, Ichimoku, Fibonacci, support/resistance detection, candlestick patterns, and multi-indicator strategy systems. Use when analyzing price charts, building indicator-based strategies, or detecting trade setups.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Technical Analysis, Indicators, RSI, MACD, Bollinger, Ichimoku, Fibonacci, Candlestick, Trading Strategy]
dependencies: [pandas, numpy, ta, mplfinance]
---

# Technical Analysis & Trading Strategies

## When to Use

- Calculating technical indicators (RSI, MACD, Bollinger, etc.)
- Building indicator-based trading strategies
- Detecting support/resistance levels, chart patterns
- Multi-timeframe analysis
- Generating buy/sell signals with confidence scoring

## Quick Start

```bash
pip install ta pandas numpy mplfinance scipy
```

## Core Indicators with `ta` Library

```python
import ta
import pandas as pd

def add_all_indicators(df: pd.DataFrame) -> pd.DataFrame:
    """Add comprehensive indicators to OHLCV DataFrame."""
    # Trend
    df['ema_9'] = ta.trend.ema_indicator(df['close'], window=9)
    df['ema_21'] = ta.trend.ema_indicator(df['close'], window=21)
    df['ema_50'] = ta.trend.ema_indicator(df['close'], window=50)
    df['ema_200'] = ta.trend.ema_indicator(df['close'], window=200)
    df['macd'] = ta.trend.macd_diff(df['close'])
    df['adx'] = ta.trend.adx(df['high'], df['low'], df['close'])

    # Momentum
    df['rsi'] = ta.momentum.rsi(df['close'], window=14)
    df['stoch_k'] = ta.momentum.stoch(df['high'], df['low'], df['close'])
    df['stoch_d'] = ta.momentum.stoch_signal(df['high'], df['low'], df['close'])

    # Volatility
    df['bb_upper'] = ta.volatility.bollinger_hband(df['close'])
    df['bb_lower'] = ta.volatility.bollinger_lband(df['close'])
    df['bb_width'] = ta.volatility.bollinger_wband(df['close'])
    df['atr'] = ta.volatility.average_true_range(df['high'], df['low'], df['close'])

    # Volume
    df['obv'] = ta.volume.on_balance_volume(df['close'], df['volume'])
    df['vwap'] = (df['volume'] * (df['high'] + df['low'] + df['close']) / 3).cumsum() / df['volume'].cumsum()

    return df
```

## Ichimoku Cloud (Popular for Gold & FX)

```python
def ichimoku(df: pd.DataFrame, tenkan=9, kijun=26, senkou_b=52) -> pd.DataFrame:
    high, low, close = df['high'], df['low'], df['close']

    df['tenkan_sen'] = (high.rolling(tenkan).max() + low.rolling(tenkan).min()) / 2
    df['kijun_sen'] = (high.rolling(kijun).max() + low.rolling(kijun).min()) / 2
    df['senkou_a'] = ((df['tenkan_sen'] + df['kijun_sen']) / 2).shift(kijun)
    df['senkou_b'] = ((high.rolling(senkou_b).max() + low.rolling(senkou_b).min()) / 2).shift(kijun)
    df['chikou_span'] = close.shift(-kijun)

    df['cloud_green'] = df['senkou_a'] > df['senkou_b']
    df['price_above_cloud'] = close > df[['senkou_a', 'senkou_b']].max(axis=1)
    df['price_below_cloud'] = close < df[['senkou_a', 'senkou_b']].min(axis=1)
    return df
```

## Support & Resistance Detection

```python
from scipy.signal import argrelextrema

def find_support_resistance(df: pd.DataFrame, window: int = 20,
                             num_levels: int = 5) -> dict:
    highs = df['high'].values
    lows = df['low'].values

    resistance_idx = argrelextrema(highs, lambda a, b: a > b, order=window)[0]
    support_idx = argrelextrema(lows, lambda a, b: a < b, order=window)[0]

    resistance_levels = sorted(set(round(highs[i], 2) for i in resistance_idx))[-num_levels:]
    support_levels = sorted(set(round(lows[i], 2) for i in support_idx))[:num_levels]

    return {"support": support_levels, "resistance": resistance_levels}
```

## Fibonacci Retracement

```python
def fibonacci_levels(high: float, low: float, direction: str = "up") -> dict:
    diff = high - low
    levels = {
        '0.0%': high if direction == 'up' else low,
        '23.6%': high - 0.236 * diff if direction == 'up' else low + 0.236 * diff,
        '38.2%': high - 0.382 * diff if direction == 'up' else low + 0.382 * diff,
        '50.0%': high - 0.500 * diff if direction == 'up' else low + 0.500 * diff,
        '61.8%': high - 0.618 * diff if direction == 'up' else low + 0.618 * diff,
        '78.6%': high - 0.786 * diff if direction == 'up' else low + 0.786 * diff,
        '100%': low if direction == 'up' else high,
    }
    return levels
```

## Candlestick Pattern Detection

```python
def detect_patterns(df: pd.DataFrame) -> pd.DataFrame:
    o, h, l, c = df['open'], df['high'], df['low'], df['close']
    body = abs(c - o)
    upper_shadow = h - pd.concat([o, c], axis=1).max(axis=1)
    lower_shadow = pd.concat([o, c], axis=1).min(axis=1) - l
    avg_body = body.rolling(20).mean()

    # Doji
    df['doji'] = body < avg_body * 0.1

    # Hammer (bullish reversal)
    df['hammer'] = (lower_shadow > body * 2) & (upper_shadow < body * 0.5) & (c > o)

    # Engulfing
    df['bullish_engulfing'] = (c > o) & (c.shift(1) < o.shift(1)) & \
                               (c > o.shift(1)) & (o < c.shift(1))
    df['bearish_engulfing'] = (c < o) & (c.shift(1) > o.shift(1)) & \
                               (c < o.shift(1)) & (o > c.shift(1))

    # Pin bar
    df['pin_bar_bull'] = (lower_shadow > body * 3) & (upper_shadow < body * 0.3)
    df['pin_bar_bear'] = (upper_shadow > body * 3) & (lower_shadow < body * 0.3)
    return df
```

## Multi-Indicator Strategy Example (Gold XAUUSD)

```python
from dataclasses import dataclass

@dataclass
class Signal:
    direction: str  # "BUY" | "SELL" | "HOLD"
    confidence: float
    reasons: list[str]
    entry: float
    sl: float
    tp: float

def gold_strategy(df: pd.DataFrame) -> Signal:
    df = add_all_indicators(df)
    df = ichimoku(df)
    df = detect_patterns(df)
    last = df.iloc[-1]
    atr = last['atr']
    reasons = []
    score = 0

    # Trend alignment
    if last['ema_9'] > last['ema_21'] > last['ema_50']:
        score += 2; reasons.append("EMA alignment bullish")
    elif last['ema_9'] < last['ema_21'] < last['ema_50']:
        score -= 2; reasons.append("EMA alignment bearish")

    # RSI
    if 30 < last['rsi'] < 45:
        score += 1; reasons.append(f"RSI oversold zone ({last['rsi']:.0f})")
    elif 55 < last['rsi'] < 70:
        score -= 1; reasons.append(f"RSI overbought zone ({last['rsi']:.0f})")

    # MACD
    if last['macd'] > 0:
        score += 1; reasons.append("MACD positive")
    else:
        score -= 1; reasons.append("MACD negative")

    # Ichimoku
    if last['price_above_cloud']:
        score += 1; reasons.append("Price above Ichimoku cloud")
    elif last['price_below_cloud']:
        score -= 1; reasons.append("Price below Ichimoku cloud")

    # Candlestick
    if last['bullish_engulfing'] or last['hammer']:
        score += 1; reasons.append("Bullish candle pattern")
    if last['bearish_engulfing'] or last['pin_bar_bear']:
        score -= 1; reasons.append("Bearish candle pattern")

    # ADX trend strength
    if last['adx'] > 25:
        reasons.append(f"Strong trend (ADX={last['adx']:.0f})")

    confidence = min(abs(score) / 5, 1.0)
    price = last['close']

    if score >= 3:
        return Signal("BUY", confidence, reasons, price,
                      sl=price - 2 * atr, tp=price + 3 * atr)
    elif score <= -3:
        return Signal("SELL", confidence, reasons, price,
                      sl=price + 2 * atr, tp=price - 3 * atr)
    return Signal("HOLD", confidence, reasons, price, 0, 0)
```

## Indicator Cheat Sheet

| Indicator | Best For | Signal Type |
|-----------|----------|-------------|
| EMA 9/21/50/200 | Trend direction | Cross = entry |
| RSI (14) | Overbought/oversold | <30 buy, >70 sell |
| MACD | Trend + momentum | Histogram cross zero |
| Bollinger Bands | Volatility squeeze → breakout | Touch bands = reversal |
| Ichimoku | Full system (trend, S/R, momentum) | Cloud crossover |
| ATR | Volatility-based SL/TP | Dynamic stop-loss |
| ADX | Trend strength | >25 = strong trend |
| Stochastic | Short-term overbought/oversold | Cross in extreme zones |
| Fibonacci | Retracement levels | 38.2%, 50%, 61.8% zones |

## Asset-Specific Notes

- **Gold (XAUUSD)**: Responds well to Ichimoku, Fibonacci on H4/D1. High ATR, use wider stops.
- **Bitcoin**: High volatility, RSI extremes often exceeded. Use 4H+ timeframes for reliability.
- **Oil (USOIL)**: Sensitive to inventory reports (Wed 10:30 ET). Avoid trading during news.
- **EUR/USD**: Most liquid pair, tight spreads. Good for scalping with M5-M15 + Bollinger.

## Advanced Analysis Skills (Cross-References)

- Elliott Wave pattern detection → see `elliott-wave-analysis` skill
- Wyckoff Accumulation/Distribution → see `wyckoff-method` skill
- ML-based signal generation (XGBoost, RF, SVM) → see `ml-trading-models` skill
- Deep Learning prediction (LSTM, Transformer, RL) → see `deep-learning-trading` skill
- Fuzzy Logic, Genetic Algorithm, Adaptive Control → see `advanced-trading-algorithms` skill
- Backtesting & validation → see `backtesting-strategies` skill
- Risk management & position sizing → see `risk-management-trading` skill
