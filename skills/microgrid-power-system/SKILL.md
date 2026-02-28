---
name: microgrid-power-system
description: Microgrid and power system design for PV+BESS - grid-tied/off-grid/hybrid topologies, power flow analysis, protection coordination, transformer sizing, switchgear selection, grounding system, harmonic analysis, grid code compliance, and islanding detection. Covers single-line diagram design, relay coordination, and power quality. Use when designing microgrid electrical systems, grid interconnection, protection schemes, or power quality analysis.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Microgrid, Power System, Grid-Tied, Off-Grid, Protection, Transformer, Switchgear, Power Quality, Harmonic, SLD]
dependencies: [numpy, pandas, matplotlib, networkx]
---

# Microgrid & Power System Design

## When to Use

- Designing grid-tied or off-grid PV+BESS electrical systems
- Single-line diagram (SLD) design
- Protection coordination (relay settings, fuse selection)
- Transformer and switchgear sizing
- Grid code compliance (voltage, frequency, power factor)
- Harmonic analysis and filtering
- Islanding detection scheme
- Grounding system design

## Microgrid Topologies

### Grid-Tied (Most Common)
```
Utility Grid ──[Main Breaker]──[Transformer]──[MV Switchgear]
                                                    │
                    ┌───────────────────────────────┤
                    │                               │
              [LV Switchboard]               [PV Inverter]──[PV Array]
                    │                               │
              [Load Panels]                  [BESS PCS]──[Battery]
                    │
              [Critical Loads]
```

### Off-Grid / Island Mode
```
[PV Array]──[PV Inverter]──┐
                            │
[BESS]──[Bidirectional PCS]─┼──[AC Bus]──[Load]
                            │
[Diesel Gen]──[ATS]─────────┘
```

## Power Flow Calculator

```python
import numpy as np

def power_flow_microgrid(sources: list[dict], loads: list[dict],
                          grid_connected: bool = True) -> dict:
    """Simple radial power flow for microgrid."""
    total_gen = sum(s['power_kw'] for s in sources)
    total_load = sum(l['power_kw'] for l in loads)
    total_reactive_load = sum(l.get('kvar', l['power_kw'] * 0.484) for l in loads)  # PF=0.9

    net_power = total_gen - total_load
    total_apparent = np.sqrt(total_load**2 + total_reactive_load**2)
    power_factor = total_load / total_apparent if total_apparent > 0 else 1.0

    if grid_connected:
        grid_power = -net_power  # Positive = import
        status = 'EXPORTING' if net_power > 0 else 'IMPORTING'
    else:
        grid_power = 0
        if net_power < 0:
            status = 'LOAD_SHEDDING_REQUIRED'
        elif net_power > total_gen * 0.1:
            status = 'CURTAILMENT_REQUIRED'
        else:
            status = 'BALANCED'

    return {
        'total_generation_kw': round(total_gen, 1),
        'total_load_kw': round(total_load, 1),
        'total_load_kva': round(total_apparent, 1),
        'net_power_kw': round(net_power, 1),
        'grid_power_kw': round(grid_power, 1),
        'power_factor': round(power_factor, 3),
        'status': status,
    }
```

## Transformer Sizing

```python
def size_transformer(total_load_kva: float, pv_kwp: float,
                      growth_factor: float = 1.2,
                      diversity_factor: float = 0.8) -> dict:
    """Select transformer for PV+BESS microgrid."""
    design_kva = total_load_kva * diversity_factor * growth_factor

    standard_sizes = [100, 160, 200, 250, 315, 400, 500, 630, 800,
                      1000, 1250, 1500, 2000, 2500, 3150]
    selected = next(s for s in standard_sizes if s >= design_kva)

    loading_pct = design_kva / selected * 100

    # Impedance (typical)
    impedance = 4.0 if selected <= 500 else 5.0 if selected <= 1000 else 6.0

    return {
        'design_load_kva': round(design_kva, 0),
        'selected_kva': selected,
        'loading_pct': round(loading_pct, 1),
        'impedance_pct': impedance,
        'voltage': '22kV/0.4kV' if selected <= 2500 else '35kV/0.4kV',
        'cooling': 'ONAN' if selected <= 1000 else 'ONAN/ONAF',
        'losses_no_load_kw': round(selected * 0.002, 1),
        'losses_full_load_kw': round(selected * 0.01, 1),
        'weight_kg_approx': round(selected * 3.5, 0),
    }
```

## Protection Coordination

```python
def design_protection_scheme(system: dict) -> dict:
    """Design protection for PV+BESS microgrid."""
    pv_kw = system['pv_kwp']
    bess_kw = system['bess_kw']
    transformer_kva = system['transformer_kva']
    voltage = system.get('voltage', 400)

    # Fault current calculation
    isc_transformer = transformer_kva * 1000 / (1.732 * voltage * system.get('z_pct', 5) / 100)
    isc_pv = pv_kw * 1000 / (1.732 * voltage) * 1.1  # PV contributes ~110% of rated

    protection = {
        'main_incomer': {
            'device': 'ACB' if transformer_kva > 800 else 'MCCB',
            'rating_a': int(np.ceil(transformer_kva * 1000 / (1.732 * voltage) * 1.25 / 50) * 50),
            'breaking_capacity_ka': round(isc_transformer / 1000 + 2, 0),
            'protection': 'LSIG (Long, Short, Instantaneous, Ground)',
            'settings': {
                'long_time': '1.0 × In, 10s',
                'short_time': '6 × In, 0.2s',
                'instantaneous': '12 × In',
                'ground_fault': '0.3 × In, 0.4s',
            },
        },
        'pv_feeder': {
            'device': 'MCCB',
            'rating_a': int(np.ceil(pv_kw * 1000 / (1.732 * voltage) * 1.25 / 10) * 10),
            'breaking_capacity_ka': round(isc_transformer / 1000 + 2, 0),
            'protection': 'LSI',
            'anti_islanding': 'Required per IEEE 1547 / IEC 62116',
        },
        'bess_feeder': {
            'device': 'MCCB',
            'rating_a': int(np.ceil(bess_kw * 1000 / (1.732 * voltage) * 1.25 / 10) * 10),
            'breaking_capacity_ka': round(isc_transformer / 1000 + 2, 0),
            'dc_breaker': f"DC MCCB {int(bess_kw * 1.25 / 0.8)}A at {system.get('dc_voltage', 800)}VDC",
            'fuse': f"gPV fuse {int(bess_kw * 1000 / system.get('dc_voltage', 800) * 1.25)}A",
        },
        'surge_protection': {
            'dc_side': 'SPD Type 2, Uc=1000VDC, In=40kA',
            'ac_side': 'SPD Type 1+2, Uc=275V, In=25kA (if exposed to lightning)',
        },
        'grounding': {
            'system': 'TN-S',
            'transformer_ground': 'Ground rod ≤ 1Ω',
            'pv_ground': 'Equipment grounding conductor + ground rod',
            'bess_ground': 'Isolated ground for DC, bonded at PCS',
        },
        'arc_fault': {
            'dc_afci': 'Required for PV strings (NEC 690.11)',
            'rapid_shutdown': 'Required (NEC 690.12)',
        },
    }
    return protection

# Example
protection = design_protection_scheme({
    'pv_kwp': 1000, 'bess_kw': 500,
    'transformer_kva': 1250, 'z_pct': 5,
    'dc_voltage': 800,
})
```

## Grid Code Compliance Checker

```python
def check_grid_code(system: dict, grid_code: str = 'vietnam') -> dict:
    """Check system against grid code requirements."""
    codes = {
        'vietnam': {
            'voltage_range': (0.90, 1.10),  # pu
            'frequency_range': (49.0, 51.0),  # Hz
            'power_factor_min': 0.9,
            'thd_voltage_max': 5.0,   # %
            'thd_current_max': 5.0,   # %
            'reconnect_delay_s': 300,
            'anti_islanding': True,
            'lvrt_required': True,     # Low Voltage Ride Through
            'max_ramp_rate_pct_min': 10,  # %/min
        },
        'ieee_1547': {
            'voltage_range': (0.88, 1.10),
            'frequency_range': (59.3, 60.5),
            'power_factor_min': 0.85,
            'thd_voltage_max': 5.0,
            'thd_current_max': 5.0,
            'reconnect_delay_s': 300,
            'anti_islanding': True,
            'lvrt_required': True,
        },
    }
    code = codes.get(grid_code, codes['vietnam'])

    checks = {
        'voltage_range': f"{code['voltage_range'][0]*100:.0f}% - {code['voltage_range'][1]*100:.0f}%",
        'frequency_range': f"{code['frequency_range'][0]} - {code['frequency_range'][1]} Hz",
        'power_factor': f"≥ {code['power_factor_min']} (leading and lagging)",
        'thd_current': f"≤ {code['thd_current_max']}% at PCC",
        'anti_islanding': 'Required' if code['anti_islanding'] else 'Not required',
        'lvrt': 'Required' if code['lvrt_required'] else 'Not required',
        'reconnect_delay': f"{code['reconnect_delay_s']}s after grid restoration",
        'ramp_rate': f"≤ {code.get('max_ramp_rate_pct_min', 'N/A')}%/min",
    }
    return {'grid_code': grid_code, 'requirements': checks}
```

## Harmonic Analysis

```python
def harmonic_check(inverter_type: str, num_inverters: int,
                    transformer_kva: float) -> dict:
    """Check harmonic injection at PCC."""
    # Typical inverter THDi by type
    thdi = {'central': 1.5, 'string': 2.5, 'micro': 3.0}
    inverter_thdi = thdi.get(inverter_type, 2.5)

    # Multiple inverters: diversity factor reduces THD
    diversity = 1 / np.sqrt(num_inverters) if num_inverters > 1 else 1
    total_thdi = inverter_thdi * diversity

    # Individual harmonics (typical for 3-level inverter)
    harmonics = {
        3: inverter_thdi * 0.10,
        5: inverter_thdi * 0.30,
        7: inverter_thdi * 0.20,
        11: inverter_thdi * 0.15,
        13: inverter_thdi * 0.10,
    }

    compliant = total_thdi < 5.0

    return {
        'total_thdi_pct': round(total_thdi, 2),
        'individual_harmonics': {f'H{k}': f'{v:.2f}%' for k, v in harmonics.items()},
        'ieee_519_compliant': compliant,
        'recommendation': 'No filter needed' if compliant else 'Consider passive harmonic filter',
    }
```

## Switchgear Selection

| Voltage | Type | Rating Range | Application |
|---------|------|-------------|-------------|
| LV (400V) | MCCB | 16-3200A | Branch feeders |
| LV (400V) | ACB | 800-6300A | Main incomer |
| MV (22kV) | VCB | 400-2500A | MV switchgear |
| MV (22kV) | Load Break Switch | 200-630A | Ring main unit |
| DC (1000V) | DC MCCB | 100-1600A | PV combiner, BESS |

## Key Standards

| Standard | Scope |
|----------|-------|
| IEC 61936 | Power installations > 1kV |
| IEC 61439 | LV switchgear assemblies |
| IEC 62271 | HV switchgear |
| IEEE 1547 | DER interconnection |
| IEC 62116 | Anti-islanding test |
| IEC 61727 | PV grid connection |
| TCVN 11855 | Vietnam solar regulation |
