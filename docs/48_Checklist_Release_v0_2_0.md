# Checklist Release v0.2.0

## Identificacion

```text
Proyecto: VirinoSoftware - Motor de Patronaje 2D
Release: v0.2.0
Tipo: MVP tecnico serializable JSON
Rama candidata: develop
Rama produccion: main
```

## Checklist pre-release

- [ ] Estar en `develop`.
- [ ] `git pull origin develop` ejecutado.
- [ ] `git status --short` sin salida antes de validar.
- [ ] `make test` aprobado.
- [ ] `make validate-garments-json` aprobado.
- [ ] `make validate-serializable-catalog` aprobado.
- [ ] `make generate-serializable-catalog` aprobado.
- [ ] `make export-serializable-catalog` aprobado.
- [ ] `make validate-geometry-short` aprobado.
- [ ] `make validate-geometry-falda-evase` aprobado.
- [ ] `make export-universal-short` aprobado.
- [ ] `make export-universal-falda-evase` aprobado.
- [ ] `exports/` eliminado antes de commit/tag.
- [ ] `git status --short` sin salida despues de limpiar exports.

## Checklist release Git

- [ ] Cambiar a `main`.
- [ ] Actualizar `main` desde remoto.
- [ ] Mergear `develop` hacia `main` con `--no-ff`.
- [ ] Ejecutar validaciones finales en `main`.
- [ ] Eliminar `exports/`.
- [ ] Confirmar `git status --short` limpio.
- [ ] Crear tag anotado `v0.2.0`.
- [ ] Push de `main`.
- [ ] Push del tag `v0.2.0`.

## Comandos de validacion

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
rm -rf exports
git status --short
```

## Resultado esperado

```text
141 passed, 7 warnings
CATALOG_OK definitions=2
CATALOG_GENERATION_OK definitions=2
CATALOG_EXPORT_OK definitions=2 exported_files=6
git status --short sin salida
```
