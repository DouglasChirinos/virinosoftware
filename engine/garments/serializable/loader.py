"""Load serializable garment definitions from dict or JSON."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .definition import (
    SerializableGarmentDefinition,
    SerializableLineDefinition,
    SerializableMeasurementDefinition,
    SerializablePieceDefinition,
    SerializablePointDefinition,
)
from .validation import SerializableGarmentValidationError


def load_garment_definition_from_json(path: str | Path) -> SerializableGarmentDefinition:
    """Load and validate a garment definition from a JSON file."""

    json_path = Path(path)
    try:
        payload = json.loads(json_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SerializableGarmentValidationError(f"JSON file not found: {json_path}") from exc
    except json.JSONDecodeError as exc:
        raise SerializableGarmentValidationError(f"Invalid JSON file: {json_path}") from exc
    return load_garment_definition_from_dict(payload)


def load_garment_definition_from_dict(payload: dict[str, Any]) -> SerializableGarmentDefinition:
    """Load and validate a garment definition from a dictionary."""

    if not isinstance(payload, dict):
        raise SerializableGarmentValidationError("garment payload must be a dictionary")

    measurements = tuple(
        SerializableMeasurementDefinition(
            name=item["name"],
            label=item.get("label", item["name"]),
            unit=item.get("unit", "cm"),
            default=item.get("default"),
            required=item.get("required", True),
        )
        for item in _require_list(payload, "measurements")
    )

    pieces = tuple(_load_piece(item) for item in _require_list(payload, "pieces"))

    definition = SerializableGarmentDefinition(
        code=payload["code"],
        name=payload["name"],
        version=payload.get("version", "0.1"),
        measurements=measurements,
        pieces=pieces,
        metadata=payload.get("metadata", {}),
    )
    definition.validate()
    return definition


def _load_piece(payload: dict[str, Any]) -> SerializablePieceDefinition:
    if not isinstance(payload, dict):
        raise SerializableGarmentValidationError("piece payload must be a dictionary")

    points_payload = payload.get("points")
    if not isinstance(points_payload, dict):
        raise SerializableGarmentValidationError("piece.points must be a dictionary")

    points = tuple(
        SerializablePointDefinition(name=name, coordinates=_as_coordinates(value, name))
        for name, value in points_payload.items()
    )

    lines = tuple(_load_line(value) for value in _require_list(payload, "lines"))

    return SerializablePieceDefinition(
        name=payload["name"],
        points=points,
        lines=lines,
        metadata=payload.get("metadata", {}),
    )


def _load_line(value: Any) -> SerializableLineDefinition:
    if isinstance(value, list) and len(value) == 2:
        return SerializableLineDefinition(start=value[0], end=value[1])
    if isinstance(value, dict):
        return SerializableLineDefinition(
            start=value["start"],
            end=value["end"],
            kind=value.get("kind", "line"),
        )
    raise SerializableGarmentValidationError(
        "line must be a two-item list or a dictionary with start/end"
    )


def _as_coordinates(value: Any, point_name: str) -> tuple[int | float | str, int | float | str]:
    if not isinstance(value, list) or len(value) != 2:
        raise SerializableGarmentValidationError(
            f"point '{point_name}' coordinates must be a two-item list"
        )
    return (value[0], value[1])


def _require_list(payload: dict[str, Any], key: str) -> list[Any]:
    value = payload.get(key)
    if not isinstance(value, list):
        raise SerializableGarmentValidationError(f"{key} must be a list")
    return value
