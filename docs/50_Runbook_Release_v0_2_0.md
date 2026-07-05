# Runbook Release v0.2.0

Este runbook se ejecuta en Fase 39. Se documenta aqui para que el release sea reproducible.

## 1. Validar develop

```bash
cd /home/antares/Proyecto/motor

git switch develop
git pull origin develop
git status --short

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

## 2. Promover a main

```bash
git switch main
git pull origin main
git merge --no-ff develop -m "Release v0.2.0 motor serializable JSON"
```

## 3. Validar main

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

## 4. Crear tag

```bash
git tag -a v0.2.0 -m "v0.2.0 - MVP motor serializable JSON"
```

## 5. Publicar

```bash
git push origin main
git push origin v0.2.0
```

## 6. Verificacion final

```bash
git log --oneline --decorate --max-count=10
git tag --list "v0.2.0"
```
