# Fase 32 - Nueva prenda serializable JSON: falda evase

## Objetivo

Validar crecimiento real del DSL serializable agregando una nueva prenda definida en JSON: `falda_evase`.

La fase evita crear una clase Python especifica por cada prenda nueva. En su lugar, el catalogo serializable crea clases dinamicas desde todos los archivos JSON ubicados en `examples/garments/`.

## Archivos principales

```text
examples/garments/falda_evase.json
engine/garments/serializable/catalog.py
engine/garments/catalog.py
scripts/generate_serializable_pattern.py
Makefile
tests/test_serializable_dynamic_catalog.py
```

## Resultado funcional

Nueva prenda registrada:

```text
falda_evase: Falda evase
```

Generacion universal esperada:

```bash
make generate-universal-falda-evase
```

Exportacion universal esperada:

```bash
make export-universal-falda-evase
```

Archivos esperados:

```text
exports/svg/falda_evase_universal.svg
exports/dxf/falda_evase_universal.dxf
exports/pdf/falda_evase_universal.pdf
```

## Contrato validado

La nueva prenda usa:

```text
waist
hip
skirt_length
ease
```

Puntos principales:

```text
A = (0, 0)
B = (waist / 4, 0)
C = (hip / 4 + ease, skirt_length)
D = (-ease, skirt_length)
```

Con medidas de prueba:

```text
waist = 73
hip = 99
skirt_length = 60
ease = 12
```

Resultado esperado:

```text
C = (36.75, 60.0)
D = (-12.0, 60.0)
```

## Validaciones

```bash
make test
make list-garments
make generate-serializable-falda-evase
make generate-universal-falda-evase
make export-universal-falda-evase
make generate-universal-short
make export-universal-short
```

## Criterio de cierre

Fase 32 queda cerrada cuando:

```text
- falda_evase aparece en list-garments.
- falda_evase genera desde JSON directo.
- falda_evase genera desde el generador universal.
- falda_evase exporta SVG/DXF/PDF.
- short_basico sigue funcionando sin clase estatica obligatoria.
- Toda la suite pasa.
```
