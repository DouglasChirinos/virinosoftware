# Fase 27 - Motor de interpretacion de formulas geometricas

## Objetivo

Convertir expresiones serializadas del DSL inicial en coordenadas numericas reales para poder generar geometria desde JSON/dict.

Ejemplos soportados:

```text
waist / 4
hip / 4 + ease
outseam
```

## Alcance implementado

Se agregaron los modulos:

```text
engine/garments/serializable/formula.py
engine/garments/serializable/geometry.py
```

Se actualizo:

```text
engine/garments/serializable/__init__.py
```

Se agregaron pruebas:

```text
tests/test_serializable_formula_interpreter.py
```

## Componentes creados

### Interpretador seguro de formulas

```text
FormulaEvaluationError
evaluate_formula
resolve_formula_value
```

El interpretador usa `ast.parse(..., mode="eval")` y solo acepta un subconjunto aritmetico controlado:

```text
+  -  *  /
parentesis
numeros
variables declaradas en contexto
signo positivo/negativo
```

No usa `eval` ni `exec`.

Bloquea expresiones como:

```text
__import__('os')
open('/tmp/x')
waist.__class__
items[0]
waist ** 2
```

### Generador de geometria serializable

```text
SerializableGeometryGenerationError
GeneratedSerializablePoint
GeneratedSerializableLine
GeneratedSerializablePiece
GeneratedSerializablePattern
build_formula_context
generate_geometry_from_definition
```

La funcion principal es:

```python
generate_geometry_from_definition(definition, measurement_values=None, extra_variables=None)
```

## Contexto de formulas

El contexto se arma con:

1. Defaults declarados en el JSON.
2. Valores de medicion pasados en runtime.
3. Variables extra de construccion, por ejemplo `ease`.

Ejemplo:

```python
pattern = generate_geometry_from_definition(
    definition,
    measurement_values={"waist": 88},
    extra_variables={"ease": 2},
)
```

## Resultado tecnico

El JSON de `short_basico` de Fase 26 ya puede resolverse a puntos numericos.

Ejemplo conceptual:

```text
B = ["waist / 4", 0]
waist = 84
B = [21.0, 0.0]
```

## Limites intencionales

Esta fase no registra prendas JSON en el catalogo universal.

Esta fase no exporta SVG/DXF/PDF desde JSON.

Esta fase no modifica la GUI.

Esta fase no implementa curvas, piquetes, margenes de costura ni reglas industriales avanzadas.

## Validaciones

Ejecutar:

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
```

## Proxima fase recomendada

```text
Fase 28 - Adaptador de prenda serializable al generador universal
```

Objetivo sugerido:

```text
Permitir registrar una definicion JSON como prenda generable por el flujo universal existente.
```
