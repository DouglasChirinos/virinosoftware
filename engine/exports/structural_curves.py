"""Structural pattern curves with patronage semantics.

Structural curves are contour-level export geometry. They can replace straight
segments and are not guide overlays.

Patronage distinction used by Fase 40.3B/40.3C:
- convex: curve projects outward from the body or piece reference axis.
- concave: curve enters inward toward the body/garment cavity.
- mixed: curve combines concave and convex behavior in one transition.

Fase 40.3C adds concavity_direction because "concave" alone is not enough for
pattern drafting. A crotch curve must be concave and must enter inward.

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
CurveConcavityDirection = Literal[
    "inward",
    "inward_deeper",
    "outward",
    "mixed_transition",
    "none",
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
    concavity_direction: CurveConcavityDirection = "none"
    extension_formula: str = ""
    extension_cm: float = 0.0
    extension_range_cm: tuple[float, float] = (0.0, 0.0)
    measurement_basis: str = ""
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
        "concavity_direction": curve.concavity_direction,
        "extension_formula": curve.extension_formula,
        "extension_cm": round(float(curve.extension_cm), 4),
        "extension_range_cm": [round(float(curve.extension_range_cm[0]), 4), round(float(curve.extension_range_cm[1]), 4)],
        "measurement_basis": curve.measurement_basis,
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


def _is_posterior_piece(piece: PatternPiece) -> bool:
    text = f"{getattr(piece, 'name', '')} {getattr(piece, 'label', '')}".lower()
    return "posterior" in text or "trasero" in text or "back" in text


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
                concavity_direction="outward",
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
                concavity_direction="outward",
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


def _inward_control_x(start: Point, end: Point, depth: float) -> float:
    """Return an x coordinate that pulls a right-side curve inward.

    Current lower-body MVP pieces place the crotch/inside transition on the
    right side of the drawing. Inward means moving the Bezier controls to the
    left of the start/end chord, not farther right.
    """

    return min(start.x, end.x) - depth




def _measurement_float(piece: PatternPiece, name: str) -> float | None:
    """Read a numeric measurement from piece metadata when exporter attached it."""

    measurements = (piece.metadata or {}).get("measurements", {})
    if not isinstance(measurements, dict):
        return None

    raw = measurements.get(name)
    if raw is None:
        return None

    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def _estimated_total_hip_cm(piece: PatternPiece, piece_width: float) -> float:
    """Return total hip used as base for crotch extension.

    Preference order:
    1. Real hip measurement attached by exporter.
    2. Conservative approximation from current piece width.

    The fallback keeps tests usable when structural curves are attached directly
    outside the exporter pipeline.
    """

    hip = _measurement_float(piece, "hip")
    if hip and hip > 0:
        return hip

    # Current MVP lower-body pieces represent roughly a quarter hip width.
    return max(piece_width * 4.0, 1.0)


def _crotch_extension_range_cm(total_hip_cm: float, posterior: bool) -> tuple[float, float]:
    """Industrial MVP range for crotch extension based on full hip circumference.

    Front crotch extension: 1/20..1/16 of full hip.
    Back crotch extension: 1/8..1/6 of full hip.
    """

    if posterior:
        return (total_hip_cm / 8.0, total_hip_cm / 6.0)
    return (total_hip_cm / 20.0, total_hip_cm / 16.0)


def _crotch_extension_formula(posterior: bool) -> str:
    return "hip/8..hip/6" if posterior else "hip/20..hip/16"


def _crotch_extension_depth_cm(piece: PatternPiece, piece_width: float, posterior: bool) -> tuple[float, tuple[float, float], str, str]:
    """Return working crotch extension depth and its formula metadata.

    The chosen working value is the midpoint of the industrial MVP range.
    It is still MVP because the current pants/short geometry does not yet have
    a full industrial crotch baseline, knee line, grainline, or notch system.
    """

    total_hip = _estimated_total_hip_cm(piece, piece_width)
    range_cm = _crotch_extension_range_cm(total_hip, posterior)
    depth = (range_cm[0] + range_cm[1]) / 2.0
    formula = _crotch_extension_formula(posterior)
    basis = f"hip={total_hip:.2f}cm"
    return depth, range_cm, formula, basis


def _pants_structural_curves(piece: PatternPiece) -> list[StructuralCurve]:
    points = piece_points(piece)
    candidates = _right_side_candidates(points)
    if candidates is None:
        return []

    top_right, crotch_or_hip, bottom_right = candidates
    height = max(bottom_right.y - top_right.y, 1.0)
    piece_width = max((point.x for point in points.values()), default=1.0) - min(
        (point.x for point in points.values()), default=0.0
    )
    posterior = _is_posterior_piece(piece)

    inward_depth, extension_range, extension_formula, measurement_basis = _crotch_extension_depth_cm(
        piece, piece_width, posterior
    )
    concavity_direction: CurveConcavityDirection = "inward_deeper" if posterior else "inward"
    crotch_note = (
        "Curva concava de tiro posterior MVP: entra hacia dentro con mayor profundidad; "
        "pendiente metodo industrial de gancho posterior."
        if posterior
        else "Curva concava de tiro delantero MVP: entra hacia dentro con extension de tiro menor; pendiente metodo industrial de gancho delantero."
    )
    inward_x = _inward_control_x(top_right, crotch_or_hip, inward_depth)

    return [
        StructuralCurve(
            label="Curva estructural de tiro",
            start=top_right,
            control1=Point(inward_x, top_right.y + height * 0.20),
            control2=Point(inward_x, crotch_or_hip.y - height * 0.08),
            end=crotch_or_hip,
            intent="crotch_curve",
            curvature="concave",
            concavity_direction=concavity_direction,
            extension_formula=extension_formula,
            extension_cm=inward_depth,
            extension_range_cm=extension_range,
            measurement_basis=measurement_basis,
            patronage_note=crotch_note,
        ),
        StructuralCurve(
            label="Curva estructural de entrepierna",
            start=crotch_or_hip,
            control1=Point(crotch_or_hip.x - max(piece_width * 0.05, 0.6), crotch_or_hip.y + height * 0.12),
            control2=Point(bottom_right.x + max(piece_width * 0.03, 0.4), bottom_right.y - height * 0.25),
            end=bottom_right,
            intent="inseam_curve",
            curvature="mixed",
            concavity_direction="mixed_transition",
            patronage_note="Transicion mixta de entrepierna MVP; no sustituye metodo industrial.",
        ),
    ]


def _short_structural_curves(piece: PatternPiece) -> list[StructuralCurve]:
    points = piece_points(piece)
    curves: list[StructuralCurve] = []
    posterior = _is_posterior_piece(piece)

    if _has(points, "B", "C"):
        start = points["B"]
        end = points["C"]
        height = max(end.y - start.y, 1.0)
        piece_width = max((point.x for point in points.values()), default=1.0) - min(
            (point.x for point in points.values()), default=0.0
        )
        inward_depth, extension_range, extension_formula, measurement_basis = _crotch_extension_depth_cm(
            piece, piece_width, posterior
        )
        inward_x = _inward_control_x(start, end, inward_depth)
        concavity_direction: CurveConcavityDirection = "inward_deeper" if posterior else "inward"
        curves.append(
            StructuralCurve(
                label="Curva estructural tiro/entrepierna",
                start=start,
                control1=Point(inward_x, start.y + height * 0.32),
                control2=Point(inward_x, end.y - height * 0.24),
                end=end,
                intent="crotch_curve",
                curvature="concave",
                concavity_direction=concavity_direction,
                extension_formula=extension_formula,
                extension_cm=inward_depth,
                extension_range_cm=extension_range,
                measurement_basis=measurement_basis,
                patronage_note=(
                    "Curva concava posterior de tiro/entrepierna MVP: entra hacia dentro con extension de tiro mayor; pendiente patron industrial de short."
                    if posterior
                    else "Curva concava delantera de tiro/entrepierna MVP: entra hacia dentro con extension de tiro menor; pendiente patron industrial de short."
                ),
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
                concavity_direction="outward",
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
            # Structural curves are the source of truth; visual overlays must
            # not coexist for the same piece because they confuse print output.
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
