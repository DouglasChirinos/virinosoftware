# Fase 40.3D — Extension de tiro con formula industrial MVP

## Decision

Fase 40.3C corrigio la direccion de concavidad del tiro, pero eso no basta. En patronaje de pantalon, la curva de tiro debe considerar la **extension de tiro** basada en el contorno total de cadera.

## Reglas incorporadas

Para una base de contextura promedio:

```text
Tiro delantero: entre 1/20 y 1/16 del contorno total de cadera.
Tiro posterior: entre 1/8 y 1/6 del contorno total de cadera.
```

Ejemplo con cadera 104 cm:

```text
Delantero: 5.20 cm a 6.50 cm.
Posterior: 13.00 cm a 17.33 cm.
```

El posterior debe ser materialmente mas profundo que el delantero.

## Cambios tecnicos

`engine/exports/structural_curves.py` agrega a cada `crotch_curve`:

```text
extension_formula
extension_cm
extension_range_cm
measurement_basis
```

Ademas, los puntos de control Bezier del tiro usan la extension calculada, no un porcentaje arbitrario del ancho de pieza.

## Estado de producto

Esto mejora el MVP estructural, pero todavia no convierte pantalon ni short en patron industrial. Faltan:

- linea base real de tiro;
- gancho delantero y posterior como entidades de patronaje;
- altura de tiro formal;
- linea de rodilla;
- aplomo / hilo de tela;
- piquetes;
- reglas por tipo de prenda, tela y silueta.

## Validacion

```bash
make validate-fase-40-3d
make validate-fase-40-3c
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness
```

Luego reexportar desde GUI:

```text
pantalon_basico
short_basico
```

Criterio visual minimo:

```text
- La curva de tiro entra hacia dentro.
- El posterior entra mas profundo que el delantero.
- No reaparecen curvas punteadas duplicadas.
- El PDF sigue legible.
```
