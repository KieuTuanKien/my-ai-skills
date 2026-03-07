# SolidWorks API Quick Reference

## Connection Methods

### Python (win32com) - Recommended
```python
import win32com.client
sw = win32com.client.Dispatch("SldWorks.Application")
```

### Python (comtypes)
```python
import comtypes.client
sw = comtypes.client.GetActiveObject("SldWorks.Application")
```

### VBA Macro (inside SolidWorks)
```vba
Dim swApp As SldWorks.SldWorks
Set swApp = Application.SldWorks
Dim swModel As ModelDoc2
Set swModel = swApp.ActiveDoc
```

## Document Types & Constants

| Constant | Value | File Extension |
|----------|:-----:|---------------|
| swDocPART | 1 | .sldprt |
| swDocASSEMBLY | 2 | .sldasm |
| swDocDRAWING | 3 | .slddrw |

## Core API Objects

```
SldWorks (Application)
├── ModelDoc2 (Active Document)
│   ├── FeatureManager (Add features)
│   ├── SketchManager (Draw sketches)
│   ├── SelectionManager (Handle selections)
│   ├── Extension
│   │   ├── CustomPropertyManager (Properties)
│   │   ├── SelectByID2() (Select entities)
│   │   └── SaveAs() (Export)
│   ├── Parameter() (Dimensions)
│   └── GetMassProperties() (Mass/volume)
├── AssemblyDoc (Assembly operations)
│   ├── AddComponent5() (Insert parts)
│   ├── AddMate5() (Add mates)
│   └── GetComponents() (List components)
└── DrawingDoc (Drawing operations)
    ├── CreateDrawViewFromModelView3()
    ├── InsertModelAnnotations3()
    └── InsertBomTable3()
```

## Selection Methods

```python
# Select by name and type
model.Extension.SelectByID2(
    "Face1",      # name
    "FACE",       # type: FACE, EDGE, VERTEX, PLANE, AXIS, SKETCH, FEATURE
    0, 0, 0,      # x, y, z coordinates
    False,         # append to selection
    0,             # mark
    None,          # callout
    0              # selection option
)

# Select by coordinates (for faces)
model.Extension.SelectByID2("", "FACE", 0.05, 0, 0.01, False, 0, None, 0)

# Clear selection
model.ClearSelection2(True)
```

## Feature Types

| Feature | Method | Common Parameters |
|---------|--------|------------------|
| Extrude Boss | FeatureExtrusion2 | depth, direction, merge |
| Extrude Cut | FeatureCut3 | depth, direction, through |
| Revolve | FeatureRevolve2 | angle, axis |
| Fillet | FeatureFillet3 | radius, edges |
| Chamfer | InsertFeatureChamfer | distance, angle |
| Shell | InsertFeatureShell | thickness, faces |
| Mirror | FeatureMirror | plane, features |
| Linear Pattern | FeatureLinearPattern4 | count, spacing, direction |
| Circular Pattern | FeatureCircularPattern4 | count, angle, axis |
| Hole Wizard | FeatureHoleWizard5 | type, size, depth |
| Sweep | InsertSweep2 | profile, path |
| Loft | InsertLoft2 | profiles, guide curves |
| Rib | InsertRib | direction, thickness |

## Sketch Entities

```python
mgr = model.SketchManager

# Line
mgr.CreateLine(x1, y1, z1, x2, y2, z2)

# Circle
mgr.CreateCircle(cx, cy, cz, edge_x, edge_y, edge_z)

# Arc (3 points)
mgr.Create3PointArc(x1, y1, z1, x2, y2, z2, x3, y3, z3)

# Rectangle (center)
mgr.CreateCenterRectangle(cx, cy, cz, corner_x, corner_y, corner_z)

# Rectangle (corner)
mgr.CreateCornerRectangle(x1, y1, z1, x2, y2, z2)

# Polygon
mgr.CreatePolygon(cx, cy, cz, edge_x, edge_y, edge_z, sides, inscribed)

# Spline
points = [x1,y1,z1, x2,y2,z2, x3,y3,z3]
mgr.CreateSpline(points)

# Slot
mgr.CreateSketchSlot(0, x1, y1, z1, x2, y2, z2, width, True)

# Construction geometry toggle
mgr.ToggleConstruction()
```

## Export Formats

```python
# Save As with format
errors = win32com.client.VARIANT(pythoncom.VT_BYREF | pythoncom.VT_I4, 0)
warnings = win32com.client.VARIANT(pythoncom.VT_BYREF | pythoncom.VT_I4, 0)

model.Extension.SaveAs(filepath, 0, 1, None, errors, warnings)

# Format determined by extension:
# .step / .stp  → STEP AP203/AP214
# .igs / .iges  → IGES
# .stl          → STL (3D printing)
# .x_t          → Parasolid
# .pdf          → PDF (drawings)
# .dxf          → DXF (2D)
# .dwg          → DWG (2D)
# .3mf          → 3MF (3D printing)
```

## Custom Properties

```python
mgr = model.Extension.CustomPropertyManager[""]  # "" = active config

# Add/update property
mgr.Add3("Material", 30, "AISI 304", 2)  # 30=text type, 2=overwrite
mgr.Add3("Weight", 30, '"SW-Mass"', 2)   # linked to mass

# Read property
val = mgr.Get5("Material", False, "", "", False)

# Get all property names
names = mgr.GetNames()

# Delete property
mgr.Delete2("OldProperty")
```

## Unit Conversion (CRITICAL)

SolidWorks API uses **meters** internally:

```python
MM = 0.001        # millimeters to meters
CM = 0.01         # centimeters to meters
INCH = 0.0254     # inches to meters
DEG = 3.14159265 / 180  # degrees to radians

# Examples
depth_10mm = 10 * MM        # = 0.01
angle_45deg = 45 * DEG      # = 0.7854
diameter_1inch = 1 * INCH   # = 0.0254
```

## Error Handling Pattern

```python
def safe_sw_operation(sw, operation_func, *args):
    """Wrap SolidWorks operations with error handling."""
    try:
        result = operation_func(*args)
        model = sw.ActiveDoc
        if model:
            model.EditRebuild3()  # rebuild after changes
        return result
    except Exception as e:
        print(f"SolidWorks error: {e}")
        model = sw.ActiveDoc
        if model:
            model.EditUndo2(1)  # undo last operation
        return None
```

## Standard Material Library

```python
MATERIALS = {
    "Steel": {"density": 7850, "yield": 250, "E": 200e9},
    "AISI 304": {"density": 8000, "yield": 215, "E": 193e9},
    "AISI 316": {"density": 8000, "yield": 220, "E": 193e9},
    "Aluminum 6061": {"density": 2700, "yield": 276, "E": 69e9},
    "Copper": {"density": 8900, "yield": 70, "E": 117e9},
    "Brass": {"density": 8500, "yield": 200, "E": 100e9},
    "Cast Iron": {"density": 7200, "yield": 130, "E": 100e9},
    "Nylon 6/6": {"density": 1140, "yield": 70, "E": 2.9e9},
    "ABS Plastic": {"density": 1040, "yield": 40, "E": 2.3e9},
}
```
