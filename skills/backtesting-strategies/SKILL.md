---
name: backtesting-strategies
description: Backtest trading strategies on historical data using backtrader, vectorbt, and custom frameworks. Covers strategy validation, walk-forward analysis, Monte Carlo simulation, optimization, and performance metrics (Sharpe, drawdown, win rate). Use when testing strategies before live trading, optimizing parameters, or validating profitability.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Backtesting, Strategy Testing, backtrader, vectorbt, Walk-Forward, Monte Carlo, Sharpe Ratio, Optimization]
dependencies: [backtrader, vectorbt, pandas, numpy, matplotlib]
---

# Backtesting Trading Strategies

## When to Use

- Testing strategies on historical data before live deployment
- Optimizing strategy parameters (walk-forward analysis)
- Measuring performance (Sharpe ratio, max drawdown, win rate)
- Monte Carlo simulation for robustness testing
- Comparing multiple strategies

## Quick Start with vectorbt (Fast, Vectorized)

```bash
pip install vectorbt pandas numpy matplotlib
```

```python
import vectorbt as vbt
import pandas as pd

# Fetch data
btc = vbt.YFData.download("BTC-USD", period="2y", interval="1d")
price = btc.get('Close')

# Simple MA crossover backtest
fast_ma = vbt.MA.run(price, window=10)
slow_ma = vbt.MA.run(price, window=30)

entries = fast_ma.ma_crossed_above(slow_ma)
exits = fast_ma.ma_crossed_below(slow_ma)

pf = vbt.Portfolio.from_signals(
    price, entries, exits,
    init_cash=10000,
    fees=0.001,
    freq='1D'
)

print(pf.stats())
pf.plot().show()
```

## Backtrader (Feature-Rich, Event-Driven)

```bash
pip install backtrader matplotlib
```

```python
import backtrader as bt

class GoldMACrossover(bt.Strategy):
    params = (('fast', 9), ('slow', 21), ('atr_mult', 2.0),)

    def __init__(self):
        self.fast_ma = bt.ind.EMA(period=self.p.fast)
        self.slow_ma = bt.ind.EMA(period=self.p.slow)
        self.atr = bt.ind.ATR(period=14)
        self.crossover = bt.ind.CrossOver(self.fast_ma, self.slow_ma)

    def next(self):
        if not self.position:
            if self.crossover > 0:  # Fast crosses above slow
                sl = self.data.close[0] - self.atr[0] * self.p.atr_mult
                size = self.broker.getvalue() * 0.02 / (self.data.close[0] - sl)
                self.buy(size=size)
                self.sell(exectype=bt.Order.Stop, price=sl)
        elif self.crossover < 0:
            self.close()

    def notify_trade(self, trade):
        if trade.isclosed:
            print(f"P&L: {trade.pnl:.2f} | Net: {trade.pnlcomm:.2f}")

# Run backtest
cerebro = bt.Cerebro()
cerebro.addstrategy(GoldMACrossover)

data = bt.feeds.GenericCSVData(
    dataname='xauusd_h1.csv',
    dtformat='%Y-%m-%d %H:%M:%S',
    datetime=0, open=1, high=2, low=3, close=4, volume=5,
)
cerebro.adddata(data)
cerebro.broker.setcash(10000)
cerebro.broker.setcommission(commission=0.0002)

# Analyzers
cerebro.addanalyzer(bt.analyzers.SharpeRatio, _name='sharpe')
cerebro.addanalyzer(bt.analyzers.DrawDown, _name='drawdown')
cerebro.addanalyzer(bt.analyzers.TradeAnalyzer, _name='trades')

results = cerebro.run()
strat = results[0]
print(f"Sharpe: {strat.analyzers.sharpe.get_analysis()['sharperatio']:.2f}")
print(f"Max DD: {strat.analyzers.drawdown.get_analysis()['max']['drawdown']:.1f}%")
cerebro.plot()
```

## Custom Backtest Engine (Lightweight)

```python
import pandas as pd
import numpy as np
from dataclasses import dataclass, field

@dataclass
class BacktestResult:
    total_return: float
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    total_trades: int
    profit_factor: float
    avg_win: float
    avg_loss: float
    trades: list = field(default_factory=list)

def backtest(df: pd.DataFrame, signals: pd.Series, sl_atr: float = 2.0,
             tp_atr: float = 3.0, risk_per_trade: float = 0.02) -> BacktestResult:
    """
    df: OHLCV with 'atr' column
    signals: Series with 1 (buy), -1 (sell), 0 (hold)
    """
    capital = 10000
    equity_curve = [capital]
    trades = []

    position = None
    for i in range(len(df)):
        row = df.iloc[i]
        if position:
            if position['type'] == 'BUY':
                if row['low'] <= position['sl']:
                    pnl = (position['sl'] - position['entry']) * position['size']
                    trades.append({'pnl': pnl, 'type': 'loss'})
                    capital += pnl; position = None
                elif row['high'] >= position['tp']:
                    pnl = (position['tp'] - position['entry']) * position['size']
                    trades.append({'pnl': pnl, 'type': 'win'})
                    capital += pnl; position = None

        if position is None and signals.iloc[i] != 0:
            atr = row['atr']
            direction = 'BUY' if signals.iloc[i] == 1 else 'SELL'
            entry = row['close']
            sl = entry - sl_atr * atr if direction == 'BUY' else entry + sl_atr * atr
            tp = entry + tp_atr * atr if direction == 'BUY' else entry - tp_atr * atr
            risk_amount = capital * risk_per_trade
            size = risk_amount / abs(entry - sl)
            position = {'type': direction, 'entry': entry, 'sl': sl, 'tp': tp, 'size': size}

        equity_curve.append(capital)

    equity = pd.Series(equity_curve)
    returns = equity.pct_change().dropna()
    wins = [t for t in trades if t['pnl'] > 0]
    losses = [t for t in trades if t['pnl'] <= 0]

    return BacktestResult(
        total_return=(capital - 10000) / 10000 * 100,
        sharpe_ratio=returns.mean() / returns.std() * np.sqrt(252) if returns.std() > 0 else 0,
        max_drawdown=((equity.cummax() - equity) / equity.cummax()).max() * 100,
        win_rate=len(wins) / len(trades) * 100 if trades else 0,
        total_trades=len(trades),
        profit_factor=sum(t['pnl'] for t in wins) / abs(sum(t['pnl'] for t in losses)) if losses else float('inf'),
        avg_win=np.mean([t['pnl'] for t in wins]) if wins else 0,
        avg_loss=np.mean([t['pnl'] for t in losses]) if losses else 0,
        trades=trades,
    )
```

## Walk-Forward Optimization

```python
def walk_forward(df, strategy_fn, param_grid, train_pct=0.7, n_splits=5):
    """Out-of-sample validation to prevent overfitting."""
    split_size = len(df) // n_splits
    results = []

    for i in range(n_splits):
        start = i * split_size
        end = start + split_size
        chunk = df.iloc[start:end]

        train_end = int(len(chunk) * train_pct)
        train_data = chunk.iloc[:train_end]
        test_data = chunk.iloc[train_end:]

        best_params = optimize_params(train_data, strategy_fn, param_grid)
        oos_result = strategy_fn(test_data, **best_params)
        results.append({
            'split': i,
            'params': best_params,
            'oos_return': oos_result.total_return,
            'oos_sharpe': oos_result.sharpe_ratio,
        })

    return pd.DataFrame(results)
```

## Monte Carlo Simulation

```python
def monte_carlo(trades: list, n_simulations: int = 1000,
                initial_capital: float = 10000) -> dict:
    """Shuffle trade order to test strategy robustness."""
    pnls = [t['pnl'] for t in trades]
    final_capitals = []
    max_drawdowns = []

    for _ in range(n_simulations):
        shuffled = np.random.permutation(pnls)
        equity = initial_capital + np.cumsum(shuffled)
        final_capitals.append(equity[-1])
        running_max = np.maximum.accumulate(equity)
        drawdowns = (running_max - equity) / running_max
        max_drawdowns.append(drawdowns.max() * 100)

    return {
        'median_return': (np.median(final_capitals) - initial_capital) / initial_capital * 100,
        'worst_case_5pct': np.percentile(final_capitals, 5),
        'best_case_95pct': np.percentile(final_capitals, 95),
        'median_max_dd': np.median(max_drawdowns),
        'worst_dd_95pct': np.percentile(max_drawdowns, 95),
        'prob_profitable': (np.array(final_capitals) > initial_capital).mean() * 100,
    }
```

## Performance Metrics Reference

| Metric | Good | Excellent | Formula |
|--------|------|-----------|---------|
| Sharpe Ratio | > 1.0 | > 2.0 | mean(returns) / std(returns) * sqrt(252) |
| Max Drawdown | < 20% | < 10% | max(peak - trough) / peak |
| Win Rate | > 45% | > 55% | wins / total_trades |
| Profit Factor | > 1.5 | > 2.0 | gross_profit / gross_loss |
| Calmar Ratio | > 1.0 | > 3.0 | annual_return / max_drawdown |
| Expectancy | > 0 | > 0.5 | (win_rate * avg_win) - (loss_rate * avg_loss) |

## Overfitting Prevention Checklist

- Use walk-forward analysis, never optimize on full dataset
- Test across multiple assets and time periods
- Monte Carlo simulation to verify robustness
- Keep strategy rules simple (< 5 parameters)
- Out-of-sample Sharpe should be > 60% of in-sample
- Minimum 100 trades for statistical significance
- Account for slippage, commissions, and spread
