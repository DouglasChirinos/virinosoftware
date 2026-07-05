from pathlib import Path

from engine.exports.svg.writer import export_svg
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.patterns.piece import PatternPiece
from engine.geometry.point import Point


def test_universal_export_svg_includes_garment_and_measurements(tmp_path: Path) -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={"waist": 72, "hip": 98, "skirt_length": 60},
            ),
            output_name="falda_visual_metadata",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    svg_text = result.svg_path.read_text(encoding="utf-8")

    assert "Prenda: falda_basica" in svg_text
    assert "Medidas:" in svg_text
    assert "waist: 72 cm" in svg_text
    assert "hip: 98 cm" in svg_text
    assert "skirt_length: 60 cm" in svg_text


def test_svg_label_positions_are_not_identical_for_close_points(tmp_path: Path) -> None:
    piece = PatternPiece(
        name="Pieza prueba",
        points={
            "Pinza_izq": Point(10, 10),
            "Pinza_der": Point(11, 10),
        },
        lines=[],
        metadata={"measurements": {"waist": 72}},
    )

    output = export_svg([piece], tmp_path / "labels.svg")
    svg_text = output.read_text(encoding="utf-8")

    assert "Pinza_izq" in svg_text
    assert "Pinza_der" in svg_text
    assert svg_text.count("font-size=\"11\"") >= 2
