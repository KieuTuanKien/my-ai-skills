# pyautocad & comtypes - Live AutoCAD Automation

## pyautocad (Simple API)

### Installation
```bash
pip install pyautocad
```

### Connect to AutoCAD
```python
from pyautocad import Autocad, APoint, aDouble

acad = Autocad(create_if_not_exists=True)
print(f"Drawing: {acad.doc.Name}")
```

### Draw Entities
```python
# Line
p1, p2 = APoint(0, 0), APoint(100, 0)
line = acad.model.AddLine(p1, p2)
line.Layer = "E-POWR-MAIN"
line.Color = 1

# Circle
center = APoint(50, 50)
circle = acad.model.AddCircle(center, 10)

# Polyline
points = aDouble(0,0,0, 100,0,0, 100,50,0, 0,50,0)
pline = acad.model.AddPolyline(points)
pline.Closed = True

# Text
text = acad.model.AddText("Panel DB-1", APoint(10, 20), 5)
text.Layer = "G-ANNO"

# MText
mtext = acad.model.AddMText(APoint(10, 50), 100, "Line 1\\nLine 2")

# Block insertion
acad.model.InsertBlock(APoint(50, 50), "OUTLET", 1, 1, 1, 0)
```

### Iterate Objects
```python
for obj in acad.iter_objects():
    print(obj.ObjectName, obj.Layer)

# Filter by type
for obj in acad.iter_objects("AcDbLine"):
    print(f"Line on {obj.Layer}: length={obj.Length:.1f}")

# Filter by layer
for obj in acad.iter_objects():
    if obj.Layer == "E-LITE":
        print(obj.ObjectName)
```

### Selection Sets
```python
# Select all on layer
ss = acad.doc.SelectionSets.Add("TempSS")
filter_type = aDouble(8)  # 8 = layer DXF code
filter_data = ["E-POWR-MAIN"]
ss.Select(5, None, None, filter_type, filter_data)  # 5 = acSelectionSetAll

for obj in ss:
    print(obj.ObjectName)

ss.Delete()
```

## comtypes (Full COM API Access)

### Installation
```bash
pip install comtypes
```

### Connect
```python
import comtypes.client

def get_autocad():
    acad = comtypes.client.GetActiveObject("AutoCAD.Application")
    doc = acad.ActiveDocument
    model = doc.ModelSpace
    return acad, doc, model

acad, doc, model = get_autocad()
```

### Advanced Operations
```python
import win32com.client
import pythoncom

def connect_autocad_com():
    acad = win32com.client.Dispatch("AutoCAD.Application")
    acad.Visible = True
    doc = acad.ActiveDocument
    return acad, doc

acad, doc = connect_autocad_com()

# Create layer
layer = doc.Layers.Add("E-NEW-LAYER")
layer.color = 3  # green
layer.Lineweight = 35

# Set active layer
doc.ActiveLayer = doc.Layers.Item("E-POWR-MAIN")

# Zoom extents
acad.ZoomExtents()

# Save
doc.Save()

# Export to PDF
doc.Plot.PlotToFile("output.pdf", "DWG To PDF.pc3")
```

### Batch Open & Process DWG
```python
import win32com.client
import os

def batch_process_dwg(folder, operation):
    acad = win32com.client.Dispatch("AutoCAD.Application")
    acad.Visible = False

    for f in os.listdir(folder):
        if f.lower().endswith('.dwg'):
            path = os.path.join(folder, f)
            doc = acad.Documents.Open(path)
            operation(doc)
            doc.Save()
            doc.Close()

    acad.Visible = True
```

### Export Block Attributes
```python
def export_attributes(doc, output_csv):
    """Export all block attributes to CSV."""
    import csv
    model = doc.ModelSpace

    with open(output_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Block', 'X', 'Y', 'Attribute', 'Value'])

        for i in range(model.Count):
            obj = model.Item(i)
            if obj.ObjectName == "AcDbBlockReference" and obj.HasAttributes:
                attrs = obj.GetAttributes()
                for attr in attrs:
                    writer.writerow([
                        obj.EffectiveName,
                        round(obj.InsertionPoint[0], 2),
                        round(obj.InsertionPoint[1], 2),
                        attr.TagString,
                        attr.TextString,
                    ])
```

## AutoLISP Integration from Python

```python
def send_lisp_command(acad, lisp_expr):
    """Send AutoLISP expression to AutoCAD."""
    acad.ActiveDocument.SendCommand(lisp_expr + "\n")

# Examples
send_lisp_command(acad, '(command "ZOOM" "E")')
send_lisp_command(acad, '(command "LAYER" "M" "E-POWR" "")')
send_lisp_command(acad, '(command "-PURGE" "ALL" "*" "N")')
```
