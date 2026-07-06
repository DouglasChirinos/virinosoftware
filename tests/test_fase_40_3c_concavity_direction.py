from __future__ import annotations

from engine.exports.structural_curves import attach_structural_curves
from engine.generation import PatternGenerationRequest
from engine.generation.exporter import normalize_pieces
from engine.generation.pattern_generator import generate_pattern


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


def _all_curves(garment_code: str, measurements: dict[str, float], options: dict | None = None) -> list[tuple[str, dict]]:
    curves: list[tuple[str, dict]] = []
    pieces = _pieces_with_structural_curves(garment_code, measurements, options)
    for piece in pieces:
        for curve in piece.metadata.get("structural_curves", []):
            curves.append((piece.name, curve))
    return curves


def _crotch_curves(garment_code: str, measurements: dict[str, float]) -> list[tuple[str, dict]]:
    return [
        (piece_name, curve)
        for piece_name, curve in _all_curves(garment_code, measurements)
        if curve["intent"] == "crotch_curve"
    ]


def test_all_structural_curves_expose_concavity_direction() -> None:
    cases = [
        ("falda_basica", {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2}, {"full_pattern": True}),
        ("falda_evase", {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12}, None),
        ("pantalon_basico", {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76}, None),
        ("short_basico", {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20}, None),
    ]

    for garment_code, measurements, options in cases:
        curves = _all_curves(garment_code, measurements, options)
        assert curves, garment_code
        for _piece_name, curve in curves:
            assert curve["concavity_direction"] in {
                "inward",
                "inward_deeper",
                "outward",
                "mixed_transition",
                "none",
            }


def test_pants_crotch_curve_is_concave_and_inward() -> None:
    curves = _crotch_curves(
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )
    assert len(curves) == 2

    for piece_name, curve in curves:
        assert curve["curvature"] == "concave"
        assert curve["curvature"] != "convex"
        assert curve["concavity_direction"] in {"inward", "inward_deeper"}
        if "posterior" in piece_name.lower():
            assert curve["concavity_direction"] == "inward_deeper"
        else:
            assert curve["concavity_direction"] == "inward"


def test_short_crotch_curve_is_concave_and_inward() -> None:
    curves = _crotch_curves(
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )
    assert len(curves) == 2

    for piece_name, curve in curves:
        assert curve["curvature"] == "concave"
        assert curve["curvature"] != "convex"
        assert curve["concavity_direction"] in {"inward", "inward_deeper"}
        if "posterior" in piece_name.lower():
            assert curve["concavity_direction"] == "inward_deeper"
        else:
            assert curve["concavity_direction"] == "inward"


def test_crotch_bezier_controls_enter_inside_piece() -> None:
    cases = [
        ("pantalon_basico", {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76}),
        ("short_basico", {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20}),
    ]

    for garment_code, measurements in cases:
        curves = _crotch_curves(garment_code, measurements)
        assert curves, garment_code
        for _piece_name, curve in curves:
            start_x = curve["start"]["x"]
            end_x = curve["end"]["x"]
            inside_threshold = min(start_x, end_x)
            assert curve["control1"]["x"] < inside_threshold
            assert curve["control2"]["x"] < inside_threshold


def test_non_crotch_curve_direction_contract() -> None:
    falda = _all_curves(
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )
    assert {curve["concavity_direction"] for _piece_name, curve in falda} == {"outward"}

    pantalon = _all_curves(
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )
    inseam = [curve for _piece_name, curve in pantalon if curve["intent"] == "inseam_curve"]
    assert inseam
    assert {curve["concavity_direction"] for curve in inseam} == {"mixed_transition"}
