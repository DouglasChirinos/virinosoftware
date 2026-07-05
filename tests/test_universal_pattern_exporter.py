"""Tests for Fase 24 universal pattern exporter."""

from __future__ import annotations

from pathlib import Path

from engine.generation import (
    PatternExportRequest,
    PatternExportResult,
    PatternGenerationRequest,
    export_generated_pattern,
    normalize_pieces,
)


def test_normalize_pieces_keeps_pattern_piece_for_basic_skirt() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            ),
            output_name="test_falda_basica_universal",
            export_svg=False,
            export_dxf=False,
            export_pdf=False,
        )
    )

    pieces = normalize_pieces(result.generation_result.pieces)

    assert pieces
    assert all(hasattr(piece, "name") for piece in pieces)
    assert all(hasattr(piece, "lines") for piece in pieces)
    assert all(hasattr(piece, "pattern_lines") for piece in pieces)


def test_export_generated_basic_skirt_creates_files() -> None:
    output_name = "test_falda_basica_universal"

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            ),
            output_name=output_name,
        )
    )

    assert isinstance(result, PatternExportResult)
    assert result.generation_result.garment_code == "falda_basica"

    for path in result.exported_paths:
        assert Path(path).exists()
        assert Path(path).stat().st_size > 0


def test_export_generated_basic_pants_creates_files() -> None:
    output_name = "test_pantalon_basico_universal"

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="pantalon_basico",
                measurements={
                    "waist": 84,
                    "hip": 104,
                    "outseam": 100,
                    "inseam": 76,
                },
            ),
            output_name=output_name,
        )
    )

    assert isinstance(result, PatternExportResult)
    assert result.generation_result.garment_code == "pantalon_basico"
    assert result.generation_result.piece_count == 2

    for path in result.exported_paths:
        assert Path(path).exists()
        assert Path(path).stat().st_size > 0


def test_export_result_exposes_only_enabled_formats() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="pantalon_basico",
                measurements={
                    "waist": 84,
                    "hip": 104,
                    "outseam": 100,
                },
            ),
            output_name="test_pantalon_svg_only",
            export_svg=True,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    assert result.dxf_path is None
    assert result.pdf_path is None
    assert len(result.exported_paths) == 1
