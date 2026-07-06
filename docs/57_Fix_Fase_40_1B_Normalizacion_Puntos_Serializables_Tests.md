# Fix Fase 40.1B - Normalizacion de puntos serializables en tests

Fecha: 2026-07-05

## Problema

Los tests de Fase 40.1B asumian que los puntos generados para prendas serializables eran objetos con atributos `.x` y `.y`.

Sin embargo, el flujo serializable puede devolver puntos como tuplas/listas antes de la normalizacion final de exportacion.

Error observado:

```text
AttributeError: 'tuple' object has no attribute 'x'
```

## Correccion

Se agrega una funcion auxiliar `_x(point)` dentro del test para leer coordenadas desde:

- objetos `Point`
- tuplas/listas
- diccionarios

## Criterio de producto/patronaje preservado

La prueba sigue validando lo importante:

- `short_basico` genera delantero + posterior.
- `falda_evase` genera delantera + posterior.
- el posterior es geometricamente diferenciado del delantero.
- el SVG exportado menciona las piezas posteriores.

## Roles obligatorios del asistente en este proyecto

- Arquitecto / consultor tecnico del producto.
- Experto en patronaje.

Una fase no se cierra solo porque los tests pasan; debe ser valida como producto y como patron.
