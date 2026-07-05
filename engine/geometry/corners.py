from __future__ import annotations

from dataclasses import dataclass
from math import isfinite

from engine.geometry.line import Line
from engine.geometry.point import Point


@dataclass(frozen=True)
class CornerJoin:
    vertex: Point
    previous_offset_end: Point
    current_offset_start: Point
    join_style: str
    miter_distance_previous_cm: float
    miter_distance_current_cm: float
    miter_limit_cm: float

    @property
    def exceeds_limit(self) -> bool:
        return max(self.miter_distance_previous_cm, self.miter_distance_current_cm) > self.miter_limit_cm

    @property
    def is_finite(self) -> bool:
        return isfinite(self.vertex.x) and isfinite(self.vertex.y)


def classify_corner_join(
    *,
    vertex: Point,
    previous_offset: Line,
    current_offset: Line,
    miter_limit_cm: float,
    bevel_fallback: bool = True,
) -> CornerJoin:
    previous_distance = vertex.distance_to(previous_offset.end)
    current_distance = vertex.distance_to(current_offset.start)

    style = "miter"
    if max(previous_distance, current_distance) > miter_limit_cm and bevel_fallback:
        style = "bevel"

    return CornerJoin(
        vertex=vertex,
        previous_offset_end=previous_offset.end,
        current_offset_start=current_offset.start,
        join_style=style,
        miter_distance_previous_cm=previous_distance,
        miter_distance_current_cm=current_distance,
        miter_limit_cm=miter_limit_cm,
    )
