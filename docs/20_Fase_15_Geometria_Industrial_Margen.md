# 20. Fase 15 - Geometria industrial de margen

## Objetivo

Evolucionar el margen de costura MVP desde offsets sueltos por linea hacia un contorno cerrado inicial.

## Alcance aplicado

- Interseccion de offsets consecutivos.
- Construccion de vertices de margen.
- Generacion de contorno cerrado de margen.
- QA por grado topologico de vertices.
- Reporte tecnico de margen.
- Preparacion conceptual para miter/fillet.

## Unidad

La unidad oficial sigue siendo:

```text
cm
```

## Algoritmo

1. Identificar el contorno principal de la pieza.
2. Calcular offset paralelo por cada linea de contorno.
3. Calcular interseccion entre offsets consecutivos.
4. Crear vertices de margen.
5. Unir vertices en lineas `seam_allowance`.
6. Validar que cada vertice tenga grado 2.

## Limitaciones conocidas

- El algoritmo esta optimizado para el bloque MVP de falda.
- Miter/fillet avanzado todavia no esta implementado.
- Curvas reales de patronaje quedan para fases futuras.
- No se aplica todavia compensacion industrial por tipo de tela.

## Salida nueva

```text
reports/falda_basica_mvp_margen.md
```
