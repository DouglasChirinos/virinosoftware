# 12. Compatibilidad de Geometria Legacy

## Contexto

Durante la fase 07 se normalizo la geometria canonica:

- `Point`
- `Line`
- `BezierCurve`
- `Polygon`

Al ejecutar la suite completa aparecio un test previo:

```text
tests/test_geometry.py
```

Ese test esperaba funciones auxiliares existentes en una primera version del motor:

- `midpoint`
- `rectangle`
- `line_intersection`

## Decision

No se elimina el test viejo.
Se conserva compatibilidad hacia atras agregando un modulo de operaciones:

```text
engine/geometry/operations.py
```

## API publica mantenida

```python
from engine.geometry import Line, Point, line_intersection, midpoint, rectangle
```

## Regla

Las operaciones geometricas reutilizables deben vivir en:

```text
engine/geometry/operations.py
```

No deben duplicarse dentro de prendas, exportadores ni GUI.
