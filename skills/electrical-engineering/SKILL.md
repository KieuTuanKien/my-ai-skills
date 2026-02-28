---
name: electrical-engineering
description: Electrical engineering calculations, power system analysis, circuit design, motor control, protection relay settings, and electrical CAD automation. Covers load calculation, short-circuit analysis, cable sizing, transformer selection, power factor correction, and lighting design. Use when designing electrical systems, calculating loads, sizing equipment, or automating electrical engineering workflows.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Electrical Engineering, Power Systems, Circuit Design, Motor Control, Protection, Cable Sizing, Load Calculation, Transformer]
dependencies: [numpy, pandas, matplotlib, scipy]
---

# Electrical Engineering

## When to Use

- Load calculation and demand factor analysis
- Cable sizing and voltage drop calculation
- Short-circuit current analysis
- Motor starter selection and protection
- Transformer sizing and tap settings
- Power factor correction (capacitor bank)
- Protection relay coordination
- Lighting design (lux calculation)

## Load Calculation

```python
import pandas as pd

def calculate_load(loads: list[dict]) -> dict:
    """
    loads: [{'name': str, 'power_kw': float, 'pf': float,
             'demand_factor': float, 'quantity': int}]
    """
    df = pd.DataFrame(loads)
    df['total_kw'] = df['power_kw'] * df['quantity'] * df['demand_factor']
    df['kva'] = df['total_kw'] / df['pf']
    df['current_a'] = df['kva'] * 1000 / (400 * 1.732)  # 3-phase 400V

    total_kw = df['total_kw'].sum()
    avg_pf = (df['total_kw'] * df['pf']).sum() / total_kw
    total_kva = total_kw / avg_pf

    return {
        'details': df,
        'total_kw': round(total_kw, 2),
        'total_kva': round(total_kva, 2),
        'total_current_a': round(total_kva * 1000 / (400 * 1.732), 1),
        'avg_power_factor': round(avg_pf, 3),
    }

loads = [
    {'name': 'Motor 1', 'power_kw': 15, 'pf': 0.85, 'demand_factor': 0.8, 'quantity': 3},
    {'name': 'Lighting', 'power_kw': 2, 'pf': 0.95, 'demand_factor': 1.0, 'quantity': 50},
    {'name': 'HVAC', 'power_kw': 30, 'pf': 0.9, 'demand_factor': 0.7, 'quantity': 2},
    {'name': 'Outlet', 'power_kw': 0.5, 'pf': 1.0, 'demand_factor': 0.4, 'quantity': 100},
]
result = calculate_load(loads)
```

## Cable Sizing

```python
import math

# Resistivity (Ω·mm²/m at 75°C)
RESISTIVITY = {'copper': 0.0213, 'aluminum': 0.0340}

# Standard cable sizes (mm²)
CABLE_SIZES = [1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300]

# Current capacity (A) for PVC/copper, single circuit, ambient 30°C
AMPACITY = {
    1.5: 17, 2.5: 23, 4: 31, 6: 40, 10: 54, 16: 73, 25: 95,
    35: 117, 50: 141, 70: 179, 95: 216, 120: 249, 150: 285,
    185: 324, 240: 380, 300: 432
}

def size_cable(current_a: float, length_m: float, voltage: float,
               max_vdrop_pct: float = 3.0, phases: int = 3,
               material: str = 'copper', pf: float = 0.85) -> dict:
    results = []
    for size in CABLE_SIZES:
        if AMPACITY[size] < current_a * 1.25:  # 25% derating
            continue

        rho = RESISTIVITY[material]
        r = rho * length_m / size  # Resistance per conductor

        if phases == 3:
            vdrop = 1.732 * current_a * r * pf
            vdrop_pct = vdrop / voltage * 100
        else:
            vdrop = 2 * current_a * r * pf
            vdrop_pct = vdrop / voltage * 100

        results.append({
            'size_mm2': size,
            'ampacity_a': AMPACITY[size],
            'voltage_drop_v': round(vdrop, 2),
            'voltage_drop_pct': round(vdrop_pct, 2),
            'pass': vdrop_pct <= max_vdrop_pct,
        })

    df = pd.DataFrame(results)
    recommended = df[df['pass']].iloc[0] if df['pass'].any() else None
    return {'all_options': df, 'recommended': recommended}

# 3-phase, 100A load, 150m run, 400V
print(size_cable(100, 150, 400, max_vdrop_pct=3.0))
```

## Short Circuit Analysis

```python
def short_circuit_current(transformer_kva: float, voltage: float,
                          impedance_pct: float, cable_impedance_ohm: float = 0) -> dict:
    z_base = voltage ** 2 / (transformer_kva * 1000)
    z_transformer = z_base * impedance_pct / 100
    z_total = z_transformer + cable_impedance_ohm

    isc_sym = voltage / (1.732 * z_total)  # Symmetrical
    isc_peak = isc_sym * 2.55  # Peak (first cycle, X/R=10)

    return {
        'isc_symmetrical_ka': round(isc_sym / 1000, 2),
        'isc_peak_ka': round(isc_peak / 1000, 2),
        'breaking_capacity_required_ka': round(isc_sym / 1000 * 1.1, 2),
        'z_total_ohm': round(z_total, 4),
    }

# 1000 kVA transformer, 400V, 5% impedance
print(short_circuit_current(1000, 400, 5.0))
```

## Motor Starter Selection

```python
def select_motor_starter(motor_kw: float, voltage: float = 400,
                          starting_method: str = 'DOL') -> dict:
    motor_fla = motor_kw * 1000 / (voltage * 1.732 * 0.85 * 0.9)  # PF=0.85, eff=0.9

    starters = {
        'DOL': {'start_current_mult': 6.0, 'start_torque_mult': 1.0,
                'max_kw': 7.5, 'cost': 'low'},
        'Star-Delta': {'start_current_mult': 2.0, 'start_torque_mult': 0.33,
                       'max_kw': 100, 'cost': 'medium'},
        'Soft Starter': {'start_current_mult': 3.0, 'start_torque_mult': 0.5,
                         'max_kw': 500, 'cost': 'medium-high'},
        'VFD': {'start_current_mult': 1.0, 'start_torque_mult': 1.5,
                'max_kw': 5000, 'cost': 'high'},
    }

    starter = starters[starting_method]
    start_current = motor_fla * starter['start_current_mult']

    contactor_rating = motor_fla * 1.25
    overload_setting = motor_fla
    fuse_rating = motor_fla * 1.6  # gG fuse

    breaker_sizes = [16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250]
    mccb_rating = next(s for s in breaker_sizes if s >= motor_fla * 1.25)

    return {
        'motor_fla': round(motor_fla, 1),
        'starting_method': starting_method,
        'start_current_a': round(start_current, 1),
        'contactor_min_a': round(contactor_rating, 0),
        'overload_setting_a': round(overload_setting, 1),
        'fuse_rating_a': round(fuse_rating, 0),
        'mccb_rating_a': mccb_rating,
    }

print(select_motor_starter(15, 400, 'Star-Delta'))
```

## Power Factor Correction

```python
def capacitor_bank_sizing(total_kw: float, current_pf: float,
                           target_pf: float = 0.95) -> dict:
    import math
    phi1 = math.acos(current_pf)
    phi2 = math.acos(target_pf)
    kvar_required = total_kw * (math.tan(phi1) - math.tan(phi2))

    standard_sizes = [5, 10, 15, 20, 25, 30, 50, 75, 100, 150, 200, 250, 300]
    bank_size = next(s for s in standard_sizes if s >= kvar_required)

    monthly_savings_pct = ((1 / current_pf) - (1 / target_pf)) / (1 / current_pf) * 100

    return {
        'kvar_required': round(kvar_required, 1),
        'bank_size_kvar': bank_size,
        'current_reduction_pct': round(monthly_savings_pct, 1),
        'steps_recommended': max(3, bank_size // 25),
    }

print(capacitor_bank_sizing(500, 0.75, 0.95))
```

## Lighting Design (Lumen Method)

```python
def lighting_calculation(room_length: float, room_width: float,
                         room_height: float, work_plane: float = 0.8,
                         target_lux: float = 500,
                         luminaire_lumens: float = 4000,
                         maintenance_factor: float = 0.8) -> dict:
    area = room_length * room_width
    mounting_height = room_height - work_plane
    room_index = (room_length * room_width) / (mounting_height * (room_length + room_width))

    # Utilization factor (approximation based on room index)
    if room_index < 1: uf = 0.35
    elif room_index < 2: uf = 0.50
    elif room_index < 3: uf = 0.60
    else: uf = 0.65

    total_lumens = target_lux * area / (uf * maintenance_factor)
    num_luminaires = math.ceil(total_lumens / luminaire_lumens)

    # Grid spacing
    cols = math.ceil(math.sqrt(num_luminaires * room_length / room_width))
    rows = math.ceil(num_luminaires / cols)

    return {
        'area_m2': area,
        'room_index': round(room_index, 2),
        'total_lumens_required': round(total_lumens),
        'num_luminaires': rows * cols,
        'grid': f'{rows} x {cols}',
        'spacing_x': round(room_length / cols, 2),
        'spacing_y': round(room_width / rows, 2),
        'actual_lux': round(rows * cols * luminaire_lumens * uf * maintenance_factor / area),
    }

print(lighting_calculation(12, 8, 3.5, target_lux=500))
```

## Quick Reference Tables

### Common Voltage Systems

| System | Voltage | Phases | Use |
|--------|---------|--------|-----|
| Residential | 220/230V | 1-phase | Home, small loads |
| Commercial | 380/400V | 3-phase | Office, retail |
| Industrial LV | 380/400V | 3-phase | Motors, MCC |
| Industrial MV | 6.6/11/22kV | 3-phase | Large motors, distribution |
| Transmission | 110/220/500kV | 3-phase | Power grid |

### Protection Device Coordination

| Level | Device | Setting |
|-------|--------|---------|
| Main Incomer | ACB/MCCB | 0.8-1.0x In, time delay 0.4s |
| Sub-Main | MCCB | 1.0x In, time delay 0.2s |
| Branch | MCB/MCCB | 1.25x In, instantaneous |
| Motor | Overload Relay | 1.0x FLA, class 10/20 |
| Final | MCB/RCBO | Per load, 30mA RCD for sockets |

## Energy & Renewable Engineering Skills (Cross-References)

- PV Solar system design → see `pv-solar-system` skill
- Battery storage (BESS/BMS) → see `bess-battery-storage` skill
- Energy Management System → see `ems-energy-management` skill
- Microgrid & power system → see `microgrid-power-system` skill
- Solar project management → see `solar-project-management` skill
