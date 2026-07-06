from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece


@dataclass(frozen=True)
class VisualCurve:
    label: str
    start: Point
    control1: Point
    control2: Point
    end: Point
    kind: str = "visual_curve"


def _point_from_any(value: Any) -> Point:
    if isinstance(value, Point):
        return value
    if hasattr(value, "x") and hasattr(value, "y"):
        return Point(float(value.x), float(value.y))
    if isinstance(value, dict):
        if "x" in value and "y" in value:
            return Point(float(value["x"]), float(value["y"]))
        return Point(float(value[0]), float(value[1]))
    return Point(float(value[0]), float(value[1]))


def _piece_points(piece: PatternPiece) -> dict[str, Point]:
    return {name: _point_from_any(point) for name, point in piece.points.items()}


def _curve_metadata(curves: list[VisualCurve]) -> list[dict[str, Any]]:
    payload: list[dict[str, Any]] = []
    for curve in curves:
        payload.append(
            {
                "label": curve.label,
                "kind": curve.kind,
                "start": {"x": curve.start.x, "y": curve.start.y},
                "control1": {"x": curve.control1.x, "y": curve.control1.y},
                "control2": {"x": curve.control2.x, "y": curve.control2.y},
                "end": {"x": curve.end.x, "y": curve.end.y},
            }
        )
    return payload


def _has(points: dict[str, Point], *names: str) -> bool:
    return all(name in points for name in names)


def _basic_skirt_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if not _has(points, "B_cintura_costado", "D_cadera_costado"):
        return []
    start = points["B_cintura_costado"]
    end = points["D_cadera_costado"]
    dx = max((end.x - start.x) * 0.35, 0.8)
    return [
        VisualCurve(
            label="Curva cadera costado",
            start=start,
            control1=Point(start.x + dx, start.y + 6.0),
            control2=Point(end.x, end.y - 6.0),
            end=end,
        )
    ]


def _evase_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if not _has(points, "D", "C"):
        return []
    start = points["D"]
    end = points["C"]
    depth = max(abs(end.x - start.x) * 0.03, 0.8)
    return [
        VisualCurve(
            label="Correccion suave de bajo",
            start=start,
            control1=Point(start.x + (end.x - start.x) * 0.33, start.y + depth),
            control2=Point(start.x + (end.x - start.x) * 0.66, start.y + depth),
            end=end,
        )
    ]


def _pants_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if len(points) < 4:
        return []

    top_y = min(point.y for point in points.values())
    bottom_y = max(point.y for point in points.values())
    height = max(bottom_y - top_y, 1.0)
    rightmost = max(points.values(), key=lambda point: point.x)
    top_right_candidates = [point for point in points.values() if point.y <= top_y + height * 0.20]
    bottom_right_candidates = [point for point in points.values() if point.y >= top_y + height * 0.75]

    if not top_right_candidates or not bottom_right_candidates:
        return []

    top_right = max(top_right_candidates, key=lambda point: point.x)
    bottom_right = max(bottom_right_candidates, key=lambda point: point.x)
    return [
        VisualCurve(
            label="Curva tiro/costado MVP",
            start=top_right,
            control1=Point(rightmost.x + 1.8, top_right.y + height * 0.25),
            control2=Point(rightmost.x + 1.8, rightmost.y + height * 0.10),
            end=rightmost,
        ),
        VisualCurve(
            label="Curva entrepierna MVP",
            start=rightmost,
            control1=Point(rightmost.x - 1.0, rightmost.y + height * 0.15),
            control2=Point(bottom_right.x + 0.8, bottom_right.y - height * 0.20),
            end=bottom_right,
        ),
    ]


def _short_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if not _has(points, "B", "C"):
        return []
    start = points["B"]
    end = points["C"]
    height = max(end.y - start.y, 1.0)
    return [
        VisualCurve(
            label="Curva tiro/entrepierna MVP",
            start=start,
            control1=Point(start.x + 1.4, start.y + height * 0.30),
            control2=Point(end.x + 1.4, end.y - height * 0.25),
            end=end,
        )
    ]


def build_piece_visual_curves(piece: PatternPiece, garment_code: str) -> list[VisualCurve]:
    code = garment_code.strip().lower()
    if code == "falda_basica":
        return _basic_skirt_curves(piece)
    if code == "falda_evase":
        return _evase_curves(piece)
    if code == "pantalon_basico":
        return _pants_curves(piece)
    if code == "short_basico":
        return _short_curves(piece)
    return []


def attach_visual_curves(pieces: list[PatternPiece], garment_code: str) -> None:
    for piece in pieces:
        # Fase 40.3B: if structural curves exist, they are contour geometry.
        # Do not add dashed visual overlays for the same piece.
        if (piece.metadata or {}).get("structural_curves"):
            piece.metadata.pop("visual_curves", None)
            continue

        curves = build_piece_visual_curves(piece, garment_code)
        if curves:
            piece.metadata["visual_curves"] = _curve_metadata(curves)
            piece.metadata["curve_status"] = "mvp_visual_not_industrial"
