from __future__ import annotations

from math import hypot

from engine.geometry.line import Line
from engine.geometry.point import Point


def parallel_offset_line(line: Line, distance_cm: float, *, kind: str = "seam_allowance") -> Line:
    """Crea una linea paralela desplazada.

    Unidad: centimetros.
    Convencion MVP: desplazamiento hacia la derecha del vector start -> end.
    """

    dx = line.end.x - line.start.x
    dy = line.end.y - line.start.y
    length = hypot(dx, dy)

    if length == 0:
        raise ValueError("No se puede desplazar una linea con longitud cero")

    nx = dy / length
    ny = -dx / length

    return Line(
        start=Point(line.start.x + nx * distance_cm, line.start.y + ny * distance_cm),
        end=Point(line.end.x + nx * distance_cm, line.end.y + ny * distance_cm),
        label=f"margen {line.label}".strip(),
        kind=kind,
    )


def infinite_line_intersection(line_a: Line, line_b: Line) -> Point | None:
    """Interseccion de dos lineas infinitas definidas por segmentos."""

    x1, y1 = line_a.start.x, line_a.start.y
    x2, y2 = line_a.end.x, line_a.end.y
    x3, y3 = line_b.start.x, line_b.start.y
    x4, y4 = line_b.end.x, line_b.end.y

    denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

    if abs(denominator) < 1e-9:
        return None

    px = (
        (x1 * y2 - y1 * x2) * (x3 - x4)
        - (x1 - x2) * (x3 * y4 - y3 * x4)
    ) / denominator
    py = (
        (x1 * y2 - y1 * x2) * (y3 - y4)
        - (y1 - y2) * (x3 * y4 - y3 * x4)
    ) / denominator

    return Point(px, py)


def polygon_signed_area(points: list[Point]) -> float:
    """Area firmada. Positiva si el contorno esta orientado antihorario."""

    if len(points) < 3:
        return 0.0

    acc = 0.0
    for idx, point in enumerate(points):
        nxt = points[(idx + 1) % len(points)]
        acc += point.x * nxt.y - nxt.x * point.y

    return acc / 2.0


def is_closed_contour(points: list[Point], *, tolerance: float = 1e-6) -> bool:
    if len(points) < 4:
        return False

    return points[0].distance_to(points[-1]) <= tolerance
