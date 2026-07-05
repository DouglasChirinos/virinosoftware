"""Semantic validation for serializable garment DSL definitions.

This layer validates the quality of a garment JSON definition before geometry
is generated. Structural validation remains in ``definition.py`` and
``loader.py``; this module focuses on semantic consistency.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .definition import SerializableGarmentDefinition, SerializablePieceDefinition
from .formula import FormulaEvaluationError, evaluate_formula
from .loader import load_garment_definition_from_json
from .validation import SerializableGarmentValidationError


class SerializableGarmentSemanticValidationError(SerializableGarmentValidationError):
    """Raised when a serializable garment definition is semantically invalid."""


@dataclass(frozen=True)
class PieceSemanticReport:
    """Semantic validation summary for one piece."""

    name: str
    point_count: int
    line_count: int
    formula_count: int


@dataclass(frozen=True)
class GarmentSemanticReport:
    """Semantic validation summary for a full garment definition."""

    code: str
    name: str
    measurement_count: int
    piece_reports: tuple[PieceSemanticReport, ...]

    @property
    def piece_count(self) -> int:
        return len(self.piece_reports)

    @property
    def formula_count(self) -> int:
        return sum(report.formula_count for report in self.piece_reports)


_ALLOWED_AST_NODES: tuple[type[ast.AST], ...] = (
    ast.Expression,
    ast.BinOp,
    ast.UnaryOp,
    ast.Constant,
    ast.Name,
    ast.Load,
    ast.Add,
    ast.Sub,
    ast.Mult,
    ast.Div,
    ast.UAdd,
    ast.USub,
)


def validate_garment_definition_semantics(
    definition: SerializableGarmentDefinition,
) -> GarmentSemanticReport:
    """Validate semantic consistency for a serializable garment definition.

    Checks implemented in Fase 34:
    - top-level structural contract is still valid;
    - each formula references only declared measurements;
    - formula syntax uses only the safe arithmetic DSL;
    - each line references existing points;
    - duplicate lines are rejected, including reversed duplicates;
    - orphan points are rejected.
    """

    definition.validate()

    measurement_names = set(definition.measurement_names)
    if not measurement_names:
        raise SerializableGarmentSemanticValidationError(
            f"garment '{definition.code}' must declare at least one measurement"
        )

    piece_reports = tuple(
        _validate_piece_semantics(piece, measurement_names)
        for piece in definition.pieces
    )

    return GarmentSemanticReport(
        code=definition.code,
        name=definition.name,
        measurement_count=len(measurement_names),
        piece_reports=piece_reports,
    )


def validate_garment_definition_file(path: str | Path) -> GarmentSemanticReport:
    """Load a JSON definition and validate its semantic DSL contract."""

    definition = load_garment_definition_from_json(path)
    return validate_garment_definition_semantics(definition)


def validate_garment_definition_files(
    paths: Iterable[str | Path],
) -> tuple[GarmentSemanticReport, ...]:
    """Validate several JSON definition files."""

    reports = tuple(validate_garment_definition_file(path) for path in paths)
    if not reports:
        raise SerializableGarmentSemanticValidationError(
            "at least one garment definition path is required"
        )
    return reports


def _validate_piece_semantics(
    piece: SerializablePieceDefinition,
    measurement_names: set[str],
) -> PieceSemanticReport:
    point_names = {point.name for point in piece.points}
    if len(point_names) != len(piece.points):
        raise SerializableGarmentSemanticValidationError(
            f"piece '{piece.name}' has duplicated point names"
        )

    formula_count = 0
    for point in piece.points:
        for coordinate in point.coordinates:
            if isinstance(coordinate, str):
                formula_count += 1
                _validate_formula_expression(
                    expression=coordinate,
                    allowed_variables=measurement_names,
                    context=f"piece '{piece.name}' point '{point.name}'",
                )

    used_points: set[str] = set()
    seen_lines: set[tuple[str, str]] = set()
    for line in piece.lines:
        if line.start not in point_names or line.end not in point_names:
            missing = sorted(
                point for point in (line.start, line.end) if point not in point_names
            )
            raise SerializableGarmentSemanticValidationError(
                f"piece '{piece.name}' line references undefined point(s): "
                + ", ".join(missing)
            )

        normalized_line = tuple(sorted((line.start, line.end)))
        if normalized_line in seen_lines:
            raise SerializableGarmentSemanticValidationError(
                f"piece '{piece.name}' has duplicated line '{line.start}-{line.end}'"
            )
        seen_lines.add(normalized_line)
        used_points.update((line.start, line.end))

    orphan_points = sorted(point_names - used_points)
    if orphan_points:
        raise SerializableGarmentSemanticValidationError(
            f"piece '{piece.name}' has orphan point(s): " + ", ".join(orphan_points)
        )

    return PieceSemanticReport(
        name=piece.name,
        point_count=len(piece.points),
        line_count=len(piece.lines),
        formula_count=formula_count,
    )


def _validate_formula_expression(
    *, expression: str, allowed_variables: set[str], context: str
) -> None:
    if not expression.strip():
        raise SerializableGarmentSemanticValidationError(
            f"{context} has an empty formula expression"
        )

    try:
        tree = ast.parse(expression, mode="eval")
    except SyntaxError as exc:
        raise SerializableGarmentSemanticValidationError(
            f"{context} has invalid formula syntax: {expression}"
        ) from exc

    for node in ast.walk(tree):
        if not isinstance(node, _ALLOWED_AST_NODES):
            raise SerializableGarmentSemanticValidationError(
                f"{context} uses unsupported formula syntax: {expression}"
            )

    referenced_variables = {
        node.id for node in ast.walk(tree) if isinstance(node, ast.Name)
    }
    unknown_variables = sorted(referenced_variables - allowed_variables)
    if unknown_variables:
        raise SerializableGarmentSemanticValidationError(
            f"{context} formula references undeclared measurement(s): "
            + ", ".join(unknown_variables)
        )

    dummy_context = {name: 1.0 for name in allowed_variables}
    try:
        evaluate_formula(expression, dummy_context)
    except FormulaEvaluationError as exc:
        raise SerializableGarmentSemanticValidationError(
            f"{context} formula is not evaluable: {expression}"
        ) from exc
