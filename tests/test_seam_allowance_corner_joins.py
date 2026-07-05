from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.geometry.corners import classify_corner_join
from engine.geometry.line import Line
from engine.geometry.offset import infinite_line_intersection
from engine.geometry.point import Point
from engine.measurements.body import BodyMeasurements
from engine.patterns.seam_allowance import (
    SeamAllowanceConfig,
    analyze_corner_joins,
    apply_seam_allowance,
    build_closed_seam_allowance_contour,
)
from engine.qa.pattern_quality import run_pattern_quality_checks


def test_corner_join_can_classify_bevel_when_miter_exceeds_limit() -> None:
    previous_line = Line(Point(0, 0), Point(10, 0), label="previo")
    current_line = Line(Point(10, 0), Point(10.1, 20), label="actual")
    vertex = Point(100, 100)

    join = classify_corner_join(
        vertex=vertex,
        previous_offset=previous_line,
        current_offset=current_line,
        miter_limit_cm=5,
        bevel_fallback=True,
    )

    assert join.join_style == "bevel"
    assert join.exceeds_limit


def test_apply_seam_allowance_adds_corner_metadata() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    result = apply_seam_allowance(piece, SeamAllowanceConfig())

    assert result.metadata["seam_allowance_mode"] == "closed_contour"
    assert result.metadata["seam_corner_join"] == "miter"
    assert result.metadata["seam_miter_limit_cm"] == "8.0"
    assert result.metadata["seam_bevel_fallback"] == "True"


def test_closed_contour_with_corner_control_passes_qa() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    result = apply_seam_allowance(piece)

    qa = run_pattern_quality_checks([piece, result])

    assert qa.passed


def test_build_closed_contour_accepts_bevel_mode() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    lines = build_closed_seam_allowance_contour(piece, SeamAllowanceConfig(corner_join="bevel"))

    assert len(lines) >= 3
    assert all(line.kind == "seam_allowance" for line in lines)


def test_analyze_corner_joins_returns_join_data() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    joins = analyze_corner_joins(piece, SeamAllowanceConfig())

    assert joins
    assert all(join.is_finite for join in joins)


def test_infinite_line_intersection_returns_point() -> None:
    a = Line(Point(0, 0), Point(10, 0))
    b = Line(Point(5, -5), Point(5, 5))

    intersection = infinite_line_intersection(a, b)

    assert intersection is not None
    assert intersection.x == 5
    assert intersection.y == 0
