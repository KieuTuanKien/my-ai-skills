---
name: construction-engineering
description: Construction and structural engineering - reinforced concrete design, steel structure design, foundation calculations, quantity surveying (BOQ), project scheduling (CPM/Gantt), and BIM automation. Covers beam/column/slab design per Eurocode/ACI, earthwork volume, cost estimation, and construction project management. Use when designing structures, estimating quantities, calculating foundations, or managing construction projects.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Construction, Structural Engineering, Reinforced Concrete, Steel Structure, Foundation, BOQ, BIM, Project Management, Eurocode, ACI]
dependencies: [numpy, pandas, matplotlib, openpyxl]
---

# Construction Engineering

## When to Use

- Reinforced concrete beam/column/slab design
- Steel structure member selection
- Foundation design (shallow/deep)
- Bill of Quantities (BOQ) and cost estimation
- Earthwork volume calculation
- Project scheduling (CPM, Gantt chart)
- Construction material estimation

## RC Beam Design (Simplified - ACI 318 / Eurocode 2)

```python
import math

def design_rc_beam(Mu_knm: float, b_mm: float = 300, fck: float = 25,
                    fy: float = 420, cover_mm: float = 40,
                    code: str = 'ACI') -> dict:
    """
    Mu_knm: Ultimate bending moment (kN·m)
    b_mm: Beam width (mm)
    fck: Concrete compressive strength (MPa)
    fy: Steel yield strength (MPa)
    """
    Mu = Mu_knm * 1e6  # Convert to N·mm

    if code == 'ACI':
        phi = 0.9
        beta1 = 0.85 if fck <= 28 else max(0.65, 0.85 - 0.05 * (fck - 28) / 7)
        fc_design = 0.85 * fck
    else:  # Eurocode
        phi = 1.0
        fc_design = 0.567 * fck  # αcc * fck / γc
        fy = fy / 1.15  # fyk / γs

    # Estimate effective depth
    d_mm = b_mm * 1.5  # Initial estimate

    # Required area of steel
    Rn = Mu / (phi * b_mm * d_mm**2)
    rho = (fc_design / fy) * (1 - math.sqrt(1 - 2 * Rn / fc_design))

    # Check limits
    rho_min = max(1.4 / fy, 0.25 * math.sqrt(fck) / fy)
    rho_max = 0.75 * beta1 * fc_design / fy * 600 / (600 + fy) if code == 'ACI' else 0.04

    rho = max(rho, rho_min)
    As_mm2 = rho * b_mm * d_mm

    # Select rebars
    rebar_areas = {10: 78.5, 12: 113.1, 16: 201.1, 20: 314.2, 25: 490.9, 32: 804.2}
    for dia, area in sorted(rebar_areas.items()):
        n_bars = math.ceil(As_mm2 / area)
        if n_bars <= 6 and n_bars * dia + (n_bars + 1) * 25 <= b_mm - 2 * cover_mm:
            break

    h_mm = d_mm + cover_mm + dia / 2 + 10  # 10mm stirrup
    h_mm = math.ceil(h_mm / 50) * 50  # Round to 50mm

    return {
        'beam_size': f'{int(b_mm)} x {int(h_mm)} mm',
        'effective_depth_mm': int(d_mm),
        'As_required_mm2': round(As_mm2, 1),
        'reinforcement': f'{n_bars}T{dia}',
        'As_provided_mm2': round(n_bars * area, 1),
        'rho_percent': round(rho * 100, 2),
        'stirrups': 'T10@150 (standard)',
    }

print(design_rc_beam(250, b_mm=300, fck=30, fy=420))
```

## RC Column Design

```python
def design_rc_column(Pu_kn: float, Mu_knm: float, h_mm: float = 400,
                      b_mm: float = 400, fck: float = 30, fy: float = 420) -> dict:
    Pu = Pu_kn * 1000
    Mu = Mu_knm * 1e6

    Ag = b_mm * h_mm
    d = h_mm - 60  # Cover + rebar

    # Minimum steel (1% of Ag)
    As_min = 0.01 * Ag
    # Maximum steel (8% of Ag in Eurocode, 4% practical)
    As_max = 0.04 * Ag

    # Approximate As from interaction (simplified)
    e = Mu / Pu if Pu > 0 else h_mm
    As = max(As_min, (Pu - 0.45 * fck * Ag) / (0.87 * fy - 0.45 * fck) if e < h_mm / 6
             else (Pu * e - 0.167 * fck * b_mm * d**2) / (0.87 * fy * (d - 60)))
    As = max(As_min, min(As, As_max))

    rebar_areas = {16: 201.1, 20: 314.2, 25: 490.9, 32: 804.2}
    for dia, area in sorted(rebar_areas.items()):
        n_bars = math.ceil(As / area)
        if n_bars >= 4 and n_bars % 2 == 0:
            break

    return {
        'column_size': f'{int(b_mm)} x {int(h_mm)} mm',
        'As_required_mm2': round(As, 1),
        'reinforcement': f'{n_bars}T{dia}',
        'As_provided_mm2': round(n_bars * area, 1),
        'ties': f'T10@{min(300, 16*dia, min(b_mm,h_mm))} mm',
        'concrete_volume_m3_per_m': round(Ag * 1e-6, 4),
    }

print(design_rc_column(1500, 120, h_mm=400, b_mm=400))
```

## Foundation Design (Isolated Footing)

```python
def design_footing(column_load_kn: float, moment_knm: float = 0,
                    soil_bearing_kpa: float = 150, fck: float = 25,
                    column_size_mm: float = 400) -> dict:
    load = column_load_kn + column_load_kn * 0.10  # 10% self-weight

    # Required area
    A_required = load / soil_bearing_kpa * 1.1  # 10% safety
    L = math.ceil(math.sqrt(A_required) * 100) / 100
    L = max(L, column_size_mm / 1000 + 0.3)

    # Round to nearest 0.1m
    L = math.ceil(L * 10) / 10

    # Actual bearing pressure
    q_actual = load / (L * L)

    # Depth (punching shear check - simplified)
    d = max(300, int(L * 1000 / 4))
    d = math.ceil(d / 50) * 50

    # Bottom reinforcement
    cantilever = (L * 1000 - column_size_mm) / 2
    Mu = q_actual * 1.5 * L * cantilever**2 / 2 / 1e6  # kN·m per m width
    As_per_m = max(Mu * 1e6 / (0.87 * 420 * 0.9 * d), 0.0013 * 1000 * d)

    rebar_areas = {10: 78.5, 12: 113.1, 16: 201.1, 20: 314.2}
    for dia, area in sorted(rebar_areas.items()):
        spacing = area * 1000 / As_per_m
        if spacing >= 100:
            spacing = min(int(spacing / 25) * 25, 300)
            break

    concrete_vol = L * L * (d + 75) / 1000

    return {
        'footing_size': f'{L} x {L} x {(d+75)/1000:.2f} m',
        'bearing_pressure_kpa': round(q_actual, 1),
        'bearing_capacity_kpa': soil_bearing_kpa,
        'utilization': f'{q_actual/soil_bearing_kpa*100:.0f}%',
        'bottom_steel': f'T{dia}@{spacing} both ways',
        'concrete_m3': round(concrete_vol, 2),
    }

print(design_footing(800, soil_bearing_kpa=150))
```

## Bill of Quantities (BOQ) Generator

```python
def generate_boq(items: list[dict]) -> pd.DataFrame:
    """
    items: [{'description': str, 'unit': str, 'quantity': float,
             'unit_rate': float, 'category': str}]
    """
    df = pd.DataFrame(items)
    df['amount'] = df['quantity'] * df['unit_rate']

    summary = df.groupby('category')['amount'].sum().reset_index()
    total = df['amount'].sum()

    df_display = df[['category', 'description', 'unit', 'quantity', 'unit_rate', 'amount']]
    df_display.columns = ['Category', 'Description', 'Unit', 'Qty', 'Rate', 'Amount']

    return {'details': df_display, 'summary': summary, 'total': total}

boq_items = [
    {'description': 'Excavation', 'unit': 'm³', 'quantity': 120, 'unit_rate': 15, 'category': 'Earthwork'},
    {'description': 'Concrete C30', 'unit': 'm³', 'quantity': 45, 'unit_rate': 120, 'category': 'Concrete'},
    {'description': 'Rebar T16', 'unit': 'kg', 'quantity': 3500, 'unit_rate': 1.2, 'category': 'Steel'},
    {'description': 'Formwork', 'unit': 'm²', 'quantity': 280, 'unit_rate': 25, 'category': 'Formwork'},
    {'description': 'Brickwork', 'unit': 'm²', 'quantity': 450, 'unit_rate': 35, 'category': 'Masonry'},
]
result = generate_boq(boq_items)
```

## Project Scheduling (CPM)

```python
def critical_path_method(activities: list[dict]) -> dict:
    """
    activities: [{'id': str, 'name': str, 'duration': int,
                  'predecessors': list[str]}]
    """
    tasks = {a['id']: a for a in activities}

    # Forward pass
    for a in activities:
        predecessors = a.get('predecessors', [])
        a['ES'] = max((tasks[p]['EF'] for p in predecessors), default=0)
        a['EF'] = a['ES'] + a['duration']

    project_duration = max(a['EF'] for a in activities)

    # Backward pass
    for a in reversed(activities):
        successors = [t for t in activities if a['id'] in t.get('predecessors', [])]
        a['LF'] = min((t['LS'] for t in successors), default=project_duration)
        a['LS'] = a['LF'] - a['duration']
        a['float'] = a['LS'] - a['ES']
        a['critical'] = a['float'] == 0

    critical_path = [a['id'] for a in activities if a['critical']]

    return {
        'project_duration': project_duration,
        'critical_path': critical_path,
        'schedule': pd.DataFrame([
            {k: a[k] for k in ['id', 'name', 'duration', 'ES', 'EF', 'LS', 'LF', 'float', 'critical']}
            for a in activities
        ]),
    }

activities = [
    {'id': 'A', 'name': 'Site Prep', 'duration': 5, 'predecessors': []},
    {'id': 'B', 'name': 'Foundation', 'duration': 10, 'predecessors': ['A']},
    {'id': 'C', 'name': 'Structure', 'duration': 20, 'predecessors': ['B']},
    {'id': 'D', 'name': 'MEP Rough-in', 'duration': 15, 'predecessors': ['C']},
    {'id': 'E', 'name': 'Finishing', 'duration': 12, 'predecessors': ['D']},
    {'id': 'F', 'name': 'Landscaping', 'duration': 8, 'predecessors': ['B']},
]
print(critical_path_method(activities))
```

## Concrete Mix Design

```python
def concrete_mix_design(grade: str = 'C30', cement_type: str = 'OPC',
                         slump_mm: int = 100, max_agg_mm: int = 20) -> dict:
    """Simplified DOE method for concrete mix design."""
    grades = {
        'C20': {'fck': 20, 'w_c': 0.60},
        'C25': {'fck': 25, 'w_c': 0.55},
        'C30': {'fck': 30, 'w_c': 0.50},
        'C35': {'fck': 35, 'w_c': 0.45},
        'C40': {'fck': 40, 'w_c': 0.40},
    }
    g = grades[grade]
    water = 180 if slump_mm <= 100 else 195  # kg/m³
    cement = water / g['w_c']

    # Aggregate proportions
    total_agg = 2400 - cement - water  # Approximate total density
    fine_agg_ratio = 0.40 if max_agg_mm == 20 else 0.35
    fine_agg = total_agg * fine_agg_ratio
    coarse_agg = total_agg * (1 - fine_agg_ratio)

    return {
        'grade': grade,
        'cement_kg_per_m3': round(cement),
        'water_kg_per_m3': water,
        'fine_aggregate_kg_per_m3': round(fine_agg),
        'coarse_aggregate_kg_per_m3': round(coarse_agg),
        'w_c_ratio': g['w_c'],
        'ratio': f'1 : {fine_agg/cement:.1f} : {coarse_agg/cement:.1f}',
    }

print(concrete_mix_design('C30'))
```

## Earthwork Volume (Prismoidal)

```python
def earthwork_volume(sections: list[dict], interval: float) -> dict:
    """
    sections: [{'station': float, 'cut_area': float, 'fill_area': float}]
    interval: distance between sections (m)
    """
    total_cut = 0
    total_fill = 0

    for i in range(len(sections) - 1):
        s1, s2 = sections[i], sections[i+1]
        cut = (s1['cut_area'] + s2['cut_area']) / 2 * interval
        fill = (s1['fill_area'] + s2['fill_area']) / 2 * interval
        total_cut += cut
        total_fill += fill

    return {
        'total_cut_m3': round(total_cut, 1),
        'total_fill_m3': round(total_fill, 1),
        'net_m3': round(total_cut - total_fill, 1),
        'balance': 'Export' if total_cut > total_fill else 'Import',
    }
```
