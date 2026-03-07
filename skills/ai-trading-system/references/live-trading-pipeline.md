# Live Trading Pipeline Reference

## System Architecture

```
┌─ Scheduler (APScheduler / cron) ─────────────────────────────┐
│                                                               │
│  Every 15min (or candle close):                               │
│    1. MarketDataPipeline.fetch_ohlcv()                        │
│    2. FeatureEngine.build_all()                               │
│    3. RegimeDetector.fit_predict()                            │
│    4. AIDecisionEngine.generate_signal()                      │
│    5. AIRiskManager.check_trade_allowed()                     │
│    6. IF allowed → calculate lot, SL/TP → execute             │
│    7. Log signal + result → database                          │
│    8. Notify via Telegram                                     │
│                                                               │
│  Every 1 hour:                                                │
│    - Update regime detection                                  │
│    - Manage trailing stops                                    │
│    - Check daily PnL limits                                   │
│                                                               │
│  Every day (market close):                                    │
│    - Generate daily report                                    │
│    - Export trade log                                         │
│    - Check model performance degradation                      │
│                                                               │
│  Every week:                                                  │
│    - Retrain models (if performance drops)                    │
│    - Re-optimize parameters (Bayesian)                        │
│    - Adapt regime weights                                     │
│                                                               │
│  Every month:                                                 │
│    - Full model retraining                                    │
│    - Monte Carlo simulation                                   │
│    - Strategy review report                                   │
└───────────────────────────────────────────────────────────────┘
```

## MT5 Execution Engine

### Order Types & Execution

```python
import MetaTrader5 as mt5

class MT5Executor:

    def market_order(self, symbol, direction, lot, sl, tp, comment=""):
        tick = mt5.symbol_info_tick(symbol)
        price = tick.ask if direction == 1 else tick.bid

        request = {
            'action': mt5.TRADE_ACTION_DEAL,
            'symbol': symbol,
            'volume': lot,
            'type': mt5.ORDER_TYPE_BUY if direction == 1 else mt5.ORDER_TYPE_SELL,
            'price': price,
            'sl': sl,
            'tp': tp,
            'deviation': 20,
            'magic': 202600,
            'comment': comment,
            'type_time': mt5.ORDER_TIME_GTC,
            'type_filling': mt5.ORDER_FILLING_IOC,
        }
        result = mt5.order_send(request)
        return self._parse_result(result)

    def modify_position(self, ticket, new_sl=None, new_tp=None):
        position = mt5.positions_get(ticket=ticket)
        if not position:
            return None
        pos = position[0]

        request = {
            'action': mt5.TRADE_ACTION_SLTP,
            'position': ticket,
            'symbol': pos.symbol,
            'sl': new_sl or pos.sl,
            'tp': new_tp or pos.tp,
        }
        return mt5.order_send(request)

    def close_position(self, ticket):
        position = mt5.positions_get(ticket=ticket)
        if not position:
            return None
        pos = position[0]

        close_type = mt5.ORDER_TYPE_SELL if pos.type == 0 else mt5.ORDER_TYPE_BUY
        tick = mt5.symbol_info_tick(pos.symbol)
        price = tick.bid if pos.type == 0 else tick.ask

        request = {
            'action': mt5.TRADE_ACTION_DEAL,
            'position': ticket,
            'symbol': pos.symbol,
            'volume': pos.volume,
            'type': close_type,
            'price': price,
            'deviation': 20,
            'magic': 202600,
            'comment': 'AI Close',
        }
        return mt5.order_send(request)

    def trailing_stop(self, ticket, trail_points):
        position = mt5.positions_get(ticket=ticket)
        if not position:
            return
        pos = position[0]
        tick = mt5.symbol_info_tick(pos.symbol)
        point = mt5.symbol_info(pos.symbol).point

        if pos.type == 0:  # Buy
            new_sl = tick.bid - trail_points * point
            if new_sl > pos.sl and new_sl > pos.price_open:
                self.modify_position(ticket, new_sl=new_sl)
        else:  # Sell
            new_sl = tick.ask + trail_points * point
            if new_sl < pos.sl and new_sl < pos.price_open:
                self.modify_position(ticket, new_sl=new_sl)

    def get_open_positions(self, symbol=None):
        if symbol:
            return mt5.positions_get(symbol=symbol)
        return mt5.positions_get()

    def get_account_info(self):
        info = mt5.account_info()
        return {
            'balance': info.balance,
            'equity': info.equity,
            'margin': info.margin,
            'free_margin': info.margin_free,
            'margin_level': info.margin_level,
            'profit': info.profit,
        }

    def _parse_result(self, result):
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            return {'success': True, 'ticket': result.order, 'price': result.price}
        return {'success': False, 'error': result.comment, 'code': result.retcode}
```

## Telegram Notification System

```python
import aiohttp
import asyncio

class TradingNotifier:

    def __init__(self, token, chat_id):
        self.token = token
        self.chat_id = chat_id
        self.base_url = f"https://api.telegram.org/bot{token}"

    async def send(self, message):
        async with aiohttp.ClientSession() as session:
            await session.post(f"{self.base_url}/sendMessage", json={
                'chat_id': self.chat_id,
                'text': message,
                'parse_mode': 'HTML',
            })

    def signal_alert(self, signal: dict):
        emoji = {'BUY': '🟢', 'SELL': '🔴', 'HOLD': '⚪'}
        direction_text = {1: 'BUY', -1: 'SELL', 0: 'HOLD'}
        d = direction_text[signal['direction']]

        msg = (
            f"{emoji.get(d, '⚪')} <b>AI Signal: {d}</b>\n"
            f"━━━━━━━━━━━━━━━━━━\n"
            f"Symbol: {signal.get('symbol', 'XAUUSD')}\n"
            f"Confidence: {signal['confidence']:.1%}\n"
            f"Regime: {signal['regime']}\n"
            f"━━━━━━━━━━━━━━━━━━\n"
            f"Models:\n"
        )
        for model, data in signal.get('model_signals', {}).items():
            s = {1: '↑', -1: '↓', 0: '→'}[data['signal']]
            msg += f"  {model.upper()}: {s} ({data['confidence']:.1%})\n"

        asyncio.run(self.send(msg))

    def trade_alert(self, trade: dict):
        msg = (
            f"📊 <b>Trade Executed</b>\n"
            f"━━━━━━━━━━━━━━━━━━\n"
            f"Direction: {trade['direction']}\n"
            f"Lot: {trade['lot']}\n"
            f"Entry: {trade['entry_price']}\n"
            f"SL: {trade['sl']} | TP: {trade['tp']}\n"
            f"R:R = {trade['risk_reward']}\n"
        )
        asyncio.run(self.send(msg))

    def daily_report(self, stats: dict):
        msg = (
            f"📈 <b>Daily Report</b>\n"
            f"━━━━━━━━━━━━━━━━━━\n"
            f"PnL: ${stats['daily_pnl']:+.2f} ({stats['daily_pnl_pct']:+.1%})\n"
            f"Trades: {stats['n_trades']} (W: {stats['wins']} / L: {stats['losses']})\n"
            f"Win Rate: {stats['win_rate']:.1%}\n"
            f"Equity: ${stats['equity']:,.2f}\n"
            f"Drawdown: {stats['drawdown']:.1%}\n"
            f"Regime: {stats['current_regime']}\n"
        )
        asyncio.run(self.send(msg))
```

## Trade Logging Database

```python
import sqlite3
from datetime import datetime

class TradeLogger:

    def __init__(self, db_path="trades.db"):
        self.conn = sqlite3.connect(db_path)
        self._create_tables()

    def _create_tables(self):
        self.conn.executescript("""
            CREATE TABLE IF NOT EXISTS signals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT, symbol TEXT,
                direction INTEGER, confidence REAL,
                regime TEXT, gbm_signal INTEGER, dl_signal INTEGER, rl_signal INTEGER,
                action_taken TEXT
            );
            CREATE TABLE IF NOT EXISTS trades (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ticket INTEGER, timestamp_open TEXT, timestamp_close TEXT,
                symbol TEXT, direction TEXT,
                lot REAL, entry_price REAL, exit_price REAL,
                sl REAL, tp REAL,
                pnl REAL, pnl_pct REAL,
                confidence REAL, regime TEXT,
                comment TEXT
            );
            CREATE TABLE IF NOT EXISTS daily_stats (
                date TEXT PRIMARY KEY,
                equity REAL, balance REAL,
                n_trades INTEGER, wins INTEGER, losses INTEGER,
                daily_pnl REAL, max_drawdown REAL,
                regime TEXT
            );
        """)
        self.conn.commit()

    def log_signal(self, signal: dict):
        self.conn.execute(
            "INSERT INTO signals (timestamp, symbol, direction, confidence, "
            "regime, action_taken) VALUES (?, ?, ?, ?, ?, ?)",
            (str(signal['timestamp']), signal.get('symbol', 'XAUUSD'),
             signal['direction'], signal['confidence'],
             signal['regime'], signal.get('action', 'HOLD'))
        )
        self.conn.commit()

    def log_trade(self, trade: dict):
        self.conn.execute(
            "INSERT INTO trades (ticket, timestamp_open, symbol, direction, "
            "lot, entry_price, sl, tp, confidence, regime) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (trade['ticket'], str(datetime.now()), trade['symbol'],
             trade['direction'], trade['lot'], trade['entry_price'],
             trade['sl'], trade['tp'], trade['confidence'], trade['regime'])
        )
        self.conn.commit()

    def get_performance_summary(self, days=30):
        cursor = self.conn.execute(
            "SELECT * FROM trades WHERE timestamp_open > datetime('now', ?)",
            (f'-{days} days',)
        )
        trades = cursor.fetchall()

        if not trades:
            return {'n_trades': 0}

        pnls = [t[11] for t in trades if t[11] is not None]
        wins = [p for p in pnls if p > 0]
        losses = [p for p in pnls if p < 0]

        return {
            'n_trades': len(pnls),
            'win_rate': len(wins) / len(pnls) if pnls else 0,
            'total_pnl': sum(pnls),
            'avg_win': np.mean(wins) if wins else 0,
            'avg_loss': np.mean(losses) if losses else 0,
            'profit_factor': abs(sum(wins) / sum(losses)) if losses else float('inf'),
            'max_win': max(pnls) if pnls else 0,
            'max_loss': min(pnls) if pnls else 0,
        }
```

## Performance Dashboard (Plotly)

```python
import plotly.graph_objects as go
from plotly.subplots import make_subplots

def create_performance_dashboard(equity_curve, trades, signals):
    fig = make_subplots(
        rows=4, cols=2,
        specs=[[{"colspan": 2}, None],
               [{"colspan": 2}, None],
               [{}, {}],
               [{}, {}]],
        subplot_titles=['Equity Curve', 'Drawdown',
                       'Win Rate by Regime', 'PnL Distribution',
                       'Model Accuracy', 'Monthly Returns'],
        vertical_spacing=0.08
    )

    # Equity curve
    fig.add_trace(go.Scatter(
        x=equity_curve.index, y=equity_curve.values,
        mode='lines', name='Equity', line=dict(color='#2196F3', width=2)
    ), row=1, col=1)

    # Drawdown
    peak = equity_curve.cummax()
    dd = (peak - equity_curve) / peak
    fig.add_trace(go.Scatter(
        x=dd.index, y=-dd.values,
        fill='tozeroy', name='Drawdown',
        line=dict(color='#F44336', width=1)
    ), row=2, col=1)

    fig.update_layout(height=1200, template='plotly_dark',
                     title='AI Trading System Dashboard')
    fig.show()
```

## Model Performance Monitoring

```python
class ModelMonitor:
    """Detect model degradation and trigger retraining."""

    def __init__(self, baseline_metrics: dict, decay_threshold: float = 0.2):
        self.baseline = baseline_metrics
        self.threshold = decay_threshold
        self.rolling_metrics = []

    def update(self, prediction, actual):
        self.rolling_metrics.append({
            'correct': int(np.sign(prediction) == np.sign(actual)),
            'timestamp': datetime.now()
        })

        if len(self.rolling_metrics) > 200:
            self.rolling_metrics = self.rolling_metrics[-200:]

    def check_degradation(self, window=100) -> dict:
        if len(self.rolling_metrics) < window:
            return {'degraded': False, 'reason': 'insufficient data'}

        recent = self.rolling_metrics[-window:]
        current_acc = np.mean([m['correct'] for m in recent])
        baseline_acc = self.baseline.get('accuracy', 0.55)

        decay = (baseline_acc - current_acc) / baseline_acc

        return {
            'degraded': decay > self.threshold,
            'current_accuracy': current_acc,
            'baseline_accuracy': baseline_acc,
            'decay_pct': decay,
            'action': 'RETRAIN' if decay > self.threshold else 'OK',
            'samples': len(recent),
        }
```

## Deployment Checklist

### Before Going Live

- [ ] Walk-forward backtest: Sharpe > 1.5 across all folds
- [ ] Monte Carlo: ruin probability < 5%
- [ ] Paper trading: minimum 3 months, consistent positive PnL
- [ ] Drawdown test: max DD < 15% in all simulations
- [ ] Latency test: signal → execution < 500ms
- [ ] Failover: automatic stop on connection loss
- [ ] Notification: Telegram alerts working
- [ ] Logging: all signals and trades recorded to DB
- [ ] Risk limits: daily loss cap, drawdown cap, position limits
- [ ] Model monitor: degradation detection active

### Production Monitoring

- Check model accuracy weekly (should be > 53%)
- Review regime detection accuracy monthly
- Re-optimize parameters every 2-4 weeks
- Full model retraining every 1-3 months
- Quarterly strategy review with Monte Carlo update
