#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
EXPORTER="$PROJECT_ROOT/engine/generation/exporter.py"

cd "$PROJECT_ROOT"

echo "== Fix Fase 30 #75: reconstruir normalizacion serializable en exporter =="

if [ ! -f "$EXPORTER" ]; then
  echo "ERROR: no existe $EXPORTER"
  exit 1
fi

BACKUP="$EXPORTER.fase30.fix75.bak"
cp "$EXPORTER" "$BACKUP"
echo "Backup creado en: $BACKUP"

python3 - <<'PY'
from pathlib import Path

path = Path("engine/generation/exporter.py")
text = path.read_text(encoding="utf-8")

start_marker = "def _normalize_point(point: Any) -> Any:\n"
end_marker = "def normalize_pieces(raw_pieces: list[Any]) -> list[Any]:\n"

start = text.find(start_marker)
end = text.find(end_marker)

if start == -1:
    raise SystemExit("ERROR: no se encontro def _normalize_point(point: Any) -> Any")
if end == -1:
    raise SystemExit("ERROR: no se encontro def normalize_pieces(raw_pieces: list[Any]) -> list[Any)")
if end <= start:
    raise SystemExit("ERROR: orden invalido de bloques en exporter.py")

replacement = '''def _normalize_point(point: Any) -> Any:
    if hasattr(point, "x") and hasattr(point, "y"):
        return point

    if isinstance(point, (tuple, list)) and len(point) >= 2:
        try:
            return SimpleNamespace(x=float(point[0]), y=float(point[1]))
        except (TypeError, ValueError) as exc:
            raise PatternExportError(f"Invalid numeric point object: {point!r}") from exc

    if isinstance(point, dict) and "x" in point and "y" in point:
        try:
            return SimpleNamespace(x=float(point["x"]), y=float(point["y"]))
        except (TypeError, ValueError) as exc:
            raise PatternExportError(f"Invalid numeric point object: {point!r}") from exc

    raise PatternExportError(f"Invalid point object: {point!r}")


def _normalize_line(line: Any) -> Any:
    if not hasattr(line, "start") or not hasattr(line, "end"):
        raise PatternExportError(f"Invalid line object: {line!r}")

    return SimpleNamespace(
        start=_normalize_point(line.start),
        end=_normalize_point(line.end),
        name=getattr(line, "name", ""),
        kind=getattr(line, "kind", "pattern"),
    )


def _resolve_serializable_line_reference(line: Any, points: Any) -> Any:
    if hasattr(line, "start") and hasattr(line, "end"):
        return line

    start_key = None
    end_key = None
    name = ""
    kind = "pattern"

    if isinstance(line, (tuple, list)) and len(line) >= 2:
        start_key = line[0]
        end_key = line[1]
        if len(line) >= 3:
            name = str(line[2])
        if len(line) >= 4:
            kind = str(line[3])
    elif isinstance(line, dict):
        start_key = line.get("start") or line.get("from") or line.get("a")
        end_key = line.get("end") or line.get("to") or line.get("b")
        name = str(line.get("name", ""))
        kind = str(line.get("kind", "pattern"))
    else:
        return line

    if not isinstance(points, dict):
        raise PatternExportError(
            f"Serializable line reference requires piece.points dict: {points!r}"
        )

    if start_key not in points:
        raise PatternExportError(f"Unknown serializable line start point: {start_key!r}")
    if end_key not in points:
        raise PatternExportError(f"Unknown serializable line end point: {end_key!r}")

    return SimpleNamespace(
        start=_normalize_point(points[start_key]),
        end=_normalize_point(points[end_key]),
        name=name,
        kind=kind,
    )


def _normalize_piece(piece: Any) -> Any:
    if not hasattr(piece, "name"):
        raise PatternExportError(f"Piece without name cannot be exported: {piece!r}")

    if not hasattr(piece, "lines"):
        raise PatternExportError(f"Piece without lines cannot be exported: {piece!r}")

    source_points = getattr(piece, "points", None)
    lines = [
        _normalize_line(_resolve_serializable_line_reference(line, source_points))
        for line in piece.lines
    ]

    points = {}

    for index, line in enumerate(lines, start=1):
        points[f"line_{index}_start"] = line.start
        points[f"line_{index}_end"] = line.end

    normalized = SimpleNamespace(
        name=piece.name,
        lines=lines,
        points=points,
        metadata=dict(getattr(piece, "metadata", {}) or {}),
    )

    normalized.pattern_lines = [
        line for line in lines if getattr(line, "kind", "pattern") == "pattern"
    ]
    normalized.seam_allowance_lines = [
        line for line in lines if getattr(line, "kind", "pattern") == "seam_allowance"
    ]

    return normalized


'''

new_text = text[:start] + replacement + text[end:]
path.write_text(new_text, encoding="utf-8")
PY

echo "OK: bloque de normalizacion reconstruido."

echo "== Validando sintaxis =="
.venv/bin/python -m py_compile engine/generation/exporter.py

echo "== Validando exportacion directa de short_basico =="
.venv/bin/python scripts/export_pattern.py \
  --garment short_basico \
  --waist 84 \
  --hip 104 \
  --outseam 45 \
  --inseam 20 \
  --output short_basico_universal

echo "== Verificando archivos exportados =="
for file in \
  exports/svg/short_basico_universal.svg \
  exports/dxf/short_basico_universal.dxf \
  exports/pdf/short_basico_universal.pdf
 do
  if [ ! -s "$file" ]; then
    echo "ERROR: archivo exportado no existe o esta vacio: $file"
    exit 1
  fi
  ls -lh "$file"
done

echo "== Ejecutando validaciones completas =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make generate-universal-short
make generate-serializable-short
make export-pattern
make export-basic-pants
make export-universal-short

echo "== Estado Git =="
git status --short

echo "OK: Fix Fase 30 #75 aplicado y validado."
