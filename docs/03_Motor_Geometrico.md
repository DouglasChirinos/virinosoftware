# 03 - Motor Geométrico

## Objetivo

Construir un núcleo geométrico 2D independiente de la interfaz gráfica y de las reglas específicas de patronaje.

## Principios

- Todas las coordenadas se expresan inicialmente en centímetros.
- El motor geométrico no conoce prendas.
- Las prendas consumen primitivas geométricas y devuelven piezas dibujables.
- La exportación convierte geometría a SVG, DXF o PDF.

## Primitivas iniciales

- `Point`: punto cartesiano.
- `Line`: segmento recto.
- `BezierCurve`: curva Bézier cúbica.
- `Polygon`: polígono cerrado.

## Operaciones iniciales

- Distancia entre puntos.
- Punto medio.
- Intersección de líneas.
- Rectángulo base.

## Regla de arquitectura

Queda prohibido meter lógica de GUI dentro de `engine/geometry`.
