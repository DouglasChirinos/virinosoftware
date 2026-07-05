# Fase 23 - Segunda prenda base

## Objetivo

Agregar una segunda prenda base al motor para validar que la arquitectura creada en Fases 20, 21 y 22 escala más allá de `falda_basica`.

La prenda seleccionada es:

```text
pantalon_basico
```

## Alcance implementado

- Se crea paquete `engine/garments/pants/`.
- Se crea `BasicPantsDraft`.
- Se crea `PantsMeasurements`.
- Se crean piezas MVP:
  - `Pantalon basico delantero`
  - `Pantalon basico posterior`
- Se registra `pantalon_basico` en el catálogo global.
- Se adapta el generador universal para soportar prendas con distintos modelos de medidas.
- Se actualiza `scripts/generate_pattern.py`.
- Se agrega target `make generate-basic-pants`.
- Se agregan tests de la segunda prenda.
- Se mantiene compatibilidad con `falda_basica`.

## Qué no incluye esta fase

- No implementa trazado industrial completo de pantalón.
- No implementa curvas avanzadas.
- No implementa pinzas, bolsillos, pretina ni aplomos.
- No implementa exportación universal.
- No modifica el GUI.

## Uso

Listar prendas:

```bash
make list-garments
```

Salida esperada:

```text
falda_basica: Falda basica
pantalon_basico: Pantalon basico
```

Generar falda desde generador universal:

```bash
make generate-pattern
```

Generar pantalón básico desde generador universal:

```bash
make generate-basic-pants
```

Salida esperada:

```text
GARMENT_CODE: pantalon_basico
GARMENT_NAME: Pantalon basico
DRAFT_CLASS: BasicPantsDraft
PIECE_COUNT: 2
PIECE_1: Pantalon basico delantero lines=5
PIECE_2: Pantalon basico posterior lines=5
```

## Decisión técnica

Fase 23 valida extensibilidad arquitectónica, no perfección industrial del pantalón.

La exportación universal debe abordarse después, cuando el contrato de piezas entre prendas esté suficientemente estable.

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
