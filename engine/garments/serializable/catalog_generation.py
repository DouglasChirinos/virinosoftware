"""Catalog-wide generation pipeline for serializable garment definitions.

This module generates all JSON garment definitions discovered in a catalog
folder using the default measurements declared in each definition. It is a
smoke-test style production pipeline: if a JSON enters the catalog, it must be
semantically valid and capable of generating resolved geometry.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .catalog_quality import (
    SerializableCatalogQualityError,
    discover_garment_definition_files,
)
from .geometry import GeneratedSerializablePattern, generate_geometry_from_definition
from .loader import load_garment_definition_from_json
from .semantic_validation import validate_garment_definition_file


class SerializableCatalogGenerationError(SerializableCatalogQualityError):
    """Raised when catalog-wide serializable generation fails."""


@dataclass(frozen=True)
class CatalogGeneratedDefinitionReport:
    """Generation report for one serializable garment JSON file."""

    path: Path
    code: str
    name: str
    piece_count: int
    point_count: int
    line_count: int
    variable_count: int


@dataclass(frozen=True)
class CatalogGenerationReport:
    """Generation report for a serializable garment JSON catalog."""

    definitions_dir: Path | None
    definition_reports: tuple[CatalogGeneratedDefinitionReport, ...]

    @property
    def definition_count(self) -> int:
        return len(self.definition_reports)

    @property
    def generated_piece_count(self) -> int:
        return sum(report.piece_count for report in self.definition_reports)

    @property
    def generated_point_count(self) -> int:
        return sum(report.point_count for report in self.definition_reports)

    @property
    def generated_line_count(self) -> int:
        return sum(report.line_count for report in self.definition_reports)


def generate_serializable_catalog(
    definitions_dir: str | Path,
) -> CatalogGenerationReport:
    """Generate every JSON garment definition found in a catalog directory."""

    directory = Path(definitions_dir)
    return CatalogGenerationReport(
        definitions_dir=directory,
        definition_reports=generate_serializable_catalog_files(
            discover_garment_definition_files(directory)
        ),
    )


def generate_serializable_catalog_files(
    paths: Iterable[str | Path],
) -> tuple[CatalogGeneratedDefinitionReport, ...]:
    """Generate an explicit list of serializable garment JSON definitions."""

    resolved_paths = tuple(Path(path) for path in paths)
    if not resolved_paths:
        raise SerializableCatalogGenerationError(
            "at least one garment definition path is required"
        )

    reports = tuple(_generate_definition(path) for path in resolved_paths)
    duplicated_codes = _find_duplicated_codes(report.code for report in reports)
    if duplicated_codes:
        raise SerializableCatalogGenerationError(
            "duplicated garment code(s): " + ", ".join(duplicated_codes)
        )
    return reports


def _generate_definition(path: Path) -> CatalogGeneratedDefinitionReport:
    validate_garment_definition_file(path)
    definition = load_garment_definition_from_json(path)
    generated_pattern = generate_geometry_from_definition(definition)
    piece_count, point_count, line_count = _summarize_generated_pattern(generated_pattern)

    if piece_count <= 0:
        raise SerializableCatalogGenerationError(
            f"definition '{path}' generated no pieces"
        )
    if point_count <= 0:
        raise SerializableCatalogGenerationError(
            f"definition '{path}' generated no points"
        )
    if line_count <= 0:
        raise SerializableCatalogGenerationError(
            f"definition '{path}' generated no lines"
        )

    return CatalogGeneratedDefinitionReport(
        path=path,
        code=generated_pattern.garment_code,
        name=generated_pattern.garment_name,
        piece_count=piece_count,
        point_count=point_count,
        line_count=line_count,
        variable_count=len(generated_pattern.variables),
    )


def _summarize_generated_pattern(
    generated_pattern: GeneratedSerializablePattern,
) -> tuple[int, int, int]:
    piece_count = len(generated_pattern.pieces)
    point_count = 0
    line_count = 0

    for piece in generated_pattern.pieces:
        point_count += len(piece.points)
        line_count += len(piece.lines)

    return piece_count, point_count, line_count


def _find_duplicated_codes(codes: Iterable[str]) -> tuple[str, ...]:
    seen: set[str] = set()
    duplicated: set[str] = set()
    for code in codes:
        if code in seen:
            duplicated.add(code)
        seen.add(code)
    return tuple(sorted(duplicated))
