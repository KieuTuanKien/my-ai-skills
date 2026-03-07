# Optimization Algorithms for Trading Strategy

## Algorithm Comparison

| Algorithm | Speed | Global Optima | Parallelizable | Best For |
|-----------|:-----:|:-------------:|:--------------:|----------|
| Grid Search | Slowest | Exhaustive | Yes | Few params (<4) |
| Bayesian (Optuna) | Fast | Good | Yes | Many params, fast eval |
| Genetic Algorithm | Medium | Excellent | Yes | Complex param spaces |
| PSO | Fast | Good | Yes | Continuous params |
| Differential Evolution | Medium | Excellent | Partial | Noisy landscapes |
| CMA-ES | Fast | Excellent | Partial | Continuous, smooth |

## Genetic Algorithm (DEAP) — Detailed

### Chromosome Design for Trading

```python
# Each individual = strategy parameter set
chromosome = [
    rsi_period,          # int: 6-30
    rsi_oversold,        # float: 15-35
    rsi_overbought,      # float: 65-85
    ma_fast,             # int: 5-30
    ma_slow,             # int: 20-200
    atr_multiplier,      # float: 1.0-4.0
    stop_loss_atr,       # float: 1.0-3.0
    take_profit_atr,     # float: 1.5-5.0
    confidence_threshold,# float: 0.5-0.9
    position_size_pct,   # float: 0.5-5.0
    entry_filter_adx,    # float: 15-40
    exit_rsi_threshold,  # float: 40-60
]
```

### Multi-Objective Optimization (NSGA-II)

```python
from deap import algorithms

# Optimize for multiple objectives simultaneously
creator.create("FitnessMulti", base.Fitness, weights=(1.0, -1.0, 1.0))
# Maximize Sharpe, Minimize Drawdown, Maximize Win Rate

def evaluate_multi(individual):
    result = backtest(individual)
    return (result['sharpe'], result['max_drawdown'], result['win_rate'])

# NSGA-II gives Pareto-optimal front
pop, log = algorithms.eaMuPlusLambda(
    pop, toolbox, mu=100, lambda_=200,
    cxpb=0.7, mutpb=0.2, ngen=50,
    halloffame=hof
)
```

### Avoid Overfitting in Optimization

```python
# 1. Train/Test split BEFORE optimization
train_data = data[:int(0.7 * len(data))]
test_data = data[int(0.7 * len(data)):]

# 2. Optimize on train, validate on test
def evaluate_with_oos(individual):
    in_sample = backtest(individual, train_data)
    out_sample = backtest(individual, test_data)

    # Penalty for IS/OOS divergence
    divergence = abs(in_sample['sharpe'] - out_sample['sharpe'])
    fitness = out_sample['sharpe'] - divergence * 0.5
    return (fitness,)

# 3. Parameter stability check
# Good params should work in neighboring values too
def stability_penalty(individual, noise_std=0.05):
    base_score = backtest(individual)['sharpe']
    noisy_scores = []
    for _ in range(10):
        noisy = [p + np.random.normal(0, noise_std * abs(p)) for p in individual]
        noisy_scores.append(backtest(noisy)['sharpe'])
    stability = np.std(noisy_scores) / abs(base_score) if base_score != 0 else 1
    return base_score * (1 - stability)
```

## Bayesian Optimization (Optuna) — Detailed

### Advanced Optuna Usage

```python
import optuna
from optuna.pruners import HyperbandPruner
from optuna.samplers import TPESampler

def objective(trial):
    params = {
        'rsi_period': trial.suggest_int('rsi_period', 6, 30),
        'ma_fast': trial.suggest_int('ma_fast', 5, 30),
        'ma_slow': trial.suggest_int('ma_slow', 20, 200),
        'atr_mult': trial.suggest_float('atr_mult', 1.0, 4.0),
        'sl_mult': trial.suggest_float('sl_mult', 1.0, 3.0),
        'tp_mult': trial.suggest_float('tp_mult', 1.5, 5.0),
        'confidence': trial.suggest_float('confidence', 0.5, 0.9),
    }

    # Constraint: ma_slow > ma_fast
    if params['ma_slow'] <= params['ma_fast'] * 2:
        return float('-inf')

    # Walk-forward backtest
    results = walk_forward_backtest(params, n_folds=5)

    # Intermediate reporting for pruning
    for fold_idx, fold_result in enumerate(results):
        trial.report(fold_result['sharpe'], fold_idx)
        if trial.should_prune():
            raise optuna.TrialPruned()

    return np.mean([r['sharpe'] for r in results])

study = optuna.create_study(
    direction='maximize',
    sampler=TPESampler(seed=42, n_startup_trials=30),
    pruner=HyperbandPruner(min_resource=1, max_resource=5)
)
study.optimize(objective, n_trials=500, n_jobs=4)

# Visualization
optuna.visualization.plot_optimization_history(study)
optuna.visualization.plot_param_importances(study)
optuna.visualization.plot_parallel_coordinate(study)
```

## PSO — Detailed

### Adaptive PSO (Inertia Weight Decay)

```python
def adaptive_pso(objective, bounds, n_particles=50, n_iterations=200):
    n_dims = len(bounds)
    lo = np.array([b[0] for b in bounds])
    hi = np.array([b[1] for b in bounds])

    positions = np.random.uniform(lo, hi, (n_particles, n_dims))
    velocities = np.zeros((n_particles, n_dims))
    p_best = positions.copy()
    p_best_scores = np.full(n_particles, -np.inf)
    g_best = positions[0].copy()
    g_best_score = -np.inf

    w_start, w_end = 0.9, 0.4  # inertia decay
    c1, c2 = 2.0, 2.0

    for t in range(n_iterations):
        w = w_start - (w_start - w_end) * t / n_iterations

        for i in range(n_particles):
            score = objective(positions[i])
            if score > p_best_scores[i]:
                p_best_scores[i] = score
                p_best[i] = positions[i].copy()
            if score > g_best_score:
                g_best_score = score
                g_best = positions[i].copy()

        r1 = np.random.random((n_particles, n_dims))
        r2 = np.random.random((n_particles, n_dims))
        velocities = (w * velocities +
                     c1 * r1 * (p_best - positions) +
                     c2 * r2 * (g_best - positions))
        positions = np.clip(positions + velocities, lo, hi)

    return g_best, g_best_score
```

## Backtesting Framework for Optimization

```python
def walk_forward_backtest(params, data, n_folds=5):
    """Proper walk-forward backtest for optimization fitness."""
    fold_size = len(data) // (n_folds + 1)
    results = []

    for i in range(n_folds):
        train_end = (i + 1) * fold_size + fold_size
        test_start = train_end
        test_end = test_start + fold_size

        train = data[:train_end]
        test = data[test_start:test_end]

        # Train model on train, evaluate on test
        model = train_strategy(params, train)
        signals = model.predict(test)
        result = evaluate_performance(signals, test)
        results.append(result)

    return {
        'sharpe': np.mean([r['sharpe'] for r in results]),
        'max_drawdown': np.max([r['max_drawdown'] for r in results]),
        'win_rate': np.mean([r['win_rate'] for r in results]),
        'profit_factor': np.mean([r['profit_factor'] for r in results]),
        'stability': 1 - np.std([r['sharpe'] for r in results]) /
                     (abs(np.mean([r['sharpe'] for r in results])) + 1e-8),
    }
```
