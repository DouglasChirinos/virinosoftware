# Exportaciones MVP - Motor Patronaje 2D

## Objetivo

Agregar salidas tecnicas basicas para que el patron generado no quede limitado a una vista SVG.

## Formatos habilitados

- SVG: formato principal de trabajo y previsualizacion.
- DXF: formato base para interoperabilidad con herramientas CAD/corte.
- PDF: formato de revision, validacion y entrega gerencial/operativa.

## Regla de control

El motor geometrico genera entidades internas. Los exportadores solo traducen esas entidades a formatos externos.

No se debe colocar logica de patronaje dentro de los exportadores.

## Comando principal

```bash
cd /home/antares/Proyecto/motor
source .venv/bin/activate
python3 scripts/generate_basic_skirt_all_exports.py
```

## Salidas esperadas

```text
exports/svg/falda_basica_mvp.svg
exports/dxf/falda_basica_mvp.dxf
exports/pdf/falda_basica_mvp.pdf
```

## Validacion

```bash
make test
```

## Criterio de cierre

Esta fase queda cerrada cuando:

- Se genera SVG sin error.
- Se genera DXF sin error.
- Se genera PDF sin error.
- Las pruebas automatizadas pasan.
