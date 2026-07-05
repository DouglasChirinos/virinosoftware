"""Registered serializable garment draft for short_basico."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement
from engine.garments.serializable.catalog import create_serializable_draft_by_code


class ShortBasicoSerializableDraft(GarmentDraft):
    """Adapter class that exposes short_basico JSON through the universal registry."""

    _delegate = create_serializable_draft_by_code("short_basico")

    metadata = GarmentMetadata(
        code="short_basico",
        name="Short basico",
        description="Short basico definido mediante DSL serializable JSON.",
    )

    required_measurements = tuple(
        MeasurementRequirement(
            name=item.name,
            label=item.label,
            unit=item.unit,
            required=item.required,
            description=item.description,
        )
        for item in _delegate.measurement_requirements
    )

    def __init__(self, measurements: Mapping[str, Any]) -> None:
        self.measurements = dict(measurements)
        self._draft = create_serializable_draft_by_code("short_basico")

    def validate_required_measurements(self, measurements: Mapping[str, Any]) -> None:
        missing = [
            requirement.name
            for requirement in self.required_measurements
            if requirement.required and requirement.name not in measurements
        ]

        if missing:
            joined = ", ".join(missing)
            raise ValueError(f"Missing required measurements for short_basico: {joined}")

    def draft(self):
        """Generate serializable short pieces using stored measurements."""
        return self._draft.generate(self.measurements)
