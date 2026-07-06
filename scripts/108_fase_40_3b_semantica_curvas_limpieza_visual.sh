#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 40.3B: semantica de curvas concavas/convexas/mixtas + limpieza visual =="
echo "== Rol operativo =="
echo "Arquitecto/consultor tecnico del producto + experto en patronaje."
echo "Criterio: una curva estructural debe tener intencion patronistica, no ser solo decoracion visual."

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
"""Structural pattern curves with patronage semantics.

Structural curves are contour-level export geometry. They can replace straight
segments and are not guide overlays.

Patronage distinction used by Fase 40.3B:
- convex: curve projects outward from the body or piece reference axis.
- concave: curve enters inward toward the body/garment cavity.
- mixed: curve combines concave and convex behavior in one transition.

This is still MVP structural geometry, not an industrial drafting method.
"""

from __future__ import annotations

from dataclasses import dataclass
from math import hypot
from typing import Any, Literal

from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece

CurveCurvature = Literal["concave", "convex", "mixed"]
CurveIntent = Literal[
    "hip_curve",
    "crotch_curve",
    "inseam_curve",
    "hem_curve",
    "leg_opening_curve",
]


@dataclass(frozen=True)
class StructuralCurve:
    """Bezier curve intended to be part of the pattern contour."""

    label: str
    start: Point
    control1: Point
    control2: Point
    end: Point
    intent: CurveIntent
    curvature: CurveCurvature
    replaces_segment: bool = True
    kind: str = "structural_curve"
    curve_type: str = "cubic_bezier"
    mvp_status: str = "mvp_structural_not_industrial"
    patronage_note: str = ""


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
        "curve_type": curve.curve_type,
        "intent": curve.intent,
        "curvature": curve.curvature,
        "replaces_segment": curve.replaces_segment,
        "mvp_status": curve.mvp_status,
        "patronage_note": curve.patronage_note,
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
                intent="hip_curve",
                curvature="convex",
                patronage_note="Curva convexa de cadera: proyecta volumen hacia el costado.",
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
                intent="hem_curve",
                curvature="convex",
                patronage_note="Curva convexa de nivelacion de bajo para lectura visual MVP.",
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
            intent="crotch_curve",
            curvature="concave",
            patronage_note="Curva concava de tiro MVP; pendiente diferenciacion real delantero/posterior.",
        ),
        StructuralCurve(
            label="Curva estructural de entrepierna",
            start=crotch_or_hip,
            control1=Point(crotch_or_hip.x - 0.6, crotch_or_hip.y + height * 0.12),
            control2=Point(bottom_right.x + 0.8, bottom_right.y - height * 0.25),
            end=bottom_right,
            intent="inseam_curve",
            curvature="mixed",
            patronage_note="Transicion mixta de entrepierna MVP; no sustituye metodo industrial.",
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
                intent="crotch_curve",
                curvature="concave",
                patronage_note="Curva concava de tiro/entrepierna MVP; pendiente patron industrial de short.",
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
                intent="leg_opening_curve",
                curvature="convex",
                patronage_note="Curva convexa MVP de boca de pierna; pendiente caida/inclinacion industrial.",
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
            # Fase 40.3B: structural curves are the source of truth; visual overlays
            # must not coexist for the same piece because they confuse print output.
            piece.metadata.pop("visual_curves", None)


def suppress_visual_curves_when_structural(pieces: list[PatternPiece]) -> None:
    """Remove guide overlays when structural contour curves are present."""

    for piece in pieces:
        if (piece.metadata or {}).get("structural_curves"):
            piece.metadata.pop("visual_curves", None)


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

if "suppress_visual_curves_when_structural" not in text.split("from engine.generation.pattern_generator", 1)[0]:
    text = text.replace(
        "from engine.exports.structural_curves import attach_structural_curves\n",
        "from engine.exports.structural_curves import attach_structural_curves, suppress_visual_curves_when_structural\n",
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

if "attach_visual_curves(pieces, generation_result.garment_code)" in text and "suppress_visual_curves_when_structural(pieces)" not in text:
    text = text.replace(
        "    attach_visual_curves(pieces, generation_result.garment_code)\n",
        "    attach_visual_curves(pieces, generation_result.garment_code)\n    suppress_visual_curves_when_structural(pieces)\n",
        1,
    )
elif "attach_visual_curves(pieces, generation_result.garment_code)" not in text and "suppress_visual_curves_when_structural(pieces)" not in text:
    text = text.replace(
        "    attach_structural_curves(pieces, generation_result.garment_code)\n",
        "    attach_structural_curves(pieces, generation_result.garment_code)\n    suppress_visual_curves_when_structural(pieces)\n",
        1,
    )

path.write_text(text, encoding="utf-8")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/exports/visual_curves.py")
if path.exists():
    text = path.read_text(encoding="utf-8")
    old = '''def attach_visual_curves(pieces: list[PatternPiece], garment_code: str) -> None:\n    for piece in pieces:\n        curves = build_piece_visual_curves(piece, garment_code)\n        if curves:\n            piece.metadata["visual_curves"] = _curve_metadata(curves)\n            piece.metadata["curve_status"] = "mvp_visual_not_industrial"\n'''
    new = '''def attach_visual_curves(pieces: list[PatternPiece], garment_code: str) -> None:\n    for piece in pieces:\n        # Fase 40.3B: if structural curves exist, they are contour geometry.\n        # Do not add dashed visual overlays for the same piece.\n        if (piece.metadata or {}).get("structural_curves"):\n            piece.metadata.pop("visual_curves", None)\n            continue\n\n        curves = build_piece_visual_curves(piece, garment_code)\n        if curves:\n            piece.metadata["visual_curves"] = _curve_metadata(curves)\n            piece.metadata["curve_status"] = "mvp_visual_not_industrial"\n'''
    if old in text:
        text = text.replace(old, new, 1)
    elif 'piece.metadata["visual_curves"] = _curve_metadata(curves)' in text and 'if (piece.metadata or {}).get("structural_curves")' not in text:
        text = text.replace(
            "    for piece in pieces:\n",
            "    for piece in pieces:\n        if (piece.metadata or {}).get(\"structural_curves\"):\n            piece.metadata.pop(\"visual_curves\", None)\n            continue\n\n",
            1,
        )
    path.write_text(text, encoding="utf-8")
PY

cat > tests/test_fase_40_3b_curve_semantics.py <<'PY'
from __future__ import annotations

from engine.exports.structural_curves import attach_structural_curves
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.generation.exporter import normalize_pieces
from engine.generation.pattern_generator import generate_pattern


VALID_CURVATURES = {"concave", "convex", "mixed"}
VALID_INTENTS = {"hip_curve", "crotch_curve", "inseam_curve", "hem_curve", "leg_opening_curve"}


def _pieces_with_structural_curves(garment_code: str, measurements: dict[str, float], options: dict | None = None):
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options=options or {},
        )
    )
    pieces = normalize_pieces(result.pieces)
    attach_structural_curves(pieces, garment_code)
    return pieces


def _all_curves(pieces) -> list[dict]:
    curves: list[dict] = []
    for piece in pieces:
        curves.extend(piece.metadata.get("structural_curves", []))
    return curves


def test_all_structural_curves_have_patronage_semantics() -> None:
    cases = [
        ("falda_basica", {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2}, {"full_pattern": True}),
        ("falda_evase", {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12}, None),
        ("pantalon_basico", {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76}, None),
        ("short_basico", {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20}, None),
    ]

    for garment_code, measurements, options in cases:
        curves = _all_curves(_pieces_with_structural_curves(garment_code, measurements, options))
        assert curves, garment_code
        for curve in curves:
            assert curve["kind"] == "structural_curve"
            assert curve["curve_type"] == "cubic_bezier"
            assert curve["curvature"] in VALID_CURVATURES
            assert curve["intent"] in VALID_INTENTS
            assert curve["replaces_segment"] is True
            assert curve["mvp_status"] == "mvp_structural_not_industrial"
            assert curve["patronage_note"]


def test_expected_curve_semantics_by_garment() -> None:
    falda = _all_curves(
        _pieces_with_structural_curves(
            "falda_basica",
            {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
            {"full_pattern": True},
        )
    )
    assert {curve["intent"] for curve in falda} == {"hip_curve"}
    assert {curve["curvature"] for curve in falda} == {"convex"}

    evase = _all_curves(
        _pieces_with_structural_curves(
            "falda_evase",
            {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        )
    )
    assert {curve["intent"] for curve in evase} == {"hem_curve"}
    assert {curve["curvature"] for curve in evase} == {"convex"}

    pantalon = _all_curves(
        _pieces_with_structural_curves(
            "pantalon_basico",
            {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        )
    )
    assert "crotch_curve" in {curve["intent"] for curve in pantalon}
    assert "inseam_curve" in {curve["intent"] for curve in pantalon}
    assert "concave" in {curve["curvature"] for curve in pantalon}
    assert "mixed" in {curve["curvature"] for curve in pantalon}

    short = _all_curves(
        _pieces_with_structural_curves(
            "short_basico",
            {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        )
    )
    assert "crotch_curve" in {curve["intent"] for curve in short}
    assert "leg_opening_curve" in {curve["intent"] for curve in short}
    assert "concave" in {curve["curvature"] for curve in short}
    assert "convex" in {curve["curvature"] for curve in short}


def test_structural_curves_suppress_visual_overlays_in_metadata() -> None:
    pieces = _pieces_with_structural_curves(
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )
    for piece in pieces:
        if piece.metadata.get("structural_curves"):
            assert "visual_curves" not in piece.metadata


def test_export_svg_has_structural_semantics_without_dashed_visual_curves(tmp_path) -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="short_basico",
                measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
            ),
            output_name="short_basico_fase_40_3b_semantica",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    content = result.svg_path.read_text(encoding="utf-8")
    assert 'class="structural-curve"' in content
    assert "Curva estructural tiro/entrepierna" in content
    assert "Boca de pierna curva MVP" in content
    assert 'stroke-dasharray="6 3"' not in content
PY

cat > docs/60_Fase_40_3B_Semantica_Curvas_Estructurales.md <<'MD'
# Fase 40.3B — Semantica de curvas estructurales

## Objetivo

Convertir las curvas estructurales del contorno en entidades con semantica de patronaje, no solo en trazos Bezier dibujados sobre el patron.

La fase corrige dos problemas detectados en la validacion visual de Fase 40.3A:

1. Seguian apareciendo curvas visuales punteadas junto con curvas estructurales solidas.
2. Las curvas no declaraban si su comportamiento era concavo, convexo o mixto.

## Regla de producto

Cuando una pieza tiene `structural_curves`, esas curvas son la fuente visual principal del contorno. No deben coexistir `visual_curves` punteadas para la misma pieza.

## Semantica agregada

Cada curva estructural incluye:

- `kind`: `structural_curve`
- `curve_type`: `cubic_bezier`
- `intent`: intencion patronistica
- `curvature`: `concave`, `convex` o `mixed`
- `replaces_segment`: indica si reemplaza un segmento recto
- `mvp_status`: estado honesto del nivel de patronaje
- `patronage_note`: nota tecnica de patronaje

## Clasificacion actual

| Prenda | Curva | Intent | Curvature | Estado |
|---|---|---|---|---|
| falda_basica | Costado curvo de cadera | hip_curve | convex | MVP estructural |
| falda_evase | Bajo curvo corregido | hem_curve | convex | MVP estructural |
| pantalon_basico | Curva estructural de tiro | crotch_curve | concave | MVP experimental |
| pantalon_basico | Curva estructural de entrepierna | inseam_curve | mixed | MVP experimental |
| short_basico | Curva estructural tiro/entrepierna | crotch_curve | concave | MVP experimental |
| short_basico | Boca de pierna curva MVP | leg_opening_curve | convex | MVP experimental |

## Advertencia tecnica

La clasificacion concava/convexa/mixta es semantica inicial. No convierte automaticamente pantalon y short en patrones industriales.

Pendientes industriales:

- Gancho delantero y posterior formal.
- Altura de tiro real.
- Entrepierna con metodo de patronaje.
- Diferenciacion delantero/posterior.
- Piquetes, hilo de tela, aplomo, margen y reglas de costura finales.

## Validacion

```bash
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness
```

Criterio de cierre visual posterior:

- Una sola curva visible por tramo.
- Sin curva punteada duplicada si hay curva estructural.
- Curvas con semantica patronistica declarada.
- SVG/PDF legibles para impresion.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-fase-40-3b:" not in text:
    text += """

validate-fase-40-3b:
	.venv/bin/python -m pytest tests/test_fase_40_3b_curve_semantics.py -q
"""

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion Fase 40.3B =="
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness

echo "== Estado Git despues del cambio =="
git status --short

echo "== Fase 40.3B aplicada =="
echo "Siguiente paso: reexportar desde GUI los 4 patrones y validar visualmente SVG/PDF."
