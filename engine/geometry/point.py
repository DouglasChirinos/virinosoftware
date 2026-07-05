from __future__ import annotations

from dataclasses import dataclass
from math import hypot


@dataclass(frozen=True)
class Point:
    """Punto 2D expresado en centimetros dentro del plano cartesiano del patron."""

    x: float
    y: float

    def distance_to(self, other: "Point") -> float:
        return hypot(other.x - self.x, other.y - self.y)

    def translate(self, dx: float = 0.0, dy: float = 0.0) -> "Point":
        return Point(self.x + dx, self.y + dy)

    def as_tuple(self) -> tuple[float, float]:
        return (self.x, self.y)
