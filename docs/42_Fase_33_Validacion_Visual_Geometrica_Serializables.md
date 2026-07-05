# Fase 33 - Validacion visual/geometrica de prendas serializables

## Objetivo

Agregar una capa objetiva de control de calidad geometrico para prendas serializables antes de seguir ampliando el catalogo JSON.

La fase no cambia el motor de patronaje ni agrega prendas nuevas. Su foco es validar que los patrones generados tengan geometria minima coherente y que los archivos exportados no esten vacios.

## Alcance

- Calculo de bounding box por pieza.
- Validacion de ancho, alto y area positivos.
- Soporte para lineas clasicas y lineas serializables por referencia.
- Soporte para puntos como objetos, tuplas, listas o diccionarios.
- Validacion de archivos SVG/DXF/PDF existentes y con tamano minimo.
- CLI de validacion para prendas serializables.
- Targets Makefile para validar `short_basico` y `falda_evase`.

## Archivos agregados

```text
engine/validation/__init__.py
engine/validation/pattern_geometry.py
scripts/validate_serializable_geometry.py
tests/test_serializable_geometry_validation.py
docs/42_Fase_33_Validacion_Visual_Geometrica_Serializables.md
scripts/83_fase_33_validacion_visual_geometrica_serializables.sh
```

## Targets agregados

```bash
make validate-geometry-short
make validate-geometry-falda-evase
```

## Resultado esperado

```text
short_basico  -> bbox positivo, 4 puntos, 4 lineas, exports no triviales
falda_evase   -> bbox positivo, 4 puntos, 4 lineas, exports no triviales
```

## Criterios de aceptacion

```bash
make test
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Nota tecnica

Esta fase prepara el camino para controles visuales mas estrictos en fases posteriores, por ejemplo snapshots SVG, tolerancias por tipo de prenda o validacion de proporciones antropometricas.

## Ajuste de criterio para falda_evase

La validacion de bounding box usa el ancho total real de la pieza, desde `min_x` hasta `max_x`. En `falda_evase`, el ruedo se expande hacia el lado negativo del eje X y hacia el lado positivo; por tanto, el ancho geometrico esperado no es solo el extremo derecho (`36.75 cm`), sino el rango completo:

```text
min_x = -12.0
max_x = 36.75
width = 48.75
```

Este criterio valida la envolvente completa de la pieza exportable y evita subestimar patrones que usan coordenadas negativas.

