# 27. Fase 18 - Tallaje base v0.2.0-dev

## Objetivo

Iniciar el ciclo `v0.2.0-dev` preparando una base controlada de tallaje sin implementar todavia gradacion industrial completa.

## Alcance aplicado

- `SizeProfile`
- `SizeChart`
- Tabla nominal de tallas para falda MVP:
  - XS
  - S
  - M
  - L
  - XL
- Conversion de talla a `BodyMeasurements`.
- Generador de falda basica por talla.
- Reporte de tabla de tallas.
- Tests automatizados.

## Unidad

La unidad oficial sigue siendo:

```text
cm
```

## Tabla nominal MVP

| Talla | Cintura cm | Cadera cm |
|---|---:|---:|
| XS | 64 | 90 |
| S | 68 | 94 |
| M | 72 | 98 |
| L | 78 | 104 |
| XL | 84 | 110 |

## Uso

```bash
make generate-size-skirt
```

O directo:

```bash
.venv/bin/python scripts/generate_basic_skirt_from_size.py --size M
```

## Salidas esperadas

```text
exports/svg/falda_basica_talla_m.svg
exports/dxf/falda_basica_talla_m.dxf
exports/pdf/falda_basica_talla_m.pdf

reports/falda_basica_talla_m_reporte.md
reports/falda_basica_talla_m_qa.md
reports/falda_basica_talla_m_margen.md
reports/tabla_tallas_mvp.md
```

## Fuera de alcance

- Gradacion industrial completa.
- Reglas por estatura.
- Reglas por morfologia.
- Reglas por elasticidad o tipo de tela.
- Curvas especificas por talla.
- Tabla comercial definitiva.

## Criterio de cierre

```bash
make test
make run-qa
make generate-all-exports
make generate-size-skirt
make show-reports
```
