---
name: deep-learning-trading
description: Deep Learning models for trading - LSTM, GRU, Temporal Convolutional Networks, Transformer (Temporal Fusion Transformer), CNN-LSTM hybrid, and Reinforcement Learning (DQN, PPO) for automated trading. Covers sequence modeling for price prediction, attention mechanisms for multi-asset, and RL-based portfolio optimization. Use when building neural network trading systems, time series forecasting with deep learning, or training RL agents for trading.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Deep Learning, LSTM, Transformer, CNN, Reinforcement Learning, DQN, PPO, Time Series, Neural Network, Trading]
dependencies: [torch, tensorflow, keras, stable-baselines3, gymnasium, pandas, numpy, ta, scikit-learn]
---

# Deep Learning for Trading

## When to Use

- Time series forecasting (price, volatility, returns)
- Sequence pattern recognition (LSTM/GRU/Transformer)
- Multi-timeframe feature fusion (CNN-LSTM)
- RL agent for autonomous trading decisions
- Attention-based multi-asset correlation modeling
- Non-linear pattern discovery beyond classical TA

## Installation

```bash
pip install torch torchvision pandas numpy ta scikit-learn matplotlib
pip install stable-baselines3 gymnasium  # For RL
```

## LSTM Price Predictor (PyTorch)

```python
import torch
import torch.nn as nn
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from torch.utils.data import DataLoader, TensorDataset

class LSTMTrading(nn.Module):
    def __init__(self, input_size, hidden_size=128, num_layers=2,
                 dropout=0.3, output_size=1):
        super().__init__()
        self.lstm = nn.LSTM(input_size, hidden_size, num_layers,
                            batch_first=True, dropout=dropout)
        self.attention = nn.MultiheadAttention(hidden_size, num_heads=4, batch_first=True)
        self.fc = nn.Sequential(
            nn.Linear(hidden_size, 64),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(64, output_size),
        )

    def forward(self, x):
        lstm_out, _ = self.lstm(x)
        attn_out, _ = self.attention(lstm_out, lstm_out, lstm_out)
        last_hidden = attn_out[:, -1, :]
        return self.fc(last_hidden)

def prepare_sequences(df, feature_cols, target_col, seq_length=60):
    """Create sequences for LSTM training."""
    scaler = StandardScaler()
    features = scaler.fit_transform(df[feature_cols].values)
    targets = df[target_col].values

    X, y = [], []
    for i in range(seq_length, len(features)):
        X.append(features[i - seq_length:i])
        y.append(targets[i])

    X = torch.FloatTensor(np.array(X))
    y = torch.FloatTensor(np.array(y))
    return X, y, scaler

def train_lstm(df, feature_cols, target_col='target_direction',
               seq_length=60, epochs=100, batch_size=64, lr=0.001):
    X, y, scaler = prepare_sequences(df, feature_cols, target_col, seq_length)

    split = int(len(X) * 0.8)
    X_train, X_test = X[:split], X[split:]
    y_train, y_test = y[:split], y[split:]

    train_loader = DataLoader(TensorDataset(X_train, y_train),
                              batch_size=batch_size, shuffle=False)

    model = LSTMTrading(input_size=len(feature_cols), output_size=1)
    criterion = nn.BCEWithLogitsLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, epochs)

    for epoch in range(epochs):
        model.train()
        total_loss = 0
        for X_batch, y_batch in train_loader:
            optimizer.zero_grad()
            pred = model(X_batch).squeeze()
            loss = criterion(pred, y_batch)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            total_loss += loss.item()
        scheduler.step()

        if (epoch + 1) % 20 == 0:
            model.eval()
            with torch.no_grad():
                test_pred = torch.sigmoid(model(X_test).squeeze())
                acc = ((test_pred > 0.5).float() == y_test).float().mean()
            print(f"Epoch {epoch+1}: Loss={total_loss/len(train_loader):.4f}, Acc={acc:.3f}")

    return model, scaler
```

## GRU (Lighter, Faster Alternative)

```python
class GRUTrading(nn.Module):
    def __init__(self, input_size, hidden_size=64, num_layers=2, dropout=0.2):
        super().__init__()
        self.gru = nn.GRU(input_size, hidden_size, num_layers,
                          batch_first=True, dropout=dropout)
        self.fc = nn.Sequential(
            nn.Linear(hidden_size, 32),
            nn.ReLU(),
            nn.Linear(32, 3),  # BUY / HOLD / SELL
        )

    def forward(self, x):
        out, _ = self.gru(x)
        return self.fc(out[:, -1, :])
```

## Temporal Fusion Transformer (State-of-the-Art)

```python
class TemporalFusionBlock(nn.Module):
    """Simplified TFT block for trading."""
    def __init__(self, d_model=64, n_heads=4, ff_dim=128, dropout=0.1):
        super().__init__()
        self.self_attn = nn.MultiheadAttention(d_model, n_heads,
                                                dropout=dropout, batch_first=True)
        self.norm1 = nn.LayerNorm(d_model)
        self.ff = nn.Sequential(
            nn.Linear(d_model, ff_dim), nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(ff_dim, d_model), nn.Dropout(dropout),
        )
        self.norm2 = nn.LayerNorm(d_model)

    def forward(self, x, mask=None):
        attn_out, attn_weights = self.self_attn(x, x, x, attn_mask=mask)
        x = self.norm1(x + attn_out)
        x = self.norm2(x + self.ff(x))
        return x, attn_weights

class TradingTransformer(nn.Module):
    def __init__(self, input_size, d_model=64, n_heads=4,
                 n_layers=3, seq_len=60, dropout=0.1):
        super().__init__()
        self.input_proj = nn.Linear(input_size, d_model)
        self.pos_encoding = nn.Parameter(torch.randn(1, seq_len, d_model) * 0.02)
        self.blocks = nn.ModuleList([
            TemporalFusionBlock(d_model, n_heads, d_model * 2, dropout)
            for _ in range(n_layers)
        ])
        self.head = nn.Sequential(
            nn.Linear(d_model, 32), nn.ReLU(), nn.Dropout(0.1),
            nn.Linear(32, 1),
        )

        # Causal mask (prevent looking into future)
        mask = torch.triu(torch.ones(seq_len, seq_len), diagonal=1).bool()
        self.register_buffer('causal_mask', mask)

    def forward(self, x):
        x = self.input_proj(x) + self.pos_encoding[:, :x.size(1), :]
        attention_maps = []
        for block in self.blocks:
            x, attn = block(x, mask=self.causal_mask[:x.size(1), :x.size(1)])
            attention_maps.append(attn)
        return self.head(x[:, -1, :]), attention_maps
```

## CNN-LSTM Hybrid (Pattern + Sequence)

```python
class CNNLSTM(nn.Module):
    """CNN extracts local patterns, LSTM captures temporal dependencies."""
    def __init__(self, input_size, seq_len=60):
        super().__init__()
        self.cnn = nn.Sequential(
            nn.Conv1d(input_size, 64, kernel_size=3, padding=1),
            nn.BatchNorm1d(64), nn.ReLU(),
            nn.Conv1d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm1d(128), nn.ReLU(),
            nn.MaxPool1d(2),
        )
        self.lstm = nn.LSTM(128, 64, num_layers=2, batch_first=True, dropout=0.2)
        self.fc = nn.Sequential(
            nn.Linear(64, 32), nn.ReLU(), nn.Dropout(0.2),
            nn.Linear(32, 1),
        )

    def forward(self, x):
        # x: (batch, seq, features) → CNN wants (batch, features, seq)
        x = x.permute(0, 2, 1)
        x = self.cnn(x)
        x = x.permute(0, 2, 1)
        lstm_out, _ = self.lstm(x)
        return self.fc(lstm_out[:, -1, :])
```

## Reinforcement Learning Trading Agent (DQN)

```python
import gymnasium as gym
from gymnasium import spaces
from stable_baselines3 import DQN, PPO, A2C

class TradingEnv(gym.Env):
    """Custom Gym environment for trading."""
    def __init__(self, df, feature_cols, initial_balance=10000,
                 commission=0.001, window_size=60):
        super().__init__()
        self.df = df
        self.features = df[feature_cols].values
        self.prices = df['close'].values
        self.initial_balance = initial_balance
        self.commission = commission
        self.window_size = window_size

        # Actions: 0=Hold, 1=Buy, 2=Sell
        self.action_space = spaces.Discrete(3)
        self.observation_space = spaces.Box(
            low=-np.inf, high=np.inf,
            shape=(window_size, len(feature_cols) + 3),  # features + position info
            dtype=np.float32
        )

    def reset(self, seed=None):
        self.balance = self.initial_balance
        self.position = 0  # Number of units held
        self.current_step = self.window_size
        self.total_pnl = 0
        self.trades = []
        return self._get_obs(), {}

    def _get_obs(self):
        window = self.features[self.current_step - self.window_size:self.current_step]
        position_info = np.full((self.window_size, 3), [
            self.position, self.balance / self.initial_balance,
            self.total_pnl / self.initial_balance
        ])
        return np.hstack([window, position_info]).astype(np.float32)

    def step(self, action):
        price = self.prices[self.current_step]
        reward = 0

        if action == 1 and self.position == 0:  # Buy
            self.position = self.balance * 0.95 / price
            cost = self.position * price * self.commission
            self.balance -= cost
            self.entry_price = price

        elif action == 2 and self.position > 0:  # Sell
            pnl = self.position * (price - self.entry_price)
            cost = self.position * price * self.commission
            self.balance += pnl - cost
            self.total_pnl += pnl - cost
            reward = pnl / self.initial_balance  # Normalized reward
            self.trades.append({'pnl': pnl - cost})
            self.position = 0

        self.current_step += 1
        done = self.current_step >= len(self.prices) - 1
        truncated = False

        # Penalize inaction slightly
        if action == 0:
            reward -= 0.0001

        return self._get_obs(), reward, done, truncated, {
            'balance': self.balance,
            'total_pnl': self.total_pnl,
            'trades': len(self.trades),
        }

# Train RL agent
env = TradingEnv(df, feature_cols)
model = PPO("MlpPolicy", env, verbose=1,
            learning_rate=3e-4, n_steps=2048,
            batch_size=64, n_epochs=10, gamma=0.99)
model.learn(total_timesteps=100000)
model.save("trading_ppo_agent")
```

## Multi-Step Prediction (Return Sequence)

```python
class MultiStepPredictor(nn.Module):
    """Predict next N candles simultaneously."""
    def __init__(self, input_size, hidden_size=128, pred_steps=5):
        super().__init__()
        self.encoder = nn.LSTM(input_size, hidden_size, 2, batch_first=True, dropout=0.2)
        self.decoder = nn.LSTM(hidden_size, hidden_size, 1, batch_first=True)
        self.fc = nn.Linear(hidden_size, 4)  # Open, High, Low, Close
        self.pred_steps = pred_steps

    def forward(self, x):
        _, (h, c) = self.encoder(x)
        outputs = []
        dec_input = h[-1].unsqueeze(1)
        h_dec = h[-1:]; c_dec = c[-1:]

        for _ in range(self.pred_steps):
            dec_out, (h_dec, c_dec) = self.decoder(dec_input, (h_dec, c_dec))
            pred = self.fc(dec_out.squeeze(1))
            outputs.append(pred)
            dec_input = dec_out

        return torch.stack(outputs, dim=1)  # (batch, pred_steps, 4)
```

## Model Architecture Selection Guide

| Model | Strength | Weakness | Best For |
|-------|----------|----------|----------|
| LSTM | Long-term memory | Slow training | Trend following |
| GRU | Fast, lightweight | Less capacity | Scalping signals |
| Transformer | Global attention, parallel | Needs more data | Multi-asset |
| CNN-LSTM | Pattern + sequence | Complex tuning | Chart pattern + trend |
| DQN/PPO (RL) | Learns strategy end-to-end | Reward shaping critical | Full system |

## Training Best Practices

- Normalize features with `StandardScaler` per walk-forward window
- Use causal masking (no data leakage from future)
- Learning rate warmup + cosine decay
- Gradient clipping (`max_norm=1.0`)
- Minimum 2000+ candles for training, 500+ for validation
- Ensemble LSTM + XGBoost for best real-world results
- For RL: shape reward carefully (Sharpe-based works best)
- Retrain models periodically as market regime changes
