---
name: revit-mep-automation
description: |
  Automate MEP (Mechanical, Electrical, Plumbing) system design in Autodesk Revit
  using pyRevit, Dynamo, and Revit API (C#/Python). Covers electrical panel schedules,
  circuit routing, cable tray layout, lighting design, HVAC duct sizing, pipe sizing,
  equipment placement, clash detection, and schedule generation.
  Use when designing electrical/mechanical systems in Revit, automating MEP workflows,
  creating Dynamo scripts for routing, or generating BOQ/schedules from Revit models.
version: 1.0.0
tags: [Revit, MEP, Electrical, Mechanical, HVAC, Dynamo, pyRevit, Automation, BIM]
dependencies: [pyrevit, revitpythonshell, dynamo, numpy, pandas, openpyxl]
---

# Goal

Automate MEP design workflows in Revit — from load calculation to equipment placement
to cable/duct routing — reducing manual drafting time by 60-80% while maintaining
compliance with IEC, TCVN, NEC, and ASHRAE standards.

# Instructions

## Phase 1: Project Setup & Standards

1. Identify project type and applicable standards:
   - **Electrical**: IEC 60364, TCVN 9206, NEC (NFPA 70), BS 7671
   - **Mechanical**: ASHRAE, SMACNA, TCVN 5687, EN 12831
   - **Plumbing**: IPC, TCVN 4513, BS EN 12056
2. Determine Revit version and available tools:
   - Revit 2022+: Use Revit API via pyRevit (IronPython/CPython)
   - Dynamo 2.x: Visual programming for parametric design
   - RevitPythonShell: Quick scripting and testing
3. Set up MEP templates with correct system classifications

## Phase 2: Electrical System Design

### 2.1 Load Calculation & Panel Schedule

```python
# pyRevit script: Auto-generate panel schedule from room loads
import clr
clr.AddReference('RevitAPI')
clr.AddReference('RevitServices')
from Autodesk.Revit.DB import *
from Autodesk.Revit.DB.Electrical import *
from RevitServices.Persistence import DocumentManager

doc = DocumentManager.Instance.CurrentDBDocument

def get_room_electrical_loads(doc):
    """Extract electrical loads from rooms with lighting + power."""
    rooms = FilteredElementCollector(doc)\
        .OfCategory(BuiltInCategory.OST_Rooms)\
        .WhereElementIsNotElementType()\
        .ToElements()

    loads = []
    for room in rooms:
        area = room.get_Parameter(BuiltInParameter.ROOM_AREA).AsDouble() * 0.0929  # ft² → m²
        name = room.get_Parameter(BuiltInParameter.ROOM_NAME).AsString()
        level = doc.GetElement(room.LevelId).Name

        lighting_w_per_m2 = get_lighting_density(name)
        power_w_per_m2 = get_power_density(name)

        loads.append({
            'room': name,
            'level': level,
            'area_m2': round(area, 1),
            'lighting_w': round(area * lighting_w_per_m2),
            'power_w': round(area * power_w_per_m2),
            'total_w': round(area * (lighting_w_per_m2 + power_w_per_m2)),
        })
    return loads


def get_lighting_density(room_name: str) -> float:
    """W/m² per TCVN 9206 / ASHRAE 90.1."""
    densities = {
        'office': 12, 'meeting': 15, 'corridor': 5,
        'lobby': 10, 'toilet': 8, 'parking': 3,
        'server': 5, 'kitchen': 15, 'warehouse': 8,
    }
    name_lower = room_name.lower()
    for key, val in densities.items():
        if key in name_lower:
            return val
    return 10  # default


def get_power_density(room_name: str) -> float:
    """W/m² for general power outlets."""
    densities = {
        'office': 25, 'meeting': 15, 'corridor': 0,
        'server': 500, 'kitchen': 50, 'lobby': 5,
    }
    name_lower = room_name.lower()
    for key, val in densities.items():
        if key in name_lower:
            return val
    return 15
```

### 2.2 Circuit Creation & Panel Assignment

```python
def create_electrical_circuits(doc, panel_name, loads):
    """Auto-create circuits and assign to panel."""
    panels = FilteredElementCollector(doc)\
        .OfCategory(BuiltInCategory.OST_ElectricalEquipment)\
        .WhereElementIsNotElementType()\
        .ToElements()

    target_panel = next((p for p in panels
        if p.Name == panel_name), None)
    if not target_panel:
        raise ValueError(f"Panel '{panel_name}' not found")

    t = Transaction(doc, "Create Circuits")
    t.Start()
    try:
        for load in loads:
            circuit_breaker_a = calculate_breaker(load['total_w'], 230)
            # Assign to nearest available slot
        t.Commit()
    except:
        t.RollBack()
        raise


def calculate_breaker(power_w, voltage, pf=0.85, safety=1.25):
    """Select standard breaker size."""
    current = power_w / (voltage * pf)
    design_current = current * safety
    standard_sizes = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250]
    return next(s for s in standard_sizes if s >= design_current)
```

### 2.3 Cable Tray Routing

```python
def auto_route_cable_tray(doc, start_point, end_point, tray_type="Ladder", width_mm=300):
    """Generate cable tray route using shortest path with obstacle avoidance."""
    # Revit API cable tray creation
    t = Transaction(doc, "Route Cable Tray")
    t.Start()

    tray_type_elem = get_cable_tray_type(doc, tray_type)
    level = get_active_level(doc)

    # Create horizontal run at ceiling - 300mm
    height = get_ceiling_height(doc, level) - 0.3  # meters

    route_points = calculate_route(doc, start_point, end_point, height)

    for i in range(len(route_points) - 1):
        p1 = XYZ(route_points[i][0], route_points[i][1], height / 0.3048)
        p2 = XYZ(route_points[i+1][0], route_points[i+1][1], height / 0.3048)
        CableTray.Create(doc, tray_type_elem.Id, p1, p2, level.Id)

    t.Commit()


def size_cable_tray(cables: list[dict]) -> int:
    """Calculate tray width based on cable fill ratio (max 50% per IEC 61537)."""
    total_area = sum(
        c['diameter_mm']**2 * 3.14159 / 4 * c['quantity']
        for c in cables
    )
    # 50% fill factor
    required_area = total_area / 0.5
    widths = [100, 150, 200, 300, 400, 500, 600, 800, 1000]
    depth = 100  # mm standard
    return next(w for w in widths if w * depth >= required_area)
```

### 2.4 Lighting Layout Automation

```python
def auto_place_lights(doc, room, target_lux, luminaire_family="LED_Panel_600x600"):
    """Auto-calculate and place luminaires to achieve target lux level."""
    area = room.Area * 0.0929  # m²
    height = room.UnboundedHeight * 0.3048  # m
    work_plane = 0.8  # m

    mounting_height = height - work_plane
    maintenance_factor = 0.8
    utilization_factor = get_uf(mounting_height, room)

    luminaire_lumen = 3600  # typical 40W LED panel

    n_luminaires = int(
        (target_lux * area) /
        (luminaire_lumen * utilization_factor * maintenance_factor)
    ) + 1

    grid = calculate_grid_layout(room, n_luminaires)

    t = Transaction(doc, "Place Luminaires")
    t.Start()
    for point in grid:
        place_luminaire(doc, luminaire_family, point, room.LevelId)
    t.Commit()

    return {
        'room': room.get_Parameter(BuiltInParameter.ROOM_NAME).AsString(),
        'area_m2': round(area, 1),
        'target_lux': target_lux,
        'luminaires': n_luminaires,
        'actual_lux': round(
            n_luminaires * luminaire_lumen * utilization_factor * maintenance_factor / area
        ),
    }
```

## Phase 3: Mechanical System Design

### 3.1 HVAC Load Calculation

```python
def calculate_cooling_load(rooms: list[dict], climate_zone="tropical") -> list[dict]:
    """
    Simplified cooling load per ASHRAE method.
    rooms: [{'name': str, 'area_m2': float, 'height_m': float,
             'occupants': int, 'orientation': str, 'glass_pct': float}]
    """
    results = []
    for room in rooms:
        # Transmission (walls + roof)
        u_wall = 2.5  # W/m²·K typical
        u_roof = 1.5
        delta_t = 15 if climate_zone == "tropical" else 10
        wall_area = room['area_m2']**0.5 * 4 * room['height_m']
        q_transmission = wall_area * u_wall * delta_t

        # Solar through glass
        shgc = 0.25
        solar_intensity = {'N': 120, 'S': 350, 'E': 280, 'W': 280}
        glass_area = wall_area * room.get('glass_pct', 0.3)
        q_solar = glass_area * shgc * solar_intensity.get(room.get('orientation', 'N'), 200)

        # Internal loads
        q_people = room.get('occupants', room['area_m2'] / 10) * 120  # W/person
        q_lighting = room['area_m2'] * 12  # W/m²
        q_equipment = room['area_m2'] * 20  # W/m²

        # Ventilation
        cfm_person = 20
        q_ventilation = room.get('occupants', room['area_m2'] / 10) * cfm_person * 1.08 * delta_t

        total_w = q_transmission + q_solar + q_people + q_lighting + q_equipment + q_ventilation
        total_btu = total_w * 3.412
        tonnage = total_btu / 12000

        results.append({
            'room': room['name'],
            'area_m2': room['area_m2'],
            'cooling_w': round(total_w),
            'cooling_btu': round(total_btu),
            'tonnage': round(tonnage, 2),
            'w_per_m2': round(total_w / room['area_m2']),
        })
    return results
```

### 3.2 Duct Sizing

```python
def size_duct(cfm: float, max_velocity_fpm: float = 1200,
              method: str = "equal_friction") -> dict:
    """
    Size rectangular/round duct per ASHRAE/SMACNA.
    method: 'equal_friction' (0.08 inWG/100ft) or 'velocity_reduction'
    """
    import math

    if method == "equal_friction":
        friction_rate = 0.08  # inWG per 100ft
        # Equivalent round diameter (inches)
        d_eq = 0.109 * cfm**0.5 * (friction_rate)**(-0.2)
        velocity = cfm / (math.pi * (d_eq/24)**2)
    else:
        velocity = max_velocity_fpm
        area_sqft = cfm / velocity
        d_eq = (area_sqft * 4 / math.pi)**0.5 * 12  # inches

    # Standard rectangular equivalents
    rect_options = find_rectangular_equivalent(d_eq)

    return {
        'cfm': cfm,
        'round_dia_inch': round(d_eq, 1),
        'velocity_fpm': round(velocity),
        'rectangular_options': rect_options,
        'pressure_drop_per_100ft': round(friction_rate if method == "equal_friction" else
            calculate_friction(d_eq, velocity), 3),
    }


def find_rectangular_equivalent(d_eq_inch: float) -> list[dict]:
    """Find W x H combinations matching equivalent round diameter."""
    import math
    target_area = math.pi * (d_eq_inch / 2)**2
    options = []
    for w in range(6, 60, 2):
        for h in range(6, min(w + 1, 40), 2):
            rect_area = w * h
            eq_d = 1.3 * (w * h)**0.625 / (w + h)**0.25
            if abs(eq_d - d_eq_inch) < 1.5:
                options.append({'width': w, 'height': h, 'eq_diameter': round(eq_d, 1)})
    return sorted(options, key=lambda x: abs(x['eq_diameter'] - d_eq_inch))[:3]
```

### 3.3 Pipe Sizing

```python
def size_pipe(flow_gpm: float, system: str = "chilled_water",
              max_velocity_fps: float = 8.0) -> dict:
    """Size pipe per ASHRAE guidelines. Returns pipe diameter and pressure drop."""
    import math

    # Velocity-based sizing
    area_sqft = flow_gpm / (max_velocity_fps * 60 * 7.48)  # convert GPM to ft³/s
    d_inch = (area_sqft * 4 / math.pi)**0.5 * 12

    standard_pipes = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0]
    selected = next(s for s in standard_pipes if s >= d_inch)

    actual_velocity = flow_gpm / (7.48 * 60 * math.pi * (selected / 24)**2)

    schedules = {
        'chilled_water': 'Sch 40 Steel',
        'hot_water': 'Sch 40 Steel',
        'condenser_water': 'Sch 40 Steel',
        'refrigerant': 'Type L Copper',
        'drainage': 'PVC DWV',
    }

    return {
        'flow_gpm': flow_gpm,
        'pipe_size_inch': selected,
        'material': schedules.get(system, 'Sch 40 Steel'),
        'velocity_fps': round(actual_velocity, 1),
        'system': system,
    }
```

### 3.4 Auto-Place Diffusers

```python
def auto_place_diffusers(doc, room, cfm_total, diffuser_family="Square_Diffuser"):
    """Place supply/return diffusers evenly across room ceiling."""
    cfm_per_diffuser = 200  # typical for 24x24 diffuser
    n_diffusers = max(1, round(cfm_total / cfm_per_diffuser))

    grid = calculate_grid_layout(room, n_diffusers)

    t = Transaction(doc, "Place Diffusers")
    t.Start()
    for point in grid:
        place_air_terminal(doc, diffuser_family, point, room.LevelId, cfm_per_diffuser)
    t.Commit()

    return {'room': room.Name, 'diffusers': n_diffusers, 'cfm_each': cfm_per_diffuser}
```

## Phase 4: Clash Detection & Coordination

```python
def run_clash_detection(doc, categories_a, categories_b, tolerance_mm=25):
    """Detect MEP clashes between two category groups."""
    from Autodesk.Revit.DB import BoundingBoxIntersectsFilter

    elements_a = []
    for cat in categories_a:
        elements_a.extend(
            FilteredElementCollector(doc).OfCategory(cat)
            .WhereElementIsNotElementType().ToElements()
        )

    clashes = []
    for elem_a in elements_a:
        bb = elem_a.get_BoundingBox(None)
        if bb is None:
            continue
        # Expand bounding box by tolerance
        outline = Outline(
            XYZ(bb.Min.X - tolerance_mm/304.8, bb.Min.Y - tolerance_mm/304.8, bb.Min.Z - tolerance_mm/304.8),
            XYZ(bb.Max.X + tolerance_mm/304.8, bb.Max.Y + tolerance_mm/304.8, bb.Max.Z + tolerance_mm/304.8),
        )
        bbf = BoundingBoxIntersectsFilter(outline)

        for cat in categories_b:
            hits = FilteredElementCollector(doc).OfCategory(cat)\
                .WherePasses(bbf).WhereElementIsNotElementType().ToElements()
            for hit in hits:
                if hit.Id != elem_a.Id:
                    clashes.append({
                        'element_a': f"{elem_a.Category.Name}: {elem_a.Id}",
                        'element_b': f"{hit.Category.Name}: {hit.Id}",
                        'location': str(bb.Min),
                    })
    return clashes
```

## Phase 5: Schedule & BOQ Generation

```python
def export_mep_schedule(doc, output_path="MEP_Schedule.xlsx"):
    """Export all MEP equipment to Excel with quantities and specs."""
    import pandas as pd

    categories = {
        'Electrical Equipment': BuiltInCategory.OST_ElectricalEquipment,
        'Electrical Fixtures': BuiltInCategory.OST_ElectricalFixtures,
        'Lighting Fixtures': BuiltInCategory.OST_LightingFixtures,
        'Mechanical Equipment': BuiltInCategory.OST_MechanicalEquipment,
        'Duct': BuiltInCategory.OST_DuctCurves,
        'Pipe': BuiltInCategory.OST_PipeCurves,
        'Cable Tray': BuiltInCategory.OST_CableTray,
    }

    with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
        for name, cat in categories.items():
            elements = FilteredElementCollector(doc)\
                .OfCategory(cat)\
                .WhereElementIsNotElementType()\
                .ToElements()

            data = []
            for elem in elements:
                row = extract_element_params(elem)
                data.append(row)

            if data:
                df = pd.DataFrame(data)
                df.to_excel(writer, sheet_name=name[:31], index=False)

    return output_path
```

## Phase 6: Dynamo Workflows

### Common Dynamo Nodes for MEP

```
# Dynamo visual script structure for duct routing:

1. Select Rooms → Room.Name, Room.Area
2. Calculate CFM per room → Code Block: area * 1.2 (CFM/sqft)
3. Get room centroids → Room.Location
4. Create duct path → Line.ByStartPointEndPoint
5. Create duct → MEPCurve.ByLine (Duct type, line, level)
6. Size duct → MEPCurve.SetParameterByName("Diameter", calculated_size)
7. Connect to main trunk → Connector.ConnectTo

# Dynamo for auto-placing outlets:
1. Select Rooms → filter by type
2. Get room boundaries → Room.Boundaries
3. Calculate outlet positions → spacing along walls (every 3.6m per code)
4. Place families → FamilyInstance.ByPoint
5. Connect to circuits → ElectricalSystem.Create
```

# Examples

## Example 1: Office Building Electrical Design

**Context:** 10-floor office, 1000m² per floor, design electrical system

**Input:** "Design electrical system for 10-floor office building, each floor 1000m²"

**Output:**
```
ELECTRICAL DESIGN SUMMARY
========================
Building: 10-Floor Office
Total Area: 10,000 m²

Per Floor Load:
  Lighting:     12 W/m² × 1000 = 12.0 kW
  Power:        25 W/m² × 1000 = 25.0 kW
  HVAC:         80 W/m² × 1000 = 80.0 kW
  Total:        117.0 kW (Demand Factor 0.7 → 81.9 kW)

Building Total: 819 kW → 966 kVA (PF=0.85)
Main Breaker: 1600A at 400V 3-phase
Transformer: 1000 kVA (20% spare capacity)

Panel Schedule (per floor):
  LP-01: Lighting   (12 kW, 63A MCB)
  PP-01: Power      (25 kW, 100A MCB)
  AP-01: HVAC       (80 kW, 200A MCB)

Cable Sizing:
  Main riser: 4×240mm² XLPE + 120mm² PE
  Sub-main:   4×70mm² XLPE + 35mm² PE
  Lighting:   2×2.5mm² per circuit
  Power:      2×4.0mm² per circuit
```

## Example 2: HVAC Duct Design

**Context:** Open-plan office 500m², tropical climate

**Input:** "Size HVAC ducts for 500m² open office, ceiling height 3.2m"

**Output:**
```
HVAC DESIGN SUMMARY
===================
Room: Open Office (500 m², 3.2m ceiling)
Cooling Load: 125 W/m² → 62.5 kW (17.8 RT)
Supply Air: 500 × 1.2 = 600 CFM × (500/100) = 6,000 CFM

Main Trunk Duct:
  CFM: 6,000 | Size: 24"×16" (Velocity: 980 FPM)
  
Branch Ducts (4 zones × 1,500 CFM each):
  CFM: 1,500 | Size: 14"×10" (Velocity: 850 FPM)

Diffusers: 30 × Square 24"×24" @ 200 CFM each
Return Grilles: 8 × 24"×24" @ 750 CFM each

AHU Selection: 6,000 CFM, 62.5 kW cooling coil
```

# Constraints

- NEVER modify structural elements (walls, columns, floors)
- ALWAYS verify clearance distances between MEP systems (min 150mm)
- ALWAYS wrap Revit API modifications in Transaction blocks
- Cable sizing MUST comply with IEC 60364 or local code (TCVN, NEC)
- Duct velocity MUST NOT exceed ASHRAE limits (main: 1500 FPM, branch: 1200 FPM)
- Pipe velocity MUST stay within 4-8 ft/s for hydronic systems
- NEVER delete existing elements without explicit user confirmation
- ALWAYS create backup (Revit detach) before bulk modifications
- Fire-rated penetrations MUST be flagged when MEP crosses fire barriers
- ALL calculations must include safety factors (typically 1.2-1.25)
