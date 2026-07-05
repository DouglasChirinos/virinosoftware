from pathlib import Path
import subprocess
import sys

import pytest

from engine.garments.serializable import (
    SerializableCatalogQualityError,
    discover_garment_definition_files,
    validate_serializable_catalog,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CATALOG_DIR = PROJECT_ROOT / "examples" / "garments"


def test_discover_garment_definition_files_finds_catalog_json_files() -> None:
    paths = discover_garment_definition_files(CATALOG_DIR)

    names = [path.name for path in paths]
    assert "short_basico.json" in names
    assert "falda_evase.json" in names
    assert names == sorted(names)


def test_validate_serializable_catalog_runs_semantic_and_generation_pipeline() -> None:
    report = validate_serializable_catalog(CATALOG_DIR)

    codes = {definition_report.code for definition_report in report.definition_reports}
    assert {"short_basico", "falda_evase"}.issubset(codes)
    assert report.definition_count >= 2
    assert report.generated_piece_count >= 2
    assert report.generated_point_count >= 8
    assert report.generated_line_count >= 8


def test_validate_serializable_catalog_rejects_empty_directory(tmp_path: Path) -> None:
    with pytest.raises(SerializableCatalogQualityError):
        validate_serializable_catalog(tmp_path)


def test_validate_serializable_catalog_cli_uses_directory_discovery() -> None:
    result = subprocess.run(
        [
            sys.executable,
            "scripts/validate_serializable_catalog.py",
            "--definitions-dir",
            "examples/garments",
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "CATALOG_OK: examples/garments" in result.stdout
    assert "CATALOG_DEFINITION: examples/garments/short_basico.json" in result.stdout
    assert "CATALOG_DEFINITION: examples/garments/falda_evase.json" in result.stdout
