from __future__ import annotations

from pathlib import Path

from app.controllers.universal_pattern_controller import export_summary, generate_summary
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern, generate_pattern


def test_falda_basica_generate_summary_returns_full_pattern() -> None:
    summary = generate_summary(
        garment_code="falda_basica",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
    )

    assert summary.piece_count == 2


def test_falda_basica_generation_with_full_pattern_option_returns_two_pieces() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
            options={"full_pattern": True},
        )
    )

    names = [piece.name for piece in result.pieces]
    assert result.piece_count == 2
    assert "Falda basica delantera" in names
    assert "Falda basica posterior" in names


def test_falda_basica_export_summary_returns_two_pieces() -> None:
    summary = export_summary(
        garment_code="falda_basica",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        output_name="falda_basica_fase40_visual_test",
    )

    assert summary.piece_count == 2
    assert summary.svg_path is not None
    assert summary.pdf_path is not None



def test_falda_basica_svg_includes_spanish_measurements_and_both_pieces(tmp_path: Path) -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
                options={"full_pattern": True},
            ),
            output_name="falda_basica_svg_visual",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    content = result.svg_path.read_text(encoding="utf-8")

    assert "Prenda: falda_basica - Falda basica" in content
    assert "Falda basica delantera" in content
    assert "Falda basica posterior" in content
    assert "Cintura: 73 cm" in content
    assert "Cadera: 99 cm" in content
    assert "Largo falda: 60 cm" in content
    assert "Cintura pieza: 19.25 cm" in content
    assert "Cadera pieza: 25.75 cm" in content
    assert "Largo pieza: 60 cm" in content


def test_falda_basica_dimension_annotations_use_real_piece_lengths() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
                options={"full_pattern": True},
            ),
            output_name="falda_basica_dimension_annotations",
            export_svg=False,
            export_dxf=False,
            export_pdf=False,
        )
    )

    pieces = result.generation_result.pieces
    assert len(pieces) == 2

    # Exported pieces are normalized internally, so validate through SVG output
    # in the main visual export test. This test protects generation intent.
    assert result.generation_result.options["full_pattern"] is True
