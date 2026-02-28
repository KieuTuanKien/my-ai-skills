---
name: elliott-wave-analysis
description: Automated Elliott Wave detection and counting for trading. Implements wave pattern recognition (impulse 5-wave, corrective ABC), degree labeling, Fibonacci wave relationships, wave validation rules, and auto-projection of wave targets. Works with FX, gold, bitcoin, oil on multiple timeframes. Use when identifying Elliott Wave patterns, projecting price targets, or building wave-based trading systems.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Elliott Wave, Wave Analysis, Fibonacci, Pattern Recognition, Price Projection, Impulse Wave, Corrective Wave, Trading]
dependencies: [pandas, numpy, scipy, matplotlib]
---

# Elliott Wave Analysis

## When to Use

- Identifying impulse (5-wave) and corrective (ABC) wave patterns
- Projecting price targets using Fibonacci wave ratios
- Validating wave counts against Elliott Wave rules
- Multi-timeframe wave analysis
- Automated wave labeling on charts

## Core Elliott Wave Rules (Inviolable)

1. **Wave 2** never retraces more than 100% of Wave 1
2. **Wave 3** is never the shortest among Waves 1, 3, and 5
3. **Wave 4** does not overlap the price territory of Wave 1

## Wave Detection Engine

```python
import pandas as pd
import numpy as np
from scipy.signal import argrelextrema
from dataclasses import dataclass
from enum import Enum

class WaveType(Enum):
    IMPULSE = "impulse"
    CORRECTIVE = "corrective"

class WaveDegree(Enum):
    GRAND_SUPER = "Grand Supercycle"
    SUPER = "Supercycle"
    CYCLE = "Cycle"
    PRIMARY = "Primary"
    INTERMEDIATE = "Intermediate"
    MINOR = "Minor"
    MINUTE = "Minute"
    MINUETTE = "Minuette"

@dataclass
class Wave:
    label: str          # "1", "2", "3", "4", "5", "A", "B", "C"
    start_idx: int
    end_idx: int
    start_price: float
    end_price: float
    degree: WaveDegree
    wave_type: WaveType

    @property
    def length(self):
        return abs(self.end_price - self.start_price)

    @property
    def direction(self):
        return "up" if self.end_price > self.start_price else "down"

    @property
    def retracement(self):
        return self.length


class ElliottWaveDetector:
    def __init__(self, df: pd.DataFrame, degree: WaveDegree = WaveDegree.MINOR):
        self.df = df
        self.degree = degree
        self.waves = []
        self.pivots = []

    def find_pivots(self, order: int = 10) -> list[dict]:
        """Detect swing highs and lows using local extrema."""
        highs = self.df['high'].values
        lows = self.df['low'].values

        high_idx = argrelextrema(highs, np.greater_equal, order=order)[0]
        low_idx = argrelextrema(lows, np.less_equal, order=order)[0]

        pivots = []
        for idx in high_idx:
            pivots.append({'idx': idx, 'price': highs[idx], 'type': 'high',
                          'time': self.df.index[idx]})
        for idx in low_idx:
            pivots.append({'idx': idx, 'price': lows[idx], 'type': 'low',
                          'time': self.df.index[idx]})

        pivots.sort(key=lambda x: x['idx'])

        # Remove consecutive same-type pivots (keep extremes)
        filtered = []
        for p in pivots:
            if not filtered or filtered[-1]['type'] != p['type']:
                filtered.append(p)
            elif p['type'] == 'high' and p['price'] > filtered[-1]['price']:
                filtered[-1] = p
            elif p['type'] == 'low' and p['price'] < filtered[-1]['price']:
                filtered[-1] = p

        self.pivots = filtered
        return filtered

    def validate_impulse(self, waves_5: list[dict]) -> dict:
        """Validate 5-wave impulse pattern against Elliott rules."""
        if len(waves_5) < 5:
            return {'valid': False, 'reason': 'Need 5 pivot segments'}

        p = [w['price'] for w in waves_5]

        # Determine direction
        is_bullish = p[4] > p[0]
        errors = []

        if is_bullish:
            w1 = p[1] - p[0]  # Wave 1 up
            w2 = p[1] - p[2]  # Wave 2 down (retracement)
            w3 = p[3] - p[2]  # Wave 3 up
            w4 = p[3] - p[4] if len(p) > 4 else 0  # Wave 4 down
            w5 = p[5] - p[4] if len(p) > 5 else w1  # Wave 5 up

            # Rule 1: Wave 2 < 100% of Wave 1
            if w2 >= w1:
                errors.append("Rule 1 violated: Wave 2 retraces 100%+ of Wave 1")

            # Rule 2: Wave 3 not shortest
            if w3 < w1 and w3 < w5:
                errors.append("Rule 2 violated: Wave 3 is shortest")

            # Rule 3: Wave 4 doesn't overlap Wave 1
            if len(p) > 4 and p[4] <= p[1]:
                errors.append("Rule 3 violated: Wave 4 overlaps Wave 1 territory")

        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'is_bullish': is_bullish,
            'wave_ratios': self._calculate_ratios(p, is_bullish),
        }

    def _calculate_ratios(self, prices, is_bullish) -> dict:
        """Calculate Fibonacci ratios between waves."""
        if len(prices) < 6:
            return {}

        if is_bullish:
            w1 = prices[1] - prices[0]
            w2_retrace = (prices[1] - prices[2]) / w1 if w1 else 0
            w3 = prices[3] - prices[2]
            w3_ext = w3 / w1 if w1 else 0
            w4_retrace = (prices[3] - prices[4]) / w3 if w3 else 0
            w5 = prices[5] - prices[4]
            w5_ratio = w5 / w1 if w1 else 0
        else:
            w1 = prices[0] - prices[1]
            w2_retrace = (prices[2] - prices[1]) / w1 if w1 else 0
            w3 = prices[2] - prices[3]
            w3_ext = w3 / w1 if w1 else 0
            w4_retrace = (prices[4] - prices[3]) / w3 if w3 else 0
            w5 = prices[4] - prices[5]
            w5_ratio = w5 / w1 if w1 else 0

        return {
            'wave2_retracement': round(w2_retrace, 3),
            'wave3_extension': round(w3_ext, 3),
            'wave4_retracement': round(w4_retrace, 3),
            'wave5_ratio_to_w1': round(w5_ratio, 3),
        }

    def detect_impulse_waves(self, order: int = 10) -> list[dict]:
        """Scan for valid 5-wave impulse patterns."""
        self.find_pivots(order)
        patterns = []

        for i in range(len(self.pivots) - 5):
            segment = self.pivots[i:i + 6]
            prices = [s['price'] for s in segment]
            validation = self.validate_impulse(segment)

            if validation['valid']:
                patterns.append({
                    'start': segment[0],
                    'end': segment[5],
                    'pivots': segment,
                    'ratios': validation['wave_ratios'],
                    'is_bullish': validation['is_bullish'],
                    'score': self._score_pattern(validation['wave_ratios']),
                })

        patterns.sort(key=lambda x: x['score'], reverse=True)
        return patterns

    def _score_pattern(self, ratios: dict) -> float:
        """Score pattern quality based on ideal Fibonacci relationships."""
        score = 0
        ideal = {
            'wave2_retracement': [0.382, 0.500, 0.618],
            'wave3_extension': [1.618, 2.618, 1.0],
            'wave4_retracement': [0.236, 0.382, 0.500],
            'wave5_ratio_to_w1': [0.618, 1.0, 1.618],
        }

        for key, targets in ideal.items():
            if key in ratios:
                min_diff = min(abs(ratios[key] - t) for t in targets)
                score += max(0, 1 - min_diff)

        return round(score, 2)
```

## Fibonacci Wave Projections

```python
def project_wave_targets(waves_completed: list[dict],
                          current_wave: int) -> dict:
    """Project next wave target using Fibonacci extensions."""
    prices = [w['price'] for w in waves_completed]
    targets = {}

    if current_wave == 2:
        w1 = abs(prices[1] - prices[0])
        base = prices[1] if prices[1] > prices[0] else prices[0]
        direction = 1 if prices[1] > prices[0] else -1
        # Wave 2 retracement targets
        targets = {
            '38.2% (shallow)': prices[1] - direction * w1 * 0.382,
            '50.0% (normal)': prices[1] - direction * w1 * 0.500,
            '61.8% (deep)': prices[1] - direction * w1 * 0.618,
        }

    elif current_wave == 3:
        w1 = abs(prices[1] - prices[0])
        w2_end = prices[2]
        direction = 1 if prices[1] > prices[0] else -1
        targets = {
            '100% of W1': w2_end + direction * w1,
            '161.8% of W1 (common)': w2_end + direction * w1 * 1.618,
            '261.8% of W1 (extended)': w2_end + direction * w1 * 2.618,
        }

    elif current_wave == 4:
        w3 = abs(prices[3] - prices[2])
        direction = -1 if prices[3] > prices[2] else 1
        targets = {
            '23.6% of W3': prices[3] + direction * w3 * 0.236,
            '38.2% of W3 (common)': prices[3] + direction * w3 * 0.382,
            '50.0% of W3': prices[3] + direction * w3 * 0.500,
        }

    elif current_wave == 5:
        w1 = abs(prices[1] - prices[0])
        w4_end = prices[4]
        direction = 1 if prices[1] > prices[0] else -1
        targets = {
            '61.8% of W1': w4_end + direction * w1 * 0.618,
            '100% of W1 (common)': w4_end + direction * w1,
            '161.8% of W1': w4_end + direction * w1 * 1.618,
        }

    return targets
```

## Corrective Pattern Detection (ABC)

```python
def detect_abc_correction(pivots: list[dict], prior_impulse_end: float) -> dict:
    """Detect ABC corrective pattern after impulse wave."""
    if len(pivots) < 3:
        return {'valid': False}

    A, B, C = pivots[0], pivots[1], pivots[2]
    impulse_range = abs(prior_impulse_end - A['price'])

    wave_a = abs(A['price'] - pivots[0]['price']) if len(pivots) > 0 else 0
    wave_b_retrace = abs(B['price'] - A['price']) / wave_a if wave_a else 0

    # Classify correction type
    c_extends = abs(C['price'] - B['price'])
    total_retrace = abs(C['price'] - prior_impulse_end) / impulse_range if impulse_range else 0

    if wave_b_retrace < 0.4:
        pattern = "Zigzag (5-3-5)"  # Sharp
    elif wave_b_retrace > 0.6:
        pattern = "Flat (3-3-5)"    # Sideways
    else:
        pattern = "Irregular"

    return {
        'valid': True,
        'pattern': pattern,
        'wave_b_retracement': round(wave_b_retrace, 3),
        'total_retracement': round(total_retrace, 3),
        'targets': {
            '38.2% retracement': prior_impulse_end * (1 - 0.382 * (1 if C['price'] < prior_impulse_end else -1)),
            '50.0% retracement': prior_impulse_end * (1 - 0.500 * (1 if C['price'] < prior_impulse_end else -1)),
            '61.8% retracement': prior_impulse_end * (1 - 0.618 * (1 if C['price'] < prior_impulse_end else -1)),
        },
    }
```

## Ideal Fibonacci Ratios Reference

| Wave | Common Ratio | Description |
|------|-------------|-------------|
| Wave 2 | 50%, 61.8% of Wave 1 | Retracement of Wave 1 |
| Wave 3 | 161.8%, 261.8% of Wave 1 | Longest & strongest wave |
| Wave 4 | 23.6%, 38.2% of Wave 3 | Shallow retracement |
| Wave 5 | 61.8%, 100% of Wave 1 | Equal to or less than Wave 1 |
| Wave A | 38.2%, 50% of Wave 5 | First corrective leg |
| Wave B | 50%, 61.8% of Wave A | Counter-trend rally |
| Wave C | 100%, 161.8% of Wave A | Final corrective thrust |

## Asset-Specific Wave Notes

- **Gold (XAUUSD)**: Clean wave structures on D1/W1. Wave 3 often extends to 2.618x.
- **Bitcoin**: Extreme extensions (Wave 3 can reach 4.236x). Use log scale for counting.
- **Oil**: Often truncated Wave 5. Corrective patterns dominate (triangle consolidations).
- **EUR/USD**: Textbook wave patterns on H4/D1. Best asset for wave analysis practice.
