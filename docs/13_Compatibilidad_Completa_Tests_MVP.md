# 13. Compatibilidad completa con tests MVP

## Problema

La suite tenia contratos de varias iteraciones:

1. `BodyMeasurements` esperaba:
   - `hip_depth`
   - `ease_hip`

2. `BasicSkirtDraft` esperaba:
   - metodo `build()`

3. `engine.garments.skirt.basic` esperaba:
   - funcion `draft_basic_skirt()`

4. `rectangle()` esperaba retornar una tupla de puntos, no un `Polygon`.

## Decision

Se mantienen ambas APIs:

### API nueva

```python
BasicSkirtDraft(measurements).draft()
```

retorna lista de piezas.

### API heredada

```python
BasicSkirtDraft(measurements).build()
draft_basic_skirt(measurements)
rectangle(Point(0, 0), 10, 20)
```

## Regla

Mientras el MVP no llegue a version `0.1.0`, se permite compatibilidad hacia atras para estabilizar el desarrollo.
No se deben borrar tests que documenten contratos activos.
