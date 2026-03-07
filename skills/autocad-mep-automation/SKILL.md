---
name: autocad-mep-automation
description: |
  Automate electrical and mechanical system design in AutoCAD using Python
  (pyautocad, ezdxf, comtypes), AutoLISP, and .NET API. Covers single-line
  diagram (SLD) generation, panel schedule drawing, cable schedule, equipment
  layout, duct/pipe routing, auto-dimensioning, block insertion, title block
  automation, and BOQ extraction from DWG/DXF files.
  Use when designing electrical/mechanical systems in AutoCAD, generating SLD,
  creating equipment layouts, automating drawing production, or extracting
  BOQ from CAD files.
version: 1.0.0
tags: [AutoCAD, MEP, Electrical, Mechanical, SLD, pyautocad, ezdxf, AutoLISP, DXF, Automation]
dependencies: [ezdxf, pyautocad, comtypes, numpy, pandas, openpyxl, matplotlib]
---

# Goal

Automate MEP drawing production in AutoCAD — from single-line diagrams to
equipment layouts to cable schedules — reducing manual drafting time by 70-90%
while producing drawings compliant with IEC, TCVN, and company standards.

# Instructions

## Tool Selection Guide

| Tool | Requires AutoCAD | Best For |
|------|:-----------------:|---------|
| **ezdxf** | No | DXF read/write, drawing generation, BOQ extraction, batch processing |
| **pyautocad** | Yes | Live AutoCAD manipulation, interactive workflows |
| **comtypes** | Yes | Full AutoCAD COM API access, advanced operations |
| **AutoLISP** | Yes | In-AutoCAD scripting, custom commands, quick tools |
| **.NET API (C#)** | Yes | High-performance plugins, complex UI, production add-ins |

> **Recommendation:** Use `ezdxf` for drawing generation (no license needed).
> Use `pyautocad`/`comtypes` when interacting with a running AutoCAD session.

## Phase 1: Drawing Setup with ezdxf

### 1.1 Create New Drawing with Standard Layers

```python
import ezdxf
from ezdxf.enums import TextEntityAlignment

def create_mep_drawing(filename: str, paper_size: str = "A1") -> ezdxf.document.Drawing:
    """Create new DXF with standard MEP layers, styles, and title block."""
    doc = ezdxf.new(dxfversion="R2018")
    msp = doc.modelspace()

    # Standard MEP layers
    layers = {
        # Electrical
        "E-POWR-MAIN":   {"color": 1, "desc": "Main power distribution"},
        "E-POWR-BRANCH": {"color": 3, "desc": "Branch circuits"},
        "E-LITE":        {"color": 2, "desc": "Lighting fixtures & circuits"},
        "E-LITE-SWIT":   {"color": 2, "desc": "Lighting switches"},
        "E-RECV":        {"color": 4, "desc": "Receptacles/outlets"},
        "E-COND":        {"color": 6, "desc": "Conduit & cable tray"},
        "E-PANL":        {"color": 1, "desc": "Panel boards"},
        "E-EQPM":        {"color": 1, "desc": "Electrical equipment"},
        "E-GRND":        {"color": 3, "desc": "Grounding system"},
        "E-FIRE":        {"color": 1, "desc": "Fire alarm system"},
        # Mechanical
        "M-HVAC-DUCT":   {"color": 140, "desc": "HVAC ductwork"},
        "M-HVAC-DIFF":   {"color": 141, "desc": "Diffusers & grilles"},
        "M-HVAC-EQPM":   {"color": 142, "desc": "HVAC equipment"},
        "M-PIPE-CW":     {"color": 150, "desc": "Chilled water pipes"},
        "M-PIPE-HW":     {"color": 30,  "desc": "Hot water pipes"},
        "M-PIPE-DR":     {"color": 160, "desc": "Drainage pipes"},
        "M-PIPE-FP":     {"color": 1,   "desc": "Fire protection pipes"},
        # General
        "G-ANNO":        {"color": 7,  "desc": "Annotations & dimensions"},
        "G-TITL":        {"color": 7,  "desc": "Title block"},
        "G-BORD":        {"color": 7,  "desc": "Drawing border"},
        "G-GRID":        {"color": 8,  "desc": "Grid lines"},
    }

    for name, props in layers.items():
        doc.layers.add(name, color=props["color"])

    # Text styles
    doc.styles.add("STANDARD", font="Arial")
    doc.styles.add("TITLE", font="Arial")
    doc.styles.add("ANNO", font="Arial Narrow")

    # Dimension style
    dimstyle = doc.dimstyles.new("MEP_DIM")
    dimstyle.dxf.dimtxt = 2.5  # text height mm
    dimstyle.dxf.dimasz = 2.5  # arrow size
    dimstyle.dxf.dimexe = 1.0  # extension line extension
    dimstyle.dxf.dimexo = 1.0  # extension line offset

    doc.saveas(filename)
    return doc
```

### 1.2 Title Block Generator

```python
def draw_title_block(msp, origin=(0, 0), size="A1",
                     project="", drawing_title="", dwg_no="",
                     scale="1:100", date="", drawn_by="", checked_by=""):
    """Draw standard title block with company info."""
    x0, y0 = origin
    sizes = {
        "A0": (1189, 841), "A1": (841, 594),
        "A2": (594, 420),  "A3": (420, 297),
    }
    w, h = sizes.get(size, (841, 594))

    # Border (10mm margin)
    m = 10
    msp.add_lwpolyline(
        [(x0+m, y0+m), (x0+w-m, y0+m), (x0+w-m, y0+h-m), (x0+m, y0+h-m)],
        close=True, dxfattribs={"layer": "G-BORD", "lineweight": 50}
    )

    # Title block box (bottom-right, 180×50mm)
    tb_w, tb_h = 180, 50
    tb_x = x0 + w - m - tb_w
    tb_y = y0 + m

    msp.add_lwpolyline(
        [(tb_x, tb_y), (tb_x+tb_w, tb_y), (tb_x+tb_w, tb_y+tb_h), (tb_x, tb_y+tb_h)],
        close=True, dxfattribs={"layer": "G-TITL", "lineweight": 35}
    )

    # Horizontal dividers
    for dy in [12, 24, 36]:
        msp.add_line((tb_x, tb_y+dy), (tb_x+tb_w, tb_y+dy),
                     dxfattribs={"layer": "G-TITL"})

    # Vertical divider
    msp.add_line((tb_x+90, tb_y), (tb_x+90, tb_y+tb_h),
                 dxfattribs={"layer": "G-TITL"})

    # Text entries
    texts = [
        (tb_x+5,  tb_y+3,  3.5, f"PROJECT: {project}"),
        (tb_x+5,  tb_y+15, 3.0, f"TITLE: {drawing_title}"),
        (tb_x+5,  tb_y+27, 2.5, f"DRAWN: {drawn_by}"),
        (tb_x+95, tb_y+27, 2.5, f"CHECKED: {checked_by}"),
        (tb_x+5,  tb_y+39, 2.5, f"DWG NO: {dwg_no}"),
        (tb_x+95, tb_y+39, 2.5, f"SCALE: {scale}"),
        (tb_x+95, tb_y+3,  2.5, f"DATE: {date}"),
    ]

    for tx, ty, th, text in texts:
        msp.add_text(text, height=th,
                     dxfattribs={"layer": "G-TITL", "style": "ANNO"}).set_placement(
            (tx, ty), align=TextEntityAlignment.LEFT
        )
```

## Phase 2: Single-Line Diagram (SLD) Generation

```python
def generate_sld(doc, config: dict, origin=(50, 400)):
    """
    Auto-generate single-line diagram from electrical config.
    config: {
        'transformer': {'rating_kva': 1000, 'voltage': '22/0.4kV'},
        'main_panel': {'name': 'MSB', 'breaker_a': 1600},
        'sub_panels': [
            {'name': 'DB-1F', 'breaker_a': 400, 'cable': '4x120+70mm²',
             'circuits': [
                 {'name': 'Lighting', 'breaker_a': 63, 'cable': '3x10mm²'},
                 {'name': 'Power', 'breaker_a': 100, 'cable': '3x25mm²'},
             ]},
            ...
        ]
    }
    """
    msp = doc.modelspace()
    x, y = origin
    bus_y = y

    # Transformer symbol
    draw_transformer_symbol(msp, (x, y + 60), config['transformer'])

    # Main bus
    msp.add_line((x, y + 40), (x, bus_y), dxfattribs={"layer": "E-POWR-MAIN", "lineweight": 50})

    # Main breaker
    draw_breaker_symbol(msp, (x, bus_y), config['main_panel']['breaker_a'],
                        config['main_panel']['name'])

    # Horizontal bus bar
    bus_width = len(config['sub_panels']) * 80 + 40
    msp.add_line((x - 20, bus_y - 10), (x + bus_width, bus_y - 10),
                 dxfattribs={"layer": "E-POWR-MAIN", "lineweight": 70})

    # Sub panels
    for i, panel in enumerate(config['sub_panels']):
        px = x + 40 + i * 80
        py = bus_y - 10

        # Vertical feeder
        msp.add_line((px, py), (px, py - 40),
                     dxfattribs={"layer": "E-POWR-BRANCH"})

        # Panel breaker
        draw_breaker_symbol(msp, (px, py - 20), panel['breaker_a'], panel['name'])

        # Cable label
        msp.add_text(panel['cable'], height=2,
                     dxfattribs={"layer": "G-ANNO", "style": "ANNO"}).set_placement(
            (px + 3, py - 30), align=TextEntityAlignment.LEFT
        )

        # Sub-circuits
        for j, circuit in enumerate(panel.get('circuits', [])):
            cx = px - 15 + j * 25
            cy = py - 50
            msp.add_line((px, py - 40), (cx, cy),
                         dxfattribs={"layer": "E-POWR-BRANCH"})
            draw_breaker_symbol(msp, (cx, cy - 5), circuit['breaker_a'],
                                circuit['name'], size="small")


def draw_transformer_symbol(msp, pos, config):
    """Draw transformer symbol (two circles) with label."""
    x, y = pos
    r = 8
    msp.add_circle((x, y + r), r, dxfattribs={"layer": "E-EQPM"})
    msp.add_circle((x, y - r + 4), r, dxfattribs={"layer": "E-EQPM"})
    msp.add_text(f"{config['rating_kva']} kVA", height=3,
                 dxfattribs={"layer": "G-ANNO"}).set_placement(
        (x + 12, y), align=TextEntityAlignment.LEFT
    )
    msp.add_text(config['voltage'], height=2.5,
                 dxfattribs={"layer": "G-ANNO"}).set_placement(
        (x + 12, y - 5), align=TextEntityAlignment.LEFT
    )


def draw_breaker_symbol(msp, pos, rating_a, label="", size="normal"):
    """Draw circuit breaker symbol."""
    x, y = pos
    s = 4 if size == "normal" else 2.5
    # Breaker: angled line with cross
    msp.add_line((x, y), (x + s, y - s*1.5),
                 dxfattribs={"layer": "E-POWR-MAIN"})
    msp.add_line((x - 1, y - s*0.75 - 1), (x + 1, y - s*0.75 + 1),
                 dxfattribs={"layer": "E-POWR-MAIN"})

    th = 2.5 if size == "normal" else 1.8
    msp.add_text(f"{rating_a}A", height=th,
                 dxfattribs={"layer": "G-ANNO"}).set_placement(
        (x + s + 2, y - s), align=TextEntityAlignment.LEFT
    )
    if label:
        msp.add_text(label, height=th,
                     dxfattribs={"layer": "G-ANNO", "style": "ANNO"}).set_placement(
            (x + s + 2, y - s - 4), align=TextEntityAlignment.LEFT
        )
```

## Phase 3: Panel Schedule Drawing

```python
def draw_panel_schedule(doc, panel_data: dict, origin=(50, 500)):
    """
    Draw panel schedule table in DXF.
    panel_data: {
        'name': 'DB-1F', 'voltage': '400/230V', 'main_breaker': 400,
        'circuits': [
            {'no': 1, 'description': 'Lighting Zone A', 'breaker_a': 16,
             'poles': 1, 'cable': '2x2.5mm²', 'load_w': 1200},
            ...
        ]
    }
    """
    msp = doc.modelspace()
    x0, y0 = origin

    # Header
    col_widths = [15, 80, 20, 15, 35, 25, 25]  # No, Desc, A, P, Cable, W, Phase
    headers = ["No.", "Description", "A", "P", "Cable", "W", "Phase"]
    total_w = sum(col_widths)
    row_h = 8

    # Panel title
    msp.add_text(f"PANEL SCHEDULE: {panel_data['name']}", height=5,
                 dxfattribs={"layer": "G-ANNO", "style": "TITLE"}).set_placement(
        (x0, y0 + 15), align=TextEntityAlignment.LEFT
    )
    msp.add_text(f"{panel_data['voltage']} | Main: {panel_data['main_breaker']}A",
                 height=3, dxfattribs={"layer": "G-ANNO"}).set_placement(
        (x0, y0 + 8), align=TextEntityAlignment.LEFT
    )

    # Header row
    cx = x0
    for i, (header, width) in enumerate(zip(headers, col_widths)):
        msp.add_lwpolyline(
            [(cx, y0), (cx+width, y0), (cx+width, y0-row_h), (cx, y0-row_h)],
            close=True, dxfattribs={"layer": "G-ANNO"}
        )
        msp.add_text(header, height=2.5,
                     dxfattribs={"layer": "G-ANNO", "style": "ANNO"}).set_placement(
            (cx + width/2, y0 - row_h/2), align=TextEntityAlignment.MIDDLE_CENTER
        )
        cx += width

    # Data rows
    for row_idx, circuit in enumerate(panel_data['circuits']):
        ry = y0 - row_h * (row_idx + 1)
        cx = x0
        values = [
            str(circuit['no']),
            circuit['description'],
            str(circuit['breaker_a']),
            str(circuit['poles']),
            circuit['cable'],
            str(circuit['load_w']),
            circuit.get('phase', 'L1'),
        ]
        for val, width in zip(values, col_widths):
            msp.add_lwpolyline(
                [(cx, ry), (cx+width, ry), (cx+width, ry-row_h), (cx, ry-row_h)],
                close=True, dxfattribs={"layer": "G-ANNO"}
            )
            msp.add_text(val, height=2,
                         dxfattribs={"layer": "G-ANNO"}).set_placement(
                (cx + 2, ry - row_h/2), align=TextEntityAlignment.MIDDLE_LEFT
            )
            cx += width

    # Total row
    total_w_val = sum(c['load_w'] for c in panel_data['circuits'])
    ry = y0 - row_h * (len(panel_data['circuits']) + 1)
    msp.add_text(f"TOTAL: {total_w_val:,} W ({total_w_val/1000:.1f} kW)", height=3,
                 dxfattribs={"layer": "G-ANNO", "style": "ANNO"}).set_placement(
        (x0, ry - 5), align=TextEntityAlignment.LEFT
    )
```

## Phase 4: Equipment Layout Drawing

```python
def draw_equipment_layout(doc, rooms: list[dict], equipment: list[dict],
                          scale=100, origin=(0, 0)):
    """
    Draw floor plan with MEP equipment placement.
    rooms: [{'name': str, 'polygon': [(x,y),...], 'height': float}]
    equipment: [{'type': str, 'symbol': str, 'x': float, 'y': float,
                 'rotation': float, 'label': str}]
    """
    msp = doc.modelspace()
    ox, oy = origin

    # Draw rooms
    for room in rooms:
        points = [(ox + p[0]*1000/scale, oy + p[1]*1000/scale)
                  for p in room['polygon']]
        msp.add_lwpolyline(points, close=True,
                           dxfattribs={"layer": "G-GRID"})
        # Room label
        cx = sum(p[0] for p in points) / len(points)
        cy = sum(p[1] for p in points) / len(points)
        msp.add_text(room['name'], height=3,
                     dxfattribs={"layer": "G-ANNO"}).set_placement(
            (cx, cy), align=TextEntityAlignment.MIDDLE_CENTER
        )

    # Place equipment symbols
    for eq in equipment:
        ex = ox + eq['x'] * 1000 / scale
        ey = oy + eq['y'] * 1000 / scale
        draw_equipment_symbol(msp, (ex, ey), eq['type'],
                              eq.get('rotation', 0), eq.get('label', ''))


def draw_equipment_symbol(msp, pos, eq_type, rotation=0, label=""):
    """Draw simplified equipment symbols."""
    x, y = pos
    symbols = {
        "panel": lambda: msp.add_lwpolyline(
            [(x-3, y-5), (x+3, y-5), (x+3, y+5), (x-3, y+5)],
            close=True, dxfattribs={"layer": "E-PANL"}),
        "outlet": lambda: msp.add_circle(
            (x, y), 1.5, dxfattribs={"layer": "E-RECV"}),
        "light": lambda: [
            msp.add_circle((x, y), 2, dxfattribs={"layer": "E-LITE"}),
            msp.add_line((x-2, y), (x+2, y), dxfattribs={"layer": "E-LITE"}),
        ],
        "switch": lambda: [
            msp.add_circle((x, y), 1, dxfattribs={"layer": "E-LITE-SWIT"}),
            msp.add_line((x, y), (x+3, y+2), dxfattribs={"layer": "E-LITE-SWIT"}),
        ],
        "ahu": lambda: msp.add_lwpolyline(
            [(x-8, y-4), (x+8, y-4), (x+8, y+4), (x-8, y+4)],
            close=True, dxfattribs={"layer": "M-HVAC-EQPM"}),
        "fcu": lambda: msp.add_lwpolyline(
            [(x-4, y-2), (x+4, y-2), (x+4, y+2), (x-4, y+2)],
            close=True, dxfattribs={"layer": "M-HVAC-EQPM"}),
        "diffuser": lambda: [
            msp.add_lwpolyline([(x-2, y-2), (x+2, y-2), (x+2, y+2), (x-2, y+2)],
                               close=True, dxfattribs={"layer": "M-HVAC-DIFF"}),
            msp.add_line((x-2, y-2), (x+2, y+2), dxfattribs={"layer": "M-HVAC-DIFF"}),
            msp.add_line((x-2, y+2), (x+2, y-2), dxfattribs={"layer": "M-HVAC-DIFF"}),
        ],
    }

    draw_fn = symbols.get(eq_type)
    if draw_fn:
        draw_fn()

    if label:
        msp.add_text(label, height=1.8,
                     dxfattribs={"layer": "G-ANNO", "style": "ANNO"}).set_placement(
            (x, y - 4), align=TextEntityAlignment.MIDDLE_CENTER
        )
```

## Phase 5: BOQ Extraction from DXF/DWG

```python
def extract_boq_from_dxf(dxf_path: str, output_excel: str = "BOQ_MEP.xlsx"):
    """
    Extract Bill of Quantities from DXF file by analyzing
    blocks, layers, and element properties.
    """
    import pandas as pd
    doc = ezdxf.readfile(dxf_path)
    msp = doc.modelspace()

    boq = {
        'blocks': [],    # equipment counts
        'lines': [],     # cable/pipe lengths
        'areas': [],     # floor areas
    }

    # Count block references (equipment)
    block_counts = {}
    for insert in msp.query("INSERT"):
        block_name = insert.dxf.name
        layer = insert.dxf.layer
        key = (block_name, layer)
        block_counts[key] = block_counts.get(key, 0) + 1

    for (block, layer), count in block_counts.items():
        boq['blocks'].append({
            'Block Name': block,
            'Layer': layer,
            'Category': classify_layer(layer),
            'Quantity': count,
        })

    # Measure line/polyline lengths (cables, ducts, pipes)
    layer_lengths = {}
    for entity in msp:
        if entity.dxftype() in ('LINE', 'LWPOLYLINE', 'POLYLINE'):
            layer = entity.dxf.layer
            if entity.dxftype() == 'LINE':
                length = entity.dxf.start.distance(entity.dxf.end)
            else:
                length = sum(
                    p1.distance(p2) for p1, p2 in zip(
                        entity.vertices(), list(entity.vertices())[1:]
                    )
                ) if hasattr(entity, 'vertices') else 0

            length_m = length / 1000  # mm to m
            layer_lengths[layer] = layer_lengths.get(layer, 0) + length_m

    for layer, total_m in layer_lengths.items():
        if any(prefix in layer for prefix in ['E-', 'M-']):
            boq['lines'].append({
                'Layer': layer,
                'Category': classify_layer(layer),
                'Total Length (m)': round(total_m, 1),
            })

    # Export to Excel
    with pd.ExcelWriter(output_excel, engine='openpyxl') as writer:
        if boq['blocks']:
            pd.DataFrame(boq['blocks']).to_excel(
                writer, sheet_name='Equipment', index=False)
        if boq['lines']:
            pd.DataFrame(boq['lines']).to_excel(
                writer, sheet_name='Cables & Pipes', index=False)

    return boq


def classify_layer(layer_name: str) -> str:
    """Classify layer to MEP category."""
    prefixes = {
        'E-POWR': 'Power Distribution',
        'E-LITE': 'Lighting',
        'E-RECV': 'Receptacles',
        'E-COND': 'Conduit & Cable Tray',
        'E-PANL': 'Panel Boards',
        'E-FIRE': 'Fire Alarm',
        'M-HVAC': 'HVAC',
        'M-PIPE': 'Piping',
    }
    for prefix, category in prefixes.items():
        if layer_name.startswith(prefix):
            return category
    return 'Other'
```

## Phase 6: Live AutoCAD Automation (pyautocad)

```python
from pyautocad import Autocad, APoint

def connect_autocad():
    """Connect to running AutoCAD instance."""
    acad = Autocad(create_if_not_exists=True)
    print(f"Connected to: {acad.doc.Name}")
    return acad


def batch_insert_blocks(acad, block_name: str, points: list[tuple],
                        scale=1.0, rotation=0.0):
    """Insert block at multiple points in active drawing."""
    for x, y in points:
        acad.model.InsertBlock(APoint(x, y, 0), block_name,
                               scale, scale, scale, rotation)


def auto_dimension_lines(acad, layer_filter: str = "E-COND"):
    """Add dimensions to all lines on specified layer."""
    for obj in acad.iter_objects():
        if obj.ObjectName == "AcDbLine" and obj.Layer == layer_filter:
            start = APoint(obj.StartPoint)
            end = APoint(obj.EndPoint)
            mid_y = (start.y + end.y) / 2 + 5  # offset above
            acad.model.AddDimAligned(start, end, APoint(start.x, mid_y, 0))


def export_block_count(acad, output_csv: str = "block_count.csv"):
    """Count all block references in current drawing."""
    import csv
    counts = {}
    for obj in acad.iter_objects():
        if obj.ObjectName == "AcDbBlockReference":
            name = obj.EffectiveName
            layer = obj.Layer
            key = (name, layer)
            counts[key] = counts.get(key, 0) + 1

    with open(output_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Block', 'Layer', 'Count'])
        for (name, layer), count in sorted(counts.items()):
            writer.writerow([name, layer, count])
    return counts
```

## Phase 7: Cable Schedule Generator

```python
def generate_cable_schedule(panels: list[dict], output_path: str = "Cable_Schedule.xlsx"):
    """
    Generate cable schedule from panel configurations.
    panels: [{'name': 'DB-1F', 'location': '1st Floor',
              'fed_from': 'MSB', 'voltage': 400,
              'circuits': [{'desc': str, 'load_w': int, 'length_m': int, ...}]}]
    """
    import pandas as pd

    rows = []
    for panel in panels:
        for ckt in panel['circuits']:
            current = ckt['load_w'] / (panel['voltage'] * 0.85)  # single phase
            cable_size = select_cable(current)
            vdrop = calc_voltage_drop(current, ckt['length_m'], cable_size, panel['voltage'])

            rows.append({
                'From': panel['fed_from'],
                'To': panel['name'],
                'Circuit': ckt['desc'],
                'Load (W)': ckt['load_w'],
                'Current (A)': round(current, 1),
                'Cable': cable_size,
                'Length (m)': ckt['length_m'],
                'V-Drop (%)': round(vdrop, 2),
                'Breaker (A)': select_breaker(current),
                'Conduit (mm)': select_conduit(cable_size),
            })

    df = pd.DataFrame(rows)
    df.to_excel(output_path, index=False, sheet_name='Cable Schedule')
    return df


def select_cable(current_a: float) -> str:
    """Select cable size per IEC 60228."""
    table = [
        (15, "2x1.5mm²"), (21, "2x2.5mm²"), (28, "2x4mm²"),
        (36, "2x6mm²"), (50, "2x10mm²"), (66, "2x16mm²"),
        (84, "4x25mm²"), (104, "4x35mm²"), (125, "4x50mm²"),
        (160, "4x70mm²"), (194, "4x95mm²"), (225, "4x120mm²"),
        (260, "4x150mm²"), (297, "4x185mm²"), (350, "4x240mm²"),
    ]
    design_current = current_a * 1.25
    for rating, cable in table:
        if rating >= design_current:
            return cable
    return "4x300mm²"


def select_breaker(current_a: float) -> int:
    sizes = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250]
    design = current_a * 1.25
    return next(s for s in sizes if s >= design)


def select_conduit(cable: str) -> int:
    """Select conduit diameter based on cable size."""
    area_map = {
        "2x1.5": 16, "2x2.5": 20, "2x4": 20, "2x6": 25,
        "2x10": 25, "2x16": 32, "4x25": 40, "4x35": 50,
        "4x50": 50, "4x70": 63, "4x95": 75, "4x120": 75,
        "4x150": 90, "4x185": 100, "4x240": 110,
    }
    key = cable.split("mm²")[0]
    return area_map.get(key, 25)


def calc_voltage_drop(current, length_m, cable, voltage):
    """Calculate voltage drop percentage."""
    resistivity = {
        "1.5": 12.1, "2.5": 7.41, "4": 4.61, "6": 3.08,
        "10": 1.83, "16": 1.15, "25": 0.727, "35": 0.524,
        "50": 0.387, "70": 0.268, "95": 0.193, "120": 0.153,
        "150": 0.124, "185": 0.0991, "240": 0.0754, "300": 0.0601,
    }
    size = cable.split("x")[1].split("mm")[0]
    r = resistivity.get(size, 1.0)  # mΩ/m
    vdrop_v = 2 * current * r * length_m / 1000  # single phase
    return vdrop_v / voltage * 100
```

# Examples

## Example 1: Generate Complete SLD for Office Building

**Input:** "Generate SLD for 5-floor office, 1000kVA transformer, 22/0.4kV"

**Output:** DXF file with transformer, MSB (1600A), 5 sub-panels (DB-1F to DB-5F),
each with lighting (63A), power (100A), HVAC (200A) circuits, cable sizes labeled.

## Example 2: Extract BOQ from Existing Drawing

**Input:** "Extract equipment quantities from electrical_layout.dxf"

**Output:** Excel file with:
- Equipment sheet: block counts by type and layer
- Cables & Pipes sheet: total lengths by layer category
- Summary: total panels, outlets, lights, cable meters

## Example 3: Batch Generate Panel Schedules

**Input:** "Create panel schedules for 10 distribution boards"

**Output:** DXF with 10 formatted panel schedule tables showing circuit numbers,
descriptions, breaker sizes, cable sizes, loads, and phase allocation.

# Constraints

- NEVER modify original DWG/DXF files without creating backup first
- ALL cable sizing MUST comply with IEC 60228 / TCVN 6612
- Voltage drop MUST NOT exceed 3% (lighting) or 5% (power)
- Layer naming MUST follow AIA/NCS standard (E- for electrical, M- for mechanical)
- DXF output MUST be version R2018 or R2013 for maximum compatibility
- ALWAYS use mm as drawing unit (model space)
- Block names MUST NOT contain special characters or spaces
- NEVER hardcode file paths — use relative paths or user input
- Equipment symbols MUST be to scale in layout drawings
- Cable tray fill ratio MUST NOT exceed 50% per IEC 61537
