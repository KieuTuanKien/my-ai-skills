---
name: pv-solar-system
description: Expert-level PV solar system design - solar irradiance analysis, PV module selection, string sizing, inverter matching, DC/AC ratio optimization, yield simulation (PVsyst methodology), shading analysis, single-line diagram generation, and system performance ratio calculation. Covers rooftop, ground-mount, carport, and floating PV. Use when designing solar PV systems, calculating energy yield, selecting equipment, sizing strings/inverters, or generating SLD.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Solar, PV, Photovoltaic, Inverter, String Sizing, Energy Yield, PVsyst, Irradiance, DC-AC Ratio, SLD]
dependencies: [numpy, pandas, pvlib, matplotlib]
---

# PV Solar System Design

## When to Use

- Designing rooftop/ground-mount PV systems (residential to utility-scale)
- PV module selection and comparison
- String sizing (Voc, Vmp temperature correction)
- Inverter selection and DC/AC ratio optimization
- Energy yield estimation (kWh/kWp)
- Shading loss and performance ratio calculation
- Single-line diagram and cable sizing

## Installation

```bash
pip install pvlib pandas numpy matplotlib
```

## Solar Resource Assessment

```python
import pvlib
import pandas as pd
import numpy as np

def get_solar_resource(latitude: float, longitude: float,
                       altitude: float = 0) -> dict:
    """Get solar irradiance data using pvlib (TMY-equivalent)."""
    # Clear-sky model for quick estimation
    site = pvlib.location.Location(latitude, longitude, altitude=altitude)
    times = pd.date_range('2024-01-01', '2024-12-31', freq='h', tz='UTC')
    cs = site.get_clearsky(times)

    monthly_ghi = cs['ghi'].resample('M').sum() / 1000  # kWh/m²
    annual_ghi = monthly_ghi.sum()

    # Peak Sun Hours
    psh = annual_ghi / 365

    return {
        'latitude': latitude,
        'longitude': longitude,
        'annual_ghi_kwh_m2': round(annual_ghi, 0),
        'avg_daily_psh': round(psh, 2),
        'monthly_ghi': monthly_ghi.round(1).to_dict(),
        'best_month': monthly_ghi.idxmax().strftime('%B'),
        'worst_month': monthly_ghi.idxmin().strftime('%B'),
    }

# Vietnam locations
hanoi = get_solar_resource(21.03, 105.85)
hcmc = get_solar_resource(10.82, 106.63)
```

## PV Module Database

```python
PV_MODULES = {
    'LONGi_Hi-MO6_580W': {
        'manufacturer': 'LONGi', 'model': 'Hi-MO 6 LR5-72HTH-580M',
        'Pmax': 580, 'Vmp': 43.30, 'Imp': 13.40, 'Voc': 51.90, 'Isc': 14.20,
        'efficiency': 22.5, 'temp_coeff_Pmax': -0.29, 'temp_coeff_Voc': -0.25,
        'temp_coeff_Isc': 0.048, 'NOCT': 45, 'bifacial': True,
        'dimensions_mm': (2278, 1134, 30), 'weight_kg': 28.5,
        'warranty_years': 30, 'degradation_year1': 1.0, 'degradation_annual': 0.4,
        'cell_type': 'HJT', 'price_usd_per_wp': 0.22,
    },
    'JinkoSolar_Tiger_Neo_585W': {
        'manufacturer': 'JinkoSolar', 'model': 'Tiger Neo N-type JKM585N-72HL4',
        'Pmax': 585, 'Vmp': 43.56, 'Imp': 13.43, 'Voc': 52.22, 'Isc': 14.25,
        'efficiency': 22.65, 'temp_coeff_Pmax': -0.30, 'temp_coeff_Voc': -0.25,
        'temp_coeff_Isc': 0.045, 'NOCT': 45, 'bifacial': True,
        'dimensions_mm': (2278, 1134, 30), 'weight_kg': 28.2,
        'warranty_years': 30, 'degradation_year1': 1.0, 'degradation_annual': 0.4,
        'cell_type': 'TOPCon', 'price_usd_per_wp': 0.20,
    },
    'Canadian_Solar_660W': {
        'manufacturer': 'Canadian Solar', 'model': 'HiKu7 CS7N-660TB-AG',
        'Pmax': 660, 'Vmp': 38.3, 'Imp': 17.23, 'Voc': 46.1, 'Isc': 18.42,
        'efficiency': 21.6, 'temp_coeff_Pmax': -0.32, 'temp_coeff_Voc': -0.26,
        'temp_coeff_Isc': 0.05, 'NOCT': 45, 'bifacial': True,
        'dimensions_mm': (2384, 1303, 35), 'weight_kg': 34.4,
        'warranty_years': 25, 'degradation_year1': 2.0, 'degradation_annual': 0.45,
        'cell_type': 'TOPCon', 'price_usd_per_wp': 0.18,
    },
}
```

## String Sizing Calculator

```python
def string_sizing(module: dict, inverter_vdc_max: float,
                   inverter_mppt_min: float, inverter_mppt_max: float,
                   t_min: float = -10, t_max: float = 70,
                   t_stc: float = 25) -> dict:
    """Calculate min/max modules per string based on temperature."""
    Voc = module['Voc']
    Vmp = module['Vmp']
    tc_voc = module['temp_coeff_Voc'] / 100  # Convert %/°C to fraction

    # Worst case: coldest temp → highest Voc
    Voc_max = Voc * (1 + tc_voc * (t_min - t_stc))
    # Worst case: hottest temp → lowest Vmp
    Vmp_min = Vmp * (1 + tc_voc * (t_max - t_stc))
    # Normal operating: NOCT
    Vmp_noct = Vmp * (1 + tc_voc * (module['NOCT'] - t_stc))

    # Max modules: Voc at coldest < inverter Vdc_max
    max_modules = int(inverter_vdc_max / Voc_max)
    # Min modules: Vmp at hottest > inverter MPPT min
    min_modules = int(np.ceil(inverter_mppt_min / Vmp_min))
    # Optimal: Vmp at NOCT in middle of MPPT range
    optimal = int((inverter_mppt_min + inverter_mppt_max) / 2 / Vmp_noct)
    optimal = max(min_modules, min(optimal, max_modules))

    return {
        'min_modules_per_string': min_modules,
        'max_modules_per_string': max_modules,
        'optimal_modules_per_string': optimal,
        'Voc_at_cold': round(Voc_max, 1),
        'Vmp_at_hot': round(Vmp_min, 1),
        'string_Voc_max': round(optimal * Voc_max, 1),
        'string_Vmp_range': f"{round(optimal * Vmp_min, 1)} - {round(optimal * Voc_max, 1)} V",
        'string_power_wp': optimal * module['Pmax'],
    }

# Example: LONGi 580W + Huawei SUN2000-100KTL
result = string_sizing(
    PV_MODULES['LONGi_Hi-MO6_580W'],
    inverter_vdc_max=1100,  # Huawei max DC voltage
    inverter_mppt_min=200,
    inverter_mppt_max=1000,
    t_min=5,   # Vietnam min
    t_max=55,  # Cell temp max
)
print(result)
```

## Complete System Sizing

```python
def design_pv_system(target_kwp: float, module_key: str,
                      inverter_power_kw: float, inverter_mppt_count: int,
                      inverter_vdc_max: float, inverter_mppt_range: tuple,
                      inverter_idc_max: float,
                      dc_ac_ratio: float = 1.2,
                      t_min: float = 5, t_max: float = 55) -> dict:
    module = PV_MODULES[module_key]

    # Total modules needed
    total_modules = int(np.ceil(target_kwp * 1000 / module['Pmax']))

    # String sizing
    ss = string_sizing(module, inverter_vdc_max,
                       inverter_mppt_range[0], inverter_mppt_range[1],
                       t_min, t_max)
    modules_per_string = ss['optimal_modules_per_string']

    # Strings per MPPT (limited by Idc_max)
    max_strings_per_mppt = int(inverter_idc_max / module['Isc'])

    # Total strings
    total_strings = int(np.ceil(total_modules / modules_per_string))

    # Number of inverters
    actual_dc_kw = total_modules * module['Pmax'] / 1000
    num_inverters = int(np.ceil(actual_dc_kw / (inverter_power_kw * dc_ac_ratio)))

    strings_per_inverter = int(np.ceil(total_strings / num_inverters))
    strings_per_mppt_actual = int(np.ceil(strings_per_inverter / inverter_mppt_count))

    # Recalculate actual
    actual_modules = num_inverters * strings_per_inverter * modules_per_string
    actual_kwp = actual_modules * module['Pmax'] / 1000
    actual_dc_ac = actual_kwp / (num_inverters * inverter_power_kw)

    # Area calculation
    module_area = module['dimensions_mm'][0] * module['dimensions_mm'][1] / 1e6  # m²
    total_area = actual_modules * module_area * 1.3  # 30% spacing factor

    return {
        'target_kwp': target_kwp,
        'actual_kwp': round(actual_kwp, 2),
        'module': f"{module['manufacturer']} {module['Pmax']}W",
        'total_modules': actual_modules,
        'modules_per_string': modules_per_string,
        'total_strings': num_inverters * strings_per_inverter,
        'num_inverters': num_inverters,
        'strings_per_inverter': strings_per_inverter,
        'strings_per_mppt': strings_per_mppt_actual,
        'dc_ac_ratio': round(actual_dc_ac, 2),
        'total_area_m2': round(total_area, 0),
        'total_weight_kg': round(actual_modules * module['weight_kg'], 0),
        'string_sizing': ss,
    }

system = design_pv_system(
    target_kwp=1000,  # 1 MWp
    module_key='LONGi_Hi-MO6_580W',
    inverter_power_kw=100,
    inverter_mppt_count=10,
    inverter_vdc_max=1100,
    inverter_mppt_range=(200, 1000),
    inverter_idc_max=30,
    dc_ac_ratio=1.25,
)
```

## Energy Yield Estimation

```python
def estimate_yield(system_kwp: float, location: dict,
                    pr: float = 0.80, degradation_annual: float = 0.4,
                    years: int = 25) -> dict:
    """Estimate annual and lifetime energy yield."""
    psh = location['avg_daily_psh']

    # Year 1
    daily_yield = system_kwp * psh * pr
    annual_yield_yr1 = daily_yield * 365

    # Specific yield
    specific_yield = annual_yield_yr1 / system_kwp

    # Lifetime yield with degradation
    lifetime_yield = 0
    yearly_yields = []
    for year in range(1, years + 1):
        if year == 1:
            factor = 1.0
        else:
            factor = (1 - 0.01) * (1 - degradation_annual / 100) ** (year - 1)
        year_yield = annual_yield_yr1 * factor
        lifetime_yield += year_yield
        yearly_yields.append(round(year_yield, 0))

    return {
        'system_kwp': system_kwp,
        'annual_yield_yr1_kwh': round(annual_yield_yr1, 0),
        'specific_yield_kwh_kwp': round(specific_yield, 0),
        'daily_yield_kwh': round(daily_yield, 0),
        'performance_ratio': pr,
        'lifetime_yield_mwh': round(lifetime_yield / 1000, 0),
        'avg_annual_yield_mwh': round(lifetime_yield / years / 1000, 1),
        'yield_by_year': yearly_yields,
    }

# 1MWp system in Ho Chi Minh City
yield_result = estimate_yield(1000, hcmc, pr=0.80)
```

## Performance Ratio Breakdown

```python
def calculate_pr(system_config: dict) -> dict:
    """Detailed PR calculation with all loss factors."""
    losses = {
        'soiling': 0.03,          # 3% - dust, dirt
        'shading': 0.02,          # 2% - near shading
        'mismatch': 0.02,         # 2% - module mismatch
        'dc_cable': 0.015,        # 1.5% - DC wiring
        'ac_cable': 0.01,         # 1% - AC wiring
        'inverter_efficiency': 0.03,  # 3% - inverter loss
        'transformer': 0.01,      # 1% - transformer loss
        'temperature': 0.06,      # 6% - temperature derating
        'degradation_yr1': 0.01,  # 1% - first year
        'availability': 0.02,     # 2% - downtime
        'clipping': 0.01,         # 1% - inverter clipping
    }

    pr = 1.0
    for loss_name, loss_pct in losses.items():
        pr *= (1 - loss_pct)

    return {
        'performance_ratio': round(pr, 4),
        'total_losses_pct': round((1 - pr) * 100, 1),
        'loss_breakdown': {k: f"{v*100:.1f}%" for k, v in losses.items()},
    }
```

## DC Cable Sizing for PV Strings

```python
def size_dc_cable(string_isc: float, string_vmp: float,
                   cable_length_m: float, max_loss_pct: float = 1.0) -> dict:
    """Size DC cable for PV string to combiner/inverter."""
    RESISTIVITY = 0.0175  # Copper Ω·mm²/m at 20°C

    CABLE_SIZES = [4, 6, 10, 16, 25, 35, 50]
    DC_AMPACITY = {4: 32, 6: 41, 10: 57, 16: 76, 25: 101, 35: 125, 50: 151}

    design_current = string_isc * 1.25  # 125% safety factor

    for size in CABLE_SIZES:
        if DC_AMPACITY[size] < design_current:
            continue

        r_cable = RESISTIVITY * cable_length_m * 2 / size  # Round trip
        v_drop = design_current * r_cable
        v_drop_pct = v_drop / string_vmp * 100
        power_loss = design_current ** 2 * r_cable

        if v_drop_pct <= max_loss_pct:
            return {
                'cable_size_mm2': size,
                'cable_type': f'PV1-F {size}mm² (solar cable)',
                'ampacity_a': DC_AMPACITY[size],
                'design_current_a': round(design_current, 1),
                'voltage_drop_v': round(v_drop, 2),
                'voltage_drop_pct': round(v_drop_pct, 2),
                'power_loss_w': round(power_loss, 1),
                'cable_length_m': cable_length_m,
            }

    return {'error': 'No suitable cable found, reduce length or increase max loss'}
```

## Inverter Selection Guide

| Type | Power Range | Application | MPPT | Efficiency |
|------|------------|-------------|------|-----------|
| Micro-inverter | 300-600W | Residential rooftop | 1 per module | 96-97% |
| String Inverter | 3-100 kW | Residential/Commercial | 2-6 MPPT | 97-98.5% |
| Central Inverter | 500-5000 kW | Utility-scale | 1-2 MPPT | 98-99% |
| Hybrid Inverter | 3-15 kW | PV + BESS residential | 2 MPPT + battery | 96-97.5% |

## Additional Resources

- For BESS integration → see `bess-battery-storage` skill
- For EMS optimization → see `ems-energy-management` skill
- For grid connection → see `microgrid-power-system` skill
- For project estimation → see `solar-project-management` skill
