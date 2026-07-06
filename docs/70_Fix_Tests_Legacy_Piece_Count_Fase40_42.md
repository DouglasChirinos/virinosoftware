# Fix tests legacy — piezas completas Fase 40.1B+

## Contexto

La bateria completa detecto pruebas antiguas que aun esperaban una sola pieza en prendas serializables `short_basico` y `falda_evase`.

Desde Fase 40.1A/40.1B el criterio de producto cambio: una prenda inferior basica no se considera completa si no tiene delantero y posterior.

## Decision

Actualizar pruebas legacy para aceptar el contrato vigente:

- `short_basico`: 2 piezas, delantero y posterior.
- `falda_evase`: 2 piezas, delantero y posterior.
- `short_basico.json`: version `0.2.1-mvp`.
- CLI universal: `PIECE_COUNT: 2`.
- Validacion semantica: formula count ajustado al total de ambas piezas.

## Regla de producto

No se debe volver a validar como correcta una prenda inferior basica con una sola pieza cuando el objetivo de producto es patron usable para usuario final.

## Alcance

Este fix no cambia el motor. Solo sincroniza pruebas heredadas con el contrato vigente de piezas completas.
