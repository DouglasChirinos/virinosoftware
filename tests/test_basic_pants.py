"""Tests for Fase 23 basic pants draft."""

from __future__ import annotations

from engine.garments import get_garment, get_garment_codes
from engine.garments.pants import BasicPantsDraft, PantsMeasurements
from engine.generation import PatternGenerationRequest, generate_pattern


def test_basic_pants_is_registered() -> None:
    assert "pantalon_basico" in get_garment_codes()
    assert get_garment("pantalon_basico") is BasicPantsDraft


def test_basic_pants_generates_front_and_back_pieces() -> None:
    draft = BasicPantsDraft(
        PantsMeasurements(
            waist=84,
            hip=104,
            outseam=100,
            inseam=76,
        )
    )

    pieces = draft.draft()

    assert len(pieces) == 2
    assert pieces[0].name == "Pantalon basico delantero"
    assert pieces[1].name == "Pantalon basico posterior"
    assert len(pieces[0].lines) >= 5
    assert len(pieces[1].lines) >= 5


def test_universal_generator_generates_basic_pants() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="pantalon_basico",
            measurements={
                "waist": 84,
                "hip": 104,
                "outseam": 100,
                "inseam": 76,
            },
        )
    )

    assert result.garment_code == "pantalon_basico"
    assert result.garment_name == "Pantalon basico"
    assert result.draft_class_name == "BasicPantsDraft"
    assert result.piece_count == 2
    assert result.pieces[0].name == "Pantalon basico delantero"
    assert result.pieces[1].name == "Pantalon basico posterior"


def test_universal_generator_keeps_basic_skirt_compatibility() -> None:
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

    assert result.garment_code == "falda_basica"
    assert result.draft_class_name == "BasicSkirtDraft"
    assert result.piece_count >= 1
