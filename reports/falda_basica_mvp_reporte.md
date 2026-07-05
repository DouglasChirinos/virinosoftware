# Reporte tecnico - Falda basica MVP

## Unidad de medida

- Unidad oficial del motor: **centimetros (cm)**.
- Las coordenadas internas del patron estan expresadas en cm.
- Los exportadores pueden convertir escala para visualizacion, pero no deben cambiar la unidad logica.

## Version del patron

- Codigo: `SKIRT_BASIC`
- Version patron: `0.1.0`
- Version motor: `mvp-0.1.0`
- Generado UTC: `2026-07-05T02:04:02.633610+00:00`

## Medidas de entrada

| Campo | Valor | Unidad |
|---|---:|---|
| waist | 72.0 | cm |
| hip | 98.0 | cm |
| skirt_length | 60.0 | cm |
| ease | 2.0 | cm |
| hip_depth | 20.0 | cm |
| ease_hip | 2.0 | cm |
| ease_waist | 2.0 | cm |

## Piezas generadas

### Falda basica delantera

- Puntos: 9
- Lineas: 9
- Lineas patron: 9
- Lineas margen: 0
- Curvas: 0

#### Puntos

| Nombre | X cm | Y cm |
|---|---:|---:|
| A_cintura_centro | 0.00 | 0.00 |
| B_cintura_costado | 19.00 | 0.00 |
| C_cadera_centro | 0.00 | 20.00 |
| D_cadera_costado | 25.50 | 20.00 |
| E_bajo_centro | 0.00 | 60.00 |
| F_bajo_costado | 25.50 | 60.00 |
| Pinza_izq | 8.42 | 0.00 |
| Pinza_punta | 9.50 | 11.00 |
| Pinza_der | 10.58 | 0.00 |

#### Lineas

| Etiqueta | Inicio | Fin | Longitud cm |
|---|---|---|---:|
| cintura | (0.00, 0.00) | (19.00, 0.00) | 19.00 |
| costado cintura-cadera | (19.00, 0.00) | (25.50, 20.00) | 21.03 |
| costado | (25.50, 20.00) | (25.50, 60.00) | 40.00 |
| bajo | (25.50, 60.00) | (0.00, 60.00) | 25.50 |
| centro | (0.00, 60.00) | (0.00, 20.00) | 40.00 |
| centro superior | (0.00, 20.00) | (0.00, 0.00) | 20.00 |
| linea de cadera | (0.00, 20.00) | (25.50, 20.00) | 25.50 |
| pinza izquierda | (8.42, 0.00) | (9.50, 11.00) | 11.05 |
| pinza derecha | (9.50, 11.00) | (10.58, 0.00) | 11.05 |

#### Anotaciones

- MVP tecnico sin margenes de costura.

### Falda basica delantera con margen

- Puntos: 9
- Lineas: 15
- Lineas patron: 9
- Lineas margen: 6
- Curvas: 0

#### Puntos

| Nombre | X cm | Y cm |
|---|---:|---:|
| A_cintura_centro | 0.00 | 0.00 |
| B_cintura_costado | 19.00 | 0.00 |
| C_cadera_centro | 0.00 | 20.00 |
| D_cadera_costado | 25.50 | 20.00 |
| E_bajo_centro | 0.00 | 60.00 |
| F_bajo_costado | 25.50 | 60.00 |
| Pinza_izq | 8.42 | 0.00 |
| Pinza_punta | 9.50 | 11.00 |
| Pinza_der | 10.58 | 0.00 |

#### Lineas

| Etiqueta | Inicio | Fin | Longitud cm |
|---|---|---|---:|
| cintura | (0.00, 0.00) | (19.00, 0.00) | 19.00 |
| costado cintura-cadera | (19.00, 0.00) | (25.50, 20.00) | 21.03 |
| costado | (25.50, 20.00) | (25.50, 60.00) | 40.00 |
| bajo | (25.50, 60.00) | (0.00, 60.00) | 25.50 |
| centro | (0.00, 60.00) | (0.00, 20.00) | 40.00 |
| centro superior | (0.00, 20.00) | (0.00, 0.00) | 20.00 |
| linea de cadera | (0.00, 20.00) | (25.50, 20.00) | 25.50 |
| pinza izquierda | (8.42, 0.00) | (9.50, 11.00) | 11.05 |
| pinza derecha | (9.50, 11.00) | (10.58, 0.00) | 11.05 |
| margen cerrado 1 | (-1.50, -1.00) | (19.73, -1.00) | 21.23 |
| margen cerrado 2 | (19.73, -1.00) | (27.00, 21.38) | 23.53 |
| margen cerrado 3 | (27.00, 21.38) | (27.00, 63.00) | 41.62 |
| margen cerrado 4 | (27.00, 63.00) | (-1.50, 63.00) | 28.50 |
| margen cerrado 5 | (-1.50, 63.00) | (-1.50, 20.00) | 43.00 |
| margen cerrado 6 | (-1.50, 20.00) | (-1.50, -1.00) | 21.00 |

#### Anotaciones

- MVP tecnico sin margenes de costura.
- Incluye contorno cerrado de margen con control miter/bevel.
