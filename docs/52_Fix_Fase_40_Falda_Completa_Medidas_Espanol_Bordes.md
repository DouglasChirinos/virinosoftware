# Fix Fase 40 - Falda completa + medidas en espanol + cotas al borde

Fecha: 2026-07-05

## Objetivo

Corregir tres brechas detectadas en la validacion manual de la GUI/producto:

1. La `falda_basica` se exportaba solo con la pieza delantera.
2. Las medidas en exportacion no estaban presentadas en espanol.
3. Las cotas/medidas visibles no estaban colocadas al borde del patron segun el lado correspondiente.

## Cambios aplicados

### 1. Generacion completa de falda basica

Se agrega opcion de producto `full_pattern=True` desde la GUI para `falda_basica`, de forma que la generacion use `draft_full()` y exporte:

- `Falda basica delantera`
- `Falda basica posterior`

### 2. Medidas visibles en espanol

En SVG/PDF se muestran etiquetas de negocio:

- Cintura
- Cadera
- Largo falda
- Largo exterior
- Entrepierna
- Holgura
- Altura cadera

### 3. Cotas al borde del patron

Para `falda_basica` se agregan cotas visibles sobre lados consistentes del patron:

- `Cintura` sobre la linea superior.
- `Cadera` sobre la linea de cadera.
- `Largo falda` sobre el lateral izquierdo.

### 4. Mejora visual complementaria

Se mantiene desplazamiento anti-solape para nombres de puntos.

## Validacion recomendada

```bash
cd /home/antares/Proyecto/motor

make validate-fase-40
make run-gui
```

## Criterio de aceptacion

- La GUI exporta `falda_basica` con delantero y posterior.
- El SVG/PDF muestra medidas en espanol.
- Las cotas se muestran junto al lado correcto del patron.
- Los nombres de puntos no se montan entre si de forma critica.
