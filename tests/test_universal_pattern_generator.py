"""Tests for Fase 22 universal pattern generator."""

from __future__ import annotations

import pytest

from engine.generation import (
    PatternGenerationError,
    PatternGenerationRequest,
    PatternGenerationResult,
    generate_pattern,
)


def test_generate_pattern_uses_registered_basic_skirt() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={
                "waist": 73,
                "hip": 99,
                "skirt_length": 60,
            },
        )
    )

    assert isinstance(result, PatternGenerationResult)
    assert result.garment_code == "falda_basica"
    assert result.garment_name == "Falda basica"
    assert result.draft_class_name == "BasicSkirtDraft"
    assert result.piece_count >= 1


def test_generate_pattern_preserves_measurements() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={
                "waist": 73,
                "hip": 99,
                "skirt_length": 60,
                "ease": 2,
                "hip_depth": 20,
            },
        )
    )

    assert result.measurements.waist == 73
    assert result.measurements.hip == 99
    assert result.measurements.skirt_length == 60


def test_generate_pattern_rejects_unknown_garment() -> None:
    with pytest.raises(PatternGenerationError) as exc:
        generate_pattern(
            PatternGenerationRequest(
                garment_code="chaqueta_inexistente",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            )
        )

    assert "Unknown garment code" in str(exc.value)


def test_generate_pattern_rejects_missing_measurements() -> None:
    with pytest.raises(PatternGenerationError) as exc:
        generate_pattern(
            PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={
                    "waist": 73,
                },
            )
        )

    assert "Missing body measurements" in str(exc.value)


def test_generate_pattern_rejects_empty_garment_code() -> None:
    with pytest.raises(PatternGenerationError) as exc:
        generate_pattern(
            PatternGenerationRequest(
                garment_code=" ",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            )
        )

    assert "garment_code cannot be empty" in str(exc.value)
