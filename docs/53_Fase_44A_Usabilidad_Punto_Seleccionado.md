# Fase 44A - Usabilidad minima del punto seleccionado

## Objetivo

Hacer que la seleccion visual de puntos sea entendible para un usuario final sin tocar la geometria base del motor.

## Alcance implementado

- Contrato de informacion del punto seleccionado en `PatternCanvas`.
- Nombre humano derivado desde ids tecnicos como `line_2_end`, `hip_side` o `crotch_curve_control`.
- Exposicion de pieza, punto tecnico, nombre humano y coordenadas X/Y.
- Helper de resumen visual para panel de estado.
- Target `make validate-fase-44a`.

## No incluido todavia

- Drag-and-drop.
- Zoom/pan.
- Reset visual de punto seleccionado.
- Undo/redo.
- Edicion de curvas.

## Criterio de aceptacion

Un usuario puede saber que punto selecciono, a que pieza pertenece, cual es su identificador tecnico y en que coordenadas esta.

## Validacion

```bash
make validate-fase-44a
make validate-fase-43a
make validate-fase-43b
make validate-fase-43c
make validate-fase-43d
make test
```
