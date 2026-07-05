from engine.geometry.line import Line
from engine.geometry.point import Point
from engine.geometry.polygon import Polygon


def test_point_distance() -> None:
    assert Point(0, 0).distance_to(Point(3, 4)) == 5


def test_line_length() -> None:
    assert Line(Point(0, 0), Point(0, 10)).length == 10


def test_polygon_area() -> None:
    polygon = Polygon([Point(0, 0), Point(10, 0), Point(10, 10), Point(0, 10)])
    assert polygon.area == 100
