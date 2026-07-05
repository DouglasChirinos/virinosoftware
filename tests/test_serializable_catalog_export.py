from pathlib import Path
import subprocess
import sys

import pytest

from engine.garments.serializable import (
    CatalogExportOptions,
    SerializableCatalogExportError,
    export_serializable_catalog,
    export_serializable_catalog_files,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CATALOG_DIR = PROJECT_ROOT / "examples" / "garments"


def test_export_serializable_catalog_exports_all_formats(tmp_path: Path) -> None:
    report = export_serializable_catalog(CATALOG_DIR, output_dir=tmp_path / "catalog")

    codes = {definition_report.code for definition_report in report.definition_reports}
    assert {"short_basico", "falda_evase"}.issubset(codes)
    assert report.definition_count >= 2
    assert report.exported_file_count >= 6
    assert report.total_bytes > 0

    for definition_report in report.definition_reports:
        assert definition_report.piece_count > 0
        assert definition_report.exported_file_count == 3
        for exported_path in definition_report.exported_paths:
            assert exported_path.exists()
            assert exported_path.stat().st_size > 0


def test_export_serializable_catalog_files_supports_svg_only(tmp_path: Path) -> None:
    reports = export_serializable_catalog_files(
        [CATALOG_DIR / "short_basico.json", CATALOG_DIR / "falda_evase.json"],
        output_dir=tmp_path / "catalog_svg_only",
        options=CatalogExportOptions(export_svg=True, export_dxf=False, export_pdf=False),
    )

    assert {report.code for report in reports} == {"short_basico", "falda_evase"}
    assert all(report.svg_path is not None for report in reports)
    assert all(report.dxf_path is None for report in reports)
    assert all(report.pdf_path is None for report in reports)
    assert all(report.exported_file_count == 1 for report in reports)


def test_export_serializable_catalog_rejects_no_formats(tmp_path: Path) -> None:
    with pytest.raises(SerializableCatalogExportError):
        export_serializable_catalog_files(
            [CATALOG_DIR / "short_basico.json"],
            output_dir=tmp_path / "catalog",
            options=CatalogExportOptions(False, False, False),
        )


def test_export_serializable_catalog_cli_uses_directory_discovery(tmp_path: Path) -> None:
    output_dir = tmp_path / "cli_catalog"
    result = subprocess.run(
        [
            sys.executable,
            "scripts/export_serializable_catalog.py",
            "--definitions-dir",
            "examples/garments",
            "--output-dir",
            str(output_dir),
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "CATALOG_EXPORT_OK: examples/garments" in result.stdout
    assert "EXPORTED_DEFINITION: examples/garments/short_basico.json" in result.stdout
    assert "EXPORTED_DEFINITION: examples/garments/falda_evase.json" in result.stdout
    assert (output_dir / "svg" / "short_basico.svg").exists()
    assert (output_dir / "dxf" / "short_basico.dxf").exists()
    assert (output_dir / "pdf" / "short_basico.pdf").exists()
