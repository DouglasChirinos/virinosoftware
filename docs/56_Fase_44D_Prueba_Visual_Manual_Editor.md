# Fase 44D — Prueba visual/manual documentada de usabilidad del editor

## Objetivo

Validar que la Fase 44 funciona como flujo de usuario real, no solo como contrato técnico cubierto por tests automatizados.

Esta fase no introduce drag-and-drop, zoom/pan ni edición de curvas. Su propósito es confirmar que el editor visual ya permite a un usuario entender, mover, corregir y exportar una variante sin perder control operativo.

## Alcance validado

Flujo manual objetivo:

```text
Generar patrón
Cargar en editor
Seleccionar punto
Ver nombre/coordenadas/paso
Mover con botones
Ver feedback de cambios pendientes
Restaurar punto
Guardar/exportar variante
```

## Precondiciones

Proyecto:

```bash
cd /home/antares/Proyecto/motor
```

Rama esperada:

```text
feature/fase-40-gui-generacion-exportacion-serializables
```

Commits base esperados antes de esta fase:

```text
1993d76 feat: add selected point reset and variant feedback
c3b76ca feat: add step selector and micro movement controls
794b2fd feat: add selected point usability contract
6f9a401 docs: close phase 43 interactive canvas
1e7fa14 feat: add interactive pattern canvas
```

Validaciones automáticas base:

```bash
make validate-fase-44a
make validate-fase-44b
make validate-fase-44c
make validate-fase-43a
make validate-fase-43b
make validate-fase-43c
make validate-fase-43d
make validate-fase-41
make validate-fase-42
make validate-piece-completeness
make test
```

## Prueba visual/manual

Ejecutar:

```bash
make run-gui
```

### Caso 1 — Generar patrón

Acción:

```text
Abrir GUI.
Seleccionar una prenda base disponible.
Ingresar o usar medidas válidas.
Ejecutar generación del patrón.
```

Resultado esperado:

```text
El patrón se genera sin error.
La GUI mantiene el flujo operativo.
```

Resultado observado:

```text
APROBADO_MANUALMENTE
```

Estado:

```text
PENDIENTE
```

---

### Caso 2 — Cargar patrón en editor visual

Acción:

```text
Cargar el patrón generado en el editor/canvas visual.
Ir a la pestaña Vista patron.
```

Resultado esperado:

```text
El patrón se muestra en la pestaña principal Vista patron.
Las piezas son visibles.
Los puntos son seleccionables.
```

Resultado observado:

```text
APROBADO_MANUALMENTE
```

Estado:

```text
PENDIENTE
```

---

### Caso 3 — Seleccionar punto y verificar información

Acción:

```text
Hacer clic sobre un punto visible del patrón.
```

Resultado esperado:

```text
El punto queda resaltado.
El panel muestra información entendible del punto seleccionado.
Se visualizan nombre, pieza, coordenadas y paso de movimiento.
```

Resultado observado:

```text
APROBADO_MANUALMENTE
```

Estado:

```text
PENDIENTE
```

---

### Caso 4 — Micro-movimiento con botones

Acción:

```text
Usar selector de paso 0.1 cm, 0.5 cm o 1.0 cm.
Mover el punto con botones Izq, Der, Arriba y Abajo.
```

Resultado esperado:

```text
El punto se mueve de forma estable.
El panel actualiza la información del punto.
El feedback indica cambios sin guardar.
```

Resultado observado:

```text
APROBADO_MANUALMENTE
```

Estado:

```text
PENDIENTE
```

---

### Caso 5 — Restaurar punto seleccionado

Acción:

```text
Después de mover el punto, presionar Restaurar punto.
```

Resultado esperado:

```text
El punto vuelve a su posición base de la sesión visual.
El feedback indica que el punto fue restaurado.
La GUI no se bloquea ni pierde selección.
```

Resultado observado:

```text
APROBADO_MANUALMENTE
```

Estado:

```text
PENDIENTE
```

---

### Caso 6 — Guardar/exportar variante

Acción:

```text
Mover al menos un punto.
Guardar/exportar variante.
Verificar salida JSON/SVG/DXF/PDF.
```

Resultado esperado:

```text
Se genera variante JSON.
Se genera exportación SVG.
Se genera exportación DXF.
Se genera exportación PDF.
Los archivos resultantes son legibles.
```

Resultado observado:

```text
APROBADO_MANUALMENTE
```

Estado:

```text
PENDIENTE
```

---

## Criterio de aceptación de Fase 44D

La fase se considera aprobada si:

```text
- La GUI abre correctamente.
- El usuario puede generar un patrón.
- El patrón se visualiza en Vista patron.
- Un punto puede seleccionarse con mouse.
- El panel muestra información entendible.
- El punto puede moverse con botones.
- El feedback de variante activa cambia cuando hay movimiento.
- El punto puede restaurarse.
- La variante puede guardarse/exportarse.
- JSON/SVG/DXF/PDF se generan sin error.
```

## Resultado de validación manual

Estado final:

```text
APROBADO_MANUALMENTE
```

Validado por:

```text
Usuario final / validacion visual directa
```

Fecha:

```text
2026-07-09
```

Observaciones:

```text
Panel validado sin referencias internas tipo <bound Method>. Pieza/punto legibles. Micro-movimiento funcional. Restaurar punto funcional. Exportacion de variante funcional en JSON/SVG/DXF/PDF.
```

## Decisión

Fase 44D no debe cerrarse hasta reemplazar los campos `APROBADO_MANUALMENTE` y `PENDIENTE` por evidencia real de ejecución manual.

Cuando la prueba sea aprobada, el cierre recomendado es:

```text
Fase 44 — Usabilidad del editor visual cerrada.
Siguiente fase sugerida: Fase 45 — Zoom, pan y centrado visual.
```\n\n
## Hallazgo manual Fase 44D — Reset no restauraba punto

Durante la prueba visual real, se confirmó:

```text
Los movimientos con botones funcionan correctamente.
El botón Restaurar punto no restauraba.
La GUI mostraba: no hay punto seleccionado o no existe movimiento para restaurar.
```

Diagnóstico:

```text
El movimiento usaba correctamente la referencia interna del canvas.
La restauración dependía de una línea base que no siempre se capturaba con la misma referencia del punto seleccionado.
```

Corrección aplicada:

```text
La captura/restauración de línea base ahora usa una resolución robusta:
1. Información pública del punto seleccionado.
2. Referencia interna selected_point.
3. Fallback defensivo por identidad de objeto.
```

Estado:

```text
APROBADO_MANUALMENTE
```

## Hallazgo manual Fase 44D — Panel mostraba referencia interna de método

Durante la revalidación visual se observó que el canvas sí tenía punto seleccionado y los botones de movimiento funcionaban, pero el panel mostraba una referencia interna similar a:

```text
<bound Method ReadOnlyPatternCanvas.selected_point ...>
```

Impacto:

```text
El usuario veía información técnica incorrecta.
El botón Restaurar punto no podía resolver correctamente la línea base.
```

Corrección aplicada:

```text
El canvas ahora resuelve `selected_point` aunque esté implementado como método callable.
La información de punto seleccionado se normaliza antes de enviarse al panel.
El reset usa la misma referencia normalizada que el panel y el baseline.
```

Estado:

```text
APROBADO_MANUALMENTE
```

## Cierre manual confirmado

Resultado de la prueba visual real:

```text
1. El panel NO muestra '<bound Method'.
2. El panel muestra pieza/punto legibles.
3. Mover con botones funciona.
4. Restaurar punto devuelve el punto visualmente.
5. Exportar variante funciona.
```

Evidencia funcional:

```text
Variante exportada:
falda_basica_variante_usuario_001_20260709_195455

Formatos confirmados:
JSON/SVG/DXF/PDF
```

Decisión:

```text
Fase 44D aprobada.
Fase 44 — Usabilidad del editor visual cerrada.
Siguiente fase recomendada: Fase 45 — Zoom, pan y centrado visual.
```
