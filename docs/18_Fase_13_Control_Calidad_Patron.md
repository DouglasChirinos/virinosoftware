# 18. Fase 13 - Control de calidad del patron

## Objetivo

Blindar la calidad geometrica del MVP antes de avanzar a nuevas prendas.

## Alcance aplicado

- Validacion de proporciones geometricas.
- Validacion de lineas duplicadas.
- Validacion de lineas con longitud cero.
- Validacion de coordenadas negativas.
- Validacion topologica simple de cierre de pieza.
- Reporte QA Markdown.
- Contrato base para margen de costura.

## Reglas QA

### Errores

- `NO_PIECES`: no hay piezas generadas.
- `INSUFFICIENT_POINTS`: pieza con menos de 4 puntos.
- `INSUFFICIENT_LINES`: pieza con menos de 4 lineas.
- `NEGATIVE_COORDINATE`: coordenadas negativas.
- `DUPLICATE_LINE`: lineas duplicadas.
- `ZERO_LENGTH_LINE`: linea sin longitud.
- `MISSING_REQUIRED_POINTS`: faltan puntos minimos de falda basica.
- `HIP_WIDTH_LESS_THAN_WAIST_WIDTH`: ancho de cadera menor que cintura.
- `INVALID_SKIRT_LENGTH`: largo invalido.

### Advertencias

- `POSSIBLE_OPEN_CONTOUR`: posible contorno abierto.

La falda MVP puede tener lineas auxiliares y pinzas, por eso el cierre topologico se reporta como advertencia y no como error.

## Reporte generado

```text
reports/falda_basica_mvp_qa.md
```

## Margen de costura

Se agrega contrato inicial:

```python
SeamAllowanceConfig
```

Todavia no aplica offset geometrico real.
La implementacion de margen de costura queda preparada para una fase posterior.
