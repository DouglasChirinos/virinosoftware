#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"

cd "$PROJECT_DIR"

echo "== Release check v0.1.0 =="

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "develop" ]; then
  echo "ERROR: ejecutar release check desde develop."
  exit 1
fi

if find . -name "*.bak.*" -type f | grep -q .; then
  echo "ERROR: existen backups .bak.*"
  find . -name "*.bak.*" -type f -print
  exit 1
fi

make test
make run-qa
make generate-all-exports
make show-exports
make show-reports

git status --short

echo
echo "OK: release check v0.1.0 completado."
echo "Para promover:"
echo "  git switch main"
echo "  git pull origin main"
echo "  git merge --no-ff develop"
echo "  git tag -a v0.1.0 -m \"Release v0.1.0 MVP motor patronaje 2D\""
echo "  git push origin main"
echo "  git push origin v0.1.0"
