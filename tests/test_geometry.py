from engine.geometry import Line, Point, line_intersection, midpoint, rectangle


def test_point_distance() -> None:
    assert Point(0, 0).distance_to(Point(3, 4)) == 5


def test_midpoint() -> None:
    assert midpoint(Point(0, 0), Point(10, 10)) == Point(5, 5)


def test_line_intersection() -> None:
    result = line_intersection(Line(Point(0, 0), Point(10, 10)), Line(Point(0, 10), Point(10, 0)))
    assert result == Point(5, 5)


def test_rectangle() -> None:
    assert rectangle(Point(0, 0), 10, 20) == (Point(0, 0), Point(10, 0), Point(10, 20), Point(0, 20))
