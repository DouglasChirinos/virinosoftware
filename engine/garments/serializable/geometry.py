"""Geometry generation from serializable garment definitions.

This module turns the Fase 26 serializable contract into resolved points and
lines. It does not yet register JSON garments in the universal garment catalog
and it does not modify the GUI.
"""

from __future__ import annotations

from engine.garments.serializable.formula import evaluate_formula

from dataclasses import dataclass, field
from typing import Mapping

from .definition import SerializableGarmentDefinition, SerializablePieceDefinition
from .formula import FormulaEvaluationError, resolve_formula_value
from .validation import SerializableGarmentValidationError


Number = int | float


class SerializableGeometryGenerationError(ValueError):
    """Raised when serializable geometry cannot be generated."""


@dataclass(frozen=True)
class GeneratedSerializablePoint:
    """Resolved geometric point."""

    name: str
    x: float
    y: float


@dataclass(frozen=True)
class GeneratedSerializableLine:
    """Resolved line referencing two generated point names."""

    start: str
    end: str
    kind: str = "line"


@dataclass(frozen=True)
class GeneratedSerializablePiece:
    """Resolved piece built from points and lines."""

    name: str
    points: tuple[GeneratedSerializablePoint, ...]
    lines: tuple[GeneratedSerializableLine, ...]
    metadata: dict = field(default_factory=dict)


@dataclass(frozen=True)
class GeneratedSerializablePattern:
    """Resolved pattern generated from a serializable definition."""

    garment_code: str
    garment_name: str
    pieces: tuple[GeneratedSerializablePiece, ...]
    variables: dict[str, float]

    @property
    def piece_count(self) -> int:
        return len(self.pieces)


def build_formula_context(
    definition: SerializableGarmentDefinition,
    measurement_values: Mapping[str, Number] | None = None,
    extra_variables: Mapping[str, Number] | None = None,
) -> dict[str, float]:
    """Build the formula variable context for one serializable definition.

    Measurement defaults come from the JSON definition. Runtime measurement
    values override defaults. Extra variables are allowed for construction
    factors such as ``ease`` while the DSL evolves.
    """

    _validate_definition(definition)
    measurement_values = measurement_values or {}
    extra_variables = extra_variables or {}

    context: dict[str, float] = {}
    known_measurements = {measurement.name for measurement in definition.measurements}

    unknown_measurements = set(measurement_values) - known_measurements
    if unknown_measurements:
        names = ", ".join(sorted(unknown_measurements))
        raise SerializableGeometryGenerationError(f"unknown measurement value(s): {names}")

    for measurement in definition.measurements:
        raw_value = measurement_values.get(measurement.name, measurement.default)
        if raw_value is None and measurement.required:
            raise SerializableGeometryGenerationError(
                f"missing required measurement '{measurement.name}'"
            )
        if raw_value is not None:
            context[measurement.name] = _as_float(raw_value, measurement.name)

    for name, value in extra_variables.items():
        if not isinstance(name, str) or not name.strip():
            raise SerializableGeometryGenerationError("extra variable names must be non-empty")
        context[name] = _as_float(value, name)

    return context


def generate_geometry_from_definition(
    definition: SerializableGarmentDefinition,
    measurement_values: Mapping[str, Number] | None = None,
    extra_variables: Mapping[str, Number] | None = None,
) -> GeneratedSerializablePattern:
    """Generate resolved geometry from a serializable garment definition."""

    context = build_formula_context(definition, measurement_values, extra_variables)

    pieces = tuple(_generate_piece(piece, context) for piece in definition.pieces)
    return GeneratedSerializablePattern(
        garment_code=definition.code,
        garment_name=definition.name,
        pieces=pieces,
        variables=context,
    )


def _generate_piece(
    piece: SerializablePieceDefinition,
    variables: Mapping[str, float],
) -> GeneratedSerializablePiece:
    generated_points: list[GeneratedSerializablePoint] = []

    for point in piece.points:
        try:
            x = resolve_formula_value(point.coordinates[0], variables)
            y = resolve_formula_value(point.coordinates[1], variables)
        except FormulaEvaluationError as exc:
            raise SerializableGeometryGenerationError(
                f"cannot resolve point '{point.name}' in piece '{piece.name}': {exc}"
            ) from exc
        generated_points.append(GeneratedSerializablePoint(point.name, x, y))

    point_names = {point.name for point in generated_points}
    generated_lines: list[GeneratedSerializableLine] = []
    for line in piece.lines:
        if line.start not in point_names or line.end not in point_names:
            raise SerializableGeometryGenerationError(
                f"line references undefined point in piece '{piece.name}'"
            )
        generated_lines.append(GeneratedSerializableLine(line.start, line.end, line.kind))

    return GeneratedSerializablePiece(
        name=piece.name,
        points=tuple(generated_points),
        lines=tuple(generated_lines),
        metadata=dict(piece.metadata),
    )


def _validate_definition(definition: SerializableGarmentDefinition) -> None:
    try:
        definition.validate()
    except SerializableGarmentValidationError as exc:
        raise SerializableGeometryGenerationError(str(exc)) from exc


def _as_float(value: Number, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SerializableGeometryGenerationError(f"variable '{name}' must be numeric")
    return float(value)

def _resolve_coordinate_value(value, context):
    """Resolve numeric coordinates or formula-string coordinates."""
    if isinstance(value, (int, float)):
        return float(value)

    return float(evaluate_formula(value, context))

# ---------------------------------------------------------------------------
# Compatibility API for Fase 28
# ---------------------------------------------------------------------------

def generate_serializable_geometry(definition, measurements):
    """Generate numeric geometry from a serializable garment definition."""
    context = dict(measurements)
    generated_pieces = []

    for piece in definition.pieces:
        resolved_points = {}

        for point in piece.points:
            x_expr, y_expr = point.coordinates
            x_value = _resolve_coordinate_value(x_expr, context)
            y_value = _resolve_coordinate_value(y_expr, context)
            resolved_points[point.name] = (float(x_value), float(y_value))

        resolved_lines = []
        for line in piece.lines:
            resolved_lines.append((line.start, line.end))

        generated_pieces.append(
            GeneratedSerializablePiece(
                name=piece.name,
                points=resolved_points,
                lines=resolved_lines,
            )
        )

    return generated_pieces

