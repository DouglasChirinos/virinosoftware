from app.gui.pattern_canvas import CanvasHitPoint, find_nearest_hit_point


def test_find_nearest_hit_point_inside_tolerance():
    hit_points = [
        CanvasHitPoint(piece_name="Delantero", point_name="cintura", x=10, y=10),
        CanvasHitPoint(piece_name="Posterior", point_name="cadera", x=50, y=50),
    ]

    selected = find_nearest_hit_point(hit_points, x=13, y=12, tolerance_px=8)

    assert selected is not None
    assert selected.piece_name == "Delantero"
    assert selected.point_name == "cintura"


def test_find_nearest_hit_point_returns_none_outside_tolerance():
    hit_points = [
        CanvasHitPoint(piece_name="Delantero", point_name="cintura", x=10, y=10),
    ]

    assert find_nearest_hit_point(hit_points, x=100, y=100, tolerance_px=8) is None


def test_find_nearest_hit_point_picks_closest_when_multiple_match():
    hit_points = [
        CanvasHitPoint(piece_name="Delantero", point_name="lejano", x=20, y=20),
        CanvasHitPoint(piece_name="Delantero", point_name="cercano", x=12, y=11),
    ]

    selected = find_nearest_hit_point(hit_points, x=10, y=10, tolerance_px=20)

    assert selected is not None
    assert selected.point_name == "cercano"
