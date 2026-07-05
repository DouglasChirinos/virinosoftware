# 14. Cierre de compatibilidad de tests MVP

## Hallazgos

Quedaban tres contratos cruzados:

1. `draft_basic_skirt()` esperaba dos piezas con nombres exactos:
   - `Falda basica - delantero`
   - `Falda basica - posterior`

2. `BasicSkirtDraft().draft()` esperaba una sola pieza en otra prueba.

3. Los exportadores recibian `piece.lines`, es decir `list[Line]`, no necesariamente `PatternPiece`.

## Decision

Se separan contratos:

- `BasicSkirtDraft().draft()` retorna una pieza para MVP atomico.
- `BasicSkirtDraft().draft_full()` retorna delantero y posterior.
- `draft_basic_skirt()` usa `draft_full()` para compatibilidad legacy.
- Exportadores aceptan:
  - `PatternPiece`
  - `list[PatternPiece]`
  - `list[Line]`

## Resultado esperado

```bash
make test
make generate-all-exports
make show-exports
```

debe finalizar sin errores.
