# Fase 22 - Generador universal de patrones

## Objetivo

Crear una capa universal de generación de patrones que reciba un código de prenda, resuelva la clase generadora desde el registro dinámico y ejecute el draft correspondiente.

## Alcance implementado

- Se crea paquete `engine/generation/`.
- Se crea `PatternGenerationRequest`.
- Se crea `PatternGenerationResult`.
- Se crea `PatternGenerationError`.
- Se crea función `generate_pattern`.
- Se crea CLI `scripts/generate_pattern.py`.
- Se agrega target `make generate-pattern`.
- Se agregan tests del generador universal.
- Se mantiene intacta la generación legacy de falda básica.
- No se crean nuevas prendas.
- No se implementa exportación universal todavía.
- No se modifica el GUI.

## Flujo técnico

```text
garment_code
  -> get_garment(code)
  -> draft_class
  -> BodyMeasurements
  -> draft_class(measurements)
  -> draft()
  -> PatternGenerationResult
```

## Uso desde Python

```python
from engine.generation import PatternGenerationRequest, generate_pattern

result = generate_pattern(
    PatternGenerationRequest(
        garment_code="falda_basica",
        measurements={
            "waist": 73,
            "hip": 99,
            "skirt_length": 60,
        },
    )
)
```

## Uso desde CLI

```bash
make generate-pattern
```

Salida esperada:

```text
GARMENT_CODE: falda_basica
GARMENT_NAME: Falda basica
DRAFT_CLASS: BasicSkirtDraft
PIECE_COUNT: ...
```

## Decisión técnica

Fase 22 no toca exportadores ni GUI. Primero se estabiliza el contrato universal de generación.

La exportación universal y/o integración GUI deben quedar para fases posteriores.

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
