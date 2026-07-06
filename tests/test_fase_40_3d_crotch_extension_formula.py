from __future__ import annotations

from engine.exports.structural_curves import attach_structural_curves
from engine.generation import PatternGenerationRequest
from engine.generation.exporter import normalize_pieces
from engine.generation.pattern_generator import generate_pattern


def _pieces_with_metadata(garment_code: str, measurements: dict[str, float]):
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options={},
        )
    )
    pieces = normalize_pieces(result.pieces)
    # Simulate exporter metadata because formula should prefer full hip.
    for piece in pieces:
        piece.metadata.setdefault("measurements", dict(measurements))
    attach_structural_curves(pieces, garment_code)
    return pieces


def _crotch_curves(garment_code: str, measurements: dict[str, float]) -> list[tuple[str, dict]]:
    curves: list[tuple[str, dict]] = []
    for piece in _pieces_with_metadata(garment_code, measurements):
        for curve in piece.metadata.get("structural_curves", []):
            if curve["intent"] == "crotch_curve":
                curves.append((piece.name, curve))
    return curves


def test_pants_crotch_extension_uses_hip_formula_ranges() -> None:
    hip = 104.0
    curves = _crotch_curves(
        "pantalon_basico",
        {"waist": 84, "hip": hip, "outseam": 100, "inseam": 76},
    )
    assert len(curves) == 2

    front = next(curve for piece_name, curve in curves if "delantero" in piece_name.lower())
    back = next(curve for piece_name, curve in curves if "posterior" in piece_name.lower())

    assert front["extension_formula"] == "hip/20..hip/16"
    assert back["extension_formula"] == "hip/8..hip/6"

    assert front["extension_range_cm"] == [round(hip / 20, 4), round(hip / 16, 4)]
    assert back["extension_range_cm"] == [round(hip / 8, 4), round(hip / 6, 4)]

    assert front["extension_range_cm"][0] <= front["extension_cm"] <= front["extension_range_cm"][1]
    assert back["extension_range_cm"][0] <= back["extension_cm"] <= back["extension_range_cm"][1]
    assert back["extension_cm"] > front["extension_cm"]


def test_pants_back_crotch_extension_is_materially_deeper_than_front() -> None:
    curves = _crotch_curves(
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )
    front = next(curve for piece_name, curve in curves if "delantero" in piece_name.lower())
    back = next(curve for piece_name, curve in curves if "posterior" in piece_name.lower())

    assert back["concavity_direction"] == "inward_deeper"
    assert front["concavity_direction"] == "inward"
    assert back["extension_cm"] >= front["extension_cm"] * 2.0


def test_short_crotch_extension_keeps_same_base_formula_semantics() -> None:
    hip = 104.0
    curves = _crotch_curves(
        "short_basico",
        {"waist": 84, "hip": hip, "outseam": 45, "inseam": 20},
    )
    assert len(curves) == 2

    front = next(curve for piece_name, curve in curves if "delantero" in piece_name.lower())
    back = next(curve for piece_name, curve in curves if "posterior" in piece_name.lower())

    assert front["extension_formula"] == "hip/20..hip/16"
    assert back["extension_formula"] == "hip/8..hip/6"
    assert back["extension_cm"] > front["extension_cm"]


def test_crotch_curve_controls_use_formula_extension_depth() -> None:
    curves = _crotch_curves(
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )
    for _piece_name, curve in curves:
        chord_x = min(curve["start"]["x"], curve["end"]["x"])
        expected_control_x = chord_x - curve["extension_cm"]
        assert abs(curve["control1"]["x"] - expected_control_x) < 0.01
        assert abs(curve["control2"]["x"] - expected_control_x) < 0.01
