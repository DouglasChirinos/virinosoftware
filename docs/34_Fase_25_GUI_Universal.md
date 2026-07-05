# Fase 25 - Integración GUI con registro, generación y exportación universal

## Objetivo

Desacoplar la GUI del flujo exclusivo de `falda_basica` y conectarla al backend universal creado en las Fases 21, 22 y 24.

## Alcance implementado

- Se crea `app/controllers/universal_pattern_controller.py`.
- Se crea `app/gui/universal_main_window.py`.
- Se crea `scripts/run_gui.py`.
- Se crea `app/main_universal.py`.
- Se agrega `make run-gui`.
- La GUI lista prendas registradas.
- La GUI permite generar y exportar SVG/DXF/PDF.
- Se agregan tests de controlador GUI.
- No se elimina la GUI legacy.
- No se modifica geometría ni exportadores.

## Uso

```bash
make run-gui
```

Alternativa:

```bash
.venv/bin/python scripts/run_gui.py
```

## Flujo funcional

```text
GUI
  -> list_garments
  -> generate_pattern
  -> export_generated_pattern
  -> exports/svg
  -> exports/dxf
  -> exports/pdf
```

## Salidas esperadas desde GUI

```text
exports/svg/falda_basica_gui_universal.svg
exports/dxf/falda_basica_gui_universal.dxf
exports/pdf/falda_basica_gui_universal.pdf

exports/svg/pantalon_basico_gui_universal.svg
exports/dxf/pantalon_basico_gui_universal.dxf
exports/pdf/pantalon_basico_gui_universal.pdf
```

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make run-gui
```
