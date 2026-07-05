# Fase 26 - Contrato serializable de prendas / DSL inicial

## Objetivo

Crear el primer contrato serializable para declarar prendas simples mediante estructuras tipo JSON/dict, reduciendo la necesidad de crear una clase Python completa por cada prenda basica.

Esta fase no crea un motor geometrico completo. Solo define y valida el contrato inicial.

## Alcance implementado

Se agrego el modulo:

```text
engine/garments/serializable/
```

Componentes creados:

```text
SerializableGarmentDefinition
SerializableMeasurementDefinition
SerializablePieceDefinition
SerializablePointDefinition
SerializableLineDefinition
SerializableGarmentValidationError
load_garment_definition_from_dict
load_garment_definition_from_json
```

Ejemplo creado:

```text
examples/garments/short_basico.json
```

Pruebas creadas:

```text
tests/test_serializable_garment_definition.py
```

## Decisiones tecnicas

1. Las coordenadas de puntos aceptan numeros o formulas como texto.
2. Las formulas no se interpretan todavia.
3. Las lineas validan que sus puntos existan dentro de la pieza.
4. El codigo de prenda y los nombres internos de puntos/medidas deben ser identificadores simples.
5. La fase queda desacoplada de la GUI universal.
6. La fase queda desacoplada del generador universal actual.

## Ejemplo conceptual

```json
{
  "code": "short_basico",
  "name": "Short basico",
  "measurements": [
    {"name": "waist", "label": "Cintura", "unit": "cm", "default": 84},
    {"name": "hip", "label": "Cadera", "unit": "cm", "default": 104}
  ],
  "pieces": [
    {
      "name": "Short delantero",
      "points": {
        "A": [0, 0],
        "B": ["waist / 4", 0],
        "C": ["hip / 4", 45]
      },
      "lines": [["A", "B"], ["B", "C"], ["C", "A"]]
    }
  ]
}
```

## Que no hace esta fase

No interpreta formulas como:

```text
waist / 4
hip / 4 + ease
outseam
```

No genera piezas geometricas reales desde JSON.

No registra `short_basico` en el catalogo universal.

No modifica la GUI.

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
Fase 27 - Motor de interpretacion de formulas geometricas
```

Objetivo de Fase 27:

```text
Convertir formulas serializadas en coordenadas reales y generar piezas desde JSON.
```
