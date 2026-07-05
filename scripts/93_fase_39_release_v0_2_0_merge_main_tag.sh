#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
RELEASE_TAG="v0.2.0"
RELEASE_BRANCH="main"
SOURCE_BRANCH="develop"

cd "$PROJECT_ROOT"

echo "== Fase 39: Release v0.2.0 - merge develop -> main + tag =="

echo "== Verificando rama inicial =="
current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$SOURCE_BRANCH" ]; then
  echo "ERROR: debes ejecutar este script desde $SOURCE_BRANCH. Rama actual: $current_branch"
  exit 1
fi

echo "== Eliminando salidas generadas no versionables =="
rm -rf exports

echo "== Verificando arbol limpio =="
if [ -n "$(git status --short)" ]; then
  echo "ERROR: el arbol de trabajo no esta limpio. Estado actual:"
  git status --short
  exit 1
fi

echo "== Sincronizando $SOURCE_BRANCH =="
git fetch origin
git pull origin "$SOURCE_BRANCH"

if [ -n "$(git status --short)" ]; then
  echo "ERROR: $SOURCE_BRANCH quedo con cambios locales despues del pull."
  git status --short
  exit 1
fi

echo "== Verificando que el tag no exista local ni remoto =="
if git rev-parse "$RELEASE_TAG" >/dev/null 2>&1; then
  echo "ERROR: el tag local $RELEASE_TAG ya existe."
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
  echo "ERROR: el tag remoto $RELEASE_TAG ya existe en origin."
  exit 1
fi

echo "== Validando release candidate en develop =="
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

if [ -n "$(git status --short)" ]; then
  echo "ERROR: quedaron cambios o salidas generadas despues de validar develop."
  git status --short
  exit 1
fi

echo "== Cambiando a $RELEASE_BRANCH =="
git switch "$RELEASE_BRANCH"
git pull origin "$RELEASE_BRANCH"

if [ -n "$(git status --short)" ]; then
  echo "ERROR: $RELEASE_BRANCH no esta limpio antes del merge."
  git status --short
  exit 1
fi

echo "== Merge $SOURCE_BRANCH -> $RELEASE_BRANCH =="
git merge --no-ff "$SOURCE_BRANCH" -m "Release v0.2.0"

echo "== Validando release en $RELEASE_BRANCH =="
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

if [ -n "$(git status --short)" ]; then
  echo "ERROR: quedaron cambios o salidas generadas despues de validar main."
  git status --short
  exit 1
fi

echo "== Creando tag anotado $RELEASE_TAG =="
git tag -a "$RELEASE_TAG" -m "VirinoSoftware Motor de Patronaje 2D $RELEASE_TAG"

echo "== Publicando main y tag =="
git push origin "$RELEASE_BRANCH"
git push origin "$RELEASE_TAG"

echo "== Regresando a develop =="
git switch "$SOURCE_BRANCH"
git pull origin "$SOURCE_BRANCH"

echo "== Estado final =="
git status --short
git log --oneline --decorate --max-count=10

echo "== Release $RELEASE_TAG completado correctamente =="
