from pathlib import Path
import subprocess
import sys

import pytest

from engine.garments.serializable import (
    SerializableCatalogGenerationError,
    generate_serializable_catalog,
    generate_serializable_catalog_files,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CATALOG_DIR = PROJECT_ROOT / "examples" / "garments"


def test_generate_serializable_catalog_generates_all_discovered_definitions() -> None:
    report = generate_serializable_catalog(CATALOG_DIR)

    codes = {definition_report.code for definition_report in report.definition_reports}
    assert {"short_basico", "falda_evase"}.issubset(codes)
    assert report.definition_count >= 2
    assert report.generated_piece_count >= 2
    assert report.generated_point_count >= 8
    assert report.generated_line_count >= 8


def test_generate_serializable_catalog_files_supports_explicit_paths() -> None:
    reports = generate_serializable_catalog_files(
        [
            CATALOG_DIR / "short_basico.json",
            CATALOG_DIR / "falda_evase.json",
        ]
    )

    assert len(reports) == 2
    assert {report.code for report in reports} == {"short_basico", "falda_evase"}
    assert all(report.piece_count > 0 for report in reports)
    assert all(report.point_count > 0 for report in reports)
    assert all(report.line_count > 0 for report in reports)


def test_generate_serializable_catalog_rejects_empty_explicit_list() -> None:
    with pytest.raises(SerializableCatalogGenerationError):
        generate_serializable_catalog_files([])


def test_generate_serializable_catalog_cli_uses_directory_discovery() -> None:
    result = subprocess.run(
        [
            sys.executable,
            "scripts/generate_serializable_catalog.py",
            "--definitions-dir",
            "examples/garments",
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "CATALOG_GENERATION_OK: examples/garments" in result.stdout
    assert "GENERATED_DEFINITION: examples/garments/short_basico.json" in result.stdout
    assert "GENERATED_DEFINITION: examples/garments/falda_evase.json" in result.stdout
