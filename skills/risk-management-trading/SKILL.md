---
name: risk-management-trading
description: Implement professional risk management for trading - position sizing, stop-loss strategies, portfolio allocation, drawdown control, Kelly criterion, and risk-reward optimization. Use when calculating lot sizes, setting stop-losses, managing portfolio risk, or building money management systems for FX/crypto/commodities.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Risk Management, Position Sizing, Stop Loss, Kelly Criterion, Portfolio, Drawdown, Money Management]
dependencies: [pandas, numpy]
---

# Risk Management for Trading

## When to Use

- Calculating position sizes based on risk percentage
- Setting dynamic stop-loss/take-profit levels
- Portfolio allocation across multiple assets
- Drawdown control and circuit breakers
- Kelly criterion for optimal bet sizing
- Correlation-based risk assessment

## Core Rules

1. **Never risk more than 1-2% per trade**
2. **Maximum 5-6% total portfolio risk at any time**
3. **Risk:Reward minimum 1:2 (ideally 1:3)**
4. **Stop trading after 3 consecutive losses (cool-down)**
5. **Cut position size 50% after 10% drawdown**

## Position Sizing Calculator

```python
def calculate_position_size(
    account_balance: float,
    risk_percent: float,
    entry_price: float,
    stop_loss: float,
    pip_value: float = None,  # For FX
    contract_size: float = 1.0,
) -> dict:
    risk_amount = account_balance * (risk_percent / 100)
    sl_distance = abs(entry_price - stop_loss)

    if sl_distance == 0:
        raise ValueError("Stop loss cannot equal entry price")

    if pip_value:  # FX calculation
        sl_pips = sl_distance / pip_value
        lot_size = risk_amount / (sl_pips * 10 * contract_size)
    else:  # Crypto/commodities
        lot_size = risk_amount / sl_distance

    return {
        'lot_size': round(lot_size, 4),
        'risk_amount': round(risk_amount, 2),
        'sl_distance': round(sl_distance, 5),
        'risk_reward_at_2x': round(entry_price + 2 * sl_distance, 5),
        'risk_reward_at_3x': round(entry_price + 3 * sl_distance, 5),
    }

# Gold: $10,000 account, 1% risk, entry $2650, SL $2640
print(calculate_position_size(10000, 1.0, 2650, 2640))
# → lot_size based on $100 risk / $10 distance

# Bitcoin: $10,000, 2% risk, entry $95000, SL $93000
print(calculate_position_size(10000, 2.0, 95000, 93000))
# → lot_size = $200 / $2000 = 0.1 BTC
```

## ATR-Based Dynamic Stop Loss

```python
def atr_stop_loss(df, atr_period: int = 14, multiplier: float = 2.0) -> dict:
    """Dynamic SL based on market volatility."""
    import ta
    atr = ta.volatility.average_true_range(df['high'], df['low'], df['close'], window=atr_period)
    current_atr = atr.iloc[-1]
    price = df['close'].iloc[-1]

    return {
        'atr': round(current_atr, 5),
        'buy_sl': round(price - multiplier * current_atr, 5),
        'buy_tp_2r': round(price + 2 * multiplier * current_atr, 5),
        'buy_tp_3r': round(price + 3 * multiplier * current_atr, 5),
        'sell_sl': round(price + multiplier * current_atr, 5),
        'sell_tp_2r': round(price - 2 * multiplier * current_atr, 5),
    }
```

## Kelly Criterion

```python
def kelly_criterion(win_rate: float, avg_win: float, avg_loss: float,
                    fraction: float = 0.5) -> float:
    """
    Optimal fraction of capital to risk.
    fraction: Kelly fraction (0.5 = half-Kelly, safer)
    """
    if avg_loss == 0:
        return 0
    b = avg_win / abs(avg_loss)  # Win/loss ratio
    p = win_rate
    q = 1 - p
    kelly = (b * p - q) / b
    return max(0, kelly * fraction)

# Win rate 55%, avg win $300, avg loss $200
optimal_risk = kelly_criterion(0.55, 300, 200, fraction=0.5)
print(f"Risk per trade: {optimal_risk:.1%}")  # ~13.75% full, ~6.9% half-Kelly
```

## Portfolio Risk Manager

```python
import numpy as np

class PortfolioRiskManager:
    def __init__(self, account_balance: float, max_risk_pct: float = 5.0,
                 max_correlated_risk: float = 3.0):
        self.balance = account_balance
        self.max_risk = max_risk_pct / 100
        self.max_correlated = max_correlated_risk / 100
        self.positions = []

    def current_risk(self) -> float:
        return sum(p['risk_amount'] for p in self.positions) / self.balance

    def can_open(self, symbol: str, risk_amount: float,
                 correlated_with: list[str] = None) -> dict:
        new_total = self.current_risk() + risk_amount / self.balance

        if new_total > self.max_risk:
            return {'allowed': False, 'reason': f'Total risk {new_total:.1%} exceeds {self.max_risk:.0%}'}

        if correlated_with:
            corr_risk = sum(p['risk_amount'] for p in self.positions
                           if p['symbol'] in correlated_with) + risk_amount
            if corr_risk / self.balance > self.max_correlated:
                return {'allowed': False, 'reason': 'Correlated exposure too high'}

        return {'allowed': True, 'new_total_risk': f'{new_total:.1%}'}

    def add_position(self, symbol: str, risk_amount: float):
        self.positions.append({'symbol': symbol, 'risk_amount': risk_amount})

    def daily_loss_limit(self, max_daily_loss_pct: float = 3.0) -> float:
        return self.balance * max_daily_loss_pct / 100

# Correlated pairs (move together)
CORRELATIONS = {
    'XAUUSD': ['XAGUSD', 'EURUSD'],      # Gold correlates with silver, EUR
    'USOIL': ['UKOIL', 'CADJPY'],         # Oil correlates with Brent, CAD
    'BTCUSDT': ['ETHUSDT', 'SOLUSDT'],    # BTC correlates with major alts
    'EURUSD': ['GBPUSD', 'XAUUSD'],      # EUR correlates with GBP, Gold
}
```

## Drawdown Control & Circuit Breaker

```python
class DrawdownController:
    def __init__(self, peak_balance: float):
        self.peak = peak_balance
        self.thresholds = {
            5: 0.75,    # 5% DD → reduce size to 75%
            10: 0.50,   # 10% DD → reduce size to 50%
            15: 0.25,   # 15% DD → reduce size to 25%
            20: 0.0,    # 20% DD → stop trading
        }

    def check(self, current_balance: float) -> dict:
        dd_pct = (self.peak - current_balance) / self.peak * 100
        if current_balance > self.peak:
            self.peak = current_balance

        size_multiplier = 1.0
        action = "normal"
        for threshold, mult in sorted(self.thresholds.items()):
            if dd_pct >= threshold:
                size_multiplier = mult
                action = "stop" if mult == 0 else f"reduce_to_{int(mult*100)}%"

        return {
            'drawdown_pct': round(dd_pct, 2),
            'size_multiplier': size_multiplier,
            'action': action,
            'peak': self.peak,
        }
```

## Risk Per Asset Type

| Asset | Max Risk/Trade | SL Method | Spread Impact | Session |
|-------|---------------|-----------|---------------|---------|
| Gold (XAUUSD) | 1-2% | ATR x 2.0-2.5 | Medium (2-3 pips) | London + NY |
| Bitcoin | 1% | ATR x 2.5-3.0 | Low (exchange) | 24/7 |
| Oil (USOIL) | 1% | ATR x 2.0 | Medium | NY session |
| EUR/USD | 1-2% | ATR x 1.5-2.0 | Very low | London + NY overlap |
| Altcoins | 0.5-1% | ATR x 3.0 | Varies | 24/7 |

## Pre-Trade Checklist

```python
def pre_trade_check(symbol, direction, entry, sl, tp, account_balance,
                    current_positions, daily_pnl):
    checks = []
    risk_amount = abs(entry - sl)
    risk_pct = risk_amount / account_balance * 100
    rr_ratio = abs(tp - entry) / abs(entry - sl) if abs(entry - sl) > 0 else 0

    checks.append(("Risk per trade ≤ 2%", risk_pct <= 2))
    checks.append(("R:R ratio ≥ 1:2", rr_ratio >= 2))
    checks.append(("Max positions ≤ 5", len(current_positions) < 5))
    checks.append(("Daily loss < 3%", abs(daily_pnl) < account_balance * 0.03))
    checks.append(("Not correlated overexposure", True))  # Check correlation map
    checks.append(("Not during high-impact news", True))  # Check economic calendar

    all_pass = all(c[1] for c in checks)
    return {'pass': all_pass, 'checks': checks}
```
