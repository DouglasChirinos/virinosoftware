# Fix Fase 42 - Contrato unificado Fase 41/Fase 42

## Problema

El editor GUI de Fase 42 sobrescribio partes del contrato de transformaciones definido en Fase 41. Eso genero fallos de compatibilidad en:

- `edit_history` de curvas ajustadas.
- `editable_variant` en metadata de piezas.
- `PatternVariant(measurements=...)` requerido por Fase 42.
- Operaciones `move_line` y `scale_line` basadas en `start_point` / `end_point`.

## Decision

Fase 42 no redefine el contrato. Consume y amplía Fase 41.

## Resultado

Se normalizaron:

- `TransformOperation` con soporte completo para `point`, `start_point`, `end_point`, `line`, `curve`, `factor`, `anchor` y `control_delta`.
- `PatternVariant` con `measurements`.
- `apply_transformations(..., variant=...)`.
- Metadata `base_pattern_preserved`, `transformation_history`, `editable_variant` y `variant`.
- `edit_history` dentro de cada curva estructural ajustada.

## Regla fija

El patron base no se modifica. Toda edicion se guarda como una operacion replayable sobre una variante.
