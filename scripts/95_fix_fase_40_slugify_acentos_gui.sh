#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40: normalizacion de acentos en nombres de salida GUI =="

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el fix para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del fix =="
git status --short

python3 - <<'PY'
from pathlib import Path

path = Path("app/controllers/universal_pattern_controller.py")
text = path.read_text(encoding="utf-8")

if "import unicodedata" not in text:
    if "import re\n" in text:
        text = text.replace("import re\n", "import re\nimport unicodedata\n", 1)
    else:
        raise SystemExit("ERROR: no se encontro 'import re' para insertar unicodedata")

old = '''def slugify_output_name(value: str) -> str:\n    """Return a filesystem-safe output name fragment."""\n\n    normalized = value.strip().lower().replace("ñ", "n")\n    normalized = re.sub(r"[^a-z0-9_-]+", "_", normalized)\n    normalized = re.sub(r"_+", "_", normalized).strip("_")\n    return normalized\n'''

new = '''def slugify_output_name(value: str) -> str:\n    """Return a filesystem-safe ASCII output name fragment."""\n\n    normalized = unicodedata.normalize("NFKD", value.strip().lower())\n    normalized = normalized.encode("ascii", "ignore").decode("ascii")\n    normalized = re.sub(r"[^a-z0-9_-]+", "_", normalized)\n    normalized = re.sub(r"_+", "_", normalized).strip("_")\n    return normalized\n'''

if old not in text:
    start = text.find("def slugify_output_name(value: str) -> str:")
    if start == -1:
        raise SystemExit("ERROR: no se encontro slugify_output_name")
    end = text.find("\ndef build_output_name", start)
    if end == -1:
        raise SystemExit("ERROR: no se encontro limite antes de build_output_name")
    text = text[:start] + new + text[end + 1:]
else:
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion puntual slugify =="
.venv/bin/python - <<'PY'
from app.controllers.universal_pattern_controller import build_output_name, slugify_output_name

assert slugify_output_name(" Short Cliente María 01 ") == "short_cliente_maria_01"
assert slugify_output_name("Falda evasé Niño Ñandú") == "falda_evase_nino_nandu"
output = build_output_name("short_basico", "Cliente María / prueba")
assert output.startswith("short_basico_cliente_maria_prueba_"), output
print("SLUGIFY_OK")
PY

echo "== Validaciones Fase 40 =="
make validate-fase-40

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix Fase 40 aplicado correctamente =="
