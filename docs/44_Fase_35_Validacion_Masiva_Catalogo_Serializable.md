# Fase 35 - Validacion masiva del catalogo serializable

## Objetivo

Crear un pipeline de calidad para validar automaticamente todas las prendas JSON del catalogo serializable sin declarar cada archivo manualmente en el Makefile.

Esta fase convierte el flujo de validacion de prendas JSON en un proceso escalable para crecer de dos prendas a muchas prendas sin deuda operativa.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/catalog_quality.py`.
- Nuevo CLI `scripts/validate_serializable_catalog.py`.
- Nuevo target `make validate-serializable-catalog`.
- Actualizacion de `make validate-garments-json` para usar descubrimiento por directorio.
- Tests de descubrimiento automatico del catalogo.
- Tests del pipeline semantico + generacion por defecto.
- Documentacion tecnica de cierre.

## Contrato funcional

El pipeline de catalogo ejecuta:

1. Descubrimiento automatico de `*.json` en `examples/garments/`.
2. Validacion semantica de cada definicion JSON.
3. Generacion geometrica usando defaults declarados en cada JSON.
4. Validacion de unicidad de `code` dentro del catalogo.
5. Resumen operativo por cada prenda.

## Comandos principales

Validar semantica de todos los JSON por directorio:

```bash
make validate-garments-json
```

Validar catalogo completo con semantica + generacion por defecto:

```bash
make validate-serializable-catalog
```

Ejecutar CLI directo:

```bash
.venv/bin/python scripts/validate_serializable_catalog.py --definitions-dir examples/garments
```

## Resultado esperado

```text
CATALOG_OK: examples/garments definitions=2 generated_pieces=2 generated_points=8 generated_lines=8
CATALOG_DEFINITION: examples/garments/falda_evase.json code=falda_evase ...
CATALOG_DEFINITION: examples/garments/short_basico.json code=short_basico ...
```

El orden puede variar segun orden alfabetico de archivos, pero debe ser deterministico.

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Valor tecnico

Antes de esta fase, el Makefile conocia explicitamente cada JSON. Eso no escala.

Despues de esta fase, una nueva prenda serializable colocada en `examples/garments/` entra automaticamente al pipeline de calidad del catalogo, siempre que tenga defaults suficientes para generar geometria base.

## Siguiente paso recomendado

Despues de Fase 35, el siguiente paso logico es versionar formalmente el DSL JSON o agregar fixtures de catalogo invalido para blindar compatibilidad hacia atras.
