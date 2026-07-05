# 15. Contratos de nombres de falda basica

## Problema

Existian dos expectativas activas:

1. API principal nueva:

```python
BasicSkirtDraft(...).draft()[0].name == "Falda basica delantera"
```

2. API heredada:

```python
[piece.name for piece in draft_basic_skirt(...)] == [
    "Falda basica - delantero",
    "Falda basica - posterior",
]
```

## Decision

Se separan responsabilidades:

- `BasicSkirtDraft` mantiene nombres modernos/descriptivos.
- `draft_basic_skirt()` adapta nombres legacy para compatibilidad.

## Regla

No se deben cambiar nombres visibles sin actualizar pruebas y documentacion.
