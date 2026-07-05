"""Catalog-wide SVG/DXF/PDF export pipeline for serializable garments."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .catalog_generation import SerializableCatalogGenerationError
from .catalog_quality import discover_garment_definition_files
from .loader import load_garment_definition_from_json
from .semantic_validation import validate_garment_definition_file


class SerializableCatalogExportError(SerializableCatalogGenerationError):
    """Raised when catalog-wide serializable export fails."""


@dataclass(frozen=True)
class CatalogExportedDefinitionReport:
    """Export report for one serializable garment JSON file."""

    path: Path
    code: str
    name: str
    piece_count: int
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    @property
    def exported_paths(self) -> tuple[Path, ...]:
        return tuple(path for path in (self.svg_path, self.dxf_path, self.pdf_path) if path)

    @property
    def exported_file_count(self) -> int:
        return len(self.exported_paths)

    @property
    def total_bytes(self) -> int:
        return sum(path.stat().st_size for path in self.exported_paths if path.exists())


@dataclass(frozen=True)
class CatalogExportReport:
    """Export report for a serializable garment JSON catalog."""

    definitions_dir: Path | None
    output_dir: Path
    definition_reports: tuple[CatalogExportedDefinitionReport, ...]

    @property
    def definition_count(self) -> int:
        return len(self.definition_reports)

    @property
    def exported_file_count(self) -> int:
        return sum(report.exported_file_count for report in self.definition_reports)

    @property
    def total_bytes(self) -> int:
        return sum(report.total_bytes for report in self.definition_reports)


@dataclass(frozen=True)
class CatalogExportOptions:
    """Format switches for catalog export."""

    export_svg: bool = True
    export_dxf: bool = True
    export_pdf: bool = True

    def validate(self) -> None:
        if not (self.export_svg or self.export_dxf or self.export_pdf):
            raise SerializableCatalogExportError(
                "at least one export format must be enabled"
            )


def export_serializable_catalog(
    definitions_dir: str | Path,
    *,
    output_dir: str | Path = "exports/catalog",
    export_svg: bool = True,
    export_dxf: bool = True,
    export_pdf: bool = True,
) -> CatalogExportReport:
    """Export every JSON garment definition found in a catalog directory."""

    directory = Path(definitions_dir)
    options = CatalogExportOptions(export_svg, export_dxf, export_pdf)
    return CatalogExportReport(
        definitions_dir=directory,
        output_dir=Path(output_dir),
        definition_reports=export_serializable_catalog_files(
            discover_garment_definition_files(directory),
            output_dir=output_dir,
            options=options,
        ),
    )


def export_serializable_catalog_files(
    paths: Iterable[str | Path],
    *,
    output_dir: str | Path = "exports/catalog",
    options: CatalogExportOptions | None = None,
) -> tuple[CatalogExportedDefinitionReport, ...]:
    """Export an explicit list of serializable garment JSON definitions."""

    selected_options = options or CatalogExportOptions()
    selected_options.validate()

    resolved_paths = tuple(Path(path) for path in paths)
    if not resolved_paths:
        raise SerializableCatalogExportError(
            "at least one garment definition path is required"
        )

    reports = tuple(
        _export_definition(path, Path(output_dir), selected_options)
        for path in resolved_paths
    )
    duplicated_codes = _find_duplicated_codes(report.code for report in reports)
    if duplicated_codes:
        raise SerializableCatalogExportError(
            "duplicated garment code(s): " + ", ".join(duplicated_codes)
        )
    return reports


def _export_definition(
    path: Path,
    output_dir: Path,
    options: CatalogExportOptions,
) -> CatalogExportedDefinitionReport:
    validate_garment_definition_file(path)
    definition = load_garment_definition_from_json(path)
    measurements = _default_measurements_for_export(path)

    # Lazy imports to avoid circular import when engine.garments imports the
    # serializable package while engine.generation is still initializing.
    from engine.generation.exporter import PatternExportRequest, export_generated_pattern
    from engine.generation.pattern_generator import PatternGenerationRequest

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=definition.code,
                measurements=measurements,
            ),
            output_name=definition.code,
            output_dir=output_dir,
            export_svg=options.export_svg,
            export_dxf=options.export_dxf,
            export_pdf=options.export_pdf,
        )
    )

    report = CatalogExportedDefinitionReport(
        path=path,
        code=result.generation_result.garment_code,
        name=result.generation_result.garment_name,
        piece_count=result.generation_result.piece_count,
        svg_path=result.svg_path,
        dxf_path=result.dxf_path,
        pdf_path=result.pdf_path,
    )
    _validate_exported_report(report)
    return report


def _default_measurements_for_export(path: Path) -> dict[str, float]:
    definition = load_garment_definition_from_json(path)
    measurements: dict[str, float] = {}
    missing_defaults: list[str] = []

    for measurement in definition.measurements:
        if measurement.default is None:
            if measurement.required:
                missing_defaults.append(measurement.name)
            continue
        measurements[measurement.name] = float(measurement.default)

    if missing_defaults:
        raise SerializableCatalogExportError(
            f"definition '{path}' has required measurements without default: "
            + ", ".join(missing_defaults)
        )

    return measurements


def _validate_exported_report(report: CatalogExportedDefinitionReport) -> None:
    if report.piece_count <= 0:
        raise SerializableCatalogExportError(
            f"definition '{report.path}' exported no pieces"
        )
    if not report.exported_paths:
        raise SerializableCatalogExportError(
            f"definition '{report.path}' exported no files"
        )
    for exported_path in report.exported_paths:
        if not exported_path.exists():
            raise SerializableCatalogExportError(
                f"exported file does not exist: {exported_path}"
            )
        if exported_path.stat().st_size <= 0:
            raise SerializableCatalogExportError(
                f"exported file is empty: {exported_path}"
            )


def _find_duplicated_codes(codes: Iterable[str]) -> tuple[str, ...]:
    seen: set[str] = set()
    duplicated: set[str] = set()
    for code in codes:
        if code in seen:
            duplicated.add(code)
        seen.add(code)
    return tuple(sorted(duplicated))
