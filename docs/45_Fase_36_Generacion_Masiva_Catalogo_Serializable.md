# Fase 36 - Generacion masiva del catalogo serializable

## Objetivo

Crear un smoke test productivo para generar automaticamente todas las prendas JSON del catalogo serializable usando las medidas por defecto declaradas en cada definicion.

La Fase 35 valida que el catalogo JSON sea semanticamente correcto y generable como pipeline de calidad. La Fase 36 separa la generacion masiva como una capacidad propia del motor, util para QA, integracion continua y futuras exportaciones masivas.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/catalog_generation.py`.
- Nuevo CLI `scripts/generate_serializable_catalog.py`.
- Nuevo target `make generate-serializable-catalog`.
- Tests de generacion masiva por directorio.
- Tests de generacion masiva por lista explicita de archivos.
- Exposicion de API publica desde `engine.garments.serializable`.
- Documentacion tecnica de cierre.

## Contrato funcional

La generacion masiva ejecuta:

1. Descubrimiento automatico de `*.json` en `examples/garments/`.
2. Validacion semantica de cada JSON antes de generar.
3. Carga de definicion serializable.
4. Generacion de geometria usando defaults declarados en el JSON.
5. Reporte por prenda con piezas, puntos, lineas y variables usadas.

## Comando principal

```bash
make generate-serializable-catalog
```

CLI directo:

```bash
.venv/bin/python scripts/generate_serializable_catalog.py --definitions-dir examples/garments
```

## Resultado esperado

```text
CATALOG_GENERATION_OK: examples/garments definitions=2 generated_pieces=2 generated_points=8 generated_lines=8
GENERATED_DEFINITION: examples/garments/falda_evase.json code=falda_evase name=Falda evase pieces=1 points=4 lines=4 variables=4
GENERATED_DEFINITION: examples/garments/short_basico.json code=short_basico name=Short basico pieces=1 points=4 lines=4 variables=4
```

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Valor tecnico

El motor ya no depende de pruebas una por una para saber si el catalogo JSON puede generar geometria. Cualquier nueva prenda colocada en `examples/garments/` entra automaticamente al smoke test productivo de generacion.

Esto prepara la siguiente capa natural: exportacion masiva del catalogo serializable hacia SVG/DXF/PDF.

## Siguiente paso recomendado

Fase 37 - Exportacion masiva del catalogo serializable hacia SVG/DXF/PDF.
