from __future__ import annotations

from dataclasses import dataclass
from math import hypot


@dataclass(frozen=True, slots=True)
class Point:
    """2D point expressed in centimeters."""

    x: float
    y: float

    def translate(self, dx: float = 0.0, dy: float = 0.0) -> "Point":
        return Point(self.x + dx, self.y + dy)

    def distance_to(self, other: "Point") -> float:
        return hypot(other.x - self.x, other.y - self.y)


@dataclass(frozen=True, slots=True)
class Line:
    """Straight segment between two points."""

    start: Point
    end: Point

    @property
    def length(self) -> float:
        return self.start.distance_to(self.end)


@dataclass(frozen=True, slots=True)
class BezierCurve:
    """Cubic Bezier curve."""

    start: Point
    control1: Point
    control2: Point
    end: Point


@dataclass(frozen=True, slots=True)
class Polygon:
    """Closed polygon represented by ordered points."""

    points: tuple[Point, ...]

    def __post_init__(self) -> None:
        if len(self.points) < 3:
            raise ValueError("A polygon needs at least three points")
