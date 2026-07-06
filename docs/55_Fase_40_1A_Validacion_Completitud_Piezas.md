# Fase 40.1A - Validacion de completitud de piezas por prenda

Fecha: 2026-07-05

## Roles obligatorios del asistente en este proyecto

### Rol 1 - Arquitecto / consultor tecnico del producto

Responsabilidad:

- Validar si lo generado sirve realmente para usuario final.
- No cerrar fases solo porque los tests pasan.
- Detectar inconsistencias funcionales, visuales, tecnicas y de flujo antes de cerrar una fase.

### Rol 2 - Experto en patronaje

Responsabilidad:

- Validar que los patrones generados tengan sentido tecnico de patronaje.
- Revisar piezas necesarias: delantero, posterior y piezas complementarias cuando apliquen.
- Diferenciar medidas corporales de entrada vs medidas geometricas reales de pieza.
- Validar cotas, proporciones, interpretacion para confeccion y usabilidad del patron exportado.

## Regla de cierre

Una fase no se cierra si el resultado no es valido como producto y como patron, aunque los tests tecnicos pasen.

## Hallazgo

Durante Fase 40.1 se detecto que algunas prendas generaban salidas visualmente limpias pero incompletas como patron:

- `short_basico` genera solo delantero.
- `falda_evase` genera solo delantero.
- `falda_basica` requiere `full_pattern=True` desde GUI para generar delantero + posterior.
- `pantalon_basico` declara delantero + posterior, pero requiere validacion visual de separacion, cotas y usabilidad.

## Alcance aplicado

Se agrega una validacion de producto para verificar que las prendas inferiores basicas tengan como minimo:

- pieza delantera
- pieza posterior

## Archivos agregados

- `engine/qa/piece_completeness.py`
- `scripts/validate_piece_completeness.py`
- `tests/test_fase_40_1a_piece_completeness.py`

## Resultado esperado actual

La validacion documenta explicitamente que el catalogo todavia no esta cerrado como producto:

- `falda_basica`: completo desde GUI con `full_pattern=True`.
- `pantalon_basico`: completo en piezas declaradas.
- `short_basico`: incompleto, falta posterior.
- `falda_evase`: incompleto, falta posterior.

## Proximo paso

Fase 40.1B:

- Agregar pieza posterior real para `short_basico`.
- Agregar pieza posterior real para `falda_evase`.
- Validar patronaje de cada pieza.
- Revalidar cotas visuales despues de tener patrones completos.
