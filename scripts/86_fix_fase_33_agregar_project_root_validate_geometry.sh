#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
SCRIPT_PATH="$PROJECT_ROOT/scripts/validate_serializable_geometry.py"
BACKUP_PATH="$SCRIPT_PATH.fase33.fix86.bak"

cd "$PROJECT_ROOT"

echo "== Fix Fase 33 #86: agregar PROJECT_ROOT al sys.path en validate_serializable_geometry.py =="

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "ERROR: no existe $SCRIPT_PATH" >&2
  exit 1
fi

cp "$SCRIPT_PATH" "$BACKUP_PATH"
echo "Backup creado en: ${BACKUP_PATH#$PROJECT_ROOT/}"

python3 - <<'PY'
from pathlib import Path

path = Path("scripts/validate_serializable_geometry.py")
text = path.read_text(encoding="utf-8")

if "PROJECT_ROOT = Path(__file__).resolve().parents[1]" in text and "sys.path.insert(0, str(PROJECT_ROOT))" in text:
    print("OK: PROJECT_ROOT ya esta configurado; no se modifica.")
else:
    if "import sys" not in text:
        text = text.replace("import argparse\n", "import argparse\nimport sys\n", 1)

    if "from pathlib import Path\n" not in text:
        raise SystemExit("ERROR: validate_serializable_geometry.py debe importar Path desde pathlib")

    marker = "from pathlib import Path\n"
    insertion = (
        "from pathlib import Path\n\n"
        "PROJECT_ROOT = Path(__file__).resolve().parents[1]\n"
        "if str(PROJECT_ROOT) not in sys.path:\n"
        "    sys.path.insert(0, str(PROJECT_ROOT))\n"
    )
    text = text.replace(marker, insertion, 1)
    path.write_text(text, encoding="utf-8")
    print("OK: PROJECT_ROOT agregado al sys.path.")
PY

echo "== Fragmento inicial del CLI =="
sed -n '1,28p' scripts/validate_serializable_geometry.py

echo "== Validando sintaxis =="
.venv/bin/python -m compileall scripts/validate_serializable_geometry.py

echo "== Validando targets geometricos =="
make validate-geometry-short
make validate-geometry-falda-evase

echo "== Validando suite completa =="
make test
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git =="
git status --short

echo "OK: Fix Fase 33 #86 aplicado y validado."
