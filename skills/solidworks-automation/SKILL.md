---
name: solidworks-automation
description: |
  Automate mechanical and electrical design in SolidWorks using Python
  (win32com, comtypes), VBA Macros, and .NET API. Covers parametric part
  modeling, assembly automation, drawing generation with auto-dimensioning,
  sheet metal design, weldment structures, piping/tubing routing, electrical
  harness design, FEA simulation setup, BOM/BOQ extraction, batch export
  (STEP/IGES/PDF/DXF), and design table-driven configurations.
  Use when automating SolidWorks workflows, generating parts/assemblies
  programmatically, creating drawings from models, or batch processing
  SolidWorks files.
version: 1.0.0
tags: [SolidWorks, CAD, Mechanical, Automation, API, VBA, Python, Sheet Metal, FEA, BOM]
dependencies: [comtypes, pywin32, numpy, pandas, openpyxl]
---

# Goal

Automate SolidWorks design workflows — from parametric part creation to
assembly building to production drawings — reducing repetitive CAD tasks
by 80-95% while maintaining design intent and engineering standards.

# Instructions

## Connection & Setup

### Python COM Connection (Primary Method)

```python
import win32com.client
import pythoncom

def connect_solidworks(version: int = 2024):
    """Connect to running SolidWorks instance."""
    try:
        sw = win32com.client.Dispatch("SldWorks.Application")
    except:
        sw = win32com.client.Dispatch(f"SldWorks.Application.{version - 1992}")
    sw.Visible = True
    return sw


def get_active_doc(sw):
    """Get active document (Part, Assembly, or Drawing)."""
    doc = sw.ActiveDoc
    if doc is None:
        raise RuntimeError("No active document in SolidWorks")
    doc_types = {1: "Part", 2: "Assembly", 3: "Drawing"}
    print(f"Active: {doc.GetTitle()} ({doc_types.get(doc.GetType(), 'Unknown')})")
    return doc


# Constants
SW_PART = 1
SW_ASSEMBLY = 2
SW_DRAWING = 3
```

### Alternative: comtypes Connection

```python
import comtypes.client

def connect_sw_comtypes():
    sw = comtypes.client.GetActiveObject("SldWorks.Application")
    return sw
```

## Phase 1: Part Modeling Automation

### 1.1 Create New Part with Features

```python
def create_part(sw, template_path=None):
    """Create new part document."""
    if template_path is None:
        template_path = sw.GetUserPreferenceStringValue(
            7)  # swDefaultTemplatePart
    doc = sw.NewDocument(template_path, 0, 0, 0)
    model = sw.ActiveDoc
    return model


def add_extrude_boss(model, sketch_plane="Front Plane", depth_mm=10,
                     sketch_func=None):
    """Create extruded boss from sketch."""
    # Select sketch plane
    model.Extension.SelectByID2(sketch_plane, "PLANE", 0, 0, 0, False, 0, None, 0)
    model.SketchManager.InsertSketch(True)

    # Draw sketch (user-provided function)
    if sketch_func:
        sketch_func(model)

    model.SketchManager.InsertSketch(True)

    # Extrude
    model.FeatureManager.FeatureExtrusion2(
        True,           # single direction
        False,          # flip
        False,          # merge
        0,              # end condition: blind
        0,              # end condition 2
        depth_mm / 1000,  # depth (meters)
        0,              # depth 2
        False, False, False, False,
        0, 0,           # draft angle
        False, False, False, False,
        True, True, True,
        0, 0, False
    )
    model.ClearSelection2(True)


def sketch_rectangle(model, width_mm, height_mm, center=True):
    """Draw rectangle in active sketch."""
    mgr = model.SketchManager
    w, h = width_mm / 1000, height_mm / 1000
    if center:
        mgr.CreateCenterRectangle(0, 0, 0, w/2, h/2, 0)
    else:
        mgr.CreateCornerRectangle(0, 0, 0, w, h, 0)


def sketch_circle(model, diameter_mm, cx=0, cy=0):
    """Draw circle in active sketch."""
    r = diameter_mm / 2000  # mm to meters, then radius
    model.SketchManager.CreateCircle(cx/1000, cy/1000, 0, cx/1000 + r, cy/1000, 0)


def add_fillet(model, radius_mm, edge_indices=None):
    """Add fillet to selected edges."""
    model.FeatureManager.FeatureFillet3(
        194,                # options
        radius_mm / 1000,   # radius
        0, 0, 0, 0, 0, 0,  # other radii
        0, 0, 0, 0, 0, 0   # parameters
    )


def add_chamfer(model, distance_mm, angle_deg=45):
    """Add chamfer to selected edges."""
    model.FeatureManager.InsertFeatureChamfer(
        4,                    # options
        1,                    # chamfer type: distance-angle
        distance_mm / 1000,   # distance
        angle_deg * 3.14159 / 180,  # angle in radians
        0, 0, 0, 0
    )
```

### 1.2 Parametric Part Generator

```python
def create_flange(sw, od_mm, id_mm, thickness_mm, bolt_holes=4,
                  bolt_pcd_mm=None, bolt_dia_mm=12, save_path=None):
    """Create parametric flange with bolt holes."""
    model = create_part(sw)

    # Outer disk
    model.Extension.SelectByID2("Front Plane", "PLANE", 0, 0, 0, False, 0, None, 0)
    model.SketchManager.InsertSketch(True)
    sketch_circle(model, od_mm)
    sketch_circle(model, id_mm)
    model.SketchManager.InsertSketch(True)

    model.FeatureManager.FeatureExtrusion2(
        True, False, False, 0, 0, thickness_mm / 1000,
        0, False, False, False, False, 0, 0,
        False, False, False, False, True, True, True, 0, 0, False
    )

    # Bolt holes
    if bolt_pcd_mm is None:
        bolt_pcd_mm = (od_mm + id_mm) / 2

    model.Extension.SelectByID2("", "FACE", 0, 0, thickness_mm / 1000,
                                 False, 0, None, 0)
    model.SketchManager.InsertSketch(True)
    sketch_circle(model, bolt_dia_mm, cx=bolt_pcd_mm / 2, cy=0)
    model.SketchManager.InsertSketch(True)

    # Cut extrude for first hole
    model.FeatureManager.FeatureCut3(
        True, False, False, 1, 0, thickness_mm / 1000, 0,
        False, False, False, False, 0, 0,
        False, False, False, False, False,
        True, True, True, True, False, 0, 0, False
    )

    # Circular pattern for remaining holes
    if bolt_holes > 1:
        model.ClearSelection2(True)
        # Select cut feature and axis
        model.FeatureManager.FeatureCircularPattern4(
            bolt_holes,                    # count
            2 * 3.14159,                   # total angle (full circle)
            False,                         # flip direction
            "TRUE", "TRUE", False, False,
            True, True
        )

    if save_path:
        model.Extension.SaveAs(save_path, 0, 1, None, 0, 0)

    return model


def create_shaft(sw, segments: list, save_path=None):
    """
    Create stepped shaft from segments.
    segments: [{'diameter_mm': float, 'length_mm': float, 'chamfer_mm': float}]
    """
    model = create_part(sw)
    total_length = sum(s['length_mm'] for s in segments) / 1000

    model.Extension.SelectByID2("Front Plane", "PLANE", 0, 0, 0, False, 0, None, 0)
    model.SketchManager.InsertSketch(True)

    # Draw profile for revolve
    mgr = model.SketchManager
    x = 0
    points = [(0, 0)]
    for seg in segments:
        r = seg['diameter_mm'] / 2000
        l = seg['length_mm'] / 1000
        points.append((x, r))
        points.append((x + l, r))
        x += l
    points.append((x, 0))

    # Draw lines connecting points
    for i in range(len(points) - 1):
        mgr.CreateLine(points[i][0], points[i][1], 0,
                       points[i+1][0], points[i+1][1], 0)
    # Close profile
    mgr.CreateLine(points[-1][0], points[-1][1], 0, points[0][0], points[0][1], 0)

    model.SketchManager.InsertSketch(True)

    # Revolve
    model.FeatureManager.FeatureRevolve2(
        True, True, False, False,
        True, False,
        0, 0,  # end conditions
        2 * 3.14159,  # angle
        0, False, False,
        0, 0, 0, 0, 0, True, True, True
    )

    if save_path:
        model.Extension.SaveAs(save_path, 0, 1, None, 0, 0)

    return model
```

## Phase 2: Assembly Automation

```python
def create_assembly(sw, components: list, save_path=None):
    """
    Build assembly from component list.
    components: [{'path': str, 'x': float, 'y': float, 'z': float,
                  'rotation': tuple, 'name': str}]
    """
    template = sw.GetUserPreferenceStringValue(8)  # swDefaultTemplateAssembly
    sw.NewDocument(template, 0, 0, 0)
    assy = sw.ActiveDoc

    for comp in components:
        assy.AddComponent5(
            comp['path'],
            0,  # config
            "",
            False,
            "",
            comp.get('x', 0) / 1000,
            comp.get('y', 0) / 1000,
            comp.get('z', 0) / 1000
        )

    if save_path:
        assy.Extension.SaveAs(save_path, 0, 1, None, 0, 0)

    return assy


def add_mate(assy, entity1_name, entity2_name, mate_type="COINCIDENT"):
    """Add mate between two entities."""
    mate_types = {
        "COINCIDENT": 0, "CONCENTRIC": 1, "PERPENDICULAR": 2,
        "PARALLEL": 3, "TANGENT": 4, "DISTANCE": 5,
        "ANGLE": 6, "LOCK": 16, "WIDTH": 22,
    }

    assy.Extension.SelectByID2(entity1_name, "FACE", 0, 0, 0, False, 1, None, 0)
    assy.Extension.SelectByID2(entity2_name, "FACE", 0, 0, 0, True, 1, None, 0)

    assy.AddMate5(
        mate_types.get(mate_type, 0),
        0,   # alignment
        False,
        0, 0, 0,  # distance/angle values
        0, 0, 0,  # tolerance
        0, 0,
        False, False,
        0, None
    )
    assy.ClearSelection2(True)


def extract_bom(assy, output_excel="BOM.xlsx"):
    """Extract Bill of Materials from assembly."""
    import pandas as pd

    components = assy.GetComponents(False)
    bom = {}

    for comp in components:
        if comp.IsSuppressed():
            continue
        name = comp.Name2
        path = comp.GetPathName()
        config = comp.ReferencedConfiguration

        part_name = name.rsplit("-", 1)[0] if "-" in name else name
        if part_name in bom:
            bom[part_name]['Qty'] += 1
        else:
            # Get custom properties
            model = comp.GetModelDoc2()
            props = {}
            if model:
                mgr = model.Extension.CustomPropertyManager[config]
                names = mgr.GetNames()
                if names:
                    for pname in names:
                        val = mgr.Get5(pname, False, "", "", False)
                        props[pname] = val[1] if isinstance(val, tuple) else val

            bom[part_name] = {
                'Part Name': part_name,
                'File': path.split("\\")[-1] if path else "",
                'Material': props.get('Material', ''),
                'Description': props.get('Description', ''),
                'Weight (kg)': props.get('Weight', ''),
                'Qty': 1,
            }

    df = pd.DataFrame(bom.values())
    df.index = range(1, len(df) + 1)
    df.index.name = 'Item'
    df.to_excel(output_excel, sheet_name='BOM')
    return df
```

## Phase 3: Drawing Automation

```python
def create_drawing(sw, model_path: str, views: list = None,
                   sheet_size="A3", scale=None, save_path=None):
    """
    Auto-generate drawing from part/assembly.
    views: [{'type': 'front'|'top'|'right'|'iso'|'section', 'x': mm, 'y': mm}]
    """
    sizes = {
        "A0": 7, "A1": 6, "A2": 5, "A3": 4, "A4": 3,
    }

    template = sw.GetUserPreferenceStringValue(9)  # swDefaultTemplateDrawing
    sw.NewDocument(template, sizes.get(sheet_size, 4), 0, 0)
    drawing = sw.ActiveDoc

    if views is None:
        views = [
            {"type": "front", "x": 150, "y": 200},
            {"type": "top",   "x": 150, "y": 80},
            {"type": "right", "x": 350, "y": 200},
            {"type": "iso",   "x": 350, "y": 80},
        ]

    sheet = drawing.GetCurrentSheet()

    view_types = {
        "front": 1, "back": 2, "top": 3, "bottom": 4,
        "right": 5, "left": 6, "iso": 7,
    }

    for view_config in views:
        vtype = view_config['type']
        x = view_config['x'] / 1000
        y = view_config['y'] / 1000

        if vtype == "iso":
            drawing.CreateDrawViewFromModelView3(
                model_path, "*Isometric", x, y, 0
            )
        else:
            drawing.CreateDrawViewFromModelView3(
                model_path, f"*{vtype.capitalize()}", x, y, 0
            )

    # Auto-dimension (optional)
    if scale:
        for view in drawing.GetViews():
            if view:
                for v in view:
                    v.ScaleRatio = scale

    if save_path:
        drawing.Extension.SaveAs(save_path, 0, 1, None, 0, 0)

    return drawing


def auto_add_dimensions(drawing, view_name=None):
    """Automatically insert dimensions on drawing view."""
    drawing.Extension.SelectByID2(
        view_name or "", "DRAWINGVIEW", 0, 0, 0, False, 0, None, 0
    )
    drawing.SetupSheet5("", 0, 0, 1, 1, True, "", 0, 0, "Default", True)

    # Auto-dimension
    model = drawing.ActiveView.ReferencedDocument
    if model:
        drawing.InsertModelAnnotations3(
            0,      # option: all
            32,     # dimensions
            True,   # use dimension placement
            True,   # use full model
            False,
            True
        )


def add_title_block_text(drawing, properties: dict):
    """Fill title block custom properties."""
    mgr = drawing.Extension.CustomPropertyManager[""]
    for key, value in properties.items():
        mgr.Add3(key, 30, value, 2)  # 30=text, 2=overwrite


def add_balloon_annotations(drawing):
    """Add item balloons to assembly drawing views."""
    drawing.InsertBomBalloon2(0)  # auto-balloon
```

## Phase 4: Sheet Metal Automation

```python
def create_sheet_metal_part(sw, base_width_mm, base_length_mm,
                            thickness_mm=2, bend_radius_mm=None):
    """Create sheet metal base flange."""
    if bend_radius_mm is None:
        bend_radius_mm = thickness_mm  # K-factor default

    model = create_part(sw)

    model.Extension.SelectByID2("Front Plane", "PLANE", 0, 0, 0, False, 0, None, 0)
    model.SketchManager.InsertSketch(True)
    sketch_rectangle(model, base_width_mm, base_length_mm)
    model.SketchManager.InsertSketch(True)

    model.FeatureManager.InsertSheetMetalBaseFlange2(
        thickness_mm / 1000,      # thickness
        False,                    # reverse
        bend_radius_mm / 1000,    # bend radius
        base_length_mm / 1000,    # length
        0,                        # gap type
        True, False, 0, 0,
        0, None, False, 0,
        0, 0, 0, True, False
    )

    return model


def add_edge_flange(model, edge_length_mm, angle_deg=90):
    """Add edge flange to sheet metal part."""
    model.FeatureManager.InsertSheetMetalEdgeFlange3(
        True,
        edge_length_mm / 1000,
        0, 0, 0,
        True, False, True,
        angle_deg * 3.14159 / 180,
        1, 1,
        0, 0, 0, 0, 0,
        True, False, False
    )


def export_flat_pattern(model, output_dxf: str):
    """Export flat pattern to DXF for laser cutting."""
    model.ExportFlatPatternView(output_dxf, 1)
```

## Phase 5: Batch Processing & Export

```python
def batch_export(sw, folder: str, export_format: str = "STEP",
                 output_folder: str = None):
    """Batch export all parts/assemblies in folder."""
    import os

    if output_folder is None:
        output_folder = os.path.join(folder, "export")
    os.makedirs(output_folder, exist_ok=True)

    extensions = {
        "STEP": ".step", "IGES": ".igs", "STL": ".stl",
        "PDF": ".pdf", "DXF": ".dxf", "PARASOLID": ".x_t",
    }
    ext = extensions.get(export_format, ".step")

    for filename in os.listdir(folder):
        if filename.lower().endswith(('.sldprt', '.sldasm')):
            filepath = os.path.join(folder, filename)
            doc = sw.OpenDoc6(filepath, SW_PART if filepath.endswith('.sldprt') else SW_ASSEMBLY,
                              1, "", 0, 0)
            if doc:
                model = sw.ActiveDoc
                out_path = os.path.join(output_folder,
                    filename.rsplit('.', 1)[0] + ext)

                model.Extension.SaveAs(out_path, 0, 1, None, 0, 0)
                sw.CloseDoc(model.GetTitle())
                print(f"Exported: {filename} → {ext}")


def batch_update_properties(sw, folder: str, properties: dict):
    """Update custom properties across all parts in folder."""
    import os

    for filename in os.listdir(folder):
        if filename.lower().endswith('.sldprt'):
            filepath = os.path.join(folder, filename)
            doc = sw.OpenDoc6(filepath, SW_PART, 1, "", 0, 0)
            if doc:
                model = sw.ActiveDoc
                mgr = model.Extension.CustomPropertyManager[""]
                for key, value in properties.items():
                    mgr.Add3(key, 30, value, 2)
                model.Save3(1, 0, 0)
                sw.CloseDoc(model.GetTitle())


def batch_print_drawings(sw, folder: str, printer="Microsoft Print to PDF"):
    """Batch print all drawings to PDF."""
    import os

    for filename in os.listdir(folder):
        if filename.lower().endswith('.slddrw'):
            filepath = os.path.join(folder, filename)
            sw.OpenDoc6(filepath, SW_DRAWING, 1, "", 0, 0)
            model = sw.ActiveDoc
            if model:
                page_setup = model.PageSetup
                page_setup.PrinterName = printer
                model.PrintDirect()
                sw.CloseDoc(model.GetTitle())


def export_mass_properties(sw, folder: str, output_excel="Mass_Properties.xlsx"):
    """Extract mass properties from all parts."""
    import os, pandas as pd

    results = []
    for filename in os.listdir(folder):
        if filename.lower().endswith('.sldprt'):
            filepath = os.path.join(folder, filename)
            sw.OpenDoc6(filepath, SW_PART, 1, "", 0, 0)
            model = sw.ActiveDoc
            if model:
                props = model.Extension.GetMassProperties(1, 0)
                if props:
                    results.append({
                        'Part': filename,
                        'Mass (kg)': round(props[5], 3),
                        'Volume (m³)': round(props[3], 6),
                        'Surface Area (m²)': round(props[4], 4),
                        'CoG X': round(props[0], 3),
                        'CoG Y': round(props[1], 3),
                        'CoG Z': round(props[2], 3),
                    })
                sw.CloseDoc(model.GetTitle())

    df = pd.DataFrame(results)
    df.to_excel(output_excel, index=False)
    return df
```

## Phase 6: Design Table (Parametric Configurations)

```python
def create_design_table(model, configurations: list[dict]):
    """
    Create configurations from parameter table.
    configurations: [
        {'name': 'M8x20', 'D@Sketch1': 8, 'L@Boss-Extrude1': 20},
        {'name': 'M10x30', 'D@Sketch1': 10, 'L@Boss-Extrude1': 30},
    ]
    """
    for config in configurations:
        name = config.pop('name')
        model.AddConfiguration3(name, "", "", 0)
        model.ShowConfiguration2(name)

        for param, value in config.items():
            dim_name, feature_name = param.split('@')
            dimension = model.Parameter(param)
            if dimension:
                dimension.SystemValue = value / 1000  # mm to m

    model.ShowConfiguration2(configurations[0].get('name', 'Default'))
```

# Examples

## Example 1: Parametric Bolt Generator

**Input:** "Create M8, M10, M12 hex bolts with lengths 20, 30, 40, 50mm"

**Output:** SolidWorks part file with 12 configurations (3 sizes × 4 lengths),
each with correct hex head dimensions per ISO 4014.

## Example 2: Assembly BOM Export

**Input:** "Extract BOM from conveyor_assembly.sldasm"

**Output:** Excel file with columns: Item, Part Name, Material, Description,
Weight, Qty — ready for procurement.

## Example 3: Batch Export for Manufacturing

**Input:** "Export all parts in /project/ to STEP and flat patterns to DXF"

**Output:** STEP files for CNC machining, DXF flat patterns for laser cutting.

# Constraints

- ALWAYS connect to existing SolidWorks instance — NEVER start SW silently for automation
- ALL dimensions in API calls use **meters** (convert from mm: ÷ 1000)
- NEVER save over original files without creating backup
- ALWAYS use `model.ClearSelection2(True)` after selections
- Sheet metal bend radius MUST be ≥ material thickness
- Assembly mates MUST be fully defined (no under-constrained)
- Custom properties MUST use standard names (Material, Description, Revision, Author)
- Batch operations MUST include error handling per file (don't stop on single failure)
- NEVER modify referenced files while assembly is open
- Export format selection: STEP for manufacturing, STL for 3D printing, DXF for laser cutting
