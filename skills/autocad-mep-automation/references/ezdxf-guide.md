# ezdxf Quick Reference - DXF Automation Without AutoCAD

## Installation

```bash
pip install ezdxf
```

## Core Operations

### Create New Drawing
```python
import ezdxf
doc = ezdxf.new(dxfversion="R2018")
msp = doc.modelspace()
doc.saveas("output.dxf")
```

### Read Existing DXF
```python
doc = ezdxf.readfile("input.dxf")
msp = doc.modelspace()
```

### Read DWG (convert first)
```bash
# Use ODA File Converter (free) to convert DWG → DXF
# Download: https://www.opendesign.com/guestfiles/oda_file_converter
```

## Drawing Entities

### Lines
```python
msp.add_line((0, 0), (100, 0), dxfattribs={"layer": "E-POWR-MAIN", "color": 1})
```

### Polylines
```python
points = [(0,0), (100,0), (100,50), (0,50)]
msp.add_lwpolyline(points, close=True, 
    dxfattribs={"layer": "E-COND", "lineweight": 35})
```

### Circles & Arcs
```python
msp.add_circle(center=(50, 50), radius=10, dxfattribs={"layer": "E-LITE"})
msp.add_arc(center=(50, 50), radius=10, start_angle=0, end_angle=180)
```

### Text
```python
from ezdxf.enums import TextEntityAlignment

msp.add_text("Hello", height=5, 
    dxfattribs={"layer": "G-ANNO", "style": "STANDARD"}).set_placement(
    (50, 50), align=TextEntityAlignment.MIDDLE_CENTER
)
```

### MText (Multi-line)
```python
msp.add_mtext("Line 1\\PLine 2\\PLine 3", 
    dxfattribs={"layer": "G-ANNO", "char_height": 3, "width": 100}).set_location(
    (10, 100)
)
```

### Dimensions
```python
dim = msp.add_aligned_dim(p1=(0,0), p2=(100,0), distance=10,
    override={"dimtxt": 2.5})
dim.render()
```

### Hatching
```python
hatch = msp.add_hatch(color=7)
hatch.paths.add_polyline_path([(0,0), (10,0), (10,10), (0,10)], is_closed=True)
hatch.set_pattern_fill("ANSI31", scale=0.5)
```

### Block Definition & Insertion
```python
# Define block
block = doc.blocks.new("OUTLET_2P")
block.add_circle((0, 0), 1.5)
block.add_line((-1, 0), (1, 0))
block.add_line((0, -1), (0, 1))

# Insert block
msp.add_blockref("OUTLET_2P", insert=(50, 50), 
    dxfattribs={"xscale": 1, "yscale": 1, "rotation": 0, "layer": "E-RECV"})
```

### Blocks with Attributes
```python
block = doc.blocks.new("PANEL_TAG")
block.add_lwpolyline([(-5,-8),(5,-8),(5,8),(-5,8)], close=True)
block.add_attdef("NAME", (0, 3), dxfattribs={"height": 2.5, "prompt": "Panel Name"})
block.add_attdef("RATING", (0, -3), dxfattribs={"height": 2, "prompt": "Rating"})

# Insert with attribute values
blockref = msp.add_blockref("PANEL_TAG", (100, 200))
blockref.add_auto_attribs({"NAME": "DB-1F", "RATING": "400A"})
```

## Layers

```python
doc.layers.add("E-POWR", color=1, linetype="Continuous")
doc.layers.add("E-LITE", color=2)
doc.layers.add("M-HVAC", color=140)

# Set layer properties
layer = doc.layers.get("E-POWR")
layer.color = 1
layer.lineweight = 35  # 0.35mm
layer.on = True
layer.freeze = False
```

## Querying Elements

```python
# All entities on layer
for entity in msp.query('*[layer=="E-POWR-MAIN"]'):
    print(entity.dxftype(), entity.dxf.layer)

# Specific entity types
for line in msp.query("LINE"):
    length = line.dxf.start.distance(line.dxf.end)

for insert in msp.query("INSERT"):
    print(f"Block: {insert.dxf.name}, Position: {insert.dxf.insert}")

# By bounding box
from ezdxf.bbox import extents
bbox = extents(msp)  # returns BoundingBox
```

## Layout (Paper Space)

```python
# Create layout
layout = doc.layouts.new("A1 Sheet")
layout.page_setup(size=(841, 594), margins=(10, 10, 10, 10))

# Add viewport
vp = layout.add_viewport(
    center=(420, 297), size=(800, 560),
    view_center_point=(0, 0), view_height=1000
)
```

## Batch Processing

```python
import os
import ezdxf

def batch_process_dxf(folder: str, operation):
    """Apply operation to all DXF files in folder."""
    for filename in os.listdir(folder):
        if filename.lower().endswith('.dxf'):
            filepath = os.path.join(folder, filename)
            doc = ezdxf.readfile(filepath)
            operation(doc)
            doc.saveas(filepath)
            print(f"Processed: {filename}")
```

## Common Linetypes

```python
doc.linetypes.add("DASHED", pattern=[0.5, 0.25, -0.25])
doc.linetypes.add("CENTER", pattern=[1.25, 0.5, -0.25, 0.0, -0.25])
doc.linetypes.add("HIDDEN", pattern=[0.25, 0.125, -0.0625])
```
