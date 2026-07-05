# Fase 28 - Adaptador de prenda serializable al generador universal

## Objetivo

Conectar el contrato serializable de prendas y el motor de formulas geometricas con una capa de adaptacion compatible con el flujo del generador universal.

Esta fase no registra todavia prendas JSON dentro del catalogo global y no modifica la GUI.

## Alcance implementado

Se agrego:

```text
engine/garments/serializable/adapter.py
scripts/generate_serializable_pattern.py
tests/test_serializable_garment_adapter.py
docs/37_Fase_28_Adaptador_Prenda_Serializable_Generador_Universal.md
```

Se actualizo:

```text
Makefile
```

Nuevo target:

```bash
make generate-serializable-short
```

## Flujo tecnico

```text
JSON serializable
  -> load_definition_from_json
  -> SerializableGarmentDefinition
  -> SerializableGarmentDraft
  -> generate_serializable_geometry
  -> SerializablePatternPiece
  -> SerializableGenerationResult
  -> resumen estilo CLI universal
```

## Resultado esperado

```text
GARMENT_CODE: short_basico
GARMENT_NAME: Short basico
DRAFT_CLASS: SerializableGarmentDraft
PIECE_COUNT: 1
PIECE_1: Short delantero lines=3
```

## Decisiones

- No se modifica el registro global de prendas.
- No se toca la GUI universal.
- No se exporta todavia la prenda JSON a SVG/DXF/PDF.
- El adaptador es una capa intermedia para no mezclar el DSL con las prendas Python existentes.

## Validaciones

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make generate-serializable-short
```

## Proxima fase sugerida

```text
Fase 29 - Registro de prendas serializables JSON en catalogo universal
```

En esa fase el codigo `short_basico` deberia poder resolverse desde el flujo universal por codigo de prenda, sin depender de un script separado.
