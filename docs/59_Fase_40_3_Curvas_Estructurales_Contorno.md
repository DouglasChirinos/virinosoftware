# Fase 40.3A - Curvas estructurales del contorno

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
- Revisar piezas necesarias, proporciones, medidas de entrada vs cotas reales, curvas y usabilidad.
- Diferenciar MVP geometrico de patron industrial.

## Cambio de enfoque

La Fase 40.2 agrego curvas visuales superpuestas. La Fase 40.3A empieza el cambio hacia curvas estructurales:

```text
De curvas visuales superpuestas
a curvas estructurales del contorno del patron.
```

## Alcance aplicado

- Se agrega `engine/exports/structural_curves.py`.
- Se adjuntan curvas estructurales en metadata exportable.
- SVG/PDF dibujan curvas estructurales con trazo de contorno.
- SVG/PDF ocultan el segmento recto cuando una curva estructural tiene los mismos extremos.
- Se agregan tests de exportacion SVG y reemplazo de segmentos rectos.

## Curvas iniciales

- `falda_basica`: costado curvo de cadera.
- `falda_evase`: bajo curvo corregido.
- `pantalon_basico`: curva estructural de tiro y curva estructural de entrepierna MVP.
- `short_basico`: curva estructural tiro/entrepierna y boca de pierna curva MVP.

## Advertencia de patronaje

Esta fase empieza a convertir curvas en contorno, pero todavia no representa patronaje industrial completo para pantalon y short.

Pendientes:

- Pantalon: gancho delantero/posterior real, altura de tiro, rodilla, bota y aplomo.
- Short: tiro delantero/posterior, gancho real, boca de pierna y curva de entrepierna.
- Falda basica: diferenciacion de pinzas delantero/posterior.
- Falda evase: ajuste de caida y nivelacion de bajo.

## Criterio de aceptacion

```bash
make validate-fase-40-3
```

Debe validar:

- Curvas estructurales exportadas en SVG.
- Segmentos rectos reemplazados cuando corresponde.
- Completitud de piezas sigue OK.
- Fase 40.2 sigue OK.
