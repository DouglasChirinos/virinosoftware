import pytest

from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.geometry.line import Line
from engine.geometry.point import Point
from engine.measurements.body import BodyMeasurements
from engine.patterns.seam_allowance import SeamAllowanceConfig, apply_seam_allowance, offset_line
from engine.qa.pattern_quality import run_pattern_quality_checks


def test_offset_line_keeps_length() -> None:
    line = Line(Point(0, 0), Point(10, 0), label="cintura")
    offset = offset_line(line, 1.0)

    assert offset.kind == "seam_allowance"
    assert offset.length == pytest.approx(line.length)
    assert offset.start.y == pytest.approx(-1.0)
    assert offset.end.y == pytest.approx(-1.0)


def test_apply_seam_allowance_adds_lines() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    result = apply_seam_allowance(piece, SeamAllowanceConfig())

    assert result.name.endswith("con margen")
    assert len(result.seam_allowance_lines) > 0
    assert len(result.lines) > len(piece.lines)
    assert result.metadata["seam_allowance"] == "enabled"


def test_seam_allowance_rejects_negative_values() -> None:
    with pytest.raises(ValueError):
        SeamAllowanceConfig(default_cm=-1)


def test_piece_with_seam_allowance_passes_qa() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    result = apply_seam_allowance(piece)

    qa = run_pattern_quality_checks([piece, result])

    assert qa.passed
