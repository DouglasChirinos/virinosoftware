# Fix Fase 40.1 - Layout independiente por pieza

Fecha: 2026-07-05

## Problema

En `pantalon_basico`, el delantero y el posterior se generan desde el mismo origen local. Eso es aceptable como geometria interna MVP, pero en PDF/SVG de producto las piezas quedaban superpuestas. Como consecuencia:

- Parecia que faltaba el patron posterior.
- Las cotas de delantero y posterior se solapaban.
- Los titulos de las piezas quedaban montados.

## Solucion

Se agrega una etapa de layout visual en `engine/generation/exporter.py` antes de adjuntar cotas y antes de llamar a los writers PDF/SVG.

La etapa:

- Calcula el bounding box de cada pieza.
- Traslada cada pieza a una lane horizontal independiente.
- Preserva las medidas geometricas porque solo aplica traslacion, no escalado.
- Calcula cotas despues del layout, para que cada pieza tenga sus propias cotas en su propio bloque visual.

## Archivos

```text
engine/generation/exporter.py
tests/test_fase_40_1_layout_piezas_independientes.py
docs/55_Fix_Fase_40_1_Layout_Piezas_Independientes.md
```

## Criterio de aceptacion

`pantalon_basico` debe mostrar delantero y posterior separados visualmente, sin cotas montadas entre piezas.
