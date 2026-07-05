# 21. Fase 16 - Uniones industriales de margen

## Objetivo

Mejorar el margen cerrado agregando control de esquinas tipo `miter` y fallback `bevel`.

## Alcance aplicado

- Clasificacion de esquinas de margen.
- Medicion de distancia miter.
- Limite configurable de miter.
- Fallback bevel si el miter excede el limite.
- Metadata industrial de margen.
- QA de metadata y vertices finitos.
- Reporte de margen con analisis de esquinas.
- Tests automatizados.

## Unidad

La unidad oficial sigue siendo:

```text
cm
```

## Configuracion

```python
SeamAllowanceConfig(
    default_cm=1.0,
    hem_cm=3.0,
    waist_cm=1.0,
    side_cm=1.5,
    corner_join="miter",
    miter_limit_cm=8.0,
    bevel_fallback=True,
)
```

## Criterio industrial MVP

- Si el miter queda dentro del limite: se usa `miter`.
- Si el miter excede el limite: se usa fallback `bevel`.
- El contorno de margen debe seguir cerrado.
