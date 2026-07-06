from __future__ import annotations

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.generation.exporter import normalize_pieces
from engine.generation.pattern_generator import generate_pattern
from engine.exports.structural_curves import attach_structural_curves, line_is_replaced_by_structural_curve


def _export_svg_text(tmp_path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_structural_curves_test",
            output_dir=tmp_path / garment_code,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def test_falda_basica_exports_structural_hip_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )

    assert 'class="structural-curve"' in content
    assert "Costado curvo de cadera" in content


def test_falda_evase_exports_structural_curved_hem(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert 'class="structural-curve"' in content
    assert "Bajo curvo corregido" in content


def test_pantalon_basico_exports_structural_crotch_and_inseam_curves(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert 'class="structural-curve"' in content
    assert "Curva estructural de tiro" in content
    assert "Curva estructural de entrepierna" in content


def test_short_basico_exports_structural_crotch_and_leg_opening_curves(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert 'class="structural-curve"' in content
    assert "Curva estructural tiro/entrepierna" in content
    assert "Boca de pierna curva MVP" in content


def test_structural_curve_replaces_matching_straight_segment_for_falda_basica() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
            options={"full_pattern": True},
        )
    )
    pieces = normalize_pieces(result.pieces)
    attach_structural_curves(pieces, "falda_basica")
    piece = pieces[0]
    curves = piece.metadata["structural_curves"]

    replaced = [
        line
        for line in piece.lines
        if line_is_replaced_by_structural_curve(line, curves)
    ]

    assert replaced
