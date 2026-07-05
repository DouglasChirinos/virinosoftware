from pathlib import Path

from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic import draft_basic_skirt
from engine.measurements.body import BodyMeasurements


def test_body_measurements_validation() -> None:
    measurements = BodyMeasurements(waist=72, hip=100, skirt_length=60)
    assert measurements.hip_depth == 20


def test_draft_basic_skirt_returns_two_pieces() -> None:
    pieces = draft_basic_skirt(BodyMeasurements(waist=72, hip=100, skirt_length=60))
    assert [piece.name for piece in pieces] == ["Falda basica - delantero", "Falda basica - posterior"]
    assert all(piece.lines for piece in pieces)


def test_svg_export(tmp_path: Path) -> None:
    pieces = draft_basic_skirt(BodyMeasurements(waist=72, hip=100, skirt_length=60))
    output = export_svg(pieces, tmp_path / "falda.svg")
    assert output.exists()
    assert "<svg" in output.read_text(encoding="utf-8")
