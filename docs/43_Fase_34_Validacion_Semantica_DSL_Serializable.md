# Fase 34 - Validacion semantica del DSL serializable

## Objetivo

Agregar una capa de control de calidad semantico para las definiciones JSON de prendas serializables antes de generar geometria o exportaciones.

Esta fase complementa la Fase 33:

- Fase 33 valida la geometria generada y los archivos exportados.
- Fase 34 valida que el DSL JSON sea consistente antes de generar.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/semantic_validation.py`.
- Nuevo CLI `scripts/validate_garment_definition.py`.
- Nuevo target `make validate-garments-json`.
- Tests para `short_basico.json` y `falda_evase.json`.
- Tests negativos para:
  - formula con medicion no declarada;
  - puntos huerfanos;
  - lineas duplicadas, incluyendo duplicados invertidos.

## Reglas semanticas validadas

El contrato semantico valida:

1. La estructura base sigue siendo valida segun el contrato serializable existente.
2. Toda formula usa solo mediciones declaradas en `measurements`.
3. Toda formula usa solo aritmetica segura del DSL.
4. Toda linea referencia puntos existentes.
5. No existen lineas duplicadas ni duplicadas invertidas.
6. No existen puntos huerfanos dentro de una pieza.

## Comandos principales

```bash
make validate-garments-json
```

Validacion directa por CLI:

```bash
.venv/bin/python scripts/validate_garment_definition.py \
  --definition examples/garments/short_basico.json \
  --definition examples/garments/falda_evase.json
```

Validacion por directorio:

```bash
.venv/bin/python scripts/validate_garment_definition.py \
  --definitions-dir examples/garments
```

## Resultado esperado

```text
VALID_DEFINITION: examples/garments/short_basico.json code=short_basico measurements=4 pieces=1 formulas=...
VALID_DEFINITION: examples/garments/falda_evase.json code=falda_evase measurements=4 pieces=1 formulas=5
```

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Siguiente paso recomendado

Despues de Fase 34, el siguiente paso logico es endurecer el DSL con un esquema versionado o agregar validacion de compatibilidad hacia atras para futuras versiones del contrato JSON.
