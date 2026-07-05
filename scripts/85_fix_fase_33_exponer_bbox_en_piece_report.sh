#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
cd "$PROJECT_ROOT"

echo "== Fix Fase 33 #85: exponer bbox en PieceGeometryReport =="

if [ ! -f engine/validation/pattern_geometry.py ]; then
  echo "ERROR: no existe engine/validation/pattern_geometry.py" >&2
  exit 1
fi

cp engine/validation/pattern_geometry.py engine/validation/pattern_geometry.py.fase33.fix85.bak

echo "Backup creado en: engine/validation/pattern_geometry.py.fase33.fix85.bak"

.venv/bin/python - <<'PY'
from pathlib import Path

path = Path("engine/validation/pattern_geometry.py")
text = path.read_text(encoding="utf-8")

if "def min_x(self) -> float:" not in text:
    needle = '''    @property\n    def height(self) -> float:\n        return self.bounding_box.height\n'''
    replacement = '''    @property\n    def height(self) -> float:\n        return self.bounding_box.height\n\n    @property\n    def min_x(self) -> float:\n        return self.bounding_box.min_x\n\n    @property\n    def min_y(self) -> float:\n        return self.bounding_box.min_y\n\n    @property\n    def max_x(self) -> float:\n        return self.bounding_box.max_x\n\n    @property\n    def max_y(self) -> float:\n        return self.bounding_box.max_y\n\n    @property\n    def area(self) -> float:\n        return self.bounding_box.area\n'''
    if needle not in text:
        raise SystemExit("ERROR: no se encontro bloque height en PieceGeometryReport")
    text = text.replace(needle, replacement, 1)

path.write_text(text, encoding="utf-8")
PY

echo "== Validando sintaxis =="
.venv/bin/python -m compileall engine/validation/pattern_geometry.py

echo "== Verificando propiedades bbox expuestas =="
grep -n "def min_x\|def max_x\|def area" engine/validation/pattern_geometry.py

echo "== Ejecutando prueba focalizada =="
.venv/bin/pytest -q tests/test_serializable_geometry_validation.py

echo "== Ejecutando validaciones completas =="
make test
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git =="
git status --short

echo "OK: Fix Fase 33 #85 aplicado y validado."
