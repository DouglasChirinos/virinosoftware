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
