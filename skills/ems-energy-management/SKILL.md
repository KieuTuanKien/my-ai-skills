---
name: ems-energy-management
description: Energy Management System (EMS) for PV+BESS+Grid optimization - dispatch algorithms (rule-based, linear programming, RL-based), peak shaving, load scheduling, self-consumption maximization, time-of-use arbitrage, demand response, and real-time power flow control. Covers Modbus/MQTT integration with inverters and meters, SCADA dashboard, and forecasting (solar/load). Use when designing EMS algorithms, optimizing energy dispatch, implementing demand response, or building microgrid controllers.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [EMS, Energy Management, Dispatch, Peak Shaving, Load Scheduling, PV, BESS, Grid, Optimization, Microgrid]
dependencies: [numpy, pandas, scipy, cvxpy, matplotlib, paho-mqtt, pymodbus]
---

# Energy Management System (EMS)

## When to Use

- Designing EMS algorithms for PV + BESS + Grid systems
- Optimizing energy dispatch (minimize cost, maximize self-consumption)
- Peak shaving and demand charge reduction
- Time-of-use (TOU) electricity arbitrage
- Load scheduling and demand response
- Real-time power flow control
- Solar and load forecasting for predictive dispatch

## EMS Architecture

```
┌─────────────────────────────────────────────────┐
│                    EMS CORE                      │
│  ┌─────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │Forecaster│ │Optimizer │ │ Dispatch Engine  │  │
│  │(PV/Load) │ │(LP/MILP) │ │ (Real-time ctrl)│  │
│  └────┬─────┘ └────┬─────┘ └────────┬─────────┘  │
│       └─────────────┼────────────────┘            │
│                     ↓                             │
│            ┌────────────────┐                     │
│            │  SCADA / HMI   │                     │
│            └────────────────┘                     │
└──────────┬──────────┬──────────┬─────────────────┘
           ↓          ↓          ↓
    ┌──────────┐ ┌─────────┐ ┌────────┐
    │PV Inverter│ │  BESS   │ │ Meter  │
    │(Modbus)   │ │(Modbus) │ │(Modbus)│
    └──────────┘ └─────────┘ └────────┘
```

## Rule-Based EMS (Simple, Reliable)

```python
from enum import Enum
from dataclasses import dataclass

class EnergySource(Enum):
    PV = "pv"
    BESS = "bess"
    GRID = "grid"

@dataclass
class SystemState:
    pv_power_kw: float
    load_kw: float
    grid_power_kw: float
    bess_power_kw: float   # Positive = discharge, Negative = charge
    bess_soc: float        # 0.0 - 1.0
    bess_capacity_kwh: float
    grid_limit_kw: float
    electricity_price: float  # $/kWh

@dataclass
class DispatchCommand:
    pv_curtail_kw: float
    bess_command_kw: float  # Positive = discharge, Negative = charge
    grid_import_kw: float
    grid_export_kw: float
    mode: str

class RuleBasedEMS:
    """Rule-based Energy Management System."""

    def __init__(self, config: dict):
        self.soc_min = config.get('soc_min', 0.10)
        self.soc_max = config.get('soc_max', 0.95)
        self.soc_reserve = config.get('soc_reserve', 0.20)  # Backup reserve
        self.grid_export_limit = config.get('grid_export_limit', 0)  # kW (0 = no export)
        self.peak_shave_target = config.get('peak_shave_target', None)
        self.tou_schedule = config.get('tou_schedule', {})
        self.bess_max_charge_kw = config.get('bess_max_charge_kw', 100)
        self.bess_max_discharge_kw = config.get('bess_max_discharge_kw', 100)

    def dispatch(self, state: SystemState, hour: int) -> DispatchCommand:
        """Main dispatch logic - called every control cycle (1-5 min)."""
        pv = state.pv_power_kw
        load = state.load_kw
        soc = state.bess_soc
        net_load = load - pv  # Positive = deficit, Negative = excess PV

        # Determine TOU period
        tou = self._get_tou_period(hour)

        # === PRIORITY 1: Self-consumption (use PV first) ===
        if net_load <= 0:  # Excess PV
            excess = abs(net_load)
            bess_cmd = 0
            grid_export = 0

            # Charge BESS with excess
            if soc < self.soc_max:
                charge = min(excess, self.bess_max_charge_kw,
                            (self.soc_max - soc) * state.bess_capacity_kwh)
                bess_cmd = -charge  # Negative = charging
                excess -= charge

            # Export remaining (if allowed)
            if excess > 0 and self.grid_export_limit > 0:
                grid_export = min(excess, self.grid_export_limit)
                excess -= grid_export

            # Curtail if still excess
            curtail = excess

            return DispatchCommand(curtail, bess_cmd, 0, grid_export,
                                   'SELF_CONSUMPTION')

        # === PRIORITY 2: Peak Shaving ===
        if self.peak_shave_target and net_load > self.peak_shave_target:
            shave_amount = net_load - self.peak_shave_target
            if soc > self.soc_reserve:
                discharge = min(shave_amount, self.bess_max_discharge_kw,
                               (soc - self.soc_reserve) * state.bess_capacity_kwh)
                grid_import = net_load - discharge
                return DispatchCommand(0, discharge, grid_import, 0,
                                       'PEAK_SHAVING')

        # === PRIORITY 3: TOU Arbitrage ===
        if tou == 'off_peak' and soc < self.soc_max:
            # Charge from grid during off-peak
            charge = min(self.bess_max_charge_kw,
                        (self.soc_max - soc) * state.bess_capacity_kwh)
            grid_import = net_load + charge
            return DispatchCommand(0, -charge, grid_import, 0,
                                   'TOU_CHARGING')

        if tou == 'peak' and soc > self.soc_reserve:
            # Discharge during peak
            discharge = min(net_load, self.bess_max_discharge_kw,
                           (soc - self.soc_reserve) * state.bess_capacity_kwh)
            grid_import = max(0, net_load - discharge)
            return DispatchCommand(0, discharge, grid_import, 0,
                                   'TOU_DISCHARGE')

        # === DEFAULT: Grid supplies deficit ===
        return DispatchCommand(0, 0, net_load, 0, 'GRID_SUPPLY')

    def _get_tou_period(self, hour: int) -> str:
        """Determine Time-of-Use period."""
        schedule = self.tou_schedule or {
            'off_peak': list(range(22, 24)) + list(range(0, 6)),
            'mid_peak': list(range(6, 9)) + list(range(12, 17)) + list(range(21, 22)),
            'peak': list(range(9, 12)) + list(range(17, 21)),
        }
        for period, hours in schedule.items():
            if hour in hours:
                return period
        return 'mid_peak'

# Configuration for 1MWp PV + 500kWh BESS
config = {
    'soc_min': 0.10,
    'soc_max': 0.95,
    'soc_reserve': 0.20,
    'grid_export_limit': 0,  # Zero export (Vietnam regulation)
    'peak_shave_target': 300,  # kW
    'bess_max_charge_kw': 100,
    'bess_max_discharge_kw': 100,
    'tou_schedule': {
        'off_peak': list(range(22, 24)) + list(range(0, 4)),
        'standard': list(range(4, 9)) + list(range(12, 17)) + list(range(21, 22)),
        'peak': list(range(9, 12)) + list(range(17, 21)),
    },
}
ems = RuleBasedEMS(config)
```

## Optimization-Based EMS (Linear Programming)

```python
import cvxpy as cp
import numpy as np

def optimize_dispatch_24h(pv_forecast: np.ndarray,
                           load_forecast: np.ndarray,
                           prices: np.ndarray,
                           bess_capacity_kwh: float,
                           bess_power_kw: float,
                           bess_soc_init: float = 0.5,
                           bess_efficiency: float = 0.95,
                           grid_import_limit: float = 500,
                           grid_export_limit: float = 0,
                           dt_hours: float = 0.25) -> dict:
    """Optimal 24-hour dispatch using Linear Programming.

    Minimizes total electricity cost over 24 hours.
    """
    T = len(pv_forecast)

    # Decision variables
    bess_charge = cp.Variable(T, nonneg=True)
    bess_discharge = cp.Variable(T, nonneg=True)
    grid_import = cp.Variable(T, nonneg=True)
    grid_export = cp.Variable(T, nonneg=True)
    pv_curtail = cp.Variable(T, nonneg=True)
    soc = cp.Variable(T + 1)

    # Objective: minimize electricity cost
    cost = cp.sum(cp.multiply(prices, grid_import) * dt_hours) \
           - cp.sum(cp.multiply(prices * 0.8, grid_export) * dt_hours)  # Feed-in tariff
    objective = cp.Minimize(cost)

    constraints = [
        # Power balance
        pv_forecast - pv_curtail + bess_discharge - bess_charge + grid_import - grid_export == load_forecast,

        # BESS constraints
        soc[0] == bess_soc_init,
        soc[T] >= 0.3,  # End SOC constraint
        bess_charge <= bess_power_kw,
        bess_discharge <= bess_power_kw,

        # Grid constraints
        grid_import <= grid_import_limit,
        grid_export <= grid_export_limit,

        # Curtailment
        pv_curtail <= pv_forecast,
        pv_curtail >= 0,
    ]

    # SOC dynamics
    for t in range(T):
        constraints.append(
            soc[t + 1] == soc[t]
            + (bess_charge[t] * bess_efficiency - bess_discharge[t] / bess_efficiency)
            * dt_hours / bess_capacity_kwh
        )
        constraints.append(soc[t + 1] >= 0.10)
        constraints.append(soc[t + 1] <= 0.95)

    prob = cp.Problem(objective, constraints)
    prob.solve(solver=cp.ECOS)

    if prob.status == 'optimal':
        return {
            'status': 'optimal',
            'total_cost': round(prob.value, 2),
            'bess_charge_kw': bess_charge.value.round(2),
            'bess_discharge_kw': bess_discharge.value.round(2),
            'grid_import_kw': grid_import.value.round(2),
            'grid_export_kw': grid_export.value.round(2),
            'soc_profile': soc.value.round(3),
            'pv_curtail_kw': pv_curtail.value.round(2),
            'self_consumption_pct': round(
                (1 - grid_import.value.sum() / load_forecast.sum()) * 100, 1),
        }
    return {'status': prob.status}

# Example: 15-minute intervals, 96 timesteps per day
T = 96
pv = np.array([0]*24 + [i*10 for i in range(24)] + [200]*12 +
               [200-i*10 for i in range(24)] + [0]*12)[:T]
load = np.full(T, 150)  # Flat 150kW load
prices = np.array([0.05]*24 + [0.08]*12 + [0.15]*24 + [0.12]*12 +
                   [0.15]*12 + [0.08]*12)[:T]

result = optimize_dispatch_24h(pv, load, prices,
                                bess_capacity_kwh=500, bess_power_kw=100)
```

## Solar & Load Forecasting

```python
def forecast_pv_simple(capacity_kwp: float, hour: int,
                        cloud_cover: float = 0.3) -> float:
    """Simple PV generation forecast based on hour and cloud cover."""
    if hour < 6 or hour > 18:
        return 0

    # Bell curve for solar generation
    peak_hour = 12
    sigma = 3
    clear_sky = capacity_kwp * np.exp(-0.5 * ((hour - peak_hour) / sigma) ** 2)
    return round(clear_sky * (1 - cloud_cover * 0.8), 2)

def forecast_load_profile(base_load_kw: float, hour: int,
                           day_type: str = 'weekday') -> float:
    """Typical commercial/industrial load profile."""
    profiles = {
        'weekday': {
            0: 0.4, 1: 0.35, 2: 0.35, 3: 0.35, 4: 0.4, 5: 0.5,
            6: 0.6, 7: 0.75, 8: 0.9, 9: 1.0, 10: 1.0, 11: 0.95,
            12: 0.85, 13: 0.9, 14: 1.0, 15: 1.0, 16: 0.95, 17: 0.8,
            18: 0.65, 19: 0.55, 20: 0.5, 21: 0.45, 22: 0.42, 23: 0.4,
        },
        'weekend': {
            h: 0.3 + 0.2 * (1 if 8 <= h <= 18 else 0) for h in range(24)
        },
    }
    factor = profiles.get(day_type, profiles['weekday']).get(hour, 0.5)
    return round(base_load_kw * factor, 2)
```

## Modbus Communication with Inverter/Meter

```python
from pymodbus.client import ModbusTcpClient

class EMSCommunicator:
    """Read/write to PV inverter, BESS, and energy meter via Modbus."""

    def __init__(self, devices: dict):
        self.devices = {}
        for name, cfg in devices.items():
            self.devices[name] = ModbusTcpClient(cfg['ip'], port=cfg.get('port', 502))
            self.devices[name].connect()

    def read_pv_inverter(self, name: str = 'pv_inverter') -> dict:
        client = self.devices[name]
        regs = client.read_holding_registers(address=32064, count=4, slave=1)
        return {
            'active_power_kw': regs.registers[0] / 1000,
            'daily_yield_kwh': regs.registers[2] / 100,
        }

    def read_bess(self, name: str = 'bess') -> dict:
        client = self.devices[name]
        regs = client.read_holding_registers(address=37000, count=10, slave=1)
        return {
            'soc': regs.registers[0] / 10,
            'power_kw': (regs.registers[1] - 32768) / 10 if regs.registers[1] > 16384 else regs.registers[1] / 10,
            'voltage_v': regs.registers[2] / 10,
            'current_a': regs.registers[3] / 10,
            'temperature_c': regs.registers[4] / 10,
        }

    def read_meter(self, name: str = 'meter') -> dict:
        client = self.devices[name]
        regs = client.read_holding_registers(address=0, count=10, slave=1)
        return {
            'total_kw': regs.registers[0] / 10,
            'import_kwh': regs.registers[2],
            'export_kwh': regs.registers[4],
        }

    def set_bess_power(self, power_kw: float, name: str = 'bess'):
        """Command BESS charge/discharge (positive=discharge, negative=charge)."""
        client = self.devices[name]
        value = int(power_kw * 10) + 32768 if power_kw < 0 else int(power_kw * 10)
        client.write_register(address=47100, value=value, slave=1)

# Device configuration
devices = {
    'pv_inverter': {'ip': '192.168.1.10', 'port': 502},
    'bess': {'ip': '192.168.1.20', 'port': 502},
    'meter': {'ip': '192.168.1.30', 'port': 502},
}
```

## EMS Performance Metrics

```python
def calculate_ems_kpis(pv_gen: np.ndarray, load: np.ndarray,
                        grid_import: np.ndarray, grid_export: np.ndarray,
                        bess_charge: np.ndarray, bess_discharge: np.ndarray,
                        prices: np.ndarray, dt_hours: float = 0.25) -> dict:
    total_pv = pv_gen.sum() * dt_hours
    total_load = load.sum() * dt_hours
    total_import = grid_import.sum() * dt_hours
    total_export = grid_export.sum() * dt_hours
    pv_self_consumed = total_pv - total_export

    return {
        'self_consumption_ratio': round(pv_self_consumed / total_pv * 100, 1) if total_pv > 0 else 0,
        'self_sufficiency_ratio': round(pv_self_consumed / total_load * 100, 1),
        'grid_dependency': round(total_import / total_load * 100, 1),
        'peak_demand_kw': round(grid_import.max(), 1),
        'total_cost': round((grid_import * prices * dt_hours).sum(), 2),
        'cost_without_bess': round((np.maximum(load - pv_gen, 0) * prices * dt_hours).sum(), 2),
        'savings': round(
            (np.maximum(load - pv_gen, 0) * prices * dt_hours).sum()
            - (grid_import * prices * dt_hours).sum(), 2),
    }
```

## EMS Operating Modes

| Mode | Strategy | When to Use |
|------|----------|-------------|
| Self-Consumption | PV→Load→BESS→Grid | Maximize on-site usage |
| Peak Shaving | BESS discharge during peaks | Reduce demand charges |
| TOU Arbitrage | Charge off-peak, discharge peak | Price spread > 2x |
| Backup | Maintain SOC reserve | Critical loads |
| Zero Export | Curtail PV + BESS absorb | Grid regulation |
| Island | BESS + PV only, no grid | Grid outage |

## Communication Protocols

| Protocol | Use Case | Devices |
|----------|----------|---------|
| Modbus TCP | Inverter, BESS, meter | Huawei, SMA, BYD |
| Modbus RTU | Legacy meters, sensors | RS-485 devices |
| MQTT | Cloud telemetry, dashboard | IoT gateway |
| SunSpec (Modbus) | Standardized solar | SMA, SolarEdge |
| CAN bus | BMS internal | Battery cells |
| IEC 61850 | Substation automation | Protection relays |
