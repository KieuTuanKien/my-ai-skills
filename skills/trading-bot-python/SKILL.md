---
name: trading-bot-python
description: Build automated trading bots for FX, gold (XAUUSD), bitcoin, oil (WTI/Brent) using Python. Covers MetaTrader5, ccxt for crypto exchanges, order execution, position management, and multi-asset bot architecture. Use when building trading bots, automating trade execution, connecting to brokers/exchanges, or developing algorithmic trading systems.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Trading Bot, MetaTrader5, ccxt, Algorithmic Trading, FX, Gold, Bitcoin, Oil, Automation]
dependencies: [MetaTrader5, ccxt, pandas, numpy, python-dotenv, websocket-client, schedule]
---

# Trading Bot Development - Python

## When to Use

- Building automated trading bots for FX/Crypto/Commodities
- Connecting to MetaTrader5 (forex, gold, oil) or crypto exchanges (Binance, Bybit)
- Automating order execution, position management, trailing stops
- Multi-asset portfolio bots running 24/7

## Architecture Overview

```
trading-bot/
├── config/
│   ├── settings.py          # API keys, broker config
│   └── instruments.py       # XAUUSD, BTCUSDT, USOIL params
├── data/
│   ├── feed.py              # Real-time price feed
│   └── historical.py        # Historical data fetcher
├── strategy/
│   ├── base.py              # Abstract strategy class
│   ├── ma_crossover.py      # Moving average crossover
│   └── breakout.py          # Support/resistance breakout
├── execution/
│   ├── mt5_executor.py      # MetaTrader5 order execution
│   ├── ccxt_executor.py     # Crypto exchange execution
│   └── risk_checker.py      # Pre-trade risk validation
├── portfolio/
│   ├── position_manager.py  # Open positions tracking
│   └── pnl_tracker.py       # P&L calculation
├── utils/
│   ├── logger.py            # Trade logging
│   └── notifier.py          # Telegram/Discord alerts
├── main.py                  # Bot entry point
└── requirements.txt
```

## Quick Start - MetaTrader5 Bot (FX, Gold, Oil)

### Installation

```bash
pip install MetaTrader5 pandas numpy ta python-dotenv schedule
```

### Connect to MT5

```python
import MetaTrader5 as mt5
from datetime import datetime

def connect_mt5(login: int, password: str, server: str) -> bool:
    if not mt5.initialize():
        raise ConnectionError(f"MT5 init failed: {mt5.last_error()}")
    authorized = mt5.login(login=login, password=password, server=server)
    if not authorized:
        raise ConnectionError(f"MT5 login failed: {mt5.last_error()}")
    return True

connect_mt5(login=12345678, password="your_pass", server="YourBroker-Server")
account = mt5.account_info()
print(f"Balance: {account.balance}, Equity: {account.equity}")
```

### Place Orders - Gold (XAUUSD)

```python
def place_order(symbol: str, order_type: str, volume: float,
                sl_points: int = 100, tp_points: int = 200):
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None or not symbol_info.visible:
        mt5.symbol_select(symbol, True)

    tick = mt5.symbol_info_tick(symbol)
    point = mt5.symbol_info(symbol).point

    if order_type == "BUY":
        price = tick.ask
        sl = price - sl_points * point
        tp = price + tp_points * point
        trade_type = mt5.ORDER_TYPE_BUY
    else:
        price = tick.bid
        sl = price + sl_points * point
        tp = price - tp_points * point
        trade_type = mt5.ORDER_TYPE_SELL

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": volume,
        "type": trade_type,
        "price": price,
        "sl": sl,
        "tp": tp,
        "deviation": 20,
        "magic": 234000,
        "comment": "python bot",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    result = mt5.order_send(request)
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        raise Exception(f"Order failed: {result.retcode} - {result.comment}")
    return result

# Gold: 0.01 lot, SL 100 points, TP 200 points
place_order("XAUUSD", "BUY", 0.01, sl_points=100, tp_points=200)
```

### Trailing Stop

```python
def trailing_stop(symbol: str, ticket: int, trail_points: int = 50):
    position = mt5.positions_get(ticket=ticket)
    if not position:
        return
    pos = position[0]
    point = mt5.symbol_info(symbol).point
    tick = mt5.symbol_info_tick(symbol)

    if pos.type == mt5.ORDER_TYPE_BUY:
        new_sl = tick.bid - trail_points * point
        if new_sl > pos.sl:
            modify_sl(ticket, new_sl, pos.tp)
    else:
        new_sl = tick.ask + trail_points * point
        if new_sl < pos.sl or pos.sl == 0:
            modify_sl(ticket, new_sl, pos.tp)

def modify_sl(ticket: int, sl: float, tp: float):
    request = {
        "action": mt5.TRADE_ACTION_SLTP,
        "position": ticket,
        "sl": sl,
        "tp": tp,
    }
    mt5.order_send(request)
```

## Quick Start - Crypto Bot (Bitcoin, Altcoins)

### Installation

```bash
pip install ccxt pandas numpy ta websocket-client
```

### Connect & Trade on Binance

```python
import ccxt

exchange = ccxt.binance({
    'apiKey': 'YOUR_API_KEY',
    'secret': 'YOUR_SECRET',
    'options': {'defaultType': 'future'},  # For futures trading
    'enableRateLimit': True,
})

# Fetch BTC price
ticker = exchange.fetch_ticker('BTC/USDT')
print(f"BTC: {ticker['last']}")

# Place limit buy
order = exchange.create_limit_buy_order(
    symbol='BTC/USDT',
    amount=0.001,
    price=95000,
    params={'stopLoss': {'triggerPrice': 93000},
            'takeProfit': {'triggerPrice': 100000}}
)
```

### Multi-Exchange Support

```python
EXCHANGES = {
    'binance': ccxt.binance,
    'bybit': ccxt.bybit,
    'okx': ccxt.okx,
}

def create_exchange(name: str, api_key: str, secret: str):
    cls = EXCHANGES[name]
    return cls({'apiKey': api_key, 'secret': secret, 'enableRateLimit': True})
```

## Base Strategy Pattern

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum

class Signal(Enum):
    BUY = "BUY"
    SELL = "SELL"
    HOLD = "HOLD"

@dataclass
class TradeSignal:
    signal: Signal
    symbol: str
    entry_price: float
    sl: float
    tp: float
    volume: float
    confidence: float  # 0.0 - 1.0

class BaseStrategy(ABC):
    @abstractmethod
    def analyze(self, df) -> TradeSignal:
        """Analyze price data and return signal."""
        pass

    @abstractmethod
    def should_exit(self, position, current_price) -> bool:
        """Check if position should be closed."""
        pass
```

## Instrument-Specific Config

```python
INSTRUMENTS = {
    "XAUUSD": {  # Gold
        "pip_value": 0.01,
        "spread_avg": 25,  # points
        "session": "07:00-20:00 UTC",
        "lot_min": 0.01,
        "margin_per_lot": 2000,
        "volatility": "high",
    },
    "BTCUSDT": {  # Bitcoin
        "min_qty": 0.001,
        "tick_size": 0.01,
        "session": "24/7",
        "funding_rate": True,
        "volatility": "very_high",
    },
    "USOIL": {  # WTI Oil
        "pip_value": 0.01,
        "spread_avg": 3,
        "session": "01:00-22:00 UTC",
        "lot_min": 0.01,
        "margin_per_lot": 1000,
        "volatility": "high",
    },
    "EURUSD": {  # EUR/USD
        "pip_value": 0.0001,
        "spread_avg": 1,
        "session": "00:00-23:59 UTC",
        "lot_min": 0.01,
        "margin_per_lot": 1000,
        "volatility": "medium",
    },
}
```

## Telegram Notifications

```python
import requests

def send_telegram(bot_token: str, chat_id: str, message: str):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    requests.post(url, json={"chat_id": chat_id, "text": message, "parse_mode": "HTML"})

def notify_trade(action, symbol, price, sl, tp, pnl=None):
    msg = (
        f"<b>{action}</b> {symbol}\n"
        f"Price: {price}\nSL: {sl} | TP: {tp}\n"
    )
    if pnl is not None:
        msg += f"P&L: <b>{pnl:+.2f}</b>"
    send_telegram(BOT_TOKEN, CHAT_ID, msg)
```

## 24/7 Bot Loop

```python
import schedule
import time

def run_bot():
    strategy = MACrossoverStrategy(fast=9, slow=21)
    symbols = ["XAUUSD", "BTCUSDT", "USOIL"]

    for symbol in symbols:
        df = get_price_data(symbol, timeframe="H1", bars=200)
        signal = strategy.analyze(df)
        if signal.signal != Signal.HOLD and signal.confidence > 0.7:
            place_order(symbol, signal.signal.value, signal.volume,
                        sl=signal.sl, tp=signal.tp)
            notify_trade(signal.signal.value, symbol, signal.entry_price,
                         signal.sl, signal.tp)

    manage_open_positions()

schedule.every(5).minutes.do(run_bot)

while True:
    schedule.run_pending()
    time.sleep(1)
```

## Key Libraries

| Library | Purpose |
|---------|---------|
| `MetaTrader5` | MT5 broker connection (FX, gold, oil) |
| `ccxt` | 100+ crypto exchanges unified API |
| `ta` / `ta-lib` | Technical indicators |
| `websocket-client` | Real-time price streaming |
| `schedule` / `APScheduler` | Task scheduling |
| `python-dotenv` | Secure API key management |

## Common Pitfalls

- Always use `python-dotenv` for API keys, never hardcode
- MT5 only works on Windows (or Wine on Linux)
- Set `deviation` for MT5 orders to handle slippage
- Use `enableRateLimit: True` for ccxt to avoid exchange bans
- Gold (XAUUSD) has wider spreads - avoid scalping on news
- Bitcoin futures: account for funding rates in overnight positions
- Always implement a kill switch for runaway bots

## Additional Resources

- For technical indicators → see `technical-analysis-trading` skill
- For backtesting → see `backtesting-strategies` skill
- For risk management → see `risk-management-trading` skill
- For market data feeds → see `market-data-pipeline` skill
