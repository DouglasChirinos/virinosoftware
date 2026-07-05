"""Catalog-wide quality pipeline for serializable garment definitions.

This module validates all JSON garment definitions in a catalog directory and
performs a smoke generation pass using the defaults declared in each JSON file.
It is intentionally catalog-oriented: new garments should be discovered without
editing the Makefile one by one.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .geometry import GeneratedSerializablePattern, generate_geometry_from_definition
from .loader import load_garment_definition_from_json
from .semantic_validation import GarmentSemanticReport, validate_garment_definition_file
from .validation import SerializableGarmentValidationError


class SerializableCatalogQualityError(SerializableGarmentValidationError):
    """Raised when the serializable garment catalog quality pipeline fails."""


@dataclass(frozen=True)
class CatalogDefinitionReport:
    """Quality report for one JSON garment definition."""

    path: Path
    semantic_report: GarmentSemanticReport
    generated_piece_count: int
    generated_point_count: int
    generated_line_count: int

    @property
    def code(self) -> str:
        return self.semantic_report.code

    @property
    def name(self) -> str:
        return self.semantic_report.name

    @property
    def measurement_count(self) -> int:
        return self.semantic_report.measurement_count

    @property
    def piece_count(self) -> int:
        return self.semantic_report.piece_count

    @property
    def formula_count(self) -> int:
        return self.semantic_report.formula_count


@dataclass(frozen=True)
class CatalogQualityReport:
    """Quality report for the full serializable JSON catalog."""

    definitions_dir: Path
    definition_reports: tuple[CatalogDefinitionReport, ...]

    @property
    def definition_count(self) -> int:
        return len(self.definition_reports)

    @property
    def generated_piece_count(self) -> int:
        return sum(report.generated_piece_count for report in self.definition_reports)

    @property
    def generated_point_count(self) -> int:
        return sum(report.generated_point_count for report in self.definition_reports)

    @property
    def generated_line_count(self) -> int:
        return sum(report.generated_line_count for report in self.definition_reports)


def discover_garment_definition_files(definitions_dir: str | Path) -> tuple[Path, ...]:
    """Return sorted garment JSON definitions from a catalog directory."""

    directory = Path(definitions_dir)
    if not directory.exists():
        raise SerializableCatalogQualityError(
            f"definitions directory does not exist: {directory}"
        )
    if not directory.is_dir():
        raise SerializableCatalogQualityError(
            f"definitions path is not a directory: {directory}"
        )

    paths = tuple(sorted(path for path in directory.glob("*.json") if path.is_file()))
    if not paths:
        raise SerializableCatalogQualityError(
            f"no garment JSON definitions found in: {directory}"
        )
    return paths


def validate_serializable_catalog(
    definitions_dir: str | Path,
) -> CatalogQualityReport:
    """Run semantic validation and default generation over the whole catalog."""

    directory = Path(definitions_dir)
    definition_reports = tuple(
        _validate_catalog_definition(path)
        for path in discover_garment_definition_files(directory)
    )

    codes: set[str] = set()
    duplicated_codes: set[str] = set()
    for report in definition_reports:
        if report.code in codes:
            duplicated_codes.add(report.code)
        codes.add(report.code)
    if duplicated_codes:
        raise SerializableCatalogQualityError(
            "duplicated garment code(s) in catalog: " + ", ".join(sorted(duplicated_codes))
        )

    return CatalogQualityReport(
        definitions_dir=directory,
        definition_reports=definition_reports,
    )


def validate_serializable_catalog_files(
    paths: Iterable[str | Path],
) -> tuple[CatalogDefinitionReport, ...]:
    """Run the same catalog checks over an explicit list of JSON files."""

    resolved_paths = tuple(Path(path) for path in paths)
    if not resolved_paths:
        raise SerializableCatalogQualityError(
            "at least one garment definition path is required"
        )
    reports = tuple(_validate_catalog_definition(path) for path in resolved_paths)

    codes: set[str] = set()
    duplicated_codes: set[str] = set()
    for report in reports:
        if report.code in codes:
            duplicated_codes.add(report.code)
        codes.add(report.code)
    if duplicated_codes:
        raise SerializableCatalogQualityError(
            "duplicated garment code(s): " + ", ".join(sorted(duplicated_codes))
        )
    return reports


def _validate_catalog_definition(path: Path) -> CatalogDefinitionReport:
    semantic_report = validate_garment_definition_file(path)
    definition = load_garment_definition_from_json(path)
    generated_pattern = generate_geometry_from_definition(definition)
    generated_piece_count, generated_point_count, generated_line_count = (
        _summarize_generated_pattern(generated_pattern)
    )

    if generated_piece_count <= 0:
        raise SerializableCatalogQualityError(
            f"definition '{path}' generated no pieces"
        )
    if generated_point_count <= 0:
        raise SerializableCatalogQualityError(
            f"definition '{path}' generated no points"
        )
    if generated_line_count <= 0:
        raise SerializableCatalogQualityError(
            f"definition '{path}' generated no lines"
        )

    return CatalogDefinitionReport(
        path=path,
        semantic_report=semantic_report,
        generated_piece_count=generated_piece_count,
        generated_point_count=generated_point_count,
        generated_line_count=generated_line_count,
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
