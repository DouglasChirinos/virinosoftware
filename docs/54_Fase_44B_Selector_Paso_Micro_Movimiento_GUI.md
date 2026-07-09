# Fase 44B — Selector de paso y botones de micro-movimiento visibles en GUI

## Objetivo

Permitir que el usuario mueva el punto seleccionado desde controles visibles, sin depender exclusivamente de las flechas del teclado.

## Alcance implementado

- Selector de paso: `0.1`, `0.5`, `1.0` cm.
- Botones visibles: `Izq`, `Der`, `Arriba`, `Abajo`.
- Método `move_selected_point_by(dx_cm, dy_cm)` integrado en `ReadOnlyPatternCanvas`.
- Reutilización de `_request_keyboard_move`, conservando la estabilidad validada en Fase 43C.
- Resumen actualizado después de cada micro-movimiento.
- Target `make validate-fase-44b`.
- Tests focales para pasos, deltas y reutilización del movimiento por teclado.

## Fuera de alcance

- Drag-and-drop.
- Zoom/pan.
- Edición visual de curvas.
- Undo/redo.
- Cambios en geometría base.
- Cambios en exportadores SVG/DXF/PDF.

## Validación

```bash
make validate-fase-44b
make validate-fase-44a
make validate-fase-43a
make validate-fase-43b
make validate-fase-43c
make validate-fase-43d
make test
```
