# Reporte margen - Falda basica talla M

## Alcance

- Contorno cerrado de margen por interseccion de offsets.
- Control de esquinas tipo miter.
- Fallback bevel cuando el miter supera el limite configurado.
- Unidad: centimetros (cm).

## Piezas con margen

### Falda basica delantera con margen

- Modo: `closed_contour`
- Join configurado: `miter`
- Limite miter cm: `8.0`
- Bevel fallback: `True`
- Lineas de margen: 6

#### Analisis de esquinas

| Join | Miter previo cm | Miter actual cm | Limite cm | Excede limite |
|---|---:|---:|---:|---|
| miter | 1.00 | 1.50 | 8.00 | no |
| miter | 0.73 | 0.73 | 8.00 | no |
| miter | 1.78 | 1.38 | 8.00 | no |
| miter | 3.00 | 1.50 | 8.00 | no |
| miter | 1.50 | 3.00 | 8.00 | no |

#### Lineas de margen

| Linea | Inicio cm | Fin cm | Longitud cm |
|---|---|---|---:|
| margen cerrado 1 | (-1.50, -1.00) | (19.73, -1.00) | 21.23 |
| margen cerrado 2 | (19.73, -1.00) | (27.00, 21.38) | 23.53 |
| margen cerrado 3 | (27.00, 21.38) | (27.00, 63.00) | 41.62 |
| margen cerrado 4 | (27.00, 63.00) | (-1.50, 63.00) | 28.50 |
| margen cerrado 5 | (-1.50, 63.00) | (-1.50, 20.00) | 43.00 |
| margen cerrado 6 | (-1.50, 20.00) | (-1.50, -1.00) | 21.00 |
