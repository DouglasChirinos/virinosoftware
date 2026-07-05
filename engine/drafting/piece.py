from __future__ import annotations

from dataclasses import dataclass, field

from engine.geometry import BezierCurve, Line, Point

Drawable = Line | BezierCurve


@dataclass(slots=True)
class PatternPiece:
    name: str
    points: dict[str, Point] = field(default_factory=dict)
    lines: list[Line] = field(default_factory=list)
    curves: list[BezierCurve] = field(default_factory=list)
    annotations: dict[str, str] = field(default_factory=dict)

    def add_point(self, key: str, point: Point) -> Point:
        self.points[key] = point
        return point

    def add_line(self, start_key: str, end_key: str) -> Line:
        line = Line(self.points[start_key], self.points[end_key])
        self.lines.append(line)
        return line

    def add_curve(self, curve: BezierCurve) -> BezierCurve:
        self.curves.append(curve)
        return curve
