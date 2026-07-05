from __future__ import annotations

from dataclasses import dataclass

from engine.geometry.point import Point


@dataclass(frozen=True)
class BezierCurve:
    """Curva Bezier cubica para sisas, costados, cintura y curvas de patronaje."""

    start: Point
    control1: Point
    control2: Point
    end: Point
    label: str = ""

    def point_at(self, t: float) -> Point:
        if not 0 <= t <= 1:
            raise ValueError("t debe estar entre 0 y 1")

        x = (
            (1 - t) ** 3 * self.start.x
            + 3 * (1 - t) ** 2 * t * self.control1.x
            + 3 * (1 - t) * t**2 * self.control2.x
            + t**3 * self.end.x
        )
        y = (
            (1 - t) ** 3 * self.start.y
            + 3 * (1 - t) ** 2 * t * self.control1.y
            + 3 * (1 - t) * t**2 * self.control2.y
            + t**3 * self.end.y
        )
        return Point(x, y)
