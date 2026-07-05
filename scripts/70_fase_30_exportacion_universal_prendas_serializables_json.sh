#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
cd "$PROJECT_ROOT"

echo "== Fase 30: Exportacion universal SVG/DXF/PDF para prendas serializables JSON =="

echo "== Verificando rama y estado Git =="
CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "feature/fase-30-exportacion-universal-prendas-serializables-json" ]; then
  echo "ERROR: rama actual: $CURRENT_BRANCH"
  echo "Debe ejecutarse en: feature/fase-30-exportacion-universal-prendas-serializables-json"
  exit 1
fi

if [ -n "$(git status --short)" ]; then
  echo "ERROR: el arbol de trabajo no esta limpio antes de iniciar Fase 30."
  git status --short
  exit 1
fi

echo "== Validando que short_basico este registrado antes de exportar =="
.venv/bin/python scripts/list_garments.py | grep -q '^short_basico: Short basico$'
.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20 | grep -q 'DRAFT_CLASS: ShortBasicoSerializableDraft'

echo "== Inspeccionando scripts/export_pattern.py =="
if [ ! -f scripts/export_pattern.py ]; then
  echo "ERROR: no existe scripts/export_pattern.py; Fase 24 debe estar presente."
  exit 1
fi

if ! grep -q -- '--garment' scripts/export_pattern.py; then
  echo "ERROR: scripts/export_pattern.py no parece soportar --garment. Revisar Fase 24 antes de continuar."
  exit 1
fi

if ! grep -q -- '--output' scripts/export_pattern.py; then
  echo "ERROR: scripts/export_pattern.py no parece soportar --output. Revisar contrato de exportacion universal."
  exit 1
fi

echo "== Agregando target Makefile export-universal-short =="
python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

target = """
export-universal-short:
	.venv/bin/python scripts/export_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20 --output short_basico_universal
""".lstrip()

if "export-universal-short:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += "\n" + target
    path.write_text(text, encoding="utf-8")
PY

echo "== Agregando prueba de exportacion universal para short_basico =="
cat > tests/test_serializable_universal_exports.py <<'PY'
from pathlib import Path
import subprocess
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_short_basico_exports_through_universal_flow():
    output_name = "short_basico_universal"

    for relative_path in (
        Path("exports/svg") / f"{output_name}.svg",
        Path("exports/dxf") / f"{output_name}.dxf",
        Path("exports/pdf") / f"{output_name}.pdf",
    ):
        path = PROJECT_ROOT / relative_path
        if path.exists():
            path.unlink()

    result = subprocess.run(
        [
            sys.executable,
            "scripts/export_pattern.py",
            "--garment",
            "short_basico",
            "--waist",
            "84",
            "--hip",
            "104",
            "--outseam",
            "45",
            "--inseam",
            "20",
            "--output",
            output_name,
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "GARMENT_CODE: short_basico" in result.stdout
    assert "GARMENT_NAME: Short basico" in result.stdout
    assert "DRAFT_CLASS: ShortBasicoSerializableDraft" in result.stdout
    assert "PIECE_COUNT: 1" in result.stdout

    for relative_path in (
        Path("exports/svg") / f"{output_name}.svg",
        Path("exports/dxf") / f"{output_name}.dxf",
        Path("exports/pdf") / f"{output_name}.pdf",
    ):
        exported = PROJECT_ROOT / relative_path
        assert exported.exists(), f"No fue generado: {exported}"
        assert exported.stat().st_size > 0, f"Archivo vacio: {exported}"
PY

echo "== Agregando documentacion Fase 30 =="
cat > docs/39_Fase_30_Exportacion_Universal_Prendas_Serializables_JSON.md <<'MD'
# Fase 30 - Exportacion universal SVG/DXF/PDF para prendas serializables JSON

## Objetivo

Permitir que una prenda serializable JSON registrada en el catalogo universal pueda exportarse mediante el flujo estandar de exportacion del motor.

La prenda validada en esta fase es:

```text
short_basico
```

## Alcance

- Exportar `short_basico` desde `scripts/export_pattern.py`.
- Generar archivos SVG, DXF y PDF.
- Agregar target `make export-universal-short`.
- Agregar prueba automatizada de exportacion universal.
- Mantener compatibilidad con prendas Python tradicionales.
- No modificar GUI.
- No crear nuevas prendas.

## Comando operativo

```bash
make export-universal-short
```

Comando equivalente:

```bash
.venv/bin/python scripts/export_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20 --output short_basico_universal
```

## Salidas esperadas

```text
exports/svg/short_basico_universal.svg
exports/dxf/short_basico_universal.dxf
exports/pdf/short_basico_universal.pdf
```

## Validaciones

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make generate-universal-short
make generate-serializable-short
make export-pattern
make export-basic-pants
make export-universal-short
```

## Resultado esperado

`short_basico` queda integrado al ciclo completo del motor:

```text
JSON -> catalogo universal -> generacion universal -> exportacion universal SVG/DXF/PDF
```
MD

echo "== Ejecutando validaciones de Fase 30 =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make generate-universal-short
make generate-serializable-short
make export-pattern
make export-basic-pants
make export-universal-short

echo "== Verificando archivos exportados =="
test -s exports/svg/short_basico_universal.svg
test -s exports/dxf/short_basico_universal.dxf
test -s exports/pdf/short_basico_universal.pdf

echo "== Estado Git posterior =="
git status --short

echo "== Fase 30 completada funcionalmente =="
echo "Archivos esperados para commit:"
echo "  Makefile"
echo "  tests/test_serializable_universal_exports.py"
echo "  docs/39_Fase_30_Exportacion_Universal_Prendas_Serializables_JSON.md"
echo "  scripts/70_fase_30_exportacion_universal_prendas_serializables_json.sh"
