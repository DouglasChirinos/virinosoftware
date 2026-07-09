# Fase 44C — Reset de punto seleccionado y feedback de variante activa

## Objetivo

Dar control operativo al usuario final para corregir movimientos sin miedo.

La Fase 44B permitió mover un punto con selector de paso y botones de micro-movimiento. La Fase 44C agrega dos capacidades necesarias para usabilidad real:

- Restaurar el punto seleccionado a su posición base de edición.
- Mostrar feedback visible de la variante activa y sus cambios pendientes.

## Alcance implementado

### Reset/restaurar punto seleccionado

Se agrega una línea base por punto seleccionado. Antes de mover un punto, el canvas conserva la coordenada original de ese punto dentro de la sesión visual.

Luego, el botón **Restaurar punto** calcula el delta inverso entre la posición actual y la línea base, y aplica el movimiento correctivo mediante el mismo mecanismo usado por los movimientos del teclado.

### Feedback visual de variante activa

El panel de micro-movimiento ahora informa el estado de la variante activa:

- Variante sin cambios pendientes.
- Variante con cambios sin guardar.
- Punto restaurado.
- Sin punto seleccionado o sin movimiento para restaurar.

## Criterio de aceptación

Un usuario no técnico puede:

1. Seleccionar un punto.
2. Moverlo con botones o teclado.
3. Ver que la variante tiene cambios pendientes.
4. Restaurar el punto seleccionado.
5. Entender si la restauración fue aplicada o si no había nada que restaurar.

## Validaciones

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

## Limitaciones

Esto no es todavía undo/redo histórico.

La restauración aplica al punto seleccionado contra la línea base capturada en la sesión visual, no contra una pila completa de operaciones.
