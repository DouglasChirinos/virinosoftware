#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40.1: layout independiente por pieza y cotas sin solape =="

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

path = Path("engine/generation/exporter.py")
text = path.read_text(encoding="utf-8")

if "def _piece_bounds" not in text:
    marker = '''def _attach_export_metadata(pieces: list[PatternPiece], generation_result: PatternGenerationResult) -> None:\n    measurements = _measurements_as_export_dict(generation_result.measurements)\n\n    for piece in pieces:\n        piece.metadata.setdefault("garment_code", generation_result.garment_code)\n        piece.metadata.setdefault("garment_name", generation_result.garment_name)\n        piece.metadata.setdefault("draft_class_name", generation_result.draft_class_name)\n        piece.metadata.setdefault("measurements", measurements)\n        piece.metadata["dimension_annotations"] = build_dimension_annotations(piece, generation_result.garment_code)\n'''
    insert = '''def _piece_bounds(piece: PatternPiece) -> tuple[float, float, float, float]:\n    """Return bounds for one piece before visual export."""\n\n    xs: list[float] = []\n    ys: list[float] = []\n\n    for point in piece.points.values():\n        xs.append(float(point.x))\n        ys.append(float(point.y))\n\n    for line in piece.lines:\n        xs.extend([float(line.start.x), float(line.end.x)])\n        ys.extend([float(line.start.y), float(line.end.y)])\n\n    if not xs or not ys:\n        return (0.0, 0.0, 0.0, 0.0)\n\n    return min(xs), min(ys), max(xs), max(ys)\n\n\ndef _translate_line(line: Any, dx: float, dy: float) -> Any:\n    return _make_export_line(\n        start=line.start.translate(dx=dx, dy=dy),\n        end=line.end.translate(dx=dx, dy=dy),\n        name=_line_name(line),\n        kind=_line_kind(line),\n    )\n\n\ndef _translate_piece(piece: PatternPiece, dx: float, dy: float) -> None:\n    if not dx and not dy:\n        return\n\n    piece.points = {\n        name: point.translate(dx=dx, dy=dy)\n        for name, point in piece.points.items()\n    }\n    piece.lines = [_translate_line(line, dx, dy) for line in piece.lines]\n\n\ndef _arrange_pieces_for_export(pieces: list[PatternPiece], gutter: float = 14.0) -> None:\n    """Place each piece in its own visual lane before PDF/SVG export.\n\n    Some MVP drafts, especially pantalon_basico, generate front and back pieces\n    from the same local origin. That is correct for drafting internals but wrong\n    for a product-facing export because pieces and dimensions overlap. This\n    layout step keeps each piece independent without changing its geometry.\n    Distances remain identical because only translation is applied.\n    """\n\n    cursor_x = 0.0\n\n    for index, piece in enumerate(pieces):\n        min_x, min_y, max_x, _max_y = _piece_bounds(piece)\n        width = max(max_x - min_x, 1.0)\n        dx = cursor_x - min_x\n        dy = -min_y\n        _translate_piece(piece, dx, dy)\n        piece.metadata["visual_layout_index"] = str(index)\n        piece.metadata["visual_layout_dx"] = str(dx)\n        piece.metadata["visual_layout_dy"] = str(dy)\n        cursor_x += width + gutter\n\n\n''' + marker
    if marker not in text:
        raise SystemExit("ERROR: no se encontro bloque _attach_export_metadata esperado en exporter.py")
    text = text.replace(marker, insert, 1)

old = '''    generation_result = generate_pattern(request.generation_request)\n    pieces = normalize_pieces(generation_result.pieces)\n    _attach_export_metadata(pieces, generation_result)\n    output_name = _safe_output_name(request.output_name)\n'''
new = '''    generation_result = generate_pattern(request.generation_request)\n    pieces = normalize_pieces(generation_result.pieces)\n    _arrange_pieces_for_export(pieces)\n    _attach_export_metadata(pieces, generation_result)\n    output_name = _safe_output_name(request.output_name)\n'''
if old not in text:
    if "_arrange_pieces_for_export(pieces)" not in text:
        raise SystemExit("ERROR: no se encontro bloque de export_generated_pattern para insertar layout")
else:
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
PY

cat > tests/test_fase_40_1_layout_piezas_independientes.py <<'PY'
from __future__ import annotations

from engine.generation import PatternGenerationRequest, generate_pattern
from engine.generation.exporter import _arrange_pieces_for_export, _piece_bounds, normalize_pieces


def test_pantalon_basico_front_and_back_are_visually_separated_after_layout() -> None:
    generation = generate_pattern(
        PatternGenerationRequest(
            garment_code="pantalon_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        )
    )
    pieces = normalize_pieces(generation.pieces)

    # The raw MVP draft starts both pieces from the same local origin.
    raw_front = _piece_bounds(pieces[0])
    raw_back = _piece_bounds(pieces[1])
    assert raw_front[0] == raw_back[0]

    _arrange_pieces_for_export(pieces)

    front = _piece_bounds(pieces[0])
    back = _piece_bounds(pieces[1])

    assert front[2] < back[0]
    assert back[0] - front[2] >= 10


def test_layout_translation_preserves_piece_widths() -> None:
    generation = generate_pattern(
        PatternGenerationRequest(
            garment_code="pantalon_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        )
    )
    pieces = normalize_pieces(generation.pieces)
    raw_widths = [bounds[2] - bounds[0] for bounds in map(_piece_bounds, pieces)]

    _arrange_pieces_for_export(pieces)
    arranged_widths = [bounds[2] - bounds[0] for bounds in map(_piece_bounds, pieces)]

    assert arranged_widths == raw_widths
PY

cat > docs/55_Fix_Fase_40_1_Layout_Piezas_Independientes.md <<'MD'
# Fix Fase 40.1 - Layout independiente por pieza

Fecha: 2026-07-05

## Problema

En `pantalon_basico`, el delantero y el posterior se generan desde el mismo origen local. Eso es aceptable como geometria interna MVP, pero en PDF/SVG de producto las piezas quedaban superpuestas. Como consecuencia:

- Parecia que faltaba el patron posterior.
- Las cotas de delantero y posterior se solapaban.
- Los titulos de las piezas quedaban montados.

## Solucion

Se agrega una etapa de layout visual en `engine/generation/exporter.py` antes de adjuntar cotas y antes de llamar a los writers PDF/SVG.

La etapa:

- Calcula el bounding box de cada pieza.
- Traslada cada pieza a una lane horizontal independiente.
- Preserva las medidas geometricas porque solo aplica traslacion, no escalado.
- Calcula cotas despues del layout, para que cada pieza tenga sus propias cotas en su propio bloque visual.

## Archivos

```text
engine/generation/exporter.py
tests/test_fase_40_1_layout_piezas_independientes.py
docs/55_Fix_Fase_40_1_Layout_Piezas_Independientes.md
```

## Criterio de aceptacion

`pantalon_basico` debe mostrar delantero y posterior separados visualmente, sin cotas montadas entre piezas.
MD

python3 - <<'PY'
from pathlib import Path

makefile = Path("Makefile")
text = makefile.read_text(encoding="utf-8")

old = "tests/test_fase_40_1_cotas_visuales_universales.py -q"
new = "tests/test_fase_40_1_cotas_visuales_universales.py tests/test_fase_40_1_layout_piezas_independientes.py -q"
if old in text and "test_fase_40_1_layout_piezas_independientes.py" not in text:
    text = text.replace(old, new, 1)
elif "validate-fase-40:" not in text:
    raise SystemExit("ERROR: Makefile no contiene validate-fase-40")

makefile.write_text(text, encoding="utf-8")
PY

echo "== Validacion puntual layout pantalon =="
.venv/bin/python - <<'PY'
from engine.generation import PatternGenerationRequest, generate_pattern
from engine.generation.exporter import _arrange_pieces_for_export, _piece_bounds, normalize_pieces

result = generate_pattern(
    PatternGenerationRequest(
        garment_code="pantalon_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )
)
pieces = normalize_pieces(result.pieces)
_arrange_pieces_for_export(pieces)
front = _piece_bounds(pieces[0])
back = _piece_bounds(pieces[1])
assert front[2] < back[0], (front, back)
print("LAYOUT_PIEZAS_INDEPENDIENTES_OK")
PY

echo "== Validaciones Fase 40.1 =="
make validate-fase-40

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix Fase 40.1 layout aplicado correctamente =="
