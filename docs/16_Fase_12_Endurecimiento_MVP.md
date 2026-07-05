# 16. Fase 12 - Endurecimiento del MVP

## Objetivo

Convertir el MVP tecnico en una base controlada y auditable.

## Alcance aplicado

- Validaciones formales de medidas.
- Logging operacional.
- Versionado interno del patron.
- Reporte tecnico Markdown del patron generado.
- Confirmacion de unidad oficial del motor.

## Unidad oficial

La unidad oficial del motor es:

```text
centimetros (cm)
```

Todas las coordenadas internas, medidas corporales, holguras, largos, profundidad de cadera y lineas del patron se calculan en centimetros.

Los exportadores pueden aplicar escala visual:

- SVG: escala a pixeles para visualizacion.
- PDF: escala para render en pagina.
- DXF: conserva coordenadas logicas del motor.

Pero la unidad logica del motor sigue siendo **cm**.

## Validaciones MVP

Rangos conservadores:

| Campo | Rango |
|---|---:|
| waist | 40 a 180 cm |
| hip | 50 a 220 cm |
| skirt_length | 20 a 140 cm |
| ease | 0 a 20 cm |
| hip_depth | 10 a 35 cm |

Reglas adicionales:

- `hip` no debe ser menor que `waist`.
- `hip_depth` debe ser menor que `skirt_length`.
- `unit` debe ser `cm`.

## Versionado interno

Cada pieza generada incluye metadatos:

- `code`
- `version`
- `engine_version`
- `created_at`
- `unit`
- `measurement_unit`
- `garment`

## Reportes

Salida esperada:

```text
reports/falda_basica_mvp_reporte.md
```

## Logging

Salida esperada:

```text
logs/motor_patronaje.log
```
