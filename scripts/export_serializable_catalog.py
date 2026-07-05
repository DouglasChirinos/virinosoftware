#!/usr/bin/env python3
"""Export all serializable garment JSON definitions to SVG/DXF/PDF."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.serializable.catalog_export import (  # noqa: E402
    CatalogExportOptions,
    export_serializable_catalog,
    export_serializable_catalog_files,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export serializable garment JSON definitions to SVG/DXF/PDF."
    )
    parser.add_argument(
        "--definitions-dir",
        default="examples/garments",
        help="Directory containing garment JSON definitions. Default: examples/garments.",
    )
    parser.add_argument(
        "--definition",
        action="append",
        default=[],
        help="Explicit garment JSON definition. Can be repeated. If provided, directory discovery is skipped.",
    )
    parser.add_argument(
        "--output-dir",
        default="exports/catalog",
        help="Base export directory. Default: exports/catalog.",
    )
    parser.add_argument("--no-svg", action="store_true", help="Skip SVG export.")
    parser.add_argument("--no-dxf", action="store_true", help="Skip DXF export.")
    parser.add_argument("--no-pdf", action="store_true", help="Skip PDF export.")
    return parser


def _format_path(path: Path | None) -> str:
    return str(path) if path is not None else "-"


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    options = CatalogExportOptions(
        export_svg=not args.no_svg,
        export_dxf=not args.no_dxf,
        export_pdf=not args.no_pdf,
    )

    if args.definition:
        definition_reports = export_serializable_catalog_files(
            args.definition,
            output_dir=args.output_dir,
            options=options,
        )
        total_files = sum(report.exported_file_count for report in definition_reports)
        total_bytes = sum(report.total_bytes for report in definition_reports)
        print(
            "CATALOG_EXPORT_OK: explicit definitions={definitions} exported_files={files} "
            "output_dir={output_dir} total_bytes={bytes}".format(
                definitions=len(definition_reports),
                files=total_files,
                output_dir=args.output_dir,
                bytes=total_bytes,
            )
        )
    else:
        catalog_report = export_serializable_catalog(
            args.definitions_dir,
            output_dir=args.output_dir,
            export_svg=options.export_svg,
            export_dxf=options.export_dxf,
            export_pdf=options.export_pdf,
        )
        definition_reports = catalog_report.definition_reports
        print(
            "CATALOG_EXPORT_OK: {directory} definitions={definitions} exported_files={files} "
            "output_dir={output_dir} total_bytes={bytes}".format(
                directory=catalog_report.definitions_dir,
                definitions=catalog_report.definition_count,
                files=catalog_report.exported_file_count,
                output_dir=catalog_report.output_dir,
                bytes=catalog_report.total_bytes,
            )
        )

    for report in definition_reports:
        print(
            "EXPORTED_DEFINITION: {path} code={code} name={name} pieces={pieces} "
            "exported_files={files} svg={svg} dxf={dxf} pdf={pdf}".format(
                path=report.path,
                code=report.code,
                name=report.name,
                pieces=report.piece_count,
                files=report.exported_file_count,
                svg=_format_path(report.svg_path),
                dxf=_format_path(report.dxf_path),
                pdf=_format_path(report.pdf_path),
            )
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
