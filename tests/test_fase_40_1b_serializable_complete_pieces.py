from __future__ import annotations

from typing import Any

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern, generate_pattern


def _x(point: Any) -> float:
    """Return x coordinate from Point, tuple/list or dict-like point."""

    if hasattr(point, "x"):
        return float(point.x)

    if isinstance(point, dict):
        if "x" in point:
            return float(point["x"])
        return float(point[0])

    return float(point[0])


def test_short_basico_generates_front_and_back_serializable_pieces() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="short_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        )
    )

    names = [piece.name for piece in result.pieces]

    assert result.piece_count == 2
    assert "Short basico delantero" in names
    assert "Short basico posterior" in names


def test_falda_evase_generates_front_and_back_serializable_pieces() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_evase",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        )
    )

    names = [piece.name for piece in result.pieces]

    assert result.piece_count == 2
    assert "Falda evase delantera" in names
    assert "Falda evase posterior" in names


def test_short_basico_posterior_is_mvp_differentiated_from_front() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="short_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        )
    )

    front = next(piece for piece in result.pieces if "delantero" in piece.name.lower())
    back = next(piece for piece in result.pieces if "posterior" in piece.name.lower())

    assert _x(back.points["B"]) > _x(front.points["B"])
    assert _x(back.points["C"]) > _x(front.points["C"])


def test_falda_evase_posterior_is_differentiated_from_front() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_evase",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        )
    )

    front = next(piece for piece in result.pieces if "delantera" in piece.name.lower())
    back = next(piece for piece in result.pieces if "posterior" in piece.name.lower())

    assert _x(back.points["B"]) > _x(front.points["B"])
    assert _x(back.points["C"]) > _x(front.points["C"])


def test_serializable_complete_patterns_export_svg_mentions_back_pieces(tmp_path) -> None:
    short_result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="short_basico",
                measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
            ),
            output_name="short_basico_complete_test",
            output_dir=tmp_path / "short",
            export_dxf=False,
            export_pdf=False,
        )
    )
    falda_result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_evase",
                measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
            ),
            output_name="falda_evase_complete_test",
            output_dir=tmp_path / "falda",
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert short_result.svg_path is not None
    assert falda_result.svg_path is not None
    assert "Short basico posterior" in short_result.svg_path.read_text(encoding="utf-8")
    assert "Falda evase posterior" in falda_result.svg_path.read_text(encoding="utf-8")
