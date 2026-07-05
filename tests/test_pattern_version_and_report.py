from pathlib import Path

from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements
from engine.reports.pattern_report import generate_pattern_report


def test_pattern_piece_has_version_metadata() -> None:
    pieces = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).draft()

    assert pieces[0].metadata["code"] == "SKIRT_BASIC"
    assert pieces[0].metadata["unit"] == "cm"
    assert pieces[0].metadata["measurement_unit"] == "cm"


def test_generate_pattern_report(tmp_path: Path) -> None:
    measurements = BodyMeasurements(waist=72, hip=98, skirt_length=60)
    pieces = BasicSkirtDraft(measurements).draft()

    report = generate_pattern_report(
        pieces=pieces,
        measurements=measurements,
        output_path=tmp_path / "reporte.md",
    )

    assert report.exists()
    text = report.read_text(encoding="utf-8")
    assert "Unidad oficial del motor" in text
    assert "Falda basica delantera" in text
    assert "SKIRT_BASIC" in text
