# Fase 20 - Contrato base de prendas

## Objetivo

Crear una arquitectura común para que nuevas prendas puedan agregarse sin modificar el núcleo del motor.

Esta fase prepara la extensibilidad del proyecto dentro del ciclo `v0.2.0-dev`.

## Alcance implementado

- Se crea el paquete `engine/garments/`.
- Se define `GarmentDraft` como contrato base.
- Se define `GarmentMetadata` para metadata técnica y funcional de la prenda.
- Se define `MeasurementRequirement` para declarar medidas requeridas.
- Se adapta la falda básica mediante `BasicSkirtDraft`.
- Se agregan tests de contrato.
- Se mantiene la compatibilidad de scripts existentes.
- No se crea registro dinámico de prendas.
- No se crean nuevas prendas.

## Archivos principales

```text
engine/garments/__init__.py
engine/garments/base.py
engine/garments/requirements.py
engine/garments/skirt/__init__.py
engine/garments/skirt/basic_skirt.py
tests/test_garment_contract.py
docs/29_Fase_20_Contrato_Base_Prendas.md
```

## Contrato base

```python
class GarmentDraft:
    metadata: GarmentMetadata
    required_measurements: tuple[MeasurementRequirement, ...]

    def draft(self):
        ...
```

## Prenda adaptada

```text
falda_basica
```

Medidas declaradas:

```text
waist
hip
skirt_length
ease
hip_depth
```

## Decisión técnica

El registro dinámico de prendas queda fuera de esta fase y debe implementarse en Fase 21.

## Validaciones esperadas

```bash
make test
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```

## Resultado esperado

La falda básica queda compatible con un contrato común de prendas, sin romper el MVP existente ni alterar el flujo de generación actual.
