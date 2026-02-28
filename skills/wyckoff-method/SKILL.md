---
name: wyckoff-method
description: Automated Wyckoff Method analysis - detect Accumulation/Distribution/Markup/Markdown phases, identify Spring/Upthrust events, volume spread analysis (VSA), composite operator footprint, and Wyckoff schematics recognition. Use when analyzing market structure with Wyckoff methodology, detecting institutional activity, identifying accumulation/distribution zones, or building volume-based trading systems.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Wyckoff, Volume Spread Analysis, VSA, Accumulation, Distribution, Spring, Upthrust, Market Structure, Smart Money]
dependencies: [pandas, numpy, scipy, matplotlib, ta]
---

# Wyckoff Method Analysis

## When to Use

- Identifying Accumulation & Distribution phases
- Detecting Spring (bear trap) & Upthrust (bull trap) events
- Volume Spread Analysis (VSA) for smart money tracking
- Market phase classification (Markup/Markdown/Range)
- Building institutional-level market structure analysis

## Wyckoff Market Cycle

```
  Distribution ──→ Markdown
       ↑                ↓
    Markup ←── Accumulation
```

## Phase Detector

```python
import pandas as pd
import numpy as np
from enum import Enum

class WyckoffPhase(Enum):
    ACCUMULATION = "Accumulation"
    MARKUP = "Markup"
    DISTRIBUTION = "Distribution"
    MARKDOWN = "Markdown"
    RANGING = "Ranging"

class WyckoffAnalyzer:
    def __init__(self, df: pd.DataFrame, lookback: int = 50):
        self.df = df.copy()
        self.lookback = lookback
        self._prepare()

    def _prepare(self):
        df = self.df
        # Volume analysis
        df['vol_avg'] = df['volume'].rolling(20).mean()
        df['vol_ratio'] = df['volume'] / df['vol_avg']
        df['vol_high'] = df['vol_ratio'] > 1.5
        df['vol_ultra'] = df['vol_ratio'] > 2.5

        # Spread analysis
        df['spread'] = df['high'] - df['low']
        df['spread_avg'] = df['spread'].rolling(20).mean()
        df['spread_ratio'] = df['spread'] / df['spread_avg']
        df['body'] = abs(df['close'] - df['open'])
        df['body_ratio'] = df['body'] / (df['spread'] + 1e-10)

        # Close position within bar
        df['close_position'] = (df['close'] - df['low']) / (df['high'] - df['low'] + 1e-10)

        # Trend
        df['sma_20'] = df['close'].rolling(20).mean()
        df['sma_50'] = df['close'].rolling(50).mean()
        df['trend'] = np.where(df['sma_20'] > df['sma_50'], 1, -1)

        # Range detection
        df['range_high'] = df['high'].rolling(self.lookback).max()
        df['range_low'] = df['low'].rolling(self.lookback).min()
        df['range_width'] = (df['range_high'] - df['range_low']) / df['close']

        self.df = df

    def detect_phase(self) -> dict:
        """Classify current Wyckoff phase."""
        df = self.df
        last = df.iloc[-self.lookback:]

        # Calculate phase scores
        range_width = last['range_width'].mean()
        vol_trend = last['vol_ratio'].rolling(10).mean().iloc[-1]
        price_trend = (last['close'].iloc[-1] - last['close'].iloc[0]) / last['close'].iloc[0]
        close_positions = last['close_position'].mean()

        scores = {
            WyckoffPhase.ACCUMULATION: 0,
            WyckoffPhase.MARKUP: 0,
            WyckoffPhase.DISTRIBUTION: 0,
            WyckoffPhase.MARKDOWN: 0,
        }

        # Accumulation signs
        if range_width < 0.08:  # Tight range
            scores[WyckoffPhase.ACCUMULATION] += 2
        if close_positions > 0.55:  # Closes in upper half
            scores[WyckoffPhase.ACCUMULATION] += 1
        if vol_trend > 1.2 and price_trend < 0.02:
            scores[WyckoffPhase.ACCUMULATION] += 2  # High volume, flat price

        # Markup signs
        if price_trend > 0.05:
            scores[WyckoffPhase.MARKUP] += 3
        if df['trend'].iloc[-1] == 1:
            scores[WyckoffPhase.MARKUP] += 1
        if vol_trend > 1.0 and price_trend > 0:
            scores[WyckoffPhase.MARKUP] += 1

        # Distribution signs
        if range_width < 0.08 and price_trend < 0.02 and price_trend > -0.02:
            scores[WyckoffPhase.DISTRIBUTION] += 2
        if close_positions < 0.45:
            scores[WyckoffPhase.DISTRIBUTION] += 1
        if vol_trend > 1.2 and abs(price_trend) < 0.02:
            scores[WyckoffPhase.DISTRIBUTION] += 2

        # Markdown signs
        if price_trend < -0.05:
            scores[WyckoffPhase.MARKDOWN] += 3
        if df['trend'].iloc[-1] == -1:
            scores[WyckoffPhase.MARKDOWN] += 1

        phase = max(scores, key=scores.get)
        confidence = scores[phase] / sum(scores.values()) if sum(scores.values()) > 0 else 0

        return {
            'phase': phase.value,
            'confidence': round(confidence, 2),
            'scores': {k.value: v for k, v in scores.items()},
            'details': {
                'range_width': round(range_width, 4),
                'vol_trend': round(vol_trend, 2),
                'price_trend': round(price_trend * 100, 2),
                'close_position_avg': round(close_positions, 3),
            },
        }

    def detect_spring(self, lookback: int = 30) -> list[dict]:
        """Detect Spring events (Wyckoff bullish signal).
        Spring = price breaks below support then quickly recovers on high volume."""
        df = self.df
        events = []

        for i in range(lookback + 5, len(df)):
            window = df.iloc[i - lookback:i]
            support = window['low'].min()
            current = df.iloc[i]
            prev = df.iloc[i - 1]

            # Price dips below support
            if prev['low'] < support:
                # Then closes back above support
                if current['close'] > support:
                    # On high volume
                    if current['vol_ratio'] > 1.5:
                        events.append({
                            'type': 'SPRING',
                            'idx': i,
                            'time': df.index[i],
                            'price': current['close'],
                            'support_level': support,
                            'false_break': round(support - prev['low'], 4),
                            'volume_ratio': round(current['vol_ratio'], 2),
                            'signal': 'BUY',
                        })
        return events

    def detect_upthrust(self, lookback: int = 30) -> list[dict]:
        """Detect Upthrust events (Wyckoff bearish signal).
        Upthrust = price breaks above resistance then quickly falls on high volume."""
        df = self.df
        events = []

        for i in range(lookback + 5, len(df)):
            window = df.iloc[i - lookback:i]
            resistance = window['high'].max()
            current = df.iloc[i]
            prev = df.iloc[i - 1]

            if prev['high'] > resistance:
                if current['close'] < resistance:
                    if current['vol_ratio'] > 1.5:
                        events.append({
                            'type': 'UPTHRUST',
                            'idx': i,
                            'time': df.index[i],
                            'price': current['close'],
                            'resistance_level': resistance,
                            'false_break': round(prev['high'] - resistance, 4),
                            'volume_ratio': round(current['vol_ratio'], 2),
                            'signal': 'SELL',
                        })
        return events
```

## Volume Spread Analysis (VSA)

```python
class VSAAnalyzer:
    """Richard Wyckoff's Volume Spread Analysis."""

    @staticmethod
    def classify_bar(row, avg_vol, avg_spread) -> dict:
        spread = row['high'] - row['low']
        body = abs(row['close'] - row['open'])
        close_pos = (row['close'] - row['low']) / (spread + 1e-10)
        vol_ratio = row['volume'] / avg_vol
        spread_ratio = spread / avg_spread

        signals = []

        # === Bullish VSA patterns ===
        # Stopping Volume: high volume, wide spread down, close near high
        if vol_ratio > 2 and close_pos > 0.6 and row['close'] < row['open']:
            signals.append(('STOPPING_VOLUME', 'bullish', 'Smart money absorbing selling'))

        # No Supply: narrow spread, low volume on down bar
        if vol_ratio < 0.7 and spread_ratio < 0.7 and row['close'] < row['open']:
            signals.append(('NO_SUPPLY', 'bullish', 'Sellers exhausted'))

        # Test: low volume, narrow spread, close near low then recovers
        if vol_ratio < 0.5 and spread_ratio < 0.6 and close_pos > 0.5:
            signals.append(('TEST', 'bullish', 'Testing for remaining supply'))

        # === Bearish VSA patterns ===
        # Upthrust: wide spread up, high volume, close near low
        if vol_ratio > 1.5 and close_pos < 0.3 and spread_ratio > 1.2 and row['close'] > row['open']:
            signals.append(('UPTHRUST_BAR', 'bearish', 'Distribution disguised as strength'))

        # No Demand: narrow spread, low volume on up bar
        if vol_ratio < 0.7 and spread_ratio < 0.7 and row['close'] > row['open']:
            signals.append(('NO_DEMAND', 'bearish', 'Buyers exhausted'))

        # Effort vs Result: high volume but small spread
        if vol_ratio > 2 and spread_ratio < 0.5:
            signals.append(('EFFORT_NO_RESULT', 'reversal', 'High effort, no price movement'))

        return {'signals': signals, 'vol_ratio': vol_ratio,
                'spread_ratio': spread_ratio, 'close_position': close_pos}

    @staticmethod
    def scan(df: pd.DataFrame) -> pd.DataFrame:
        avg_vol = df['volume'].rolling(20).mean()
        avg_spread = (df['high'] - df['low']).rolling(20).mean()
        results = []

        for i in range(20, len(df)):
            classification = VSAAnalyzer.classify_bar(
                df.iloc[i], avg_vol.iloc[i], avg_spread.iloc[i]
            )
            if classification['signals']:
                for sig in classification['signals']:
                    results.append({
                        'time': df.index[i],
                        'pattern': sig[0],
                        'bias': sig[1],
                        'description': sig[2],
                        'price': df.iloc[i]['close'],
                        'vol_ratio': classification['vol_ratio'],
                    })

        return pd.DataFrame(results)
```

## Wyckoff Accumulation Schematic Events

```python
def detect_accumulation_events(df: pd.DataFrame) -> list[dict]:
    """Detect key events in Wyckoff Accumulation schematic."""
    events = []
    analyzer = WyckoffAnalyzer(df)

    # PS (Preliminary Support) - high volume selling halts
    # SC (Selling Climax) - highest volume, widest spread, panic selling
    # AR (Automatic Rally) - bounce after SC
    # ST (Secondary Test) - retest SC low on lower volume
    # Spring - false break below support (best entry)
    # SOS (Sign of Strength) - strong move up on high volume
    # LPS (Last Point of Support) - pullback to support = entry

    springs = analyzer.detect_spring(lookback=40)
    for s in springs:
        events.append({**s, 'phase_event': 'Spring (Phase C)'})

    vsa = VSAAnalyzer.scan(df)
    stopping = vsa[vsa['pattern'] == 'STOPPING_VOLUME']
    for _, row in stopping.iterrows():
        events.append({
            'type': 'SELLING_CLIMAX',
            'time': row['time'],
            'price': row['price'],
            'signal': 'WATCH',
            'phase_event': 'SC (Phase A)',
        })

    return events
```

## Wyckoff Schematic Reference

### Accumulation Phases (Bullish Setup)
```
Phase A: PS → SC → AR → ST           (Stopping the downtrend)
Phase B: Range-bound, tests, shakeouts (Building cause)
Phase C: SPRING / Shakeout             (Bear trap = BEST BUY)
Phase D: SOS → LPS → SOS              (Markup begins)
Phase E: Markup (trend up)             (Ride the trend)
```

### Distribution Phases (Bearish Setup)
```
Phase A: PSY → BC → AR → ST           (Stopping the uptrend)
Phase B: Range-bound, upthrusts        (Distributing to public)
Phase C: UPTHRUST / UTAD               (Bull trap = BEST SELL)
Phase D: SOW → LPSY → SOW             (Markdown begins)
Phase E: Markdown (trend down)          (Short the trend)
```

## Asset-Specific Wyckoff Notes

- **Gold**: Accumulation phases visible on D1/W1. Springs at round numbers ($2600, $2500...).
- **Bitcoin**: Wyckoff very effective, large accumulation ranges. Look for springs at support.
- **Oil**: Distribution often precedes OPEC announcements. VSA effective on H4.
- **FX pairs**: Wyckoff works best on major pairs (EUR/USD, GBP/USD) on H4/D1.
