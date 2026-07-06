# Fix Fase 42 - Restaurar TransformError y compatibilidad con Fase 41

## Contexto

La Fase 42 agrego el editor visual MVP en GUI y valido correctamente sus pruebas propias.

Sin embargo, al sobrescribir `engine/transformations/apply.py`, se perdio el simbolo publico `TransformError`, usado por los tests y el contrato de Fase 41.

## Problema

`make validate-fase-41` fallaba durante la coleccion de tests:

```text
ImportError: cannot import name 'TransformError' from 'engine.transformations.apply'
```

## Correccion

Se restaura:

```python
class TransformError(ValueError):
    """Error raised when an editable pattern transformation cannot be applied."""
```

Y se actualizan las excepciones internas del aplicador de transformaciones para usar `TransformError` en vez de `ValueError` directo.

## Criterio de aceptacion

Deben pasar:

```bash
make validate-fase-42
make validate-fase-41
```

## Regla tecnica

La Fase 42 puede ampliar el contrato de transformaciones, pero no puede romper el API publico establecido en Fase 41.
