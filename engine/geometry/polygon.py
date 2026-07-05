from __future__ import annotations

from dataclasses import dataclass, field

from engine.geometry.line import Line
from engine.geometry.point import Point


@dataclass(frozen=True)
class Polygon:
    """Poligono cerrado usado para piezas simples de patronaje."""

    points: list[Point] = field(default_factory=list)
    label: str = ""

    def __post_init__(self) -> None:
        if len(self.points) < 3:
            raise ValueError("un poligono requiere al menos 3 puntos")

    @property
    def lines(self) -> list[Line]:
        return [
            Line(self.points[i], self.points[(i + 1) % len(self.points)])
            for i in range(len(self.points))
        ]

    @property
    def area(self) -> float:
        acc = 0.0
        for i, point in enumerate(self.points):
            nxt = self.points[(i + 1) % len(self.points)]
            acc += point.x * nxt.y - nxt.x * point.y
        return abs(acc) / 2
