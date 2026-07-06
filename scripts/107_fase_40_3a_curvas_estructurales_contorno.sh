#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 40.3A: contrato de curvas estructurales del contorno =="
echo "== Rol operativo =="
echo "Arquitecto/consultor tecnico del producto + experto en patronaje."
echo "Criterio: pasar de curvas visuales superpuestas a curvas estructurales exportables."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el script para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del cambio =="
git status --short

mkdir -p engine/exports docs tests scripts

cat > engine/exports/structural_curves.py <<'PY'
"""Structural pattern curves for export.

This module is the first real step from visual curve overlays to contour-level
pattern curves. Structural curves are exported as final contour curves and can
replace straight line segments with matching endpoints in SVG/PDF output.

Important product/patronage distinction:
- visual_curves: guide/annotation overlays.
- structural_curves: intended pattern contour geometry for export.
"""

from __future__ import annotations

from dataclasses import dataclass
from math import hypot
from typing import Any

from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece


@dataclass(frozen=True)
class StructuralCurve:
    """Bezier curve intended to be part of the pattern contour."""

    label: str
    start: Point
    control1: Point
    control2: Point
    end: Point
    replaces_segment: bool = True
    kind: str = "structural_curve"


def point_from_any(value: Any) -> Point:
    """Normalize point-like input into a Point."""

    if isinstance(value, Point):
        return value

    if hasattr(value, "x") and hasattr(value, "y"):
        return Point(float(value.x), float(value.y))

    if isinstance(value, dict):
        if "x" in value and "y" in value:
            return Point(float(value["x"]), float(value["y"]))
        return Point(float(value[0]), float(value[1]))

    return Point(float(value[0]), float(value[1]))


def piece_points(piece: PatternPiece) -> dict[str, Point]:
    return {name: point_from_any(point) for name, point in piece.points.items()}


def _curve_payload(curve: StructuralCurve) -> dict[str, Any]:
    return {
        "label": curve.label,
        "kind": curve.kind,
        "replaces_segment": curve.replaces_segment,
        "start": {"x": curve.start.x, "y": curve.start.y},
        "control1": {"x": curve.control1.x, "y": curve.control1.y},
        "control2": {"x": curve.control2.x, "y": curve.control2.y},
        "end": {"x": curve.end.x, "y": curve.end.y},
    }


def curve_payloads(curves: list[StructuralCurve]) -> list[dict[str, Any]]:
    return [_curve_payload(curve) for curve in curves]


def _has(points: dict[str, Point], *names: str) -> bool:
    return all(name in points for name in names)


def _distance(a: Point, b: Point) -> float:
    return hypot(a.x - b.x, a.y - b.y)


def _basic_skirt_structural_curves(piece: PatternPiece) -> list[StructuralCurve]:
    points = piece_points(piece)
    curves: list[StructuralCurve] = []

    if _has(points, "B_cintura_costado", "D_cadera_costado"):
        start = points["B_cintura_costado"]
        end = points["D_cadera_costado"]
        dx = max((end.x - start.x) * 0.40, 0.8)
        curves.append(
            StructuralCurve(
                label="Costado curvo de cadera",
                start=start,
                control1=Point(start.x + dx, start.y + 5.0),
                control2=Point(end.x + 0.4, end.y - 5.0),
                end=end,
            )
        )

    return curves


def _evase_structural_curves(piece: PatternPiece) -> list[StructuralCurve]:
    points = piece_points(piece)
    curves: list[StructuralCurve] = []

    if _has(points, "D", "C"):
        start = points["D"]
        end = points["C"]
        width = max(abs(end.x - start.x), 1.0)
        depth = max(width * 0.025, 0.6)
        curves.append(
            StructuralCurve(
                label="Bajo curvo corregido",
                start=start,
                control1=Point(start.x + (end.x - start.x) * 0.33, start.y + depth),
                control2=Point(start.x + (end.x - start.x) * 0.66, start.y + depth),
                end=end,
            )
        )

    return curves


def _right_side_candidates(points: dict[str, Point]) -> tuple[Point, Point, Point] | None:
    if len(points) < 4:
        return None

    top_y = min(point.y for point in points.values())
    bottom_y = max(point.y for point in points.values())
    height = max(bottom_y - top_y, 1.0)

    rightmost = max(points.values(), key=lambda point: point.x)
    top_candidates = [point for point in points.values() if point.y <= top_y + height * 0.20]
    bottom_candidates = [point for point in points.values() if point.y >= top_y + height * 0.75]

    if not top_candidates or not bottom_candidates:
        return None

    top_right = max(top_candidates, key=lambda point: point.x)
    bottom_right = max(bottom_candidates, key=lambda point: point.x)
    return top_right, rightmost, bottom_right


def _pants_structural_curves(piece: PatternPiece) -> list[StructuralCurve]:
    points = piece_points(piece)
    candidates = _right_side_candidates(points)
    if candidates is None:
        return []

    top_right, crotch_or_hip, bottom_right = candidates
    height = max(bottom_right.y - top_right.y, 1.0)

    return [
        StructuralCurve(
            label="Curva estructural de tiro",
            start=top_right,
            control1=Point(crotch_or_hip.x + 1.6, top_right.y + height * 0.22),
            control2=Point(crotch_or_hip.x + 1.6, crotch_or_hip.y - height * 0.08),
            end=crotch_or_hip,
        ),
        StructuralCurve(
            label="Curva estructural de entrepierna",
            start=crotch_or_hip,
            control1=Point(crotch_or_hip.x - 0.6, crotch_or_hip.y + height * 0.12),
            control2=Point(bottom_right.x + 0.8, bottom_right.y - height * 0.25),
            end=bottom_right,
        ),
    ]


def _short_structural_curves(piece: PatternPiece) -> list[StructuralCurve]:
    points = piece_points(piece)
    curves: list[StructuralCurve] = []

    if _has(points, "B", "C"):
        start = points["B"]
        end = points["C"]
        height = max(end.y - start.y, 1.0)
        curves.append(
            StructuralCurve(
                label="Curva estructural tiro/entrepierna",
                start=start,
                control1=Point(start.x + 1.4, start.y + height * 0.32),
                control2=Point(end.x + 1.2, end.y - height * 0.24),
                end=end,
            )
        )

    if _has(points, "D", "C"):
        start = points["D"]
        end = points["C"]
        width = max(abs(end.x - start.x), 1.0)
        curves.append(
            StructuralCurve(
                label="Boca de pierna curva MVP",
                start=start,
                control1=Point(start.x + width * 0.33, start.y + 0.4),
                control2=Point(start.x + width * 0.66, start.y + 0.4),
                end=end,
            )
        )

    return curves


def build_piece_structural_curves(piece: PatternPiece, garment_code: str) -> list[StructuralCurve]:
    code = garment_code.strip().lower()

    if code == "falda_basica":
        return _basic_skirt_structural_curves(piece)

    if code == "falda_evase":
        return _evase_structural_curves(piece)

    if code == "pantalon_basico":
        return _pants_structural_curves(piece)

    if code == "short_basico":
        return _short_structural_curves(piece)

    return []


def attach_structural_curves(pieces: list[PatternPiece], garment_code: str) -> None:
    """Attach contour-level structural curves to export piece metadata."""

    for piece in pieces:
        curves = build_piece_structural_curves(piece, garment_code)
        if curves:
            piece.metadata["structural_curves"] = curve_payloads(curves)
            piece.metadata["curve_status"] = "mvp_structural_not_industrial"


def points_match(a: Any, b: Any, tolerance: float = 0.01) -> bool:
    return _distance(point_from_any(a), point_from_any(b)) <= tolerance


def line_is_replaced_by_structural_curve(line: Any, curves: list[dict[str, Any]], tolerance: float = 0.01) -> bool:
    """Return True if a straight line should be hidden in favor of a structural curve."""

    if not hasattr(line, "start") or not hasattr(line, "end"):
        return False

    for curve in curves:
        if not bool(curve.get("replaces_segment", True)):
            continue

        start = curve.get("start", {})
        end = curve.get("end", {})

        if points_match(line.start, start, tolerance) and points_match(line.end, end, tolerance):
            return True

        if points_match(line.start, end, tolerance) and points_match(line.end, start, tolerance):
            return True

    return False


def bezier_point(curve: dict[str, Any], t: float) -> Point:
    """Return a point on a cubic Bezier curve."""

    p0 = point_from_any(curve.get("start", {}))
    p1 = point_from_any(curve.get("control1", {}))
    p2 = point_from_any(curve.get("control2", {}))
    p3 = point_from_any(curve.get("end", {}))
    one = 1.0 - t

    x = (
        one * one * one * p0.x
        + 3 * one * one * t * p1.x
        + 3 * one * t * t * p2.x
        + t * t * t * p3.x
    )
    y = (
        one * one * one * p0.y
        + 3 * one * one * t * p1.y
        + 3 * one * t * t * p2.y
        + t * t * t * p3.y
    )
    return Point(x, y)


def curve_polyline_points(curve: dict[str, Any], segments: int = 16) -> list[Point]:
    return [bezier_point(curve, index / segments) for index in range(segments + 1)]
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/generation/exporter.py")
text = path.read_text(encoding="utf-8")

if "from engine.exports.structural_curves import attach_structural_curves" not in text:
    text = text.replace(
        "from engine.exports.svg.writer import export_svg\n",
        "from engine.exports.svg.writer import export_svg\nfrom engine.exports.structural_curves import attach_structural_curves\n",
        1,
    )

if "attach_structural_curves(pieces, generation_result.garment_code)" not in text:
    marker = "_attach_export_metadata(pieces, generation_result)\n"
    if marker not in text:
        raise SystemExit("ERROR: no se encontro _attach_export_metadata")
    text = text.replace(
        marker,
        marker + "    attach_structural_curves(pieces, generation_result.garment_code)\n",
        1,
    )

path.write_text(text, encoding="utf-8")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/exports/svg/writer.py")
text = path.read_text(encoding="utf-8")

if "from engine.exports.structural_curves import line_is_replaced_by_structural_curve" not in text:
    import_marker = "from engine.patterns.piece import PatternPiece\n"
    if import_marker not in text:
        raise SystemExit("ERROR: no se encontro import PatternPiece en SVG writer")
    text = text.replace(
        import_marker,
        import_marker + "from engine.exports.structural_curves import line_is_replaced_by_structural_curve\n",
        1,
    )

if "def _structural_curve_elements" not in text:
    curve_func = """
def _structural_curve_elements(tx: Any, ty: Any, curve: dict[str, Any]) -> list[str]:
    start = curve.get("start", {})
    control1 = curve.get("control1", {})
    control2 = curve.get("control2", {})
    end = curve.get("end", {})
    label = escape(str(curve.get("label", "") or ""))

    x1 = tx(float(start.get("x", 0.0)))
    y1 = ty(float(start.get("y", 0.0)))
    cx1 = tx(float(control1.get("x", 0.0)))
    cy1 = ty(float(control1.get("y", 0.0)))
    cx2 = tx(float(control2.get("x", 0.0)))
    cy2 = ty(float(control2.get("y", 0.0)))
    x2 = tx(float(end.get("x", 0.0)))
    y2 = ty(float(end.get("y", 0.0)))
    label_x = (x1 + x2) / 2 + 4
    label_y = (y1 + y2) / 2 - 4

    return [
        (
            f'<path class="structural-curve" d="M {x1:.2f} {y1:.2f} '
            f'C {cx1:.2f} {cy1:.2f}, {cx2:.2f} {cy2:.2f}, {x2:.2f} {y2:.2f}" '
            f'stroke="black" fill="none" stroke-width="2.2"/>'
        ),
        f'<text x="{label_x:.2f}" y="{label_y:.2f}" font-size="10" fill="black">{label}</text>',
    ]


"""
    marker = "def _curve_elements"
    if marker in text:
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]
    else:
        marker = "def export_svg"
        if marker not in text:
            raise SystemExit("ERROR: no se encontro export_svg en SVG writer")
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]

old = """        for line in piece.lines:
            dash = _dash(line)
            stroke_width = "2" if line.kind == "pattern" else "1.5"
            lines.append(
                f'<line x1="{tx(float(line.start.x)):.2f}" y1="{ty(float(line.start.y)):.2f}" '
                f'x2="{tx(float(line.end.x)):.2f}" y2="{ty(float(line.end.y)):.2f}" '
                f'stroke="black" fill="none" stroke-width="{stroke_width}"{dash}/>'
            )
"""

new = """        structural_curves = (piece.metadata or {}).get("structural_curves", [])
        for line in piece.lines:
            if line_is_replaced_by_structural_curve(line, structural_curves):
                continue

            dash = _dash(line)
            stroke_width = "2" if line.kind == "pattern" else "1.5"
            lines.append(
                f'<line x1="{tx(float(line.start.x)):.2f}" y1="{ty(float(line.start.y)):.2f}" '
                f'x2="{tx(float(line.end.x)):.2f}" y2="{ty(float(line.end.y)):.2f}" '
                f'stroke="black" fill="none" stroke-width="{stroke_width}"{dash}/>'
            )

        for curve in structural_curves:
            lines.extend(_structural_curve_elements(tx, ty, curve))
"""

if old in text:
    text = text.replace(old, new, 1)
elif "line_is_replaced_by_structural_curve(line, structural_curves)" not in text:
    raise SystemExit("ERROR: no se pudo parchear loop de lineas SVG; requiere revision manual")

path.write_text(text, encoding="utf-8")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/exports/pdf/writer.py")
text = path.read_text(encoding="utf-8")

if "from engine.exports.structural_curves import line_is_replaced_by_structural_curve" not in text:
    import_marker = "from engine.patterns.piece import PatternPiece\n"
    if import_marker not in text:
        raise SystemExit("ERROR: no se encontro import PatternPiece en PDF writer")
    text = text.replace(
        import_marker,
        import_marker + "from engine.exports.structural_curves import line_is_replaced_by_structural_curve\n",
        1,
    )

if "def _draw_structural_curve" not in text:
    curve_func = """
def _draw_structural_curve(canvas: Any, tx: Any, ty: Any, curve: dict[str, Any]) -> None:
    start = curve.get("start", {})
    control1 = curve.get("control1", {})
    control2 = curve.get("control2", {})
    end = curve.get("end", {})
    label = str(curve.get("label", "") or "")

    x1 = tx(float(start.get("x", 0.0)))
    y1 = ty(float(start.get("y", 0.0)))
    cx1 = tx(float(control1.get("x", 0.0)))
    cy1 = ty(float(control1.get("y", 0.0)))
    cx2 = tx(float(control2.get("x", 0.0)))
    cy2 = ty(float(control2.get("y", 0.0)))
    x2 = tx(float(end.get("x", 0.0)))
    y2 = ty(float(end.get("y", 0.0)))

    path = canvas.beginPath()
    path.moveTo(x1, y1)
    path.curveTo(cx1, cy1, cx2, cy2, x2, y2)

    canvas.setDash()
    canvas.setLineWidth(1.1)
    canvas.drawPath(path, stroke=1, fill=0)

    canvas.setFont("Helvetica", 6.5)
    canvas.drawString((x1 + x2) / 2 + 3, (y1 + y2) / 2 + 3, label)


"""
    marker = "def _draw_curve"
    if marker in text:
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]
    else:
        marker = "def export_pdf"
        if marker not in text:
            raise SystemExit("ERROR: no se encontro export_pdf en PDF writer")
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]

old = """        for line in piece.lines:
            x1 = tx(float(line.start.x))
            y1 = ty(float(line.start.y))
            x2 = tx(float(line.end.x))
            y2 = ty(float(line.end.y))
            if line.kind == "seam_allowance":
                c.setDash(4, 3)
                c.setLineWidth(0.7)
            elif line.kind == "helper":
                c.setDash(2, 3)
                c.setLineWidth(0.6)
            else:
                c.setDash()
                c.setLineWidth(1.0)
            c.line(x1, y1, x2, y2)
"""

new = """        structural_curves = (piece.metadata or {}).get("structural_curves", [])
        for line in piece.lines:
            if line_is_replaced_by_structural_curve(line, structural_curves):
                continue

            x1 = tx(float(line.start.x))
            y1 = ty(float(line.start.y))
            x2 = tx(float(line.end.x))
            y2 = ty(float(line.end.y))
            if line.kind == "seam_allowance":
                c.setDash(4, 3)
                c.setLineWidth(0.7)
            elif line.kind == "helper":
                c.setDash(2, 3)
                c.setLineWidth(0.6)
            else:
                c.setDash()
                c.setLineWidth(1.0)
            c.line(x1, y1, x2, y2)

        for curve in structural_curves:
            _draw_structural_curve(c, tx, ty, curve)
"""

if old in text:
    text = text.replace(old, new, 1)
elif "line_is_replaced_by_structural_curve(line, structural_curves)" not in text:
    raise SystemExit("ERROR: no se pudo parchear loop de lineas PDF; requiere revision manual")

path.write_text(text, encoding="utf-8")
PY

cat > tests/test_fase_40_3_structural_curves.py <<'PY'
from __future__ import annotations

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.generation.exporter import normalize_pieces
from engine.generation.pattern_generator import generate_pattern
from engine.exports.structural_curves import attach_structural_curves, line_is_replaced_by_structural_curve


def _export_svg_text(tmp_path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_structural_curves_test",
            output_dir=tmp_path / garment_code,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def test_falda_basica_exports_structural_hip_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )

    assert 'class="structural-curve"' in content
    assert "Costado curvo de cadera" in content


def test_falda_evase_exports_structural_curved_hem(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert 'class="structural-curve"' in content
    assert "Bajo curvo corregido" in content


def test_pantalon_basico_exports_structural_crotch_and_inseam_curves(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert 'class="structural-curve"' in content
    assert "Curva estructural de tiro" in content
    assert "Curva estructural de entrepierna" in content


def test_short_basico_exports_structural_crotch_and_leg_opening_curves(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert 'class="structural-curve"' in content
    assert "Curva estructural tiro/entrepierna" in content
    assert "Boca de pierna curva MVP" in content


def test_structural_curve_replaces_matching_straight_segment_for_falda_basica() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
            options={"full_pattern": True},
        )
    )
    pieces = normalize_pieces(result.pieces)
    attach_structural_curves(pieces, "falda_basica")
    piece = pieces[0]
    curves = piece.metadata["structural_curves"]

    replaced = [
        line
        for line in piece.lines
        if line_is_replaced_by_structural_curve(line, curves)
    ]

    assert replaced
PY

cat > docs/59_Fase_40_3_Curvas_Estructurales_Contorno.md <<'MD'
# Fase 40.3A - Curvas estructurales del contorno

Fecha: 2026-07-05

## Roles obligatorios del asistente en este proyecto

### Rol 1 - Arquitecto / consultor tecnico del producto

Responsabilidad:

- Validar si lo generado sirve realmente para usuario final.
- No cerrar fases solo porque los tests pasan.
- Detectar inconsistencias funcionales, visuales, tecnicas y de flujo antes de cerrar una fase.

### Rol 2 - Experto en patronaje

Responsabilidad:

- Validar que los patrones generados tengan sentido tecnico de patronaje.
- Revisar piezas necesarias, proporciones, medidas de entrada vs cotas reales, curvas y usabilidad.
- Diferenciar MVP geometrico de patron industrial.

## Cambio de enfoque

La Fase 40.2 agrego curvas visuales superpuestas. La Fase 40.3A empieza el cambio hacia curvas estructurales:

```text
De curvas visuales superpuestas
a curvas estructurales del contorno del patron.
```

## Alcance aplicado

- Se agrega `engine/exports/structural_curves.py`.
- Se adjuntan curvas estructurales en metadata exportable.
- SVG/PDF dibujan curvas estructurales con trazo de contorno.
- SVG/PDF ocultan el segmento recto cuando una curva estructural tiene los mismos extremos.
- Se agregan tests de exportacion SVG y reemplazo de segmentos rectos.

## Curvas iniciales

- `falda_basica`: costado curvo de cadera.
- `falda_evase`: bajo curvo corregido.
- `pantalon_basico`: curva estructural de tiro y curva estructural de entrepierna MVP.
- `short_basico`: curva estructural tiro/entrepierna y boca de pierna curva MVP.

## Advertencia de patronaje

Esta fase empieza a convertir curvas en contorno, pero todavia no representa patronaje industrial completo para pantalon y short.

Pendientes:

- Pantalon: gancho delantero/posterior real, altura de tiro, rodilla, bota y aplomo.
- Short: tiro delantero/posterior, gancho real, boca de pierna y curva de entrepierna.
- Falda basica: diferenciacion de pinzas delantero/posterior.
- Falda evase: ajuste de caida y nivelacion de bajo.

## Criterio de aceptacion

```bash
make validate-fase-40-3
```

Debe validar:

- Curvas estructurales exportadas en SVG.
- Segmentos rectos reemplazados cuando corresponde.
- Completitud de piezas sigue OK.
- Fase 40.2 sigue OK.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-fase-40-3:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += "\nvalidate-fase-40-3:\n"
    text += "\t.venv/bin/python -m pytest tests/test_fase_40_3_structural_curves.py -q\n"
    text += "\t.venv/bin/python -m pytest tests/test_fase_40_2_visual_curves.py -q\n"
    text += "\t.venv/bin/python scripts/validate_piece_completeness.py\n"

if ".PHONY:" in text:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith(".PHONY:") and "validate-fase-40-3" not in line:
            lines[i] = line + " validate-fase-40-3"
            break
    text = "\n".join(lines) + "\n"

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion Fase 40.3 =="
make validate-fase-40-3

echo "== Validacion Fase 40.2 sigue OK =="
make validate-fase-40-2

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del cambio =="
git status --short

echo "== Fase 40.3A aplicada correctamente =="
