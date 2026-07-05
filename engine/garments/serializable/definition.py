"""Dataclass contract for serializable garment definitions.

This module intentionally validates only the first DSL contract. It does not
interpret formulas or generate geometry yet. Formula evaluation belongs to the
next phase.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .validation import SerializableGarmentValidationError


PointCoordinate = int | float | str
PointCoordinates = tuple[PointCoordinate, PointCoordinate]


@dataclass(frozen=True)
class SerializableMeasurementDefinition:
    """Measurement required by a serializable garment definition."""

    name: str
    label: str
    unit: str = "cm"
    default: float | None = None
    required: bool = True

    def validate(self) -> None:
        _require_identifier(self.name, "measurement.name")
        _require_non_empty(self.label, "measurement.label")
        _require_non_empty(self.unit, "measurement.unit")
        if self.default is not None and not isinstance(self.default, (int, float)):
            raise SerializableGarmentValidationError(
                f"measurement '{self.name}' default must be numeric"
            )


@dataclass(frozen=True)
class SerializablePointDefinition:
    """Named point for a serializable piece.

    Coordinates can be numbers or formula strings. Formula strings are only
    stored and validated as non-empty values in this phase.
    """

    name: str
    coordinates: PointCoordinates

    def validate(self) -> None:
        _require_identifier(self.name, "point.name")
        if not isinstance(self.coordinates, tuple) or len(self.coordinates) != 2:
            raise SerializableGarmentValidationError(
                f"point '{self.name}' coordinates must be a tuple of two values"
            )
        for coordinate in self.coordinates:
            if isinstance(coordinate, str):
                _require_non_empty(coordinate, f"point '{self.name}' coordinate")
            elif not isinstance(coordinate, (int, float)):
                raise SerializableGarmentValidationError(
                    f"point '{self.name}' coordinate must be numeric or formula string"
                )


@dataclass(frozen=True)
class SerializableLineDefinition:
    """Line between two named points."""

    start: str
    end: str
    kind: str = "line"

    def validate(self, point_names: set[str]) -> None:
        _require_identifier(self.start, "line.start")
        _require_identifier(self.end, "line.end")
        _require_non_empty(self.kind, "line.kind")
        if self.start == self.end:
            raise SerializableGarmentValidationError("line start and end cannot be equal")
        missing = [point for point in (self.start, self.end) if point not in point_names]
        if missing:
            raise SerializableGarmentValidationError(
                f"line references undefined point(s): {', '.join(missing)}"
            )


@dataclass(frozen=True)
class SerializablePieceDefinition:
    """Serializable piece composed of points and lines."""

    name: str
    points: tuple[SerializablePointDefinition, ...]
    lines: tuple[SerializableLineDefinition, ...]
    metadata: dict[str, Any] = field(default_factory=dict)

    def validate(self) -> None:
        _require_non_empty(self.name, "piece.name")
        if not self.points:
            raise SerializableGarmentValidationError(f"piece '{self.name}' must define points")
        point_names: set[str] = set()
        for point in self.points:
            point.validate()
            if point.name in point_names:
                raise SerializableGarmentValidationError(
                    f"piece '{self.name}' has duplicated point '{point.name}'"
                )
            point_names.add(point.name)
        for line in self.lines:
            line.validate(point_names)


@dataclass(frozen=True)
class SerializableGarmentDefinition:
    """Top-level serializable garment definition.

    The contract is intentionally strict enough to keep future generation safe,
    but small enough to avoid prematurely designing the full DSL engine.
    """

    code: str
    name: str
    measurements: tuple[SerializableMeasurementDefinition, ...]
    pieces: tuple[SerializablePieceDefinition, ...]
    version: str = "0.1"
    metadata: dict[str, Any] = field(default_factory=dict)

    def validate(self) -> None:
        _require_identifier(self.code, "garment.code")
        _require_non_empty(self.name, "garment.name")
        _require_non_empty(self.version, "garment.version")
        if not self.measurements:
            raise SerializableGarmentValidationError("garment must define measurements")
        if not self.pieces:
            raise SerializableGarmentValidationError("garment must define pieces")

        measurement_names: set[str] = set()
        for measurement in self.measurements:
            measurement.validate()
            if measurement.name in measurement_names:
                raise SerializableGarmentValidationError(
                    f"duplicated measurement '{measurement.name}'"
                )
            measurement_names.add(measurement.name)

        piece_names: set[str] = set()
        for piece in self.pieces:
            piece.validate()
            if piece.name in piece_names:
                raise SerializableGarmentValidationError(
                    f"duplicated piece '{piece.name}'"
                )
            piece_names.add(piece.name)

    @property
    def measurement_names(self) -> tuple[str, ...]:
        return tuple(measurement.name for measurement in self.measurements)

    @property
    def piece_names(self) -> tuple[str, ...]:
        return tuple(piece.name for piece in self.pieces)


def _require_non_empty(value: str, field_name: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise SerializableGarmentValidationError(f"{field_name} must be a non-empty string")


def _require_identifier(value: str, field_name: str) -> None:
    _require_non_empty(value, field_name)
    if not value.replace("_", "").isalnum() or value[0].isdigit():
        raise SerializableGarmentValidationError(
            f"{field_name} must be an identifier-like string"
        )

# ---------------------------------------------------------------------------
# Compatibility API for Fase 28
# ---------------------------------------------------------------------------

def _serializable_measurement_from_dict(raw):
    return SerializableMeasurementDefinition(
        name=raw["name"],
        label=raw.get("label", raw["name"]),
        unit=raw.get("unit", "cm"),
        default=raw.get("default"),
        required=raw.get("required", True),
    )


def _serializable_point_from_dict(name, coordinates):
    return SerializablePointDefinition(
        name=name,
        coordinates=tuple(coordinates),
    )


def _serializable_line_from_raw(raw):
    if isinstance(raw, dict):
        return SerializableLineDefinition(
            start=raw["start"],
            end=raw["end"],
            kind=raw.get("kind", "line"),
        )

    if isinstance(raw, (list, tuple)) and len(raw) == 2:
        return SerializableLineDefinition(
            start=raw[0],
            end=raw[1],
        )

    if isinstance(raw, (list, tuple)) and len(raw) == 3:
        return SerializableLineDefinition(
            start=raw[0],
            end=raw[1],
            kind=raw[2],
        )

    raise SerializableGarmentValidationError(
        f"invalid line definition: {raw!r}"
    )


def _serializable_piece_from_dict(raw):
    raw_points = raw.get("points", {})

    if isinstance(raw_points, dict):
        points = tuple(
            _serializable_point_from_dict(name, coordinates)
            for name, coordinates in raw_points.items()
        )
    else:
        points = tuple(
            SerializablePointDefinition(
                name=item["name"],
                coordinates=tuple(item["coordinates"]),
            )
            for item in raw_points
        )

    lines = tuple(_serializable_line_from_raw(item) for item in raw.get("lines", []))

    return SerializablePieceDefinition(
        name=raw["name"],
        points=points,
        lines=lines,
        metadata=raw.get("metadata", {}),
    )


def _serializable_garment_from_dict(raw):
    garment = SerializableGarmentDefinition(
        code=raw["code"],
        name=raw["name"],
        measurements=tuple(
            _serializable_measurement_from_dict(item)
            for item in raw.get("measurements", [])
        ),
        pieces=tuple(
            _serializable_piece_from_dict(item)
            for item in raw.get("pieces", [])
        ),
        version=raw.get("version", "0.1"),
        metadata=raw.get("metadata", {}),
    )
    garment.validate()
    return garment


SerializableGarmentDefinition.from_dict = staticmethod(_serializable_garment_from_dict)
