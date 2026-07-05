# 11. Saneamiento de Geometria Canonica

## Objetivo

Estabilizar el contrato interno del motor de patronaje 2D.

## Problema detectado

Los scripts de exportacion importaban:

```python
from engine.geometry.point import Point
```

pero el modulo canonico no existia todavia.

## Decision

Se establece como API geometrica base:

- `engine.geometry.point.Point`
- `engine.geometry.line.Line`
- `engine.geometry.curve.BezierCurve`
- `engine.geometry.polygon.Polygon`

## Regla de arquitectura

Las prendas no deben definir su propia geometria.
Las prendas solo deben consumir el motor geometrico comun.

## Flujo validado

```text
BodyMeasurements
  -> BasicSkirtDraft
  -> PatternPiece
  -> export_svg / export_dxf / export_pdf
```

## Salidas MVP

- `exports/svg/falda_basica_mvp.svg`
- `exports/dxf/falda_basica_mvp.dxf`
- `exports/pdf/falda_basica_mvp.pdf`
