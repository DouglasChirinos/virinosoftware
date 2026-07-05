# Fase 21 - Registro dinámico de prendas

## Objetivo

Crear un registro dinámico de prendas para resolver generadores por código, sin modificar el núcleo geométrico del motor.

Esta fase prepara la base técnica para que, en fases posteriores, el sistema pueda generar patrones por tipo de prenda sin acoplarse directamente a una clase concreta.

## Alcance implementado

- Se crea `engine/garments/registry.py`.
- Se crea `GarmentRegistry`.
- Se crea `RegisteredGarment`.
- Se crean excepciones específicas:
  - `GarmentRegistryError`
  - `GarmentAlreadyRegisteredError`
  - `GarmentNotFoundError`
- Se crean funciones globales:
  - `register_garment`
  - `get_garment`
  - `list_garments`
  - `get_garment_codes`
- Se crea `engine/garments/catalog.py`.
- Se registra `BasicSkirtDraft` como primera prenda del catálogo.
- Se crea CLI `scripts/list_garments.py`.
- Se agrega target `make list-garments`.
- Se agregan tests del registro.
- No se crean nuevas prendas.
- No se crea todavía generador universal de patrones.

## Prenda registrada inicialmente

```text
falda_basica: Falda basica
```

## Uso técnico

Obtener una prenda por código:

```python
from engine.garments import get_garment

draft_class = get_garment("falda_basica")
```

Listar códigos registrados:

```python
from engine.garments import get_garment_codes

codes = get_garment_codes()
```

Listar desde CLI:

```bash
make list-garments
```

Salida esperada:

```text
falda_basica: Falda basica
```

## Decisión técnica

Fase 21 solo resuelve registro y descubrimiento de prendas.

El generador universal queda reservado para Fase 22.

## Validaciones esperadas

```bash
make test
make list-garments
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
