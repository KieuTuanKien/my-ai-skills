# Revit API Quick Reference for MEP

## Setup & Environment

### pyRevit (Recommended for Python scripts)
```python
# pyRevit script header
from pyrevit import revit, DB, script, forms

doc = revit.doc
uidoc = revit.uidoc
output = script.get_output()
```

### RevitPythonShell / Dynamo Python
```python
import clr
clr.AddReference('RevitAPI')
clr.AddReference('RevitAPIUI')
clr.AddReference('RevitServices')

from Autodesk.Revit.DB import *
from Autodesk.Revit.DB.Electrical import *
from Autodesk.Revit.DB.Mechanical import *
from Autodesk.Revit.DB.Plumbing import *
from Autodesk.Revit.UI import *
from RevitServices.Persistence import DocumentManager
from RevitServices.Transactions import TransactionManager

doc = DocumentManager.Instance.CurrentDBDocument
```

### C# Add-in Template
```csharp
using Autodesk.Revit.DB;
using Autodesk.Revit.DB.Electrical;
using Autodesk.Revit.DB.Mechanical;
using Autodesk.Revit.UI;

[Transaction(TransactionMode.Manual)]
public class MEPCommand : IExternalCommand
{
    public Result Execute(ExternalCommandData commandData, 
                         ref string message, ElementSet elements)
    {
        UIDocument uidoc = commandData.Application.ActiveUIDocument;
        Document doc = uidoc.Document;

        using (Transaction t = new Transaction(doc, "MEP Operation"))
        {
            t.Start();
            // MEP operations here
            t.Commit();
        }
        return Result.Succeeded;
    }
}
```

## Element Collection Patterns

```python
# Get all electrical panels
panels = FilteredElementCollector(doc)\
    .OfCategory(BuiltInCategory.OST_ElectricalEquipment)\
    .WhereElementIsNotElementType().ToElements()

# Get all lighting fixtures on specific level
level = get_level_by_name(doc, "Level 1")
lights = FilteredElementCollector(doc)\
    .OfCategory(BuiltInCategory.OST_LightingFixtures)\
    .WhereElementIsNotElementType().ToElements()
lights_on_level = [l for l in lights if l.LevelId == level.Id]

# Get all ducts
ducts = FilteredElementCollector(doc)\
    .OfCategory(BuiltInCategory.OST_DuctCurves)\
    .WhereElementIsNotElementType().ToElements()

# Get all pipes by system type
pipes = FilteredElementCollector(doc)\
    .OfCategory(BuiltInCategory.OST_PipeCurves)\
    .WhereElementIsNotElementType().ToElements()
chw_pipes = [p for p in pipes if "Chilled" in get_system_name(p)]

# Get rooms
rooms = FilteredElementCollector(doc)\
    .OfCategory(BuiltInCategory.OST_Rooms)\
    .WhereElementIsNotElementType().ToElements()
```

## MEP-Specific Categories

| Category | BuiltInCategory | Use |
|----------|----------------|-----|
| Electrical Equipment | OST_ElectricalEquipment | Panels, transformers, MCC |
| Electrical Fixtures | OST_ElectricalFixtures | Outlets, switches |
| Lighting Fixtures | OST_LightingFixtures | Luminaires |
| Lighting Devices | OST_LightingDevices | Sensors, dimmers |
| Cable Trays | OST_CableTray | Cable tray runs |
| Cable Tray Fittings | OST_CableTrayFitting | Tees, elbows, reducers |
| Conduits | OST_Conduit | Conduit runs |
| Mechanical Equipment | OST_MechanicalEquipment | AHU, FCU, chillers |
| Ducts | OST_DuctCurves | Duct runs |
| Duct Fittings | OST_DuctFitting | Elbows, tees, reducers |
| Duct Accessories | OST_DuctAccessory | Dampers, VAV boxes |
| Air Terminals | OST_DuctTerminal | Diffusers, grilles |
| Pipes | OST_PipeCurves | Pipe runs |
| Pipe Fittings | OST_PipeFitting | Elbows, tees |
| Pipe Accessories | OST_PipeAccessory | Valves, strainers |
| Sprinklers | OST_Sprinklers | Fire sprinkler heads |

## Transaction Pattern (CRITICAL)

```python
# ALWAYS wrap modifications in transactions
t = Transaction(doc, "Description")
t.Start()
try:
    # Revit API modifications here
    t.Commit()
except Exception as e:
    t.RollBack()
    print(f"Error: {e}")
```

## Unit Conversion (Revit uses feet internally)

```python
MM_TO_FEET = 1 / 304.8
M_TO_FEET = 1 / 0.3048
FEET_TO_MM = 304.8
FEET_TO_M = 0.3048
SQFT_TO_SQM = 0.0929
SQM_TO_SQFT = 10.764

def mm_to_internal(mm): return mm * MM_TO_FEET
def m_to_internal(m): return m * M_TO_FEET
def internal_to_mm(feet): return feet * FEET_TO_MM
def internal_to_m(feet): return feet * FEET_TO_M
```

## Creating MEP Elements

```python
# Place family instance (equipment, fixtures)
def place_family(doc, family_name, type_name, location_xyz, level_id):
    symbol = get_family_symbol(doc, family_name, type_name)
    if not symbol.IsActive:
        symbol.Activate()
    return doc.Create.NewFamilyInstance(
        location_xyz, symbol, level, 
        Autodesk.Revit.DB.Structure.StructuralType.NonStructural
    )

# Create duct
def create_duct(doc, duct_type_id, level_id, start_xyz, end_xyz, diameter_mm):
    return Duct.Create(doc, duct_type_id, level_id, 
        None,  # connector
        start_xyz, end_xyz)

# Create pipe
def create_pipe(doc, pipe_type_id, level_id, start_xyz, end_xyz):
    return Pipe.Create(doc, pipe_type_id, level_id,
        None, start_xyz, end_xyz)

# Create cable tray
def create_cable_tray(doc, tray_type_id, start_xyz, end_xyz, level_id):
    return CableTray.Create(doc, tray_type_id, start_xyz, end_xyz, level_id)
```

## Connector Operations

```python
def get_connectors(element):
    """Get all connectors from MEP element."""
    conn_mgr = element.ConnectorManager
    if conn_mgr is None:
        return []
    return list(conn_mgr.Connectors)

def connect_elements(conn1, conn2):
    """Connect two MEP connectors."""
    if conn1.IsConnected or conn2.IsConnected:
        return False
    conn1.ConnectTo(conn2)
    return True
```
