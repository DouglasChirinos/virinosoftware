"""Catalog helpers for serializable JSON garment definitions.

This module keeps JSON garments discoverable by code and exposes them as
runtime garment draft classes compatible with the universal registry.
"""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path
from typing import Any

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement
from engine.garments.serializable.adapter import (
    create_serializable_draft,
    create_serializable_draft_from_json,
    load_definition_from_json,
)


PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SERIALIZABLE_GARMENT_DIR = PROJECT_ROOT / "examples" / "garments"


def get_serializable_garment_path(code: str) -> Path:
    """Return the JSON definition path for a serializable garment code."""

    normalized = code.strip()
    if not normalized:
        raise ValueError("serializable garment code cannot be empty")
    return DEFAULT_SERIALIZABLE_GARMENT_DIR / f"{normalized}.json"


def load_serializable_definition_by_code(code: str):
    """Load and validate a serializable garment definition by code."""

    return load_definition_from_json(get_serializable_garment_path(code))


def create_serializable_draft_by_code(code: str):
    """Create a SerializableGarmentDraft from a JSON garment code."""

    return create_serializable_draft_from_json(get_serializable_garment_path(code))


def list_serializable_garment_codes() -> tuple[str, ...]:
    """List available serializable garment codes."""

    if not DEFAULT_SERIALIZABLE_GARMENT_DIR.exists():
        return tuple()

    return tuple(
        sorted(path.stem for path in DEFAULT_SERIALIZABLE_GARMENT_DIR.glob("*.json"))
    )


def _class_name_from_code(code: str) -> str:
    parts = [part for part in code.strip().split("_") if part]
    if not parts:
        raise ValueError("serializable garment code cannot be empty")
    return "".join(part.capitalize() for part in parts) + "SerializableDraft"


def _measurement_mapping(measurements: Any) -> dict[str, Any]:
    if isinstance(measurements, Mapping):
        return dict(measurements)

    if hasattr(measurements, "__dict__"):
        return {
            key: value
            for key, value in vars(measurements).items()
            if not key.startswith("_") and value is not None
        }

    raise TypeError("measurements must be a mapping or measurement object")


def create_serializable_draft_class(code: str) -> type[GarmentDraft]:
    """Create a universal-registry draft class backed by one JSON definition."""

    definition = load_serializable_definition_by_code(code)
    delegate = create_serializable_draft(definition)
    class_name = _class_name_from_code(definition.code)

    required_measurements = tuple(
        MeasurementRequirement(
            name=item.name,
            label=item.label,
            unit=item.unit,
            required=item.required,
            description=item.description,
        )
        for item in delegate.measurement_requirements
    )

    metadata = GarmentMetadata(
        code=definition.code,
        name=definition.name,
        description="Prenda definida mediante DSL serializable JSON.",
    )

    def __init__(self, measurements: Any) -> None:
        self.measurements = _measurement_mapping(measurements)
        self._draft = create_serializable_draft_by_code(definition.code)

    def validate_required_measurements(self, measurements: Mapping[str, Any]) -> None:
        missing = [
            requirement.name
            for requirement in required_measurements
            if requirement.required and requirement.name not in measurements
        ]
        if missing:
            joined = ", ".join(missing)
            raise ValueError(
                f"Missing required measurements for {definition.code}: {joined}"
            )

    def draft(self):
        """Generate pieces from the JSON-backed serializable draft."""

        return self._draft.generate(self.measurements)

    namespace = {
        "__doc__": f"Universal registry adapter for {definition.code} JSON garment.",
        "__module__": __name__,
        "metadata": metadata,
        "required_measurements": required_measurements,
        "__init__": __init__,
        "validate_required_measurements": validate_required_measurements,
        "draft": draft,
    }

    return type(class_name, (GarmentDraft,), namespace)


def iter_serializable_garment_draft_classes() -> tuple[type[GarmentDraft], ...]:
    """Return dynamic draft classes for every JSON garment definition."""

    return tuple(
        create_serializable_draft_class(code)
        for code in list_serializable_garment_codes()
    )
