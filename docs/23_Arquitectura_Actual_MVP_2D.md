# 23. Arquitectura actual MVP 2D

## Resumen

El proyecto esta organizado como un motor Python modular para patronaje 2D.

## Estructura principal

```text
engine/
  geometry/
  measurements/
  garments/
  patterns/
  exports/
  qa/
  reports/
  logging/

app/
  main.py

scripts/
  generate_basic_skirt_all_exports.py
  run_basic_skirt_qa.py

tests/
docs/
reports/
exports/
```

## Capas

### `engine.geometry`

Responsable de primitivas geometricas y operaciones base:

- `Point`
- `Line`
- `BezierCurve`
- `Polygon`
- operaciones legacy
- offsets
- intersecciones
- analisis de esquinas

### `engine.measurements`

Responsable de medidas corporales y validacion de dominio:

- `BodyMeasurements`
- `MeasurementValidationError`
- unidad oficial `cm`

### `engine.garments`

Responsable de generadores de prendas.

MVP actual:

```text
engine/garments/skirt/basic_skirt.py
```

### `engine.patterns`

Responsable de piezas de patronaje y metadata:

- `PatternPiece`
- `PatternVersion`
- `SeamAllowanceConfig`
- `apply_seam_allowance`

### `engine.exports`

Responsable de salida a formatos:

- SVG
- DXF
- PDF

### `engine.qa`

Responsable de control de calidad:

- errores geometricos,
- advertencias,
- validacion de contornos,
- validacion de margen,
- validacion de metadata industrial.

### `engine.reports`

Responsable de reportes Markdown:

- reporte tecnico del patron,
- reporte QA,
- reporte de margen.

### `app`

Interfaz grafica minima CustomTkinter.

## Flujo tecnico

```text
BodyMeasurements
      |
      v
BasicSkirtDraft
      |
      v
PatternPiece base
      |
      v
apply_seam_allowance
      |
      v
PatternPiece con margen
      |
      v
QA + exportadores + reportes
```

## Salidas

```text
exports/svg/falda_basica_mvp.svg
exports/dxf/falda_basica_mvp.dxf
exports/pdf/falda_basica_mvp.pdf

reports/falda_basica_mvp_reporte.md
reports/falda_basica_mvp_qa.md
reports/falda_basica_mvp_margen.md
```
