from pathlib import Path

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements


def test_basic_skirt_draft_generates_piece() -> None:
    pieces = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).draft()
    assert len(pieces) == 1
    assert pieces[0].name == "Falda basica delantera"
    assert len(pieces[0].points) >= 6
    assert len(pieces[0].lines) >= 6


def test_basic_skirt_exports(tmp_path: Path) -> None:
    pieces = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).draft()

    svg = export_svg(pieces, tmp_path / "falda.svg")
    dxf = export_dxf(pieces, tmp_path / "falda.dxf")
    pdf = export_pdf(pieces, tmp_path / "falda.pdf")

    assert svg.exists()
    assert dxf.exists()
    assert pdf.exists()
    assert svg.stat().st_size > 100
    assert dxf.stat().st_size > 100
    assert pdf.stat().st_size > 100
