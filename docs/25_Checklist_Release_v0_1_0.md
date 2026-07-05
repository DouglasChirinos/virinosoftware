# 25. Checklist Release v0.1.0

## Release

```text
v0.1.0 - MVP motor patronaje 2D
```

## Validaciones obligatorias

Ejecutar desde `develop`:

```bash
make test
make run-qa
make generate-all-exports
make show-exports
make show-reports
```

## Estado esperado

```text
pytest verde
QA_STATUS: PASSED
SVG generado
DXF generado
PDF generado
Reporte tecnico generado
Reporte QA generado
Reporte margen generado
```

## Archivos esperados

```text
exports/svg/falda_basica_mvp.svg
exports/dxf/falda_basica_mvp.dxf
exports/pdf/falda_basica_mvp.pdf

reports/falda_basica_mvp_reporte.md
reports/falda_basica_mvp_qa.md
reports/falda_basica_mvp_margen.md
```

## Git

```bash
git status
git branch -vv
git log --oneline --max-count=10
```

## Promocion a main

```bash
git switch main
git pull origin main
git merge --no-ff develop
git tag -a v0.1.0 -m "Release v0.1.0 MVP motor patronaje 2D"
git push origin main
git push origin v0.1.0
```

## Criterio de no avance

No promover si ocurre cualquiera de estos puntos:

- tests fallan,
- QA falla,
- exportaciones no se generan,
- reportes no se generan,
- hay archivos `.bak.*`,
- hay cambios sin commit no justificados,
- `develop` no esta actualizado con remoto,
- existe duda sobre el alcance del MVP.
