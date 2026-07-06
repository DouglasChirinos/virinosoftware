from pathlib import Path

import pytest

from engine.garments.serializable import (
    SerializableGarmentValidationError,
    load_garment_definition_from_dict,
    load_garment_definition_from_json,
)


VALID_PAYLOAD = {
    "code": "short_basico",
    "name": "Short basico",
    "measurements": [
        {"name": "waist", "label": "Cintura", "unit": "cm", "default": 84},
        {"name": "hip", "label": "Cadera", "unit": "cm", "default": 104},
    ],
    "pieces": [
        {
            "name": "Short delantero",
            "points": {
                "A": [0, 0],
                "B": ["waist / 4", 0],
                "C": ["hip / 4", 45],
            },
            "lines": [["A", "B"], ["B", "C"], ["C", "A"]],
        }
    ],
}


def test_load_serializable_garment_from_dict():
    definition = load_garment_definition_from_dict(VALID_PAYLOAD)

    assert definition.code == "short_basico"
    assert definition.name == "Short basico"
    assert definition.measurement_names == ("waist", "hip")
    assert definition.piece_names == ("Short delantero",)
    assert definition.pieces[0].points[1].coordinates == ("waist / 4", 0)


def test_load_serializable_garment_from_json_example():
    definition = load_garment_definition_from_json(
        Path("examples/garments/short_basico.json")
    )

    assert definition.code == "short_basico"
    assert definition.version == "0.2.1-mvp"
    assert len(definition.measurements) == 4
    assert len(definition.pieces) == 2


def test_rejects_duplicated_measurements():
    payload = {
        **VALID_PAYLOAD,
        "measurements": [
            {"name": "waist", "label": "Cintura"},
            {"name": "waist", "label": "Cintura duplicada"},
        ],
    }

    with pytest.raises(SerializableGarmentValidationError, match="duplicated measurement"):
        load_garment_definition_from_dict(payload)


def test_rejects_lines_with_undefined_points():
    payload = {
        **VALID_PAYLOAD,
        "pieces": [
            {
                "name": "Short delantero",
                "points": {"A": [0, 0], "B": [10, 0]},
                "lines": [["A", "Z"]],
            }
        ],
    }

    with pytest.raises(SerializableGarmentValidationError, match="undefined point"):
        load_garment_definition_from_dict(payload)


def test_rejects_invalid_garment_code():
    payload = {**VALID_PAYLOAD, "code": "123-short"}

    with pytest.raises(SerializableGarmentValidationError, match="identifier-like"):
        load_garment_definition_from_dict(payload)
