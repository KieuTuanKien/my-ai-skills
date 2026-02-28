---
name: market-data-pipeline
description: Build real-time and historical market data pipelines for FX, crypto, and commodities. Covers WebSocket streaming, REST APIs, OHLCV aggregation, data storage with SQLite/TimescaleDB, and multi-source data fusion. Use when fetching price data, building data feeds, storing market data, or creating real-time dashboards.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Market Data, WebSocket, OHLCV, Data Pipeline, Real-Time, FX, Crypto, TimescaleDB]
dependencies: [ccxt, MetaTrader5, websocket-client, pandas, sqlalchemy, aiohttp]
---

# Market Data Pipeline

## When to Use

- Fetching real-time or historical price data (OHLCV)
- Building WebSocket streams for live prices
- Storing market data in databases (SQLite, PostgreSQL/TimescaleDB)
- Creating multi-timeframe data feeds
- Data fusion from multiple sources (MT5 + crypto exchanges)

## Historical Data - MetaTrader5

```python
import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime, timedelta

TIMEFRAMES = {
    "M1": mt5.TIMEFRAME_M1,
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "H1": mt5.TIMEFRAME_H1,
    "H4": mt5.TIMEFRAME_H4,
    "D1": mt5.TIMEFRAME_D1,
}

def fetch_mt5_ohlcv(symbol: str, timeframe: str = "H1",
                     bars: int = 1000) -> pd.DataFrame:
    tf = TIMEFRAMES[timeframe]
    rates = mt5.copy_rates_from_pos(symbol, tf, 0, bars)
    if rates is None:
        raise ValueError(f"No data for {symbol}: {mt5.last_error()}")

    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    df.set_index('time', inplace=True)
    df.rename(columns={'tick_volume': 'volume'}, inplace=True)
    return df[['open', 'high', 'low', 'close', 'volume']]

# Fetch 1000 bars of XAUUSD H1
gold = fetch_mt5_ohlcv("XAUUSD", "H1", 1000)
```

## Historical Data - Crypto (ccxt)

```python
import ccxt
import pandas as pd

def fetch_crypto_ohlcv(exchange_id: str, symbol: str,
                        timeframe: str = '1h', limit: int = 1000) -> pd.DataFrame:
    exchange = getattr(ccxt, exchange_id)({'enableRateLimit': True})
    ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)

    df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
    df.set_index('timestamp', inplace=True)
    return df

btc = fetch_crypto_ohlcv('binance', 'BTC/USDT', '1h', 1000)
```

## Real-Time WebSocket Stream

```python
import asyncio
import json
import websockets

class PriceStream:
    def __init__(self, symbols: list[str]):
        self.symbols = symbols
        self.prices = {}
        self.callbacks = []

    def on_price(self, callback):
        self.callbacks.append(callback)

    async def connect_binance(self):
        streams = "/".join([f"{s.lower().replace('/', '')}@ticker" for s in self.symbols])
        url = f"wss://stream.binance.com:9443/stream?streams={streams}"

        async with websockets.connect(url) as ws:
            async for msg in ws:
                data = json.loads(msg)['data']
                price_update = {
                    'symbol': data['s'],
                    'bid': float(data['b']),
                    'ask': float(data['a']),
                    'last': float(data['c']),
                    'volume_24h': float(data['v']),
                }
                self.prices[data['s']] = price_update
                for cb in self.callbacks:
                    await cb(price_update)

stream = PriceStream(['BTC/USDT', 'ETH/USDT'])
stream.on_price(lambda p: print(f"{p['symbol']}: {p['last']}"))
asyncio.run(stream.connect_binance())
```

## Data Storage - SQLite (Simple)

```python
import sqlite3

def init_db(db_path: str = "market_data.db"):
    conn = sqlite3.connect(db_path)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS ohlcv (
            symbol TEXT,
            timeframe TEXT,
            timestamp DATETIME,
            open REAL,
            high REAL,
            low REAL,
            close REAL,
            volume REAL,
            PRIMARY KEY (symbol, timeframe, timestamp)
        )
    """)
    conn.commit()
    return conn

def save_ohlcv(conn, symbol: str, timeframe: str, df: pd.DataFrame):
    df = df.copy()
    df['symbol'] = symbol
    df['timeframe'] = timeframe
    df.reset_index(inplace=True)
    df.to_sql('ohlcv', conn, if_exists='append', index=False,
              method='multi')
```

## Data Storage - TimescaleDB (Production)

```python
from sqlalchemy import create_engine, text

engine = create_engine("postgresql://user:pass@localhost/trading")

def init_timescale():
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS ohlcv (
                time TIMESTAMPTZ NOT NULL,
                symbol TEXT NOT NULL,
                timeframe TEXT NOT NULL,
                open DOUBLE PRECISION,
                high DOUBLE PRECISION,
                low DOUBLE PRECISION,
                close DOUBLE PRECISION,
                volume DOUBLE PRECISION
            );
            SELECT create_hypertable('ohlcv', 'time', if_not_exists => TRUE);
            CREATE INDEX IF NOT EXISTS idx_symbol_tf ON ohlcv (symbol, timeframe, time DESC);
        """))
        conn.commit()
```

## Multi-Timeframe Data Builder

```python
def resample_ohlcv(df: pd.DataFrame, target_tf: str) -> pd.DataFrame:
    """Resample lower timeframe to higher (e.g., M5 → H1)."""
    rules = {'M5': '5min', 'M15': '15min', 'H1': '1h', 'H4': '4h', 'D1': '1D'}
    return df.resample(rules[target_tf]).agg({
        'open': 'first',
        'high': 'max',
        'low': 'min',
        'close': 'last',
        'volume': 'sum'
    }).dropna()
```

## Data Quality Checks

```python
def validate_ohlcv(df: pd.DataFrame) -> dict:
    issues = {}
    if df.isnull().any().any():
        issues['missing_values'] = df.isnull().sum().to_dict()
    if (df['high'] < df['low']).any():
        issues['invalid_hl'] = int((df['high'] < df['low']).sum())
    if (df['close'] > df['high']).any() or (df['close'] < df['low']).any():
        issues['close_out_of_range'] = True

    gaps = df.index.to_series().diff()
    median_gap = gaps.median()
    large_gaps = gaps[gaps > median_gap * 3]
    if len(large_gaps) > 0:
        issues['data_gaps'] = len(large_gaps)
    return issues
```

## Common Data Sources

| Source | Assets | Type | Cost |
|--------|--------|------|------|
| MetaTrader5 | FX, Gold, Oil, Indices | Broker feed | Free (with broker account) |
| Binance API | 500+ crypto pairs | Exchange | Free |
| Alpha Vantage | Stocks, FX, Crypto | REST API | Free tier available |
| Polygon.io | Stocks, Options, FX, Crypto | REST + WebSocket | Paid |
| Yahoo Finance (yfinance) | Stocks, ETFs, Indices | REST | Free |
| OANDA API | FX, CFDs | REST + Streaming | Free (with account) |
