# 24. Flujo Git main/develop/feature

## Ramas oficiales

```text
main       -> estable / produccion
develop    -> integracion de desarrollo
feature/*  -> trabajo por fase o funcionalidad
```

## Regla principal

No se desarrolla directamente sobre `main`.

Todo cambio entra por:

```text
feature/* -> develop -> main
```

## Crear una fase nueva

```bash
cd /home/antares/Proyecto/motor

git switch develop
git pull origin develop

git switch -c feature/fase-XX-nombre-corto
```

## Validar una fase

```bash
make test
make run-qa
make generate-all-exports
make show-reports
```

## Cerrar una feature

```bash
find . -name "*.bak.*" -type f -delete

git status
git add .
git commit -m "Fase XX descripcion corta"

git push -u origin feature/fase-XX-nombre-corto
```

## Integrar a develop

```bash
git switch develop
git pull origin develop
git merge --no-ff feature/fase-XX-nombre-corto
git push origin develop
```

## Promover a main

Solo cuando `develop` este estable:

```bash
git switch main
git pull origin main

git merge --no-ff develop

git tag -a v0.1.0 -m "Release v0.1.0 MVP motor patronaje 2D"

git push origin main
git push origin v0.1.0
```

## Convencion de nombres

```text
feature/fase-16-uniones-industriales-margen
feature/fase-17-cierre-tecnico-mvp
feature/fase-18-nombre-futuro
```
