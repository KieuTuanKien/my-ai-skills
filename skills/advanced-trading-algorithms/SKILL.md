---
name: advanced-trading-algorithms
description: Advanced algorithmic trading methods - Fuzzy Logic trading systems, adaptive control strategies, Genetic Algorithms for strategy optimization, Particle Swarm Optimization (PSO), Bayesian optimization, Hidden Markov Models for regime detection, and neural-fuzzy hybrid systems (ANFIS). Use when building self-adapting strategies, optimizing trading parameters with evolutionary algorithms, implementing fuzzy decision systems, or detecting market regime changes.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Fuzzy Logic, Adaptive Control, Genetic Algorithm, PSO, Bayesian, HMM, ANFIS, Regime Detection, Optimization, Evolutionary]
dependencies: [numpy, pandas, scipy, scikit-fuzzy, deap, hmmlearn, scikit-learn, optuna]
---

# Advanced Trading Algorithms

## When to Use

- Building fuzzy logic trading decision systems
- Self-adapting strategies that adjust to market conditions
- Optimizing strategy parameters with genetic algorithms/PSO
- Detecting market regime changes (trending/ranging/volatile)
- Neural-fuzzy hybrid (ANFIS) for nonlinear decision boundaries
- Combining multiple signals with intelligent weighting

## Installation

```bash
pip install scikit-fuzzy deap hmmlearn optuna pandas numpy scipy
```

---

## 1. Fuzzy Logic Trading System

```python
import numpy as np
import skfuzzy as fuzz
from skfuzzy import control as ctrl

class FuzzyTradingSystem:
    """Fuzzy inference system for trade decisions."""

    def __init__(self):
        # --- Define fuzzy variables ---
        self.rsi = ctrl.Antecedent(np.arange(0, 101, 1), 'rsi')
        self.macd = ctrl.Antecedent(np.arange(-5, 5, 0.1), 'macd')
        self.volume = ctrl.Antecedent(np.arange(0, 5, 0.1), 'volume_ratio')
        self.trend = ctrl.Antecedent(np.arange(-1, 1.01, 0.01), 'trend')
        self.signal = ctrl.Consequent(np.arange(-100, 101, 1), 'signal')

        # --- RSI membership functions ---
        self.rsi['oversold'] = fuzz.trapmf(self.rsi.universe, [0, 0, 20, 35])
        self.rsi['neutral'] = fuzz.trimf(self.rsi.universe, [30, 50, 70])
        self.rsi['overbought'] = fuzz.trapmf(self.rsi.universe, [65, 80, 100, 100])

        # --- MACD membership functions ---
        self.macd['negative'] = fuzz.trapmf(self.macd.universe, [-5, -5, -1, 0])
        self.macd['zero'] = fuzz.trimf(self.macd.universe, [-0.5, 0, 0.5])
        self.macd['positive'] = fuzz.trapmf(self.macd.universe, [0, 1, 5, 5])

        # --- Volume ratio ---
        self.volume['low'] = fuzz.trapmf(self.volume.universe, [0, 0, 0.5, 0.8])
        self.volume['normal'] = fuzz.trimf(self.volume.universe, [0.7, 1.0, 1.5])
        self.volume['high'] = fuzz.trapmf(self.volume.universe, [1.3, 2.0, 5, 5])

        # --- Trend (EMA slope normalized) ---
        self.trend['bearish'] = fuzz.trapmf(self.trend.universe, [-1, -1, -0.3, 0])
        self.trend['flat'] = fuzz.trimf(self.trend.universe, [-0.2, 0, 0.2])
        self.trend['bullish'] = fuzz.trapmf(self.trend.universe, [0, 0.3, 1, 1])

        # --- Output signal (-100 strong sell to +100 strong buy) ---
        self.signal['strong_sell'] = fuzz.trapmf(self.signal.universe, [-100, -100, -70, -40])
        self.signal['sell'] = fuzz.trimf(self.signal.universe, [-60, -35, -10])
        self.signal['hold'] = fuzz.trimf(self.signal.universe, [-20, 0, 20])
        self.signal['buy'] = fuzz.trimf(self.signal.universe, [10, 35, 60])
        self.signal['strong_buy'] = fuzz.trapmf(self.signal.universe, [40, 70, 100, 100])

        # --- Fuzzy Rules ---
        self.rules = [
            # Strong buy conditions
            ctrl.Rule(self.rsi['oversold'] & self.macd['positive'] & self.trend['bullish'],
                      self.signal['strong_buy']),
            ctrl.Rule(self.rsi['oversold'] & self.volume['high'] & self.trend['bullish'],
                      self.signal['strong_buy']),

            # Buy conditions
            ctrl.Rule(self.rsi['oversold'] & self.macd['zero'], self.signal['buy']),
            ctrl.Rule(self.rsi['neutral'] & self.macd['positive'] & self.trend['bullish'],
                      self.signal['buy']),
            ctrl.Rule(self.rsi['neutral'] & self.volume['high'] & self.trend['bullish'],
                      self.signal['buy']),

            # Hold conditions
            ctrl.Rule(self.rsi['neutral'] & self.macd['zero'], self.signal['hold']),
            ctrl.Rule(self.trend['flat'] & self.volume['low'], self.signal['hold']),

            # Sell conditions
            ctrl.Rule(self.rsi['overbought'] & self.macd['zero'], self.signal['sell']),
            ctrl.Rule(self.rsi['neutral'] & self.macd['negative'] & self.trend['bearish'],
                      self.signal['sell']),

            # Strong sell conditions
            ctrl.Rule(self.rsi['overbought'] & self.macd['negative'] & self.trend['bearish'],
                      self.signal['strong_sell']),
            ctrl.Rule(self.rsi['overbought'] & self.volume['high'] & self.trend['bearish'],
                      self.signal['strong_sell']),
        ]

        self.system = ctrl.ControlSystem(self.rules)
        self.sim = ctrl.ControlSystemSimulation(self.system)

    def evaluate(self, rsi: float, macd: float, volume_ratio: float,
                 trend_slope: float) -> dict:
        self.sim.input['rsi'] = np.clip(rsi, 0, 100)
        self.sim.input['macd'] = np.clip(macd, -5, 5)
        self.sim.input['volume_ratio'] = np.clip(volume_ratio, 0, 5)
        self.sim.input['trend'] = np.clip(trend_slope, -1, 1)
        self.sim.compute()

        score = self.sim.output['signal']
        if score > 50: action = 'STRONG_BUY'
        elif score > 20: action = 'BUY'
        elif score > -20: action = 'HOLD'
        elif score > -50: action = 'SELL'
        else: action = 'STRONG_SELL'

        return {'signal': action, 'score': round(score, 2), 'confidence': abs(score) / 100}

# Usage
fuzzy = FuzzyTradingSystem()
result = fuzzy.evaluate(rsi=28, macd=0.5, volume_ratio=2.1, trend_slope=0.4)
print(result)  # {'signal': 'STRONG_BUY', 'score': 72.5, 'confidence': 0.725}
```

---

## 2. Adaptive Control Strategy

```python
class AdaptiveStrategy:
    """Self-adapting strategy that adjusts parameters based on market regime."""

    def __init__(self, base_params: dict):
        self.params = base_params.copy()
        self.performance_window = []
        self.regime = 'unknown'
        self.adaptation_rate = 0.1

    def detect_regime(self, df: pd.DataFrame) -> str:
        """Classify current market regime."""
        returns = df['close'].pct_change().dropna()
        volatility = returns.rolling(20).std().iloc[-1]
        adx = df['adx'].iloc[-1] if 'adx' in df.columns else 25
        trend = (df['close'].iloc[-1] - df['close'].iloc[-50]) / df['close'].iloc[-50]

        if adx > 30 and abs(trend) > 0.03:
            self.regime = 'trending'
        elif volatility > returns.std() * 1.5:
            self.regime = 'volatile'
        else:
            self.regime = 'ranging'

        return self.regime

    def adapt_parameters(self, recent_pnl: list[float]):
        """Dynamically adjust parameters based on performance."""
        self.performance_window.extend(recent_pnl)
        if len(self.performance_window) > 50:
            self.performance_window = self.performance_window[-50:]

        win_rate = sum(1 for p in self.performance_window if p > 0) / len(self.performance_window)

        # Regime-based adaptation
        if self.regime == 'trending':
            self.params['fast_ma'] = max(5, self.params['fast_ma'] - 1)
            self.params['atr_sl_mult'] = min(3.0, self.params['atr_sl_mult'] + 0.1)
            self.params['tp_ratio'] = 3.0  # Let profits run
        elif self.regime == 'ranging':
            self.params['fast_ma'] = min(20, self.params['fast_ma'] + 2)
            self.params['atr_sl_mult'] = max(1.0, self.params['atr_sl_mult'] - 0.1)
            self.params['tp_ratio'] = 1.5  # Quick targets
        elif self.regime == 'volatile':
            self.params['atr_sl_mult'] = min(4.0, self.params['atr_sl_mult'] + 0.3)
            self.params['risk_pct'] = max(0.005, self.params['risk_pct'] * 0.8)

        # Performance-based adaptation
        if win_rate < 0.4:
            self.params['risk_pct'] *= 0.9  # Reduce risk
            self.params['confidence_threshold'] += 0.05
        elif win_rate > 0.6:
            self.params['risk_pct'] = min(0.02, self.params['risk_pct'] * 1.05)

        return self.params

base = {
    'fast_ma': 9, 'slow_ma': 21, 'atr_sl_mult': 2.0,
    'tp_ratio': 2.5, 'risk_pct': 0.01, 'confidence_threshold': 0.6,
}
adaptive = AdaptiveStrategy(base)
```

---

## 3. Genetic Algorithm Strategy Optimization

```python
from deap import base, creator, tools, algorithms
import random

def optimize_with_genetic_algorithm(df, strategy_fn, param_ranges,
                                     population_size=50, generations=100):
    """Evolve optimal strategy parameters using genetic algorithm."""

    creator.create("FitnessMax", base.Fitness, weights=(1.0,))
    creator.create("Individual", list, fitness=creator.FitnessMax)

    toolbox = base.Toolbox()

    # Define gene ranges
    for i, (name, (low, high)) in enumerate(param_ranges.items()):
        if isinstance(low, int):
            toolbox.register(f"attr_{i}", random.randint, low, high)
        else:
            toolbox.register(f"attr_{i}", random.uniform, low, high)

    def create_individual():
        return creator.Individual([
            getattr(toolbox, f"attr_{i}")()
            for i in range(len(param_ranges))
        ])

    toolbox.register("individual", create_individual)
    toolbox.register("population", tools.initRepeat, list, toolbox.individual)

    def evaluate(individual):
        params = dict(zip(param_ranges.keys(), individual))
        try:
            result = strategy_fn(df, **params)
            # Fitness = Sharpe ratio * sqrt(number of trades) to avoid overfitting
            fitness = result['sharpe'] * np.sqrt(max(result['trades'], 1)) / 10
            if result['max_drawdown'] > 25:  # Penalty for high drawdown
                fitness *= 0.5
            return (fitness,)
        except Exception:
            return (-100,)

    toolbox.register("evaluate", evaluate)
    toolbox.register("mate", tools.cxBlend, alpha=0.5)
    toolbox.register("mutate", tools.mutGaussian, mu=0, sigma=1, indpb=0.2)
    toolbox.register("select", tools.selTournament, tournsize=3)

    pop = toolbox.population(n=population_size)
    hof = tools.HallOfFame(5)  # Keep top 5

    stats = tools.Statistics(lambda ind: ind.fitness.values)
    stats.register("max", np.max)
    stats.register("avg", np.mean)

    pop, log = algorithms.eaSimple(pop, toolbox, cxpb=0.7, mutpb=0.2,
                                    ngen=generations, stats=stats,
                                    halloffame=hof, verbose=True)

    best = hof[0]
    best_params = dict(zip(param_ranges.keys(), best))
    return best_params, best.fitness.values[0], log

# Define parameter search space
param_ranges = {
    'fast_ma': (3, 30),
    'slow_ma': (15, 100),
    'rsi_oversold': (15, 40),
    'rsi_overbought': (60, 85),
    'atr_sl_mult': (1.0, 4.0),
    'atr_tp_mult': (1.5, 6.0),
}
```

---

## 4. Particle Swarm Optimization (PSO)

```python
class PSO:
    """Particle Swarm Optimization for strategy parameters."""

    def __init__(self, objective_fn, bounds, n_particles=30, n_iterations=100,
                 w=0.7, c1=1.5, c2=1.5):
        self.obj = objective_fn
        self.bounds = np.array(bounds)
        self.n_particles = n_particles
        self.n_iter = n_iterations
        self.w = w    # Inertia weight
        self.c1 = c1  # Cognitive (personal best)
        self.c2 = c2  # Social (global best)
        self.dim = len(bounds)

    def optimize(self):
        # Initialize particles
        positions = np.random.uniform(
            self.bounds[:, 0], self.bounds[:, 1],
            (self.n_particles, self.dim)
        )
        velocities = np.random.uniform(-1, 1, (self.n_particles, self.dim))

        personal_best_pos = positions.copy()
        personal_best_val = np.array([self.obj(p) for p in positions])
        global_best_idx = np.argmax(personal_best_val)
        global_best_pos = personal_best_pos[global_best_idx].copy()
        global_best_val = personal_best_val[global_best_idx]

        history = []

        for it in range(self.n_iter):
            for i in range(self.n_particles):
                r1, r2 = np.random.rand(self.dim), np.random.rand(self.dim)

                velocities[i] = (self.w * velocities[i] +
                                 self.c1 * r1 * (personal_best_pos[i] - positions[i]) +
                                 self.c2 * r2 * (global_best_pos - positions[i]))

                positions[i] += velocities[i]
                positions[i] = np.clip(positions[i], self.bounds[:, 0], self.bounds[:, 1])

                val = self.obj(positions[i])
                if val > personal_best_val[i]:
                    personal_best_val[i] = val
                    personal_best_pos[i] = positions[i].copy()
                    if val > global_best_val:
                        global_best_val = val
                        global_best_pos = positions[i].copy()

            history.append(global_best_val)
            # Adaptive inertia decay
            self.w *= 0.99

        return global_best_pos, global_best_val, history

# Usage
bounds = [(3, 30), (15, 100), (1.0, 4.0), (1.5, 6.0)]  # fast_ma, slow_ma, sl_mult, tp_mult

def fitness(params):
    fast, slow, sl, tp = int(params[0]), int(params[1]), params[2], params[3]
    result = backtest_strategy(df, fast_ma=fast, slow_ma=slow, sl_mult=sl, tp_mult=tp)
    return result['sharpe_ratio']

pso = PSO(fitness, bounds, n_particles=40, n_iterations=80)
best_params, best_fitness, history = pso.optimize()
```

---

## 5. Hidden Markov Model (Regime Detection)

```python
from hmmlearn.hmm import GaussianHMM

class MarketRegimeHMM:
    """Detect market regimes (bull/bear/sideways) using Hidden Markov Model."""

    def __init__(self, n_regimes: int = 3):
        self.n_regimes = n_regimes
        self.model = GaussianHMM(
            n_components=n_regimes,
            covariance_type="full",
            n_iter=200,
            random_state=42
        )

    def fit(self, df: pd.DataFrame):
        features = np.column_stack([
            df['close'].pct_change().fillna(0),
            df['close'].pct_change().rolling(5).std().fillna(0),
            df['volume'].pct_change().fillna(0),
        ])
        self.model.fit(features)
        self.regimes = self.model.predict(features)

        # Label regimes by return characteristics
        regime_returns = {}
        for r in range(self.n_regimes):
            mask = self.regimes == r
            regime_returns[r] = features[mask, 0].mean()

        sorted_regimes = sorted(regime_returns, key=regime_returns.get)
        self.regime_map = {
            sorted_regimes[0]: 'bear',
            sorted_regimes[1]: 'sideways',
            sorted_regimes[2]: 'bull',
        }

        return self

    def current_regime(self) -> str:
        return self.regime_map.get(self.regimes[-1], 'unknown')

    def transition_probabilities(self) -> pd.DataFrame:
        return pd.DataFrame(
            self.model.transmat_,
            columns=[self.regime_map[i] for i in range(self.n_regimes)],
            index=[self.regime_map[i] for i in range(self.n_regimes)]
        ).round(3)

hmm = MarketRegimeHMM(n_regimes=3)
hmm.fit(df)
print(f"Current regime: {hmm.current_regime()}")
print(hmm.transition_probabilities())
```

---

## 6. ANFIS (Adaptive Neuro-Fuzzy Inference)

```python
import torch
import torch.nn as nn

class ANFIS(nn.Module):
    """Adaptive Neuro-Fuzzy Inference System for trading."""

    def __init__(self, n_inputs=4, n_mfs=3):
        super().__init__()
        self.n_inputs = n_inputs
        self.n_mfs = n_mfs
        self.n_rules = n_mfs ** n_inputs

        # Layer 1: Fuzzy membership (Gaussian)
        self.centers = nn.Parameter(torch.randn(n_inputs, n_mfs))
        self.widths = nn.Parameter(torch.ones(n_inputs, n_mfs) * 0.5)

        # Layer 4: Consequent parameters (Takagi-Sugeno)
        self.consequent = nn.Linear(n_inputs + 1, 1)

    def forward(self, x):
        batch_size = x.size(0)

        # Layer 1: Fuzzification (Gaussian MFs)
        memberships = []
        for i in range(self.n_inputs):
            xi = x[:, i:i+1]
            mu = torch.exp(-0.5 * ((xi - self.centers[i]) / self.widths[i]) ** 2)
            memberships.append(mu)

        # Layer 2: Rule firing strengths (T-norm = product)
        # Simplified: use strongest membership per input
        rule_strengths = memberships[0]
        for i in range(1, self.n_inputs):
            rule_strengths = rule_strengths * memberships[i][:, :1]

        # Layer 3: Normalize
        rule_sum = rule_strengths.sum(dim=1, keepdim=True) + 1e-10
        normalized = rule_strengths / rule_sum

        # Layer 4: Consequent (first-order Takagi-Sugeno)
        x_aug = torch.cat([x, torch.ones(batch_size, 1)], dim=1)
        output = self.consequent(x_aug)

        # Layer 5: Weighted sum
        return (normalized[:, 0:1] * output).sum(dim=1)

def train_anfis(X_train, y_train, epochs=200, lr=0.01):
    model = ANFIS(n_inputs=X_train.shape[1], n_mfs=3)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    criterion = nn.MSELoss()

    X = torch.FloatTensor(X_train)
    y = torch.FloatTensor(y_train)

    for epoch in range(epochs):
        optimizer.zero_grad()
        pred = model(X)
        loss = criterion(pred, y)
        loss.backward()
        optimizer.step()

    return model
```

## Algorithm Selection Guide

| Algorithm | Best For | Computational Cost | Adaptability |
|-----------|----------|-------------------|-------------|
| Fuzzy Logic | Interpretable decisions, multi-indicator fusion | Low | Manual rule tuning |
| Adaptive Control | Changing market regimes | Low | Self-adjusting |
| Genetic Algorithm | Strategy parameter optimization | High | Offline optimization |
| PSO | Continuous parameter search | Medium | Offline optimization |
| HMM | Regime detection (bull/bear/range) | Medium | Probabilistic |
| ANFIS | Non-linear decision + interpretability | Medium | Self-learning |
| Bayesian (Optuna) | Efficient hyperparameter search | Medium | Sequential |

## Combined System Architecture

```
Market Data → [HMM Regime Detection] → regime label
                                          ↓
         → [Feature Engineering] → [Fuzzy Logic System] → signal score
                                          ↓
         → [ANFIS / Neural Net] → confidence → [Adaptive Controller]
                                                      ↓
                                              [Position Sizing] → ORDER
                                                      ↑
                                [GA/PSO] ← periodic parameter re-optimization
```
