from dataclasses import dataclass

from app.gui.pattern_canvas import (
    build_canvas_transform,
    get_pattern_bounds,
    transform_point,
)


@dataclass(frozen=True)
class Point:
    x: float
    y: float


@dataclass(frozen=True)
class Piece:
    name: str
    points: dict[str, Point]
    lines: tuple = ()


def test_canvas_bounds_use_all_piece_points():
    pieces = [
        Piece(name="Delantero", points={"a": Point(0, 0), "b": Point(10, 20)}),
        Piece(name="Posterior", points={"c": Point(-5, 4), "d": Point(15, 30)}),
    ]

    assert get_pattern_bounds(pieces) == (-5.0, 0.0, 15.0, 30.0)


def test_canvas_transform_fits_inside_canvas_with_padding():
    pieces = [
        Piece(name="Pieza", points={"a": Point(0, 0), "b": Point(20, 40)}),
    ]

    transform = build_canvas_transform(
        pieces,
        canvas_width=300,
        canvas_height=500,
        padding=30,
    )

    x1, y1 = transform_point(0, 0, transform)
    x2, y2 = transform_point(20, 40, transform)

    assert 30 <= x1 <= 270
    assert 30 <= y1 <= 470
    assert 30 <= x2 <= 270
    assert 30 <= y2 <= 470
    assert x2 > x1
    assert y2 > y1
