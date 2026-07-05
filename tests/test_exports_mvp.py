from pathlib import Path

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements


def test_basic_skirt_generates_lines():
    measurements = BodyMeasurements(waist=72.0, hip=100.0, skirt_length=60.0, ease=2.0)
    piece = BasicSkirtDraft(measurements).build()
    assert piece.name
    assert len(piece.lines) >= 4


def test_exports_create_files(tmp_path: Path):
    measurements = BodyMeasurements(waist=72.0, hip=100.0, skirt_length=60.0, ease=2.0)
    piece = BasicSkirtDraft(measurements).build()

    svg = export_svg(piece.lines, tmp_path / "falda.svg")
    dxf = export_dxf(piece.lines, tmp_path / "falda.dxf")
    pdf = export_pdf(piece.lines, tmp_path / "falda.pdf")

    assert svg.exists() and svg.stat().st_size > 0
    assert dxf.exists() and dxf.stat().st_size > 0
    assert pdf.exists() and pdf.stat().st_size > 0
