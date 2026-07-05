from pathlib import Path

from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.geometry.line import Line
from engine.geometry.point import Point
from engine.measurements.body import BodyMeasurements
from engine.patterns.piece import PatternPiece
from engine.patterns.seam_allowance import SeamAllowanceConfig
from engine.qa.pattern_quality import run_pattern_quality_checks
from engine.reports.quality_report import generate_quality_report


def test_basic_skirt_quality_passes_without_errors() -> None:
    pieces = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).draft()

    report = run_pattern_quality_checks(pieces)

    assert report.passed
    assert len(report.errors) == 0


def test_quality_detects_negative_coordinates() -> None:
    piece = PatternPiece(name="pieza invalida")
    a = piece.add_point("A", Point(-1, 0))
    b = piece.add_point("B", Point(10, 0))
    piece.add_line(a, b)

    report = run_pattern_quality_checks([piece])

    assert not report.passed
    assert any(issue.code == "NEGATIVE_COORDINATE" for issue in report.errors)


def test_quality_detects_duplicate_lines() -> None:
    piece = PatternPiece(name="pieza duplicada")
    a = piece.add_point("A", Point(0, 0))
    b = piece.add_point("B", Point(10, 0))
    c = piece.add_point("C", Point(10, 10))
    d = piece.add_point("D", Point(0, 10))

    piece.add_line(a, b)
    piece.add_line(a, b)
    piece.add_line(b, c)
    piece.add_line(c, d)
    piece.add_line(d, a)

    report = run_pattern_quality_checks([piece])

    assert not report.passed
    assert any(issue.code == "DUPLICATE_LINE" for issue in report.errors)


def test_quality_detects_zero_length_line() -> None:
    piece = PatternPiece(name="pieza cero")
    a = piece.add_point("A", Point(0, 0))
    b = piece.add_point("B", Point(10, 0))
    c = piece.add_point("C", Point(10, 10))
    d = piece.add_point("D", Point(0, 10))

    piece.add_line(a, a)
    piece.add_line(a, b)
    piece.add_line(b, c)
    piece.add_line(c, d)
    piece.add_line(d, a)

    report = run_pattern_quality_checks([piece])

    assert not report.passed
    assert any(issue.code == "ZERO_LENGTH_LINE" for issue in report.errors)


def test_generate_quality_report(tmp_path: Path) -> None:
    pieces = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).draft()
    qa = run_pattern_quality_checks(pieces)

    output = generate_quality_report(
        pieces=pieces,
        quality_report=qa,
        output_path=tmp_path / "qa.md",
    )

    assert output.exists()
    text = output.read_text(encoding="utf-8")
    assert "Reporte QA" in text
    assert "APROBADO" in text


def test_seam_allowance_config_contract() -> None:
    config = SeamAllowanceConfig()
    assert config.default_cm == 1.0
    assert config.hem_cm == 3.0
