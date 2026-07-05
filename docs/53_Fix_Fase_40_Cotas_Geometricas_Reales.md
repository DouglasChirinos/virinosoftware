# Fix Fase 40 - Cotas geometricas reales

Fecha: 2026-07-05

## Problema detectado

En la exportacion visual de `falda_basica`, las cotas al borde del patron mostraban la medida corporal completa de entrada.

Ejemplo incorrecto:

```text
A_cintura_centro -> B_cintura_costado = Cintura: 73 cm
```

Esto es incorrecto porque el tramo mostrado no representa la cintura corporal completa. En una pieza delantera/posterior con centro, ese segmento representa una fraccion geometrica del patron.

## Decision

Separar dos conceptos:

- Encabezado: conserva las medidas corporales de entrada.
- Cotas al borde: muestran la longitud real del segmento dibujado.

## Resultado esperado

Para `waist=73`, `hip=99`, `skirt_length=60`, `ease=2`:

```text
Encabezado: Cintura: 73 cm | Cadera: 99 cm | Largo falda: 60 cm
Cota superior: Cintura pieza: 19.25 cm
Cota cadera: Cadera pieza: 25.75 cm
Cota vertical: Largo pieza: 60 cm
```

## Criterio de aceptacion

Las medidas colocadas junto al patron deben coincidir con el lado del patron donde aparecen.
