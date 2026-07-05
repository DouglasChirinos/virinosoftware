from pathlib import Path

import pytest

from engine.garments.serializable import (
    FormulaEvaluationError,
    SerializableGeometryGenerationError,
    build_formula_context,
    evaluate_formula,
    generate_geometry_from_definition,
    load_garment_definition_from_dict,
    load_garment_definition_from_json,
)


def test_evaluates_basic_formula_with_measurement():
    assert evaluate_formula("waist / 4", {"waist": 84}) == 21.0


def test_evaluates_formula_with_ease_variable():
    assert evaluate_formula("hip / 4 + ease", {"hip": 104, "ease": 2}) == 28.0


def test_evaluates_plain_measurement_name():
    assert evaluate_formula("outseam", {"outseam": 45}) == 45.0


@pytest.mark.parametrize(
    "expression",
    [
        "__import__('os').system('echo bad')",
        "open('/tmp/x')",
        "waist.__class__",
        "items[0]",
        "waist ** 2",
    ],
)
def test_rejects_unsafe_or_unsupported_expressions(expression):
    with pytest.raises(FormulaEvaluationError):
        evaluate_formula(expression, {"waist": 84, "items": 1})


def test_rejects_unknown_variable():
    with pytest.raises(FormulaEvaluationError, match="unknown variable"):
        evaluate_formula("hip / 4", {"waist": 84})


def test_rejects_division_by_zero():
    with pytest.raises(FormulaEvaluationError, match="division by zero"):
        evaluate_formula("waist / divisor", {"waist": 84, "divisor": 0})


def test_build_formula_context_uses_defaults_and_runtime_overrides():
    definition = load_garment_definition_from_json(Path("examples/garments/short_basico.json"))

    context = build_formula_context(
        definition,
        measurement_values={"waist": 88},
        extra_variables={"ease": 2},
    )

    assert context["waist"] == 88.0
    assert context["hip"] == 104.0
    assert context["outseam"] == 45.0
    assert context["ease"] == 2.0


def test_generates_geometry_from_short_basico_json_defaults():
    definition = load_garment_definition_from_json(Path("examples/garments/short_basico.json"))

    pattern = generate_geometry_from_definition(definition)

    assert pattern.garment_code == "short_basico"
    assert pattern.garment_name == "Short basico"
    assert pattern.piece_count == 1
    piece = pattern.pieces[0]
    points = {point.name: point for point in piece.points}
    assert points["A"].x == 0.0
    assert points["A"].y == 0.0
    assert points["B"].x == 21.0
    assert points["B"].y == 0.0
    assert points["C"].x == 26.0
    assert points["C"].y == 45.0
    assert len(piece.lines) == 4


def test_generates_geometry_with_ease_formula():
    payload = {
        "code": "top_basico",
        "name": "Top basico",
        "measurements": [
            {"name": "chest", "label": "Pecho", "default": 96},
            {"name": "length", "label": "Largo", "default": 60},
        ],
        "pieces": [
            {
                "name": "Top delantero",
                "points": {
                    "A": [0, 0],
                    "B": ["chest / 4 + ease", 0],
                    "C": ["chest / 4 + ease", "length"],
                    "D": [0, "length"],
                },
                "lines": [["A", "B"], ["B", "C"], ["C", "D"], ["D", "A"]],
            }
        ],
    }
    definition = load_garment_definition_from_dict(payload)

    pattern = generate_geometry_from_definition(definition, extra_variables={"ease": 3})

    points = {point.name: point for point in pattern.pieces[0].points}
    assert points["B"].x == 27.0
    assert points["C"].y == 60.0


def test_generating_geometry_requires_missing_required_measurement():
    payload = {
        "code": "pieza_test",
        "name": "Pieza test",
        "measurements": [{"name": "waist", "label": "Cintura"}],
        "pieces": [
            {
                "name": "Pieza",
                "points": {"A": [0, 0], "B": ["waist", 0]},
                "lines": [["A", "B"]],
            }
        ],
    }
    definition = load_garment_definition_from_dict(payload)

    with pytest.raises(SerializableGeometryGenerationError, match="missing required"):
        generate_geometry_from_definition(definition)


def test_generating_geometry_rejects_unknown_measurement_override():
    definition = load_garment_definition_from_json(Path("examples/garments/short_basico.json"))

    with pytest.raises(SerializableGeometryGenerationError, match="unknown measurement"):
        generate_geometry_from_definition(definition, measurement_values={"unknown": 10})
