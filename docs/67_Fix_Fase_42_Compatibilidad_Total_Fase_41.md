# Fix Fase 42 — Compatibilidad total con contrato Fase 41

## Objetivo

Fase 42 incorpora un editor GUI MVP, pero no puede romper el contrato de transformaciones editables creado en Fase 41.

## Problema

El editor sobrescribio parte de `engine/transformations/apply.py` y dejo fuera elementos del contrato publico:

- `TransformOperation.start_point`
- `TransformOperation.end_point`
- `TransformOperation.factor`
- `TransformOperation.anchor`
- parametro `variant` en `apply_transformations`
- metadata `base_pattern_preserved`
- metadata `transformation_history`
- ajuste correcto de controles Bezier
- mensajes estables de `TransformError`

## Correccion

Se restaura el contrato completo:

- `move_point`
- `move_line`
- `scale_line`
- `adjust_curve`
- `PatternVariant`
- `TransformError`
- `apply_transformations(..., variant=...)`

## Criterio de cierre

Deben pasar:

```bash
make validate-fase-41
make validate-fase-42
```

Fase 42 puede ampliar la interfaz, pero Fase 41 sigue siendo el contrato backend de transformacion.
