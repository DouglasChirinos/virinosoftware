# Fase 40.2 - Curvas de patronaje MVP

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

## Decision tecnica

Se introduce una capa de curvas visuales MVP para evolucionar el motor desde poligonos rectos hacia patronaje mas real.

Esta fase no convierte automaticamente las prendas en patrones industriales.

## Alcance aplicado

- Soporte SVG/PDF para curvas visuales tipo Bezier.
- Curva de cadera para `falda_basica`.
- Correccion suave de bajo para `falda_evase`.
- Curva MVP de tiro/costado para `pantalon_basico`.
- Curva MVP de tiro/entrepierna para `short_basico`.
- Tests de exportacion SVG con curvas.

## DXF

El soporte DXF queda documentado como pendiente de endurecimiento industrial. La exportacion principal validada en esta fase es SVG/PDF visual. El DXF conserva las lineas base del patron.

## Advertencia de patronaje

Las curvas de esta fase son refinamientos visuales y estructurales iniciales.

Pendientes industriales:

- pantalon: gancho delantero/posterior, tiro, rodilla, bota, entrepierna real.
- short: tiro delantero/posterior, curva de gancho, boca de pierna y entrepierna.
- falda basica: afinado de cintura/cadera/pinzas.
- falda evase: correccion avanzada de bajo por caida.

## Criterio de aceptacion

```text
make validate-fase-40-2
```

Debe validar:

- SVG exporta curvas.
- Las curvas aparecen en prendas actuales.
- El flujo de completitud de piezas sigue OK.
