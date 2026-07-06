"""Visual annotation rules for pattern exports.

This module keeps product-facing dimensions out of low-level PDF/SVG writers.
The writers only render annotations. The business rule lives here:
headers show input measurements, edge dimensions show real geometry.
"""

from __future__ import annotations

import math
import re
from typing import Any, Iterable

from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece

MEASUREMENT_LABELS = {
    "waist": "Cintura",
    "hip": "Cadera",
    "skirt_length": "Largo falda",
    "outseam": "Largo exterior",
    "inseam": "Entrepierna",
    "rise": "Tiro",
    "ease": "Holgura",
    "hip_depth": "Altura cadera",
    "ease_hip": "Holgura cadera",
    "ease_waist": "Holgura cintura",
}

_TECHNICAL_POINT_RE = re.compile(r"^line_\d+_(start|end)$")


def is_technical_point_name(name: str) -> bool:
    """Return True for exporter-generated point names that should not be shown."""

    return bool(_TECHNICAL_POINT_RE.match(str(name)))


def displayable_point_names(points: dict[str, Any]) -> list[str]:
    """Return point names useful enough to show to end users."""

    return [name for name in points if not is_technical_point_name(name)]


def format_number(value: float | int | Any) -> str:
    """Format centimeters without noisy trailing decimals."""

    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value)

    return f"{number:.2f}".rstrip("0").rstrip(".")


def format_measurements_for_header(measurements: dict[str, Any]) -> list[str]:
    """Return input measurements for the PDF/SVG header in Spanish."""

    lines: list[str] = []
    for key in ("waist", "hip", "skirt_length", "outseam", "inseam", "rise", "ease", "hip_depth"):
        if key in measurements and measurements[key] is not None:
            lines.append(f"{MEASUREMENT_LABELS.get(key, key)}: {format_number(measurements[key])} cm")
    return lines


def line_label(line: Any) -> str:
    """Return a normalized label/name for an export line."""

    value = getattr(line, "name", None) or getattr(line, "label", None) or ""
    return str(value).strip().lower()


def distance(start: Point, end: Point) -> float:
    return math.hypot(float(end.x) - float(start.x), float(end.y) - float(start.y))


def _dim(label: str, start: Point, end: Point, *, offset_x: float = 0.0, offset_y: float = 0.0) -> dict[str, Any]:
    return {
        "label": label,
        "start": {"x": float(start.x), "y": float(start.y)},
        "end": {"x": float(end.x), "y": float(end.y)},
        "offset": {"x": float(offset_x), "y": float(offset_y)},
    }


def _point_at(x: float, y: float) -> Point:
    return Point(float(x), float(y))


def _points_bounds(points: Iterable[Point]) -> tuple[float, float, float, float]:
    point_list = list(points)
    if not point_list:
        return (0.0, 0.0, 0.0, 0.0)
    xs = [float(point.x) for point in point_list]
    ys = [float(point.y) for point in point_list]
    return min(xs), min(ys), max(xs), max(ys)


def _line_by_label(piece: PatternPiece, expected: str) -> Any | None:
    for line in piece.lines:
        if line_label(line) == expected:
            return line
    return None


def _line_containing(piece: PatternPiece, expected: str) -> Any | None:
    for line in piece.lines:
        if expected in line_label(line):
            return line
    return None


def _basic_skirt_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    points = piece.points
    dimensions: list[dict[str, Any]] = []

    if "A_cintura_centro" in points and "B_cintura_costado" in points:
        start = points["A_cintura_centro"]
        end = points["B_cintura_costado"]
        dimensions.append(_dim(f"Cintura pieza: {format_number(distance(start, end))} cm", start, end, offset_y=-4.0))

    if "C_cadera_centro" in points and "D_cadera_costado" in points:
        start = points["C_cadera_centro"]
        end = points["D_cadera_costado"]
        dimensions.append(_dim(f"Cadera pieza: {format_number(distance(start, end))} cm", start, end, offset_y=4.0))

    if "A_cintura_centro" in points and "E_bajo_centro" in points:
        start = points["A_cintura_centro"]
        end = points["E_bajo_centro"]
        dimensions.append(_dim(f"Largo pieza: {format_number(distance(start, end))} cm", start, end, offset_x=-4.0))

    return dimensions


def _pants_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    dimensions: list[dict[str, Any]] = []
    points_from_lines = [line.start for line in piece.lines] + [line.end for line in piece.lines]
    min_x, min_y, max_x, max_y = _points_bounds(points_from_lines)

    waist_line = _line_by_label(piece, "cintura")
    if waist_line is not None:
        dimensions.append(
            _dim(
                f"Cintura pieza: {format_number(distance(waist_line.start, waist_line.end))} cm",
                waist_line.start,
                waist_line.end,
                offset_y=-4.0,
            )
        )

    upper_side = _line_by_label(piece, "costado_superior")
    if upper_side is not None:
        hip_start = _point_at(min_x, float(upper_side.end.y))
        hip_end = _point_at(float(upper_side.end.x), float(upper_side.end.y))
        if abs(float(hip_end.x) - float(hip_start.x)) > 0.01:
            dimensions.append(
                _dim(
                    f"Cadera pieza: {format_number(distance(hip_start, hip_end))} cm",
                    hip_start,
                    hip_end,
                    offset_y=4.0,
                )
            )

    # The current MVP pants geometry has no explicit inseam segment. The only
    # reliable vertical product dimension in geometry is total outside height.
    if max_y > min_y:
        start = _point_at(min_x, min_y)
        end = _point_at(min_x, max_y)
        dimensions.append(
            _dim(
                f"Largo exterior pieza: {format_number(distance(start, end))} cm",
                start,
                end,
                offset_x=-4.0,
            )
        )

    return dimensions


def _serializable_quad_points(piece: PatternPiece) -> tuple[Point, Point, Point, Point] | None:
    points = piece.points
    if all(name in points for name in ("A", "B", "C", "D")):
        return points["A"], points["B"], points["C"], points["D"]
    return None


def _short_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    quad = _serializable_quad_points(piece)
    if quad is None:
        return []

    a, b, c, d = quad
    dimensions = [
        _dim(f"Cintura pieza: {format_number(distance(a, b))} cm", a, b, offset_y=-4.0),
        _dim(f"Cadera/pierna pieza: {format_number(distance(d, c))} cm", d, c, offset_y=4.0),
        _dim(f"Largo exterior pieza: {format_number(distance(a, d))} cm", a, d, offset_x=-4.0),
    ]
    return dimensions


def _evase_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    quad = _serializable_quad_points(piece)
    if quad is None:
        return []

    a, b, c, d = quad
    _, min_y, _, max_y = _points_bounds((a, b, c, d))
    vertical_start = _point_at(float(d.x), min_y)
    vertical_end = _point_at(float(d.x), max_y)

    dimensions = [
        _dim(f"Cintura pieza: {format_number(distance(a, b))} cm", a, b, offset_y=-4.0),
        _dim(f"Bajo pieza: {format_number(distance(d, c))} cm", d, c, offset_y=4.0),
        _dim(f"Largo falda: {format_number(distance(vertical_start, vertical_end))} cm", vertical_start, vertical_end, offset_x=-4.0),
    ]
    return dimensions


def _generic_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    """Best-effort dimensions for future simple pieces."""

    dimensions: list[dict[str, Any]] = []
    for line in piece.lines:
        label = line_label(line)
        if label in {"cintura", "bajo"}:
            product_label = "Cintura pieza" if label == "cintura" else "Bajo pieza"
            dimensions.append(
                _dim(
                    f"{product_label}: {format_number(distance(line.start, line.end))} cm",
                    line.start,
                    line.end,
                    offset_y=-4.0 if label == "cintura" else 4.0,
                )
            )
    return dimensions


def build_dimension_annotations(piece: PatternPiece, garment_code: str) -> list[dict[str, Any]]:
    """Build product-facing geometric dimensions for one piece."""

    if garment_code == "falda_basica":
        return _basic_skirt_dimensions(piece)
    if garment_code == "pantalon_basico":
        return _pants_dimensions(piece)
    if garment_code == "short_basico":
        return _short_dimensions(piece)
    if garment_code == "falda_evase":
        return _evase_dimensions(piece)
    return _generic_dimensions(piece)
