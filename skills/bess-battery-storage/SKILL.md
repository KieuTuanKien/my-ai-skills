---
name: bess-battery-storage
description: Battery Energy Storage System (BESS) design - battery chemistry selection (LFP, NMC, NCA), capacity sizing for PV self-consumption/peak shaving/backup, BMS architecture (cell balancing, SOC/SOH estimation, thermal management), rack/container layout, C-rate analysis, cycle life modeling, and safety standards (UL 9540, IEC 62619). Use when designing BESS systems, sizing batteries for solar, implementing BMS logic, or calculating battery lifetime and ROI.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [BESS, Battery, BMS, LFP, NMC, SOC, SOH, Cell Balancing, Energy Storage, Lithium-ion, Cycle Life]
dependencies: [numpy, pandas, matplotlib, scipy]
---

# Battery Energy Storage System (BESS) & BMS

## When to Use

- Sizing BESS for PV self-consumption, peak shaving, or backup power
- Selecting battery chemistry (LFP vs NMC vs NCA)
- BMS algorithm design (SOC, SOH, cell balancing, thermal)
- Cycle life modeling and degradation analysis
- Container/rack layout and safety design
- ROI and LCOE calculation for storage projects

## Battery Chemistry Comparison

```python
BATTERY_CHEMISTRIES = {
    'LFP': {
        'full_name': 'Lithium Iron Phosphate (LiFePO4)',
        'nominal_voltage': 3.2,     # V per cell
        'energy_density_wh_kg': 160,
        'cycle_life': 6000,          # cycles at 80% DOD
        'calendar_life_years': 15,
        'round_trip_efficiency': 0.95,
        'max_c_rate_charge': 1.0,
        'max_c_rate_discharge': 1.0,
        'operating_temp_c': (-20, 60),
        'optimal_temp_c': (15, 35),
        'thermal_runaway_risk': 'Very Low',
        'cost_usd_per_kwh': 120,
        'dod_recommended': 0.90,
        'self_discharge_per_month': 0.02,
        'best_for': 'Stationary storage, long cycle life, safety-critical',
    },
    'NMC_532': {
        'full_name': 'Nickel Manganese Cobalt (5:3:2)',
        'nominal_voltage': 3.7,
        'energy_density_wh_kg': 220,
        'cycle_life': 3000,
        'calendar_life_years': 12,
        'round_trip_efficiency': 0.94,
        'max_c_rate_charge': 1.0,
        'max_c_rate_discharge': 2.0,
        'operating_temp_c': (-20, 55),
        'optimal_temp_c': (15, 35),
        'thermal_runaway_risk': 'Medium',
        'cost_usd_per_kwh': 140,
        'dod_recommended': 0.80,
        'self_discharge_per_month': 0.03,
        'best_for': 'Higher energy density, EV, space-constrained',
    },
    'NCA': {
        'full_name': 'Nickel Cobalt Aluminum',
        'nominal_voltage': 3.6,
        'energy_density_wh_kg': 250,
        'cycle_life': 2000,
        'calendar_life_years': 10,
        'round_trip_efficiency': 0.93,
        'max_c_rate_charge': 0.7,
        'max_c_rate_discharge': 1.5,
        'operating_temp_c': (-20, 50),
        'thermal_runaway_risk': 'High',
        'cost_usd_per_kwh': 150,
        'dod_recommended': 0.80,
        'best_for': 'Highest energy density, EV applications',
    },
}
```

## BESS Sizing Calculator

```python
def size_bess(application: str, pv_kwp: float = 0,
              daily_load_kwh: float = 0, peak_load_kw: float = 0,
              peak_shave_target_kw: float = 0,
              backup_hours: float = 4,
              chemistry: str = 'LFP') -> dict:
    """
    application: 'self_consumption' | 'peak_shaving' | 'backup' | 'hybrid'
    """
    chem = BATTERY_CHEMISTRIES[chemistry]
    dod = chem['dod_recommended']
    rte = chem['round_trip_efficiency']

    if application == 'self_consumption':
        # Store excess PV for evening use (~30-50% of daily PV generation)
        daily_pv_kwh = pv_kwp * 4.5  # Avg PSH
        excess_pv = daily_pv_kwh * 0.40
        usable_kwh = excess_pv / rte
        power_kw = usable_kwh / 4  # 4-hour discharge

    elif application == 'peak_shaving':
        shave_amount = peak_load_kw - peak_shave_target_kw
        duration_hours = 3  # Typical peak duration
        usable_kwh = shave_amount * duration_hours
        power_kw = shave_amount

    elif application == 'backup':
        usable_kwh = peak_load_kw * backup_hours
        power_kw = peak_load_kw

    elif application == 'hybrid':
        pv_excess = pv_kwp * 4.5 * 0.40
        backup_kwh = peak_load_kw * backup_hours * 0.3
        usable_kwh = max(pv_excess, backup_kwh)
        power_kw = peak_load_kw

    # Gross capacity (account for DOD)
    gross_kwh = usable_kwh / dod
    # Number of cells
    cells_series = int(np.ceil(800 / chem['nominal_voltage']))  # ~800V system
    cell_capacity_ah = gross_kwh * 1000 / (cells_series * chem['nominal_voltage'])

    # Standard rack sizing
    rack_kwh = 200  # Typical rack unit (LFP)
    num_racks = int(np.ceil(gross_kwh / rack_kwh))

    return {
        'application': application,
        'chemistry': chemistry,
        'usable_capacity_kwh': round(usable_kwh, 1),
        'gross_capacity_kwh': round(gross_kwh, 1),
        'rated_power_kw': round(power_kw, 1),
        'c_rate': round(power_kw / gross_kwh, 2),
        'cells_in_series': cells_series,
        'system_voltage': round(cells_series * chem['nominal_voltage'], 0),
        'num_racks': num_racks,
        'estimated_cycles': chem['cycle_life'],
        'estimated_lifetime_years': min(chem['calendar_life_years'],
                                        int(chem['cycle_life'] / 365)),
        'weight_kg': round(gross_kwh * 1000 / chem['energy_density_wh_kg'], 0),
        'estimated_cost_usd': round(gross_kwh * chem['cost_usd_per_kwh'], 0),
        'round_trip_efficiency': chem['round_trip_efficiency'],
    }

# 1MWp PV + BESS for self-consumption
bess = size_bess('self_consumption', pv_kwp=1000, chemistry='LFP')
# Peak shaving: reduce 500kW peak to 300kW
bess_ps = size_bess('peak_shaving', peak_load_kw=500, peak_shave_target_kw=300)
```

## BMS Core Algorithms

### SOC Estimation (Coulomb Counting + OCV Correction)

```python
class BMSController:
    """Battery Management System core algorithms."""

    def __init__(self, capacity_ah: float, cells_series: int,
                 cells_parallel: int, chemistry: str = 'LFP'):
        self.capacity_ah = capacity_ah
        self.cells_s = cells_series
        self.cells_p = cells_parallel
        self.chem = BATTERY_CHEMISTRIES[chemistry]
        self.soc = 1.0
        self.soh = 1.0
        self.cycle_count = 0
        self.total_ah_throughput = 0

        # LFP OCV-SOC lookup (V per cell)
        self.ocv_soc_table = {
            3.65: 1.00, 3.35: 0.90, 3.32: 0.70, 3.30: 0.50,
            3.28: 0.30, 3.25: 0.20, 3.20: 0.10, 2.80: 0.05, 2.50: 0.00,
        }

    def update_soc_coulomb(self, current_a: float, dt_seconds: float):
        """Coulomb counting SOC update."""
        delta_ah = current_a * dt_seconds / 3600
        self.soc -= delta_ah / (self.capacity_ah * self.soh)
        self.soc = np.clip(self.soc, 0, 1)
        self.total_ah_throughput += abs(delta_ah)

    def correct_soc_ocv(self, cell_voltage: float):
        """OCV-based SOC correction (only valid at rest, I≈0)."""
        voltages = sorted(self.ocv_soc_table.keys())
        for i in range(len(voltages) - 1):
            if voltages[i] <= cell_voltage <= voltages[i + 1]:
                v_range = voltages[i + 1] - voltages[i]
                soc_range = self.ocv_soc_table[voltages[i + 1]] - self.ocv_soc_table[voltages[i]]
                self.soc = self.ocv_soc_table[voltages[i]] + \
                           (cell_voltage - voltages[i]) / v_range * soc_range
                break

    def estimate_soh(self) -> float:
        """SOH estimation based on cycle count."""
        equivalent_cycles = self.total_ah_throughput / (2 * self.capacity_ah)
        self.cycle_count = int(equivalent_cycles)
        # Linear degradation model
        self.soh = max(0.5, 1.0 - (equivalent_cycles / self.chem['cycle_life']) * 0.2)
        return self.soh

    def cell_balancing_check(self, cell_voltages: list[float]) -> dict:
        """Passive cell balancing decision."""
        v_min = min(cell_voltages)
        v_max = max(cell_voltages)
        v_avg = np.mean(cell_voltages)
        imbalance = v_max - v_min

        cells_to_balance = []
        BALANCE_THRESHOLD = 0.020  # 20mV

        if imbalance > BALANCE_THRESHOLD:
            for i, v in enumerate(cell_voltages):
                if v - v_min > BALANCE_THRESHOLD:
                    cells_to_balance.append({
                        'cell': i + 1,
                        'voltage': v,
                        'excess_mv': round((v - v_avg) * 1000, 1),
                        'action': 'BLEED_RESISTOR_ON',
                    })

        return {
            'v_min': round(v_min, 3),
            'v_max': round(v_max, 3),
            'v_avg': round(v_avg, 3),
            'imbalance_mv': round(imbalance * 1000, 1),
            'balancing_needed': imbalance > BALANCE_THRESHOLD,
            'cells_to_balance': cells_to_balance,
        }

    def thermal_management(self, cell_temps: list[float]) -> dict:
        """Thermal management decisions."""
        t_min = min(cell_temps)
        t_max = max(cell_temps)
        t_avg = np.mean(cell_temps)
        t_delta = t_max - t_min

        action = 'NORMAL'
        if t_max > 45:
            action = 'ACTIVE_COOLING_ON'
        elif t_max > 55:
            action = 'REDUCE_POWER_50PCT'
        elif t_max > 60:
            action = 'SHUTDOWN_PROTECTION'
        elif t_min < 0:
            action = 'HEATING_ON'
        elif t_min < -10:
            action = 'DISABLE_CHARGING'

        if t_delta > 5:
            action += ' + BALANCE_AIRFLOW'

        return {
            't_min': t_min, 't_max': t_max, 't_avg': round(t_avg, 1),
            'delta_t': round(t_delta, 1), 'action': action,
        }

    def protection_check(self, pack_voltage: float, pack_current: float,
                          cell_voltages: list, cell_temps: list) -> dict:
        """BMS protection logic."""
        alarms = []
        trips = []

        # Over-voltage
        if max(cell_voltages) > 3.65:
            alarms.append('CELL_OV_WARNING')
        if max(cell_voltages) > 3.75:
            trips.append('CELL_OV_TRIP')

        # Under-voltage
        if min(cell_voltages) < 2.80:
            alarms.append('CELL_UV_WARNING')
        if min(cell_voltages) < 2.50:
            trips.append('CELL_UV_TRIP')

        # Over-current
        max_current = self.capacity_ah * self.chem['max_c_rate_discharge']
        if abs(pack_current) > max_current * 0.9:
            alarms.append('OC_WARNING')
        if abs(pack_current) > max_current:
            trips.append('OC_TRIP')

        # Over-temperature
        if max(cell_temps) > 55:
            alarms.append('OT_WARNING')
        if max(cell_temps) > 65:
            trips.append('OT_TRIP')

        return {
            'status': 'TRIP' if trips else 'ALARM' if alarms else 'NORMAL',
            'alarms': alarms,
            'trips': trips,
            'soc': round(self.soc * 100, 1),
            'soh': round(self.soh * 100, 1),
        }
```

## Cycle Life & Degradation Model

```python
def model_degradation(chemistry: str, daily_cycles: float,
                       avg_dod: float, avg_temp: float,
                       years: int = 20) -> pd.DataFrame:
    """Model battery degradation over time."""
    chem = BATTERY_CHEMISTRIES[chemistry]
    base_cycles = chem['cycle_life']

    # Temperature acceleration factor (Arrhenius)
    t_ref = 25
    temp_factor = np.exp(0.03 * (avg_temp - t_ref))

    # DOD stress factor
    dod_factor = (avg_dod / 0.8) ** 1.5

    effective_cycle_life = base_cycles / (temp_factor * dod_factor)

    results = []
    cumulative_cycles = 0
    capacity_pct = 100

    for year in range(1, years + 1):
        annual_cycles = daily_cycles * 365
        cumulative_cycles += annual_cycles
        cycle_degradation = (annual_cycles / effective_cycle_life) * 20  # 20% total degradation
        calendar_degradation = 0.5  # 0.5% per year calendar aging
        total_degradation = cycle_degradation + calendar_degradation
        capacity_pct -= total_degradation

        results.append({
            'year': year,
            'cumulative_cycles': int(cumulative_cycles),
            'capacity_pct': round(max(capacity_pct, 60), 1),
            'soh': round(max(capacity_pct, 60) / 100, 3),
            'eol': capacity_pct <= 80,
        })

    df = pd.DataFrame(results)
    eol_year = df[df['eol']].iloc[0]['year'] if df['eol'].any() else years
    return df, eol_year
```

## Container BESS Layout

```python
def design_container_bess(total_kwh: float, total_kw: float,
                           chemistry: str = 'LFP') -> dict:
    """Design containerized BESS system."""
    chem = BATTERY_CHEMISTRIES[chemistry]

    # Standard 20ft container: ~1 MWh / 500kW
    # Standard 40ft container: ~2-4 MWh / 1-2 MW
    rack_kwh = 200  # Standard rack
    rack_kw = 100

    num_racks = int(np.ceil(total_kwh / rack_kwh))
    racks_per_20ft = 8
    racks_per_40ft = 16

    if num_racks <= racks_per_20ft:
        container = '20ft'
        num_containers = 1
    else:
        container = '40ft'
        num_containers = int(np.ceil(num_racks / racks_per_40ft))

    return {
        'total_kwh': total_kwh,
        'total_kw': total_kw,
        'chemistry': chemistry,
        'num_racks': num_racks,
        'container_type': container,
        'num_containers': num_containers,
        'pcs_kw': total_kw,  # Power Conversion System
        'cooling': 'Liquid cooling' if total_kwh > 500 else 'Forced air',
        'fire_suppression': 'Aerosol / Novec 1230',
        'hvac_kw': round(total_kwh * 0.02, 1),
        'aux_power_kw': round(total_kwh * 0.03, 1),
        'footprint_m2': num_containers * (12.2 if container == '40ft' else 6.1) * 2.44,
    }
```

## Safety Standards Reference

| Standard | Scope | Required For |
|----------|-------|-------------|
| IEC 62619 | Safety of Li-ion for industrial | All BESS |
| UL 9540 | Energy storage systems | US market |
| UL 9540A | Thermal runaway fire test | US, insurance |
| IEC 62933 | Electrical energy storage systems | International |
| NFPA 855 | Installation of ESS | US fire code |
| GB/T 36276 | Li-ion for electrical storage | China market |
| AS 5139 | Battery installation | Australia |
