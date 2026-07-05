# Fix importaciones y exportaciones MVP

## Problema corregido

El generador multi-formato esperaba el modulo:

```text
engine.garments.skirt.basic_skirt
```

pero la estructura real del proyecto no exponia ese modulo canonico. Esto causaba:

```text
ModuleNotFoundError: No module named 'engine.garments.skirt.basic_skirt'
```

## Decision tecnica

Se normalizo un modulo canonico para la falda basica MVP:

```text
engine/garments/skirt/basic_skirt.py
```

La regla queda asi:

- `engine.geometry` contiene primitivas geometricas.
- `engine.measurements` contiene medidas y validaciones.
- `engine.garments.skirt` contiene reglas de patronaje de falda.
- `engine.exports` contiene salidas SVG, DXF y PDF.
- `scripts/` solo orquesta casos de uso; no contiene logica de negocio.

## Comandos de validacion

```bash
cd /home/antares/Proyecto/motor
make generate-all-exports
make show-exports
make test
```
