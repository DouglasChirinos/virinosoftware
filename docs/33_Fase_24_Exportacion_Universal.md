# Fase 24 - Exportación universal SVG/DXF/PDF

## Objetivo

Crear una capa universal de exportación para que cualquier prenda generada por el generador universal pueda producir salidas SVG, DXF y PDF.

## Alcance implementado

- Se crea `engine/generation/exporter.py`.
- Se crea `PatternExportRequest`.
- Se crea `PatternExportResult`.
- Se crea `PatternExportError`.
- Se crea `export_generated_pattern`.
- Se crea `normalize_pieces`.
- Se crea CLI `scripts/export_pattern.py`.
- Se agregan targets:
  - `make export-pattern`
  - `make export-basic-pants`
- Se agregan tests de exportación universal.
- Se mantiene compatibilidad con scripts legacy.
- No se modifica el GUI.

## Flujo técnico

```text
PatternGenerationRequest
  -> generate_pattern
  -> PatternGenerationResult
  -> normalize_pieces
  -> export_svg / export_dxf / export_pdf
  -> PatternExportResult
```

## Uso

Exportar falda básica desde flujo universal:

```bash
make export-pattern
```

Exportar pantalón básico desde flujo universal:

```bash
make export-basic-pants
```

## Salidas esperadas

```text
exports/svg/falda_basica_universal.svg
exports/dxf/falda_basica_universal.dxf
exports/pdf/falda_basica_universal.pdf

exports/svg/pantalon_basico_universal.svg
exports/dxf/pantalon_basico_universal.dxf
exports/pdf/pantalon_basico_universal.pdf
```

## Decisión técnica

Fase 24 no toca el GUI. Primero estabiliza la salida universal del backend.

El GUI puede desacoplarse después para consumir:

```text
list_garments
generate_pattern
export_generated_pattern
```

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
