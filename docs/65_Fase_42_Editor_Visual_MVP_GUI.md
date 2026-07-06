# Fase 42 - Editor visual MVP en GUI

## Objetivo

Convertir el flujo de generacion en un flujo de patronaje asistido:

```text
Generar patron base -> crear variante editable -> aplicar transformaciones -> guardar historial -> exportar variante
```

## Decision de alcance

No se implementa un CAD completo ni drag-and-drop libre en esta fase. La primera version usa campos controlados `dx/dy` para mover puntos seleccionados. Esto reduce errores, mantiene trazabilidad y permite validar el contrato de transformaciones antes de agregar interaccion directa con mouse.

## Capacidades implementadas

- Cargar un patron generado en el editor.
- Seleccionar pieza.
- Seleccionar punto.
- Aplicar `move_point` con `dx/dy` en centimetros.
- Guardar variante JSON.
- Exportar variante transformada en SVG/DXF/PDF.
- Mantener intacto el patron base.

## Regla clave

El patron generado por medidas no se modifica directamente. El usuario trabaja sobre una variante editable con historial de operaciones.

```text
patron_base
  -> variante_usuario_001
  -> variante_usuario_002
```

## Archivos principales

- `engine/transformations/operations.py`
- `engine/transformations/apply.py`
- `app/controllers/pattern_editor_controller.py`
- `app/gui/universal_main_window.py`
- `tests/test_fase_42_editor_visual_mvp_gui.py`

## Limitaciones deliberadas

- Sin drag-and-drop con mouse todavia.
- Sin seleccion grafica real sobre canvas todavia.
- Sin edicion avanzada de curvas desde GUI en esta fase.
- `move_line`, `scale_line` y `adjust_curve` quedan en contrato backend para fases posteriores de UI.

## Proxima fase recomendada

Fase 42.1 o Fase 43:

- Canvas visual real del patron.
- Seleccion grafica de puntos.
- Preview antes/despues.
- Medidas en vivo por segmento.
- Deshacer/rehacer por historial.
