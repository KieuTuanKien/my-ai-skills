# Tham chiếu – Thuật toán tối ưu & Điều khiển học trong Trading

---

## 1. Thuật toán tối ưu hóa

### 1.1 Hyperparameter & Bayesian

| Thuật toán | Thư viện | Đặc điểm |
|------------|----------|----------|
| **Optuna** | optuna | TPE sampler, pruning, multi-objective |
| **Hyperopt** | hyperopt | TPE, Random, Annealing |
| **Bayesian Opt** | scikit-optimize, BoTorch | Gaussian Process, acquisition function |
| **Grid/Random** | sklearn | Đơn giản, tốn thời gian |

**Trading**: Tối ưu ATR_mult, R:R, MACD params, stop/target, filters.

### 1.2 Evolutionary & Metaheuristic

| Thuật toán | Mô tả | Trading |
|------------|-------|---------|
| **Genetic Algorithm (GA)** | Selection, crossover, mutation | Rule discovery, strategy evolution |
| **Particle Swarm (PSO)** | Swarm intelligence | Portfolio weights |
| **Simulated Annealing** | Temperature schedule | Discrete optimization |
| **CMA-ES** | Covariance matrix adaptation | Continuous black-box |
| **Differential Evolution** | Vector differences | Multi-objective |

### 1.3 Gradient-based

| Thuật toán | Dùng cho |
|------------|---------|
| SGD, Adam, RMSprop | Neural network training |
| L-BFGS, Newton | Convex optimization |
| Second-order (Block-diagonal, K-FAC) | Deep hedging, derivatives |

### 1.4 Reinforcement Learning

| Phương pháp | Ứng dụng |
|-------------|----------|
| DQN, DDQN | Discrete action (buy/sell/hold) |
| PPO, A2C, SAC | Continuous action, policy gradient |
| Multi-agent RL | Market microstructure |
| Transfer learning | Adapt strategy across markets |

### 1.5 Tránh overfit

- **Walk-forward**: Train trên [0:T], test trên [T:T+h], roll
- **Out-of-sample**: Giữ 20–30% data không train
- **Cross-validation**: K-fold theo thời gian (không shuffle)
- **Monte Carlo**: Shuffle trades để đánh giá ổn định

---

## 2. Điều khiển học

### 2.1 PID Controller

```
u(t) = Kp·e(t) + Ki·∫e(τ)dτ + Kd·de/dt
```

- **P**: Phản ứng tỷ lệ (sai lệch)
- **I**: Loại bỏ sai lệch dài hạn
- **D**: Giảm overshoot

**Trading**: So sánh portfolio vs benchmark, điều chỉnh allocation.

### 2.2 Model Predictive Control (MPC)

- Dự đoán trajectory qua horizon
- Tối ưu cost function (execution cost, tracking error)
- Ràng buộc: turnover, position limits, transaction cost

**Ứng dụng**: Optimal execution (TWAP/VWAP), portfolio rebalancing.

### 2.3 Linear Quadratic Regulator (LQR)

- State-space: ẋ = Ax + Bu
- Cost: J = ∫(x'Qx + u'Ru)dt
- Giải Riccati → gain K tối ưu

### 2.4 State-space & System ID

- **Mô hình**: ẋ = Ax + Bu, y = Cx + Du
- **System ID**: Ước lượng A,B,C,D từ input-output (ARMAX, subspace)
- **Ứng dụng**: Mô hình hóa dynamics thị trường, dự báo

---

## 3. Mô hình hóa đối tượng

### 3.1 Mô hình thống kê

| Mô hình | Dùng cho |
|---------|----------|
| ARIMA | Chuỗi thời gian giá |
| GARCH | Volatility clustering |
| VAR | Đa biến, spillover |
| Markov switching | Regime change |

### 3.2 Mô hình ML

| Mô hình | Đặc điểm |
|---------|----------|
| LSTM, GRU | Sequential, long memory |
| Transformer | Attention, multi-horizon |
| XGBoost, LightGBM | Tabular, feature-based |
| Ensemble | Kết hợp nhiều model |

### 3.3 Mô hình vật lý/kinh tế

- Ornstein-Uhlenbeck (mean reversion)
- Black-Scholes (options)
- Market impact models (Almgren-Chriss)

---

## 4. Công cụ Python

| Mục đích | Thư viện |
|----------|----------|
| Optimization | optuna, scipy.optimize, nevergrad |
| RL | stable-baselines3, rllib |
| Control | python-control, do-mpc |
| Backtest | backtrader, vectorbt, zipline |
