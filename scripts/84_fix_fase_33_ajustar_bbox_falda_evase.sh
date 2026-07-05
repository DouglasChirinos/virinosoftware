#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
cd "$PROJECT_ROOT"

echo "== Fix Fase 33 #84: ajustar expectativa bbox falda_evase =="

BRANCH="$(git branch --show-current)"
if [ "$BRANCH" != "feature/fase-33-validacion-visual-geometrica-serializables" ]; then
  echo "ERROR: rama actual inesperada: $BRANCH" >&2
  echo "Esperada: feature/fase-33-validacion-visual-geometrica-serializables" >&2
  exit 1
fi

TEST_FILE="tests/test_serializable_geometry_validation.py"
DOC_FILE="docs/42_Fase_33_Validacion_Visual_Geometrica_Serializables.md"

if [ ! -f "$TEST_FILE" ]; then
  echo "ERROR: no existe $TEST_FILE" >&2
  exit 1
fi

cp "$TEST_FILE" "$TEST_FILE.fase33.fix84.bak"

python3 - <<'PY'
from pathlib import Path

path = Path("tests/test_serializable_geometry_validation.py")
text = path.read_text(encoding="utf-8")

old = "assert piece.width == pytest.approx(36.75)"
new = "assert piece.width == pytest.approx(48.75)"
if old not in text:
    raise SystemExit(f"ERROR: no se encontro expectativa antigua: {old}")

text = text.replace(old, new)

# Add/adjust explicit min/max assertions if the test has enough context and they are not present.
marker = "assert piece.width == pytest.approx(48.75)\n"
addition = (
    "assert piece.width == pytest.approx(48.75)\n"
    "    assert piece.min_x == pytest.approx(-12.0)\n"
    "    assert piece.max_x == pytest.approx(36.75)\n"
)
if "assert piece.min_x == pytest.approx(-12.0)" not in text:
    text = text.replace(marker, addition)

path.write_text(text, encoding="utf-8")
PY

if [ -f "$DOC_FILE" ]; then
  cp "$DOC_FILE" "$DOC_FILE.fase33.fix84.bak"
  python3 - <<'PY'
from pathlib import Path

path = Path("docs/42_Fase_33_Validacion_Visual_Geometrica_Serializables.md")
text = path.read_text(encoding="utf-8")

note = """

## Ajuste de criterio para falda_evase

La validacion de bounding box usa el ancho total real de la pieza, desde `min_x` hasta `max_x`. En `falda_evase`, el ruedo se expande hacia el lado negativo del eje X y hacia el lado positivo; por tanto, el ancho geometrico esperado no es solo el extremo derecho (`36.75 cm`), sino el rango completo:

```text
min_x = -12.0
max_x = 36.75
width = 48.75
```

Este criterio valida la envolvente completa de la pieza exportable y evita subestimar patrones que usan coordenadas negativas.
"""

if "## Ajuste de criterio para falda_evase" not in text:
    text = text.rstrip() + note + "\n"

path.write_text(text, encoding="utf-8")
PY
fi

echo "== Validando prueba focalizada =="
.venv/bin/pytest -q tests/test_serializable_geometry_validation.py

echo "== Validando suite completa =="
make test

echo "== Validando CLIs geométricos =="
make validate-geometry-short
make validate-geometry-falda-evase

echo "== Validando exports serializables =="
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git =="
git status --short

echo "OK: Fix Fase 33 #84 aplicado y validado."
