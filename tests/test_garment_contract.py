"""Tests for Fase 20 garment base contract."""

from __future__ import annotations

import pytest

from engine.garments import GarmentDraft, GarmentMetadata, MeasurementRequirement
from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements import BodyMeasurements


def test_measurement_requirement_defaults() -> None:
    requirement = MeasurementRequirement(name="waist", label="Cintura")

    assert requirement.name == "waist"
    assert requirement.label == "Cintura"
    assert requirement.unit == "cm"
    assert requirement.required is True


def test_basic_skirt_declares_garment_contract() -> None:
    draft = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60))

    assert isinstance(draft, GarmentDraft)
    assert isinstance(draft.metadata, GarmentMetadata)
    assert draft.code == "falda_basica"
    assert draft.name == "Falda basica"

    required_names = {item.name for item in draft.required_measurements}

    assert {"waist", "hip", "skirt_length"}.issubset(required_names)
    assert "ease" in required_names
    assert "hip_depth" in required_names


def test_basic_skirt_required_measurement_validation_passes() -> None:
    draft = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60))

    draft.validate_required_measurements(
        {
            "waist": 72,
            "hip": 98,
            "skirt_length": 60,
        }
    )


def test_basic_skirt_required_measurement_validation_fails() -> None:
    draft = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60))

    with pytest.raises(ValueError) as exc:
        draft.validate_required_measurements({"waist": 72})

    message = str(exc.value)

    assert "falda_basica" in message
    assert "hip" in message
    assert "skirt_length" in message
