# Fase 40.1B - Completar prendas serializables incompletas

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

## Decision de producto

Se adopta la estrategia de **MVP honesto** para no bloquear Fase 40.

Esto significa:

- `falda_evase` debe quedar completa en piezas: delantero + posterior.
- `short_basico` debe quedar completo en piezas: delantero + posterior.
- `short_basico` se declara expresamente como **MVP geometrico no industrial**.
- Queda pendiente una futura fase de short industrial con tiro, curva de gancho, boca de pierna y ajuste completo.

## Criterio tecnico de patronaje aplicado

### Falda evase

El posterior se agrega como pieza propia:

- `Falda evase delantera`
- `Falda evase posterior`

El posterior MVP mantiene la logica base de falda evase, pero se diferencia con mayor amplitud en cintura/cadera.

### Short basico

El posterior se agrega como pieza propia:

- `Short basico delantero`
- `Short basico posterior`

El posterior MVP se diferencia con mayor amplitud en cintura/cadera/pierna.

Advertencia tecnica:

`short_basico` queda completo como patron MVP de piezas, pero no debe considerarse un patron industrial definitivo porque aun no incorpora:

- altura de tiro
- curva de gancho delantero
- curva de gancho posterior
- boca de pierna real
- curva de entrepierna

## Resultado esperado

```text
falda_basica: COMPLETE
pantalon_basico: COMPLETE
short_basico: COMPLETE
falda_evase: COMPLETE
PIECE_COMPLETENESS_OK
```

## Archivos modificados

- `examples/garments/short_basico.json`
- `examples/garments/falda_evase.json`
- `tests/test_fase_40_1a_piece_completeness.py`

## Archivos agregados

- `tests/test_fase_40_1b_serializable_complete_pieces.py`
- `docs/56_Fase_40_1B_Completar_Prendas_Serializables_Incompletas.md`

## Pendiente futuro

Crear una fase especifica para `short_basico_industrial`, con medidas adicionales y construccion real de tiro.
