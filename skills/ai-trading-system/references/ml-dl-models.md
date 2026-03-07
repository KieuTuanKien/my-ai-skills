# ML & DL Model Reference for Trading

## Model Selection Guide

| Model | Best For | Training Time | Inference | Interpretability |
|-------|---------|:------------:|:---------:|:---------------:|
| XGBoost | Tabular features, regime detection | Fast | Fast | High (SHAP) |
| LightGBM | Large datasets, fast iteration | Fastest | Fastest | High |
| CatBoost | Mixed features, no tuning | Medium | Fast | Medium |
| LSTM | Sequential patterns, trend | Slow | Medium | Low |
| Transformer | Long-range dependencies | Slowest | Medium | Medium (attention) |
| CNN-LSTM | Local patterns + trends | Slow | Medium | Low |
| DQN | Portfolio management | Very Slow | Fast | Low |
| PPO | Continuous action space | Very Slow | Fast | Low |

## Hyperparameter Tuning Guide

### XGBoost
```python
xgb_params = {
    'n_estimators': [300, 500, 800],
    'max_depth': [4, 6, 8],
    'learning_rate': [0.01, 0.05, 0.1],
    'subsample': [0.7, 0.8, 0.9],
    'colsample_bytree': [0.7, 0.8, 0.9],
    'reg_alpha': [0, 0.1, 1.0],
    'reg_lambda': [0.5, 1.0, 2.0],
    'min_child_weight': [1, 3, 5],
    'gamma': [0, 0.1, 0.3],
}
```

### LSTM Architecture Variants

```python
# Variant 1: Simple LSTM
LSTM(input_dim, 128, num_layers=2, dropout=0.3)

# Variant 2: Bidirectional LSTM + Attention (recommended)
BiLSTM(input_dim, 128, n_layers=3) + MultiheadAttention(256, 8)

# Variant 3: Stacked LSTM with skip connections
StackedLSTM(input_dim, [128, 64, 32]) + ResidualConnections
```

### Transformer Architecture

```python
# Recommended config for M15/H1 trading
TransformerTrader(
    input_dim=80,       # number of features
    d_model=128,        # embedding dimension
    nhead=8,            # attention heads
    n_layers=4,         # encoder layers
    seq_len=60,         # lookback window (60 bars)
    dropout=0.2,
)
```

## Training Best Practices

### Walk-Forward Validation (CRITICAL)

```
|------ Train ------|-- Val --|-- Test --|
|==================|========|==========|
                    |==================|========|==========|
                                       |==================|========|==========|

NEVER use random train/test split for time series!
```

```python
from sklearn.model_selection import TimeSeriesSplit

tscv = TimeSeriesSplit(n_splits=5, test_size=500)
for train_idx, test_idx in tscv.split(X):
    X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
    y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
```

### Class Imbalance Handling

```python
# Method 1: SMOTE for tabular
from imblearn.over_sampling import SMOTE
X_resampled, y_resampled = SMOTE().fit_resample(X_train, y_train)

# Method 2: Class weights
model = XGBClassifier(scale_pos_weight=len(y[y==0]) / len(y[y==1]))

# Method 3: Custom loss (for DL)
class FocalLoss(nn.Module):
    def __init__(self, gamma=2.0, alpha=0.25):
        super().__init__()
        self.gamma = gamma
        self.alpha = alpha

    def forward(self, pred, target):
        ce = nn.CrossEntropyLoss(reduction='none')(pred, target)
        pt = torch.exp(-ce)
        return (self.alpha * (1 - pt) ** self.gamma * ce).mean()
```

### Model Ensemble Strategies

```python
# Strategy 1: Weighted average (confidence-based)
final_pred = sum(w * model.predict_proba(X) for w, model in zip(weights, models))

# Strategy 2: Stacking (meta-learner)
meta_features = np.column_stack([m.predict_proba(X) for m in base_models])
meta_model = LogisticRegression().fit(meta_features, y)

# Strategy 3: Dynamic weighting (regime-aware)
weights = regime_weights[current_regime]
```

## Model Evaluation Metrics

### Trading-Specific Metrics

```python
def trading_metrics(predictions, actual_returns):
    """Calculate trading-specific metrics."""
    # Direction accuracy
    direction_acc = np.mean(np.sign(predictions) == np.sign(actual_returns))

    # Profit factor
    winners = actual_returns[predictions > 0]
    losers = actual_returns[predictions < 0]
    profit_factor = abs(winners.sum() / losers.sum()) if losers.sum() != 0 else np.inf

    # Expectancy
    win_rate = len(winners[winners > 0]) / len(predictions[predictions != 0])
    avg_win = winners[winners > 0].mean() if len(winners[winners > 0]) > 0 else 0
    avg_loss = abs(losers[losers < 0].mean()) if len(losers[losers < 0]) > 0 else 0
    expectancy = win_rate * avg_win - (1 - win_rate) * avg_loss

    return {
        'direction_accuracy': direction_acc,
        'profit_factor': profit_factor,
        'win_rate': win_rate,
        'avg_win': avg_win,
        'avg_loss': avg_loss,
        'expectancy': expectancy,
    }
```

## ONNX Export for Production

```python
import torch.onnx

# Export PyTorch model to ONNX
dummy_input = torch.randn(1, 60, 80)  # batch, seq_len, features
torch.onnx.export(
    model, dummy_input, "trading_model.onnx",
    input_names=['market_data'],
    output_names=['signal'],
    dynamic_axes={'market_data': {0: 'batch'}}
)

# Load ONNX for inference
import onnxruntime as ort
session = ort.InferenceSession("trading_model.onnx")
result = session.run(None, {'market_data': input_data.numpy()})
```
