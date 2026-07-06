# Fase 40.3B — Semantica de curvas estructurales

## Objetivo

Convertir las curvas estructurales del contorno en entidades con semantica de patronaje, no solo en trazos Bezier dibujados sobre el patron.

La fase corrige dos problemas detectados en la validacion visual de Fase 40.3A:

1. Seguian apareciendo curvas visuales punteadas junto con curvas estructurales solidas.
2. Las curvas no declaraban si su comportamiento era concavo, convexo o mixto.

## Regla de producto

Cuando una pieza tiene `structural_curves`, esas curvas son la fuente visual principal del contorno. No deben coexistir `visual_curves` punteadas para la misma pieza.

## Semantica agregada

Cada curva estructural incluye:

- `kind`: `structural_curve`
- `curve_type`: `cubic_bezier`
- `intent`: intencion patronistica
- `curvature`: `concave`, `convex` o `mixed`
- `replaces_segment`: indica si reemplaza un segmento recto
- `mvp_status`: estado honesto del nivel de patronaje
- `patronage_note`: nota tecnica de patronaje

## Clasificacion actual

| Prenda | Curva | Intent | Curvature | Estado |
|---|---|---|---|---|
| falda_basica | Costado curvo de cadera | hip_curve | convex | MVP estructural |
| falda_evase | Bajo curvo corregido | hem_curve | convex | MVP estructural |
| pantalon_basico | Curva estructural de tiro | crotch_curve | concave | MVP experimental |
| pantalon_basico | Curva estructural de entrepierna | inseam_curve | mixed | MVP experimental |
| short_basico | Curva estructural tiro/entrepierna | crotch_curve | concave | MVP experimental |
| short_basico | Boca de pierna curva MVP | leg_opening_curve | convex | MVP experimental |

## Advertencia tecnica

La clasificacion concava/convexa/mixta es semantica inicial. No convierte automaticamente pantalon y short en patrones industriales.

Pendientes industriales:

- Gancho delantero y posterior formal.
- Altura de tiro real.
- Entrepierna con metodo de patronaje.
- Diferenciacion delantero/posterior.
- Piquetes, hilo de tela, aplomo, margen y reglas de costura finales.

## Validacion

```bash
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness
```

Criterio de cierre visual posterior:

- Una sola curva visible por tramo.
- Sin curva punteada duplicada si hay curva estructural.
- Curvas con semantica patronistica declarada.
- SVG/PDF legibles para impresion.
