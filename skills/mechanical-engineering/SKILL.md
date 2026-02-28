---
name: mechanical-engineering
description: Mechanical engineering calculations, CAD automation, FEA stress analysis, thermal analysis, bearing/gear/shaft selection, material properties, and manufacturing process optimization. Covers structural mechanics, fluid dynamics, vibration analysis, and Python-based engineering tools (FreeCAD, CadQuery, PyMAPDL). Use when designing mechanical systems, performing stress calculations, sizing components, or automating CAD/CAM workflows.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Mechanical Engineering, CAD, FEA, Stress Analysis, Thermal, Bearing, Shaft, Gear, CadQuery, Material Selection]
dependencies: [numpy, scipy, matplotlib, cadquery, pint]
---

# Mechanical Engineering

## When to Use

- Structural stress and deflection calculations
- Shaft, bearing, gear design and selection
- Thermal analysis and heat transfer
- CAD automation with CadQuery/FreeCAD scripting
- Material selection and comparison
- Vibration and fatigue analysis
- Bolt, weld, and joint calculations

## Beam Analysis (Simply Supported)

```python
import numpy as np
import matplotlib.pyplot as plt

def simply_supported_beam(length: float, loads: list[dict],
                           E: float = 200e9, I: float = 1e-5) -> dict:
    """
    loads: [{'type': 'point'|'udl', 'value': N or N/m, 'position': m, 'length': m}]
    E: Young's modulus (Pa), I: Moment of inertia (m^4)
    """
    x = np.linspace(0, length, 500)
    M = np.zeros_like(x)  # Bending moment
    V = np.zeros_like(x)  # Shear force

    for load in loads:
        if load['type'] == 'point':
            P, a = load['value'], load['position']
            b = length - a
            R_A = P * b / length
            R_B = P * a / length
            for i, xi in enumerate(x):
                V[i] += R_A - (P if xi >= a else 0)
                if xi < a:
                    M[i] += R_A * xi
                else:
                    M[i] += R_A * xi - P * (xi - a)
        elif load['type'] == 'udl':
            w = load['value']
            R = w * length / 2
            for i, xi in enumerate(x):
                V[i] += R - w * xi
                M[i] += R * xi - w * xi**2 / 2

    M_max = np.max(np.abs(M))
    V_max = np.max(np.abs(V))
    deflection_max = M_max * length**2 / (8 * E * I) if E and I else None

    return {
        'x': x, 'moment': M, 'shear': V,
        'max_moment_nm': round(M_max, 2),
        'max_shear_n': round(V_max, 2),
        'max_deflection_mm': round(deflection_max * 1000, 3) if deflection_max else None,
    }

# 5m beam, 10kN point load at center, 2kN/m UDL
result = simply_supported_beam(5.0, [
    {'type': 'point', 'value': 10000, 'position': 2.5},
    {'type': 'udl', 'value': 2000, 'position': 0, 'length': 5.0},
])
```

## Shaft Design

```python
def design_shaft(torque_nm: float, bending_nm: float,
                 material_sy: float = 250e6,  # Yield strength (Pa)
                 safety_factor: float = 2.5,
                 kb: float = 1.5, kt: float = 1.0) -> dict:
    """ASME method for shaft diameter calculation."""
    import math

    allowable = material_sy / safety_factor
    sigma_b = 32 * kb * bending_nm / math.pi
    tau_t = 16 * kt * torque_nm / math.pi

    # Von Mises equivalent
    d_cubed = (16 / (math.pi * allowable)) * math.sqrt(
        (2 * kb * bending_nm)**2 + 3 * (kt * torque_nm)**2
    )
    diameter = d_cubed ** (1/3) * 1000  # Convert to mm

    standard_sizes = [10, 12, 15, 17, 20, 25, 30, 35, 40, 45, 50,
                      55, 60, 65, 70, 75, 80, 90, 100, 110, 120]
    selected = next(s for s in standard_sizes if s >= diameter)

    return {
        'calculated_diameter_mm': round(diameter, 1),
        'selected_diameter_mm': selected,
        'max_shear_stress_mpa': round(tau_t / (selected/1000)**3 / 1e6, 1),
    }

print(design_shaft(500, 800, material_sy=350e6))
```

## Bearing Selection

```python
def select_bearing(radial_load_n: float, axial_load_n: float,
                   speed_rpm: float, desired_life_hours: float = 20000,
                   load_factor: float = 1.2) -> dict:
    import math

    # Equivalent dynamic load (for ball bearings, e=0.56)
    if axial_load_n / radial_load_n <= 0.56:
        P = radial_load_n * load_factor
    else:
        P = (0.56 * radial_load_n + 1.2 * axial_load_n) * load_factor

    # Required dynamic capacity
    L10_rev = desired_life_hours * 60 * speed_rpm
    C_required = P * (L10_rev / 1e6) ** (1/3)  # Ball bearing exponent = 3

    # Standard bearing database (simplified)
    bearings = [
        {'id': '6205', 'bore_mm': 25, 'C_kn': 14.8, 'C0_kn': 7.8},
        {'id': '6206', 'bore_mm': 30, 'C_kn': 19.5, 'C0_kn': 10.0},
        {'id': '6207', 'bore_mm': 35, 'C_kn': 25.5, 'C0_kn': 13.7},
        {'id': '6208', 'bore_mm': 40, 'C_kn': 29.1, 'C0_kn': 16.0},
        {'id': '6210', 'bore_mm': 50, 'C_kn': 35.1, 'C0_kn': 19.8},
        {'id': '6212', 'bore_mm': 60, 'C_kn': 43.6, 'C0_kn': 26.0},
    ]

    suitable = [b for b in bearings if b['C_kn'] * 1000 >= C_required]
    selected = suitable[0] if suitable else None

    if selected:
        actual_life = (selected['C_kn'] * 1000 / P) ** 3 * 1e6 / (60 * speed_rpm)
    else:
        actual_life = 0

    return {
        'equivalent_load_n': round(P),
        'required_C_kn': round(C_required / 1000, 1),
        'selected_bearing': selected['id'] if selected else 'None - check larger series',
        'actual_life_hours': round(actual_life) if selected else 0,
    }

print(select_bearing(5000, 1000, 1500, desired_life_hours=20000))
```

## CAD Automation with CadQuery

```bash
pip install cadquery
```

```python
import cadquery as cq

# Parametric bracket
def create_bracket(width=50, height=80, thickness=5, hole_dia=10,
                   fillet_r=3):
    bracket = (
        cq.Workplane("XY")
        .box(width, height, thickness)
        .faces(">Z")
        .workplane()
        .hole(hole_dia)
        .faces(">Z")
        .workplane(offset=-height/2 + 15)
        .hole(hole_dia)
        .edges("|Z")
        .fillet(fillet_r)
    )
    cq.exporters.export(bracket, "bracket.step")
    return bracket

# Parametric gear (spur)
def create_spur_gear(module=2, num_teeth=20, face_width=10, bore_dia=12):
    import math
    pitch_r = module * num_teeth / 2
    addendum = module
    dedendum = 1.25 * module

    outer_r = pitch_r + addendum
    root_r = pitch_r - dedendum

    gear = (
        cq.Workplane("XY")
        .circle(outer_r)
        .extrude(face_width)
        .faces(">Z")
        .workplane()
        .hole(bore_dia)
    )
    cq.exporters.export(gear, f"gear_m{module}_z{num_teeth}.step")
    return gear
```

## Material Properties Database

```python
MATERIALS = {
    'Steel_S235': {'Sy': 235, 'Su': 360, 'E': 200, 'density': 7850, 'poisson': 0.3},
    'Steel_S355': {'Sy': 355, 'Su': 510, 'E': 200, 'density': 7850, 'poisson': 0.3},
    'Steel_4140': {'Sy': 655, 'Su': 900, 'E': 200, 'density': 7850, 'poisson': 0.3},
    'Stainless_304': {'Sy': 215, 'Su': 505, 'E': 193, 'density': 8000, 'poisson': 0.29},
    'Aluminum_6061T6': {'Sy': 276, 'Su': 310, 'E': 69, 'density': 2700, 'poisson': 0.33},
    'Cast_Iron': {'Sy': 130, 'Su': 200, 'E': 100, 'density': 7200, 'poisson': 0.26},
    'Brass': {'Sy': 200, 'Su': 350, 'E': 100, 'density': 8500, 'poisson': 0.34},
}
# Units: Sy/Su in MPa, E in GPa, density in kg/m³
```

## Thermal Analysis

```python
def heat_transfer(mode: str, **kwargs) -> dict:
    """Calculate heat transfer for conduction, convection, radiation."""
    if mode == 'conduction':
        k, A, dT, L = kwargs['k'], kwargs['A'], kwargs['dT'], kwargs['L']
        Q = k * A * dT / L
        return {'Q_watts': round(Q, 2), 'mode': 'conduction'}

    elif mode == 'convection':
        h, A, dT = kwargs['h'], kwargs['A'], kwargs['dT']
        Q = h * A * dT
        return {'Q_watts': round(Q, 2), 'mode': 'convection'}

    elif mode == 'radiation':
        epsilon, A, T1, T2 = kwargs['epsilon'], kwargs['A'], kwargs['T1'], kwargs['T2']
        sigma = 5.67e-8  # Stefan-Boltzmann
        Q = epsilon * sigma * A * (T1**4 - T2**4)
        return {'Q_watts': round(Q, 2), 'mode': 'radiation'}

# Conduction through steel wall
print(heat_transfer('conduction', k=50, A=2, dT=100, L=0.01))
# Convection from surface
print(heat_transfer('convection', h=25, A=2, dT=50))
```

## Bolt Torque Calculator

```python
def bolt_torque(bolt_grade: str, bolt_dia_mm: float,
                friction_coeff: float = 0.15) -> dict:
    grades = {
        '4.8': {'proof': 310, 'yield': 340, 'ult': 420},
        '8.8': {'proof': 600, 'yield': 640, 'ult': 800},
        '10.9': {'proof': 830, 'yield': 940, 'ult': 1040},
        '12.9': {'proof': 970, 'yield': 1100, 'ult': 1220},
    }
    import math
    grade = grades[bolt_grade]
    stress_area = math.pi / 4 * (bolt_dia_mm * 0.001) ** 2 * 0.75  # Approx
    clamp_force = grade['proof'] * 1e6 * stress_area * 0.75  # 75% of proof
    torque = friction_coeff * clamp_force * bolt_dia_mm * 0.001

    return {
        'bolt': f'M{bolt_dia_mm} Grade {bolt_grade}',
        'clamp_force_kn': round(clamp_force / 1000, 1),
        'torque_nm': round(torque, 1),
        'max_torque_nm': round(torque * 1.33, 1),
    }

print(bolt_torque('8.8', 12))
```
