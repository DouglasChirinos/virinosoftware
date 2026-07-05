# Fase 37 - Exportacion masiva del catalogo serializable SVG/DXF/PDF

## Objetivo

Agregar una salida productiva masiva para exportar automaticamente todas las prendas JSON del catalogo serializable hacia SVG, DXF y PDF.

La Fase 36 valida que todas las definiciones JSON puedan generar geometria. La Fase 37 cierra el ciclo de punta a punta: JSON validado -> geometria generada -> archivos industriales/exportables.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/catalog_export.py`.
- Nuevo CLI `scripts/export_serializable_catalog.py`.
- Nuevo target `make export-serializable-catalog`.
- Exportacion masiva hacia `exports/catalog/svg`, `exports/catalog/dxf` y `exports/catalog/pdf`.
- Tests de exportacion masiva completa.
- Tests de exportacion parcial por formato.
- Tests de CLI con descubrimiento automatico.
- Exposicion de API publica desde `engine.garments.serializable`.

## Comando principal

```bash
make export-serializable-catalog
```

CLI directo:

```bash
.venv/bin/python scripts/export_serializable_catalog.py --definitions-dir examples/garments --output-dir exports/catalog
```

## Resultado esperado

```text
CATALOG_EXPORT_OK: examples/garments definitions=2 exported_files=6 output_dir=exports/catalog total_bytes=...
EXPORTED_DEFINITION: examples/garments/falda_evase.json code=falda_evase name=Falda evase pieces=1 exported_files=3 svg=exports/catalog/svg/falda_evase.svg dxf=exports/catalog/dxf/falda_evase.dxf pdf=exports/catalog/pdf/falda_evase.pdf
EXPORTED_DEFINITION: examples/garments/short_basico.json code=short_basico name=Short basico pieces=1 exported_files=3 svg=exports/catalog/svg/short_basico.svg dxf=exports/catalog/dxf/short_basico.dxf pdf=exports/catalog/pdf/short_basico.pdf
```

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Valor tecnico

El motor ya puede validar, generar y exportar en bloque todo el catalogo JSON sin declarar prenda por prenda. Esto reduce deuda operativa y prepara el cierre de release v0.2.0.

## Siguiente paso recomendado

Fase 38 - Documentacion y checklist release v0.2.0.

## Nota tecnica: imports diferidos

El modulo `engine/garments/serializable/catalog_export.py` usa imports diferidos de
`engine.generation.exporter` y `engine.generation.pattern_generator` dentro del flujo de
exportacion. Esta decision evita un ciclo de imports entre `engine.generation`,
`engine.garments` y el paquete serializable cuando se ejecutan CLIs como
`scripts/export_pattern.py`.

