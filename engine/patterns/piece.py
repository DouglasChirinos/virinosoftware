from __future__ import annotations

from dataclasses import dataclass, field

from engine.geometry.curve import BezierCurve
from engine.geometry.line import Line
from engine.geometry.point import Point


@dataclass
class PatternPiece:
    """Pieza de patronaje con puntos, lineas, curvas y metadatos."""

    name: str
    points: dict[str, Point] = field(default_factory=dict)
    lines: list[Line] = field(default_factory=list)
    curves: list[BezierCurve] = field(default_factory=list)
    annotations: list[str] = field(default_factory=list)

    def add_point(self, name: str, point: Point) -> Point:
        self.points[name] = point
        return point

    def add_line(self, start: Point, end: Point, label: str = "") -> Line:
        line = Line(start=start, end=end, label=label)
        self.lines.append(line)
        return line

    def add_annotation(self, text: str) -> None:
        self.annotations.append(text)

    @property
    def label(self) -> str:
        return self.name
