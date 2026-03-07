# Dynamo Workflows for Revit MEP

## Common Dynamo Packages for MEP

| Package | Use Case |
|---------|----------|
| MEPover | MEP-specific tools, system classification |
| Rhythm | Advanced element filtering and manipulation |
| Clockwork | Room/space operations, parameter management |
| Springs | Geometry operations, FamilyInstance tools |
| BimorphNodes | Clash detection, element geometry |
| archi-lab | Selection, views, sheets management |
| Data-Shapes | UI forms, multi-input dialogs |

## Workflow 1: Auto-Place Outlets Along Walls

```
# Dynamo nodes sequence:
1. Categories → "Rooms" → All Elements of Category
2. Room.Boundaries → get wall curves
3. Curve.Length → filter walls > 1m
4. Curve.PointAtParameter → spacing every 3.6m
   - Code Block: 0..1..#(Math.Ceiling(length/3.6)+1)
5. Point.Add → offset from wall (150mm inward)
6. Point.Add → set height (300mm from floor)
7. Family Types → "Outlet_2P+E"
8. FamilyInstance.ByPointAndLevel → place outlets
9. Element.SetParameterByName → set circuit info
```

## Workflow 2: Size and Tag All Ducts

```
# Dynamo nodes:
1. Categories → "Ducts" → All Elements of Category
2. Element.GetParameterValueByName → "Flow"
3. Code Block (duct sizing):
   def size_duct(cfm):
       if cfm <= 200: return 8
       elif cfm <= 400: return 10
       elif cfm <= 800: return 12
       elif cfm <= 1200: return 14
       elif cfm <= 1800: return 16
       elif cfm <= 2500: return 18
       elif cfm <= 3500: return 20
       else: return 24
4. Element.SetParameterByName → "Diameter" or "Width"×"Height"
5. Tag.ByElement → auto-tag with size
```

## Workflow 3: Generate Panel Schedule from Rooms

```
# Dynamo nodes:
1. All Rooms → Room.Name, Room.Area
2. Code Block: classify rooms by type
3. Calculate loads:
   lighting = area × density_table[room_type]
   power = area × power_table[room_type]
4. Group by level → assign to panels
5. Export to Excel:
   Data.ExportExcel → "Panel_Schedule.xlsx"
   Columns: Room, Level, Area, Lighting_kW, Power_kW, Total_kW, Breaker_A
```

## Workflow 4: Clash Detection Report

```
# Dynamo nodes:
1. Categories → Select two MEP categories
2. All Elements of Category (Group A, Group B)
3. Element.BoundingBox → get bounds
4. BoundingBox.Intersect → find clashes
5. Filter by tolerance (25mm)
6. Create clash report:
   - Element A ID, Category, Location
   - Element B ID, Category, Location
   - Clash point XYZ
7. Export to Excel
8. Create 3D views at clash locations (optional)
```

## Workflow 5: Auto-Route Cable Tray

```
# Dynamo nodes:
1. Select Start Panel → get XYZ
2. Select End Panel/DB → get XYZ
3. Code Block: create route path
   - Horizontal at ceiling - 300mm
   - Vertical risers where needed
   - Avoid structural elements (query structural model)
4. Line.ByStartPointEndPoint → create path segments
5. CableTray.ByLine → create cable tray elements
6. CableTrayFitting.ByConnectors → add elbows/tees
7. Element.SetParameterByName → set width, material
```

## Workflow 6: Lighting Analysis & Auto-Layout

```
# Dynamo nodes:
1. Select Rooms → filter by room type
2. Room.Area → calculate number of luminaires
   n = (target_lux × area) / (lumen × UF × MF)
3. Room.Boundaries → get room shape
4. Calculate grid positions:
   - rows = ceil(sqrt(n × L/W))
   - cols = ceil(n / rows)
   - spacing_x = L / (cols + 1)
   - spacing_y = W / (rows + 1)
5. Create points at grid intersections
6. FamilyInstance.ByPoint → place luminaires
7. Verify: actual_lux = n × lumen × UF × MF / area
```

## Python Script Node Templates

### Template: Batch Parameter Update
```python
import clr
clr.AddReference('RevitAPI')
from Autodesk.Revit.DB import *

elements = IN[0]  # element list from Dynamo
param_name = IN[1]  # parameter name
values = IN[2]  # values to set

results = []
for elem, val in zip(elements, values):
    param = elem.LookupParameter(param_name)
    if param and not param.IsReadOnly:
        if param.StorageType == StorageType.Double:
            param.Set(float(val))
        elif param.StorageType == StorageType.String:
            param.Set(str(val))
        elif param.StorageType == StorageType.Integer:
            param.Set(int(val))
        results.append(True)
    else:
        results.append(False)

OUT = results
```

### Template: Create Electrical System
```python
import clr
clr.AddReference('RevitAPI')
from Autodesk.Revit.DB import *
from Autodesk.Revit.DB.Electrical import *

doc = IN[0]
fixtures = IN[1]  # list of electrical fixture elements
panel = IN[2]  # panel element

connector_set = ConnectorSet()
for fixture in fixtures:
    connectors = fixture.MEPModel.ConnectorManager.Connectors
    for conn in connectors:
        if conn.ElectricalSystemType == ElectricalSystemType.PowerCircuit:
            connector_set.Insert(conn)

if connector_set.Size > 0:
    system = ElectricalSystem.Create(doc, connector_set, 
        ElectricalSystemType.PowerCircuit)
    # Assign to panel
    system.SelectPanel(panel)

OUT = system
```
