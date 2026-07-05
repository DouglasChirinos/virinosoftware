from __future__ import annotations

from dataclasses import dataclass
from math import atan2, degrees

from engine.geometry.point import Point


@dataclass(frozen=True)
class Line:
    """Segmento entre dos puntos del patron.

    kind:
    - pattern: linea base del patron
    - seam_allowance: linea de margen de costura
    - helper: linea auxiliar
    """

    start: Point
    end: Point
    label: str = ""
    kind: str = "pattern"

    @property
    def length(self) -> float:
        return self.start.distance_to(self.end)

    @property
    def angle_degrees(self) -> float:
        return degrees(atan2(self.end.y - self.start.y, self.end.x - self.start.x))
