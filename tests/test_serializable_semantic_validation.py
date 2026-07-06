from pathlib import Path
import subprocess
import sys

import pytest

from engine.garments.serializable import (
    SerializableGarmentDefinition,
    SerializableGarmentSemanticValidationError,
    SerializableLineDefinition,
    SerializableMeasurementDefinition,
    SerializablePieceDefinition,
    SerializablePointDefinition,
    validate_garment_definition_file,
    validate_garment_definition_semantics,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_short_basico_json_passes_semantic_validation() -> None:
    report = validate_garment_definition_file(
        PROJECT_ROOT / "examples" / "garments" / "short_basico.json"
    )

    assert report.code == "short_basico"
    assert report.measurement_count == 4
    assert report.piece_count == 2
    assert report.formula_count >= 1


def test_falda_evase_json_passes_semantic_validation() -> None:
    report = validate_garment_definition_file(
        PROJECT_ROOT / "examples" / "garments" / "falda_evase.json"
    )

    assert report.code == "falda_evase"
    assert report.measurement_count == 4
    assert report.piece_count == 2
    assert report.formula_count == 10


def test_semantic_validation_rejects_undeclared_formula_measurement() -> None:
    definition = _definition_with_piece(
        SerializablePieceDefinition(
            name="Pieza con formula invalida",
            points=(
                SerializablePointDefinition("A", (0, 0)),
                SerializablePointDefinition("B", ("unknown_measure / 4", 0)),
                SerializablePointDefinition("C", (10, 10)),
            ),
            lines=(
                SerializableLineDefinition("A", "B"),
                SerializableLineDefinition("B", "C"),
                SerializableLineDefinition("C", "A"),
            ),
        )
    )

    with pytest.raises(SerializableGarmentSemanticValidationError):
        validate_garment_definition_semantics(definition)


def test_semantic_validation_rejects_orphan_point() -> None:
    definition = _definition_with_piece(
        SerializablePieceDefinition(
            name="Pieza con punto huerfano",
            points=(
                SerializablePointDefinition("A", (0, 0)),
                SerializablePointDefinition("B", (10, 0)),
                SerializablePointDefinition("C", (10, 10)),
                SerializablePointDefinition("D", (0, 10)),
            ),
            lines=(
                SerializableLineDefinition("A", "B"),
                SerializableLineDefinition("B", "C"),
            ),
        )
    )

    with pytest.raises(SerializableGarmentSemanticValidationError):
        validate_garment_definition_semantics(definition)


def test_semantic_validation_rejects_duplicate_line_even_if_reversed() -> None:
    definition = _definition_with_piece(
        SerializablePieceDefinition(
            name="Pieza con linea duplicada",
            points=(
                SerializablePointDefinition("A", (0, 0)),
                SerializablePointDefinition("B", (10, 0)),
                SerializablePointDefinition("C", (10, 10)),
            ),
            lines=(
                SerializableLineDefinition("A", "B"),
                SerializableLineDefinition("B", "A"),
                SerializableLineDefinition("B", "C"),
                SerializableLineDefinition("C", "A"),
            ),
        )
    )

    with pytest.raises(SerializableGarmentSemanticValidationError):
        validate_garment_definition_semantics(definition)


def test_validate_garment_definition_cli_validates_current_json_definitions() -> None:
    result = subprocess.run(
        [
            sys.executable,
            "scripts/validate_garment_definition.py",
            "--definition",
            "examples/garments/short_basico.json",
            "--definition",
            "examples/garments/falda_evase.json",
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "VALID_DEFINITION: examples/garments/short_basico.json" in result.stdout
    assert "VALID_DEFINITION: examples/garments/falda_evase.json" in result.stdout


def _definition_with_piece(piece: SerializablePieceDefinition) -> SerializableGarmentDefinition:
    return SerializableGarmentDefinition(
        code="test_semantic_garment",
        name="Test semantic garment",
        measurements=(
            SerializableMeasurementDefinition("waist", "Cintura"),
            SerializableMeasurementDefinition("hip", "Cadera"),
        ),
        pieces=(piece,),
    )
