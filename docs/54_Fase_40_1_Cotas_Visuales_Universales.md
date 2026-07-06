# Fase 40.1 - Cotas visuales universales por prenda

Fecha: 2026-07-05

## Objetivo

Convertir la salida visual PDF/SVG en una salida de producto para usuario final, no una salida tecnica interna.

## Problema detectado

Despues de corregir `falda_basica`, otras prendas seguian mostrando nombres tecnicos como:

```text
line_1_start
line_5_end
line_2_start
```

Ademas, las cotas no estaban colocadas al borde del patron para todas las prendas.

## Reglas de producto

1. El encabezado muestra medidas de entrada en espanol.
2. Las cotas al borde muestran medidas geometricas reales del segmento o proyeccion dibujada.
3. Los puntos tecnicos autogenerados no se muestran.
4. Solo se muestran nombres de puntos semanticos cuando existen.

## Prendas cubiertas

### falda_basica

- Cintura pieza.
- Cadera pieza.
- Largo pieza.

### pantalon_basico

- Cintura pieza.
- Cadera pieza.
- Largo exterior pieza.
- Entrepierna solo queda en encabezado porque la geometria MVP actual no dibuja un segmento interno explicito.

### short_basico

- Cintura pieza.
- Cadera/pierna pieza.
- Largo exterior pieza.
- Entrepierna queda en encabezado porque la geometria serializable actual no dibuja un segmento interno explicito.

### falda_evase

- Cintura pieza.
- Bajo pieza.
- Largo falda como proyeccion vertical de la geometria.

## Archivos principales

```text
engine/exports/visual_annotations.py
engine/generation/exporter.py
engine/exports/pdf/writer.py
engine/exports/svg/writer.py
tests/test_export_visual_metadata.py
tests/test_fase_40_1_cotas_visuales_universales.py
```

## Validacion

```bash
make validate-fase-40
```

Resultado esperado:

```text
VALIDATE_FASE_40_1_OK
```
