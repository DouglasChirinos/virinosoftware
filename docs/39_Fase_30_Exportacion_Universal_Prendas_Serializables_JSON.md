# Fase 30 - Exportacion universal SVG/DXF/PDF para prendas serializables JSON

## Objetivo

Permitir que una prenda serializable JSON registrada en el catalogo universal pueda exportarse mediante el flujo estandar de exportacion del motor.

La prenda validada en esta fase es:

```text
short_basico
```

## Alcance

- Exportar `short_basico` desde `scripts/export_pattern.py`.
- Generar archivos SVG, DXF y PDF.
- Agregar target `make export-universal-short`.
- Agregar prueba automatizada de exportacion universal.
- Mantener compatibilidad con prendas Python tradicionales.
- No modificar GUI.
- No crear nuevas prendas.

## Comando operativo

```bash
make export-universal-short
```

Comando equivalente:

```bash
.venv/bin/python scripts/export_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20 --output short_basico_universal
```

## Salidas esperadas

```text
exports/svg/short_basico_universal.svg
exports/dxf/short_basico_universal.dxf
exports/pdf/short_basico_universal.pdf
```

## Validaciones

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make generate-universal-short
make generate-serializable-short
make export-pattern
make export-basic-pants
make export-universal-short
```

## Resultado esperado

`short_basico` queda integrado al ciclo completo del motor:

```text
JSON -> catalogo universal -> generacion universal -> exportacion universal SVG/DXF/PDF
```
