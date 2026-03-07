# SolidWorks VBA Macros - Quick Templates

## How to Run VBA Macros

1. Open SolidWorks → Tools → Macro → New (or Edit)
2. Paste code → Run (F5)
3. Save as .swp file for reuse

## Macro 1: Auto-Dimension All Edges

```vba
Sub AutoDimensionAllEdges()
    Dim swApp As SldWorks.SldWorks
    Dim swModel As ModelDoc2
    Dim swDraw As DrawingDoc
    Dim swView As View

    Set swApp = Application.SldWorks
    Set swModel = swApp.ActiveDoc

    If swModel.GetType <> 3 Then
        MsgBox "Open a drawing first!"
        Exit Sub
    End If

    Set swDraw = swModel
    Set swView = swDraw.ActiveDrawingView

    swModel.InsertModelAnnotations3 0, 32, True, True, False, True
    swModel.ForceRebuild3 True

    MsgBox "Dimensions added!"
End Sub
```

## Macro 2: Export All Configs to STEP

```vba
Sub ExportAllConfigsSTEP()
    Dim swApp As SldWorks.SldWorks
    Dim swModel As ModelDoc2
    Dim configNames As Variant
    Dim folder As String

    Set swApp = Application.SldWorks
    Set swModel = swApp.ActiveDoc

    folder = Left(swModel.GetPathName, InStrRev(swModel.GetPathName, "\"))
    configNames = swModel.GetConfigurationNames

    Dim i As Integer
    For i = 0 To UBound(configNames)
        swModel.ShowConfiguration2 configNames(i)
        swModel.ForceRebuild3 True

        Dim outPath As String
        outPath = folder & configNames(i) & ".step"

        Dim errors As Long, warnings As Long
        swModel.Extension.SaveAs outPath, 0, 1, Nothing, errors, warnings
    Next i

    MsgBox "Exported " & (UBound(configNames) + 1) & " configurations!"
End Sub
```

## Macro 3: Mass Properties Report

```vba
Sub MassPropertiesReport()
    Dim swApp As SldWorks.SldWorks
    Dim swModel As ModelDoc2
    Dim props As Variant

    Set swApp = Application.SldWorks
    Set swModel = swApp.ActiveDoc

    props = swModel.Extension.GetMassProperties(1, 0)

    If Not IsEmpty(props) Then
        Dim msg As String
        msg = "Mass Properties:" & vbCrLf
        msg = msg & "Mass: " & Format(props(5), "0.000") & " kg" & vbCrLf
        msg = msg & "Volume: " & Format(props(3) * 1000000000#, "0.0") & " mm³" & vbCrLf
        msg = msg & "Surface: " & Format(props(4) * 1000000#, "0.0") & " mm²" & vbCrLf
        msg = msg & "CoG: (" & Format(props(0) * 1000, "0.0") & ", " & _
              Format(props(1) * 1000, "0.0") & ", " & _
              Format(props(2) * 1000, "0.0") & ") mm"
        MsgBox msg, vbInformation, "Mass Properties"
    End If
End Sub
```

## Macro 4: Batch Update Custom Properties

```vba
Sub BatchUpdateProperties()
    Dim swApp As SldWorks.SldWorks
    Dim swModel As ModelDoc2
    Dim folder As String
    Dim filename As String

    Set swApp = Application.SldWorks
    folder = "C:\Projects\Parts\"
    filename = Dir(folder & "*.sldprt")

    Do While filename <> ""
        Dim errors As Long, warnings As Long
        Set swModel = swApp.OpenDoc6(folder & filename, 1, 1, "", errors, warnings)

        If Not swModel Is Nothing Then
            Dim mgr As CustomPropertyManager
            Set mgr = swModel.Extension.CustomPropertyManager("")
            mgr.Add3 "Project", 30, "PROJECT-001", 2
            mgr.Add3 "Author", 30, "Engineering Dept", 2

            swModel.Save3 1, errors, warnings
            swApp.CloseDoc swModel.GetTitle
        End If

        filename = Dir
    Loop

    MsgBox "Properties updated!"
End Sub
```

## Macro 5: Create Drawing from Active Part

```vba
Sub AutoCreateDrawing()
    Dim swApp As SldWorks.SldWorks
    Dim swModel As ModelDoc2
    Dim swDraw As DrawingDoc
    Dim partPath As String

    Set swApp = Application.SldWorks
    Set swModel = swApp.ActiveDoc

    If swModel Is Nothing Then Exit Sub
    partPath = swModel.GetPathName

    ' Create A3 drawing
    Dim template As String
    template = swApp.GetUserPreferenceStringValue(9)
    swApp.NewDocument template, 4, 0, 0  ' 4 = A3
    Set swDraw = swApp.ActiveDoc

    ' Front view
    swDraw.CreateDrawViewFromModelView3 partPath, "*Front", 0.15, 0.2, 0
    ' Right view
    swDraw.CreateDrawViewFromModelView3 partPath, "*Right", 0.35, 0.2, 0
    ' Top view
    swDraw.CreateDrawViewFromModelView3 partPath, "*Top", 0.15, 0.07, 0
    ' Isometric
    swDraw.CreateDrawViewFromModelView3 partPath, "*Isometric", 0.35, 0.07, 0

    ' Auto dimensions on front view
    swDraw.ActivateView "Drawing View1"
    swDraw.InsertModelAnnotations3 0, 32, True, True, False, True

    MsgBox "Drawing created with 4 views!"
End Sub
```

## Macro 6: Flatten Sheet Metal & Export DXF

```vba
Sub FlattenAndExportDXF()
    Dim swApp As SldWorks.SldWorks
    Dim swModel As ModelDoc2
    Dim folder As String

    Set swApp = Application.SldWorks
    Set swModel = swApp.ActiveDoc

    If swModel Is Nothing Then Exit Sub

    folder = Left(swModel.GetPathName, InStrRev(swModel.GetPathName, "\"))
    Dim partName As String
    partName = Mid(swModel.GetTitle, 1, InStrRev(swModel.GetTitle, ".") - 1)

    ' Export flat pattern
    Dim outPath As String
    outPath = folder & partName & "_FLAT.dxf"

    swModel.ExportFlatPatternView outPath, 1
    MsgBox "Flat pattern exported: " & outPath
End Sub
```
