from __future__ import annotations

from engine.generation import PatternGenerationRequest, generate_pattern
from engine.qa.piece_completeness import assert_complete_lower_garment


def test_falda_basica_gui_full_pattern_has_front_and_back() -> None:
    check = assert_complete_lower_garment(
        garment_code="falda_basica",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        options={"full_pattern": True},
    )

    assert check.is_complete
    assert any("delantera" in name.lower() for name in check.piece_names)
    assert any("posterior" in name.lower() for name in check.piece_names)


def test_pantalon_basico_has_front_and_back() -> None:
    check = assert_complete_lower_garment(
        garment_code="pantalon_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert check.is_complete


def test_short_basico_product_pattern_has_front_and_back_mvp() -> None:
    check = assert_complete_lower_garment(
        garment_code="short_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert check.is_complete
    assert any("delantero" in name.lower() for name in check.piece_names)
    assert any("posterior" in name.lower() for name in check.piece_names)


def test_falda_evase_product_pattern_has_front_and_back() -> None:
    check = assert_complete_lower_garment(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert check.is_complete
    assert any("delantera" in name.lower() for name in check.piece_names)
    assert any("posterior" in name.lower() for name in check.piece_names)


def test_generation_result_keeps_legacy_cli_behavior_for_falda_basica_without_full_option() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        )
    )

    assert result.piece_count == 1
