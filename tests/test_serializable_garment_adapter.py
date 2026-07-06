from pathlib import Path

from engine.garments.serializable.adapter import (
    SerializableGarmentDraft,
    create_serializable_draft_from_json,
    generate_serializable_pattern_from_json,
    summarize_serializable_result,
)


DEFINITION_PATH = Path("examples/garments/short_basico.json")


def test_create_serializable_draft_from_json_exposes_contract_metadata():
    draft = create_serializable_draft_from_json(DEFINITION_PATH)

    assert isinstance(draft, SerializableGarmentDraft)
    assert draft.metadata.code == "short_basico"
    assert draft.metadata.name == "Short basico"
    assert [item.name for item in draft.measurement_requirements] == [
        "waist",
        "hip",
        "outseam",
        "inseam",
    ]


def test_generate_serializable_pattern_from_json_returns_engine_friendly_result():
    result = generate_serializable_pattern_from_json(
        DEFINITION_PATH,
        {
            "waist": 84,
            "hip": 104,
            "outseam": 45,
            "inseam": 20,
        },
    )

    assert result.garment_code == "short_basico"
    assert result.garment_name == "Short basico"
    assert result.draft_class == "SerializableGarmentDraft"
    assert result.piece_count == 2
    assert result.pieces[0].name == "Short basico delantero"
    assert result.pieces[0].points["B"] == (21.0, 0.0)
    assert result.pieces[0].points["C"] == (26.0, 45.0)
    assert result.pieces[0].line_count() == 4


def test_summarize_serializable_result_matches_universal_cli_style():
    result = generate_serializable_pattern_from_json(
        DEFINITION_PATH,
        {
            "waist": 84,
            "hip": 104,
            "outseam": 45,
            "inseam": 20,
        },
    )

    assert summarize_serializable_result(result) == [
        "GARMENT_CODE: short_basico",
        "GARMENT_NAME: Short basico",
        "DRAFT_CLASS: SerializableGarmentDraft",
        "PIECE_COUNT: 2",
        "PIECE_1: Short basico delantero lines=4",
        "PIECE_2: Short basico posterior lines=4",
    ]
