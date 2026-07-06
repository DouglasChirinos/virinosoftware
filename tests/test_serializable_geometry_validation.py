from pathlib import Path
from types import SimpleNamespace

import pytest

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.validation import (
    PatternGeometryValidationError,
    compute_pattern_geometry_report,
    compute_piece_geometry_report,
    validate_exported_files,
)

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_short_basico_geometry_report_has_positive_bbox() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="short_basico",
                measurements={
                    "waist": 84,
                    "hip": 104,
                    "outseam": 45,
                    "inseam": 20,
                },
            ),
            output_name="test_short_geometry_validation",
            export_svg=False,
            export_dxf=False,
            export_pdf=False,
        )
    )

    report = compute_pattern_geometry_report(
        garment_code="short_basico",
        pieces=result.generation_result.pieces,
    )

    assert report.piece_count == 2
    piece = report.piece_reports[0]
    assert piece.line_count == 4
    assert piece.point_count == 4
    assert piece.width == pytest.approx(26.0)
    posterior = report.piece_reports[1]
    assert posterior.line_count == 4
    assert posterior.point_count == 4
    assert posterior.width == pytest.approx(28.0)
    assert piece.height == pytest.approx(45.0)


def test_falda_evase_geometry_report_has_expected_expanded_bbox() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_evase",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                    "ease": 12,
                },
            ),
            output_name="test_falda_evase_geometry_validation",
            export_svg=False,
            export_dxf=False,
            export_pdf=False,
        )
    )

    report = compute_pattern_geometry_report(
        garment_code="falda_evase",
        pieces=result.generation_result.pieces,
    )

    assert report.piece_count == 2
    piece = report.piece_reports[0]
    assert piece.line_count == 4
    assert piece.point_count == 4
    assert piece.width == pytest.approx(48.75)
    assert piece.min_x == pytest.approx(-12.0)
    assert piece.max_x == pytest.approx(36.75)
    posterior = report.piece_reports[1]
    assert posterior.line_count == 4
    assert posterior.point_count == 4
    assert posterior.width == pytest.approx(49.75)
    assert posterior.min_x == pytest.approx(-12.0)
    assert posterior.max_x == pytest.approx(37.75)
    assert piece.height == pytest.approx(60.0)


def test_geometry_validation_rejects_flat_piece() -> None:
    point_a = SimpleNamespace(x=0.0, y=0.0)
    point_b = SimpleNamespace(x=10.0, y=0.0)
    line = SimpleNamespace(start=point_a, end=point_b)
    piece = SimpleNamespace(name="Pieza plana", lines=[line])

    with pytest.raises(PatternGeometryValidationError):
        compute_piece_geometry_report(piece)


def test_validate_exported_files_rejects_missing_file() -> None:
    missing = PROJECT_ROOT / "exports" / "svg" / "no_existe_fase_33.svg"

    with pytest.raises(PatternGeometryValidationError):
        validate_exported_files([missing])


def test_falda_evase_exported_files_are_non_trivial() -> None:
    output_name = "test_falda_evase_geometry_exports"
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_evase",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                    "ease": 12,
                },
            ),
            output_name=output_name,
        )
    )

    validated = validate_exported_files(result.exported_paths, min_bytes=100)

    assert len(validated) == 3
    assert {path.suffix for path in validated} == {".svg", ".dxf", ".pdf"}
