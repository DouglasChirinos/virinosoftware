from __future__ import annotations

from engine.exports.structural_curves import attach_structural_curves
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.generation.exporter import normalize_pieces
from engine.generation.pattern_generator import generate_pattern


VALID_CURVATURES = {"concave", "convex", "mixed"}
VALID_INTENTS = {"hip_curve", "crotch_curve", "inseam_curve", "hem_curve", "leg_opening_curve"}


def _pieces_with_structural_curves(garment_code: str, measurements: dict[str, float], options: dict | None = None):
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options=options or {},
        )
    )
    pieces = normalize_pieces(result.pieces)
    attach_structural_curves(pieces, garment_code)
    return pieces


def _all_curves(pieces) -> list[dict]:
    curves: list[dict] = []
    for piece in pieces:
        curves.extend(piece.metadata.get("structural_curves", []))
    return curves


def test_all_structural_curves_have_patronage_semantics() -> None:
    cases = [
        ("falda_basica", {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2}, {"full_pattern": True}),
        ("falda_evase", {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12}, None),
        ("pantalon_basico", {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76}, None),
        ("short_basico", {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20}, None),
    ]

    for garment_code, measurements, options in cases:
        curves = _all_curves(_pieces_with_structural_curves(garment_code, measurements, options))
        assert curves, garment_code
        for curve in curves:
            assert curve["kind"] == "structural_curve"
            assert curve["curve_type"] == "cubic_bezier"
            assert curve["curvature"] in VALID_CURVATURES
            assert curve["intent"] in VALID_INTENTS
            assert curve["replaces_segment"] is True
            assert curve["mvp_status"] == "mvp_structural_not_industrial"
            assert curve["patronage_note"]


def test_expected_curve_semantics_by_garment() -> None:
    falda = _all_curves(
        _pieces_with_structural_curves(
            "falda_basica",
            {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
            {"full_pattern": True},
        )
    )
    assert {curve["intent"] for curve in falda} == {"hip_curve"}
    assert {curve["curvature"] for curve in falda} == {"convex"}

    evase = _all_curves(
        _pieces_with_structural_curves(
            "falda_evase",
            {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        )
    )
    assert {curve["intent"] for curve in evase} == {"hem_curve"}
    assert {curve["curvature"] for curve in evase} == {"convex"}

    pantalon = _all_curves(
        _pieces_with_structural_curves(
            "pantalon_basico",
            {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        )
    )
    assert "crotch_curve" in {curve["intent"] for curve in pantalon}
    assert "inseam_curve" in {curve["intent"] for curve in pantalon}
    assert "concave" in {curve["curvature"] for curve in pantalon}
    assert "mixed" in {curve["curvature"] for curve in pantalon}

    short = _all_curves(
        _pieces_with_structural_curves(
            "short_basico",
            {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        )
    )
    assert "crotch_curve" in {curve["intent"] for curve in short}
    assert "leg_opening_curve" in {curve["intent"] for curve in short}
    assert "concave" in {curve["curvature"] for curve in short}
    assert "convex" in {curve["curvature"] for curve in short}


def test_structural_curves_suppress_visual_overlays_in_metadata() -> None:
    pieces = _pieces_with_structural_curves(
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )
    for piece in pieces:
        if piece.metadata.get("structural_curves"):
            assert "visual_curves" not in piece.metadata


def test_export_svg_has_structural_semantics_without_dashed_visual_curves(tmp_path) -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="short_basico",
                measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
            ),
            output_name="short_basico_fase_40_3b_semantica",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    content = result.svg_path.read_text(encoding="utf-8")
    assert 'class="structural-curve"' in content
    assert "Curva estructural tiro/entrepierna" in content
    assert "Boca de pierna curva MVP" in content
    assert 'stroke-dasharray="6 3"' not in content
