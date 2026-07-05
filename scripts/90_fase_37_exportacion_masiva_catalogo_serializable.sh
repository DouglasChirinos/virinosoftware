#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
PHASE_BRANCH="feature/fase-37-exportacion-masiva-catalogo-serializable"
PLAYBOOK_NAME="90_fase_37_exportacion_masiva_catalogo_serializable.sh"

cd "$PROJECT_ROOT"

echo "== Fase 37: Exportacion masiva del catalogo serializable SVG/DXF/PDF =="
echo "== Verificando rama =="
current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$PHASE_BRANCH" ]; then
  echo "ERROR: rama actual '$current_branch'. Debe ser '$PHASE_BRANCH'."
  exit 1
fi

echo "== Verificando estado Git base =="
status="$(git status --short)"
allowed="?? scripts/$PLAYBOOK_NAME"
if [ -n "$status" ] && [ "$status" != "$allowed" ]; then
  echo "ERROR: el arbol de trabajo no esta limpio antes de iniciar Fase 37."
  echo "Solo se tolera el playbook sin rastrear: scripts/$PLAYBOOK_NAME"
  git status --short
  exit 1
fi

echo "== Validando base Fase 36 =="
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase

mkdir -p engine/garments/serializable scripts tests docs

cat > engine/garments/serializable/catalog_export.py <<'PY'
"""Catalog-wide SVG/DXF/PDF export pipeline for serializable garments."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from engine.generation import (
    PatternExportRequest,
    PatternGenerationRequest,
    export_generated_pattern,
)

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
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/garments/serializable/__init__.py")
text = path.read_text(encoding="utf-8")

import_block = """from .catalog_export import (\n    CatalogExportedDefinitionReport,\n    CatalogExportOptions,\n    CatalogExportReport,\n    SerializableCatalogExportError,\n    export_serializable_catalog,\n    export_serializable_catalog_files,\n)\n"""
if "from .catalog_export import" not in text:
    marker = "from .catalog_generation import (\n"
    if marker not in text:
        raise SystemExit("No se encontro import de catalog_generation en __init__.py. Fase 36 no parece estar completa.")
    text = text.replace(marker, import_block + marker)

exports = [
    '    "SerializableCatalogExportError",',
    '    "CatalogExportOptions",',
    '    "CatalogExportedDefinitionReport",',
    '    "CatalogExportReport",',
    '    "export_serializable_catalog",',
    '    "export_serializable_catalog_files",',
]
for item in exports:
    if item not in text:
        marker = "\n]\n"
        if marker not in text:
            raise SystemExit("No se encontro cierre de __all__ en __init__.py")
        text = text.replace(marker, f"\n{item}{marker}", 1)

path.write_text(text, encoding="utf-8")
PY

cat > scripts/export_serializable_catalog.py <<'PY'
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
PY
chmod +x scripts/export_serializable_catalog.py

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

target = "\nexport-serializable-catalog:\n\t.venv/bin/python scripts/export_serializable_catalog.py --definitions-dir examples/garments --output-dir exports/catalog\n"
if "export-serializable-catalog:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += target

path.write_text(text, encoding="utf-8")
PY

cat > tests/test_serializable_catalog_export.py <<'PY'
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
PY

cat > docs/46_Fase_37_Exportacion_Masiva_Catalogo_Serializable.md <<'MD'
# Fase 37 - Exportacion masiva del catalogo serializable SVG/DXF/PDF

## Objetivo

Agregar una salida productiva masiva para exportar automaticamente todas las prendas JSON del catalogo serializable hacia SVG, DXF y PDF.

La Fase 36 valida que todas las definiciones JSON puedan generar geometria. La Fase 37 cierra el ciclo de punta a punta: JSON validado -> geometria generada -> archivos industriales/exportables.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/catalog_export.py`.
- Nuevo CLI `scripts/export_serializable_catalog.py`.
- Nuevo target `make export-serializable-catalog`.
- Exportacion masiva hacia `exports/catalog/svg`, `exports/catalog/dxf` y `exports/catalog/pdf`.
- Tests de exportacion masiva completa.
- Tests de exportacion parcial por formato.
- Tests de CLI con descubrimiento automatico.
- Exposicion de API publica desde `engine.garments.serializable`.

## Comando principal

```bash
make export-serializable-catalog
```

CLI directo:

```bash
.venv/bin/python scripts/export_serializable_catalog.py --definitions-dir examples/garments --output-dir exports/catalog
```

## Resultado esperado

```text
CATALOG_EXPORT_OK: examples/garments definitions=2 exported_files=6 output_dir=exports/catalog total_bytes=...
EXPORTED_DEFINITION: examples/garments/falda_evase.json code=falda_evase name=Falda evase pieces=1 exported_files=3 svg=exports/catalog/svg/falda_evase.svg dxf=exports/catalog/dxf/falda_evase.dxf pdf=exports/catalog/pdf/falda_evase.pdf
EXPORTED_DEFINITION: examples/garments/short_basico.json code=short_basico name=Short basico pieces=1 exported_files=3 svg=exports/catalog/svg/short_basico.svg dxf=exports/catalog/dxf/short_basico.dxf pdf=exports/catalog/pdf/short_basico.pdf
```

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Valor tecnico

El motor ya puede validar, generar y exportar en bloque todo el catalogo JSON sin declarar prenda por prenda. Esto reduce deuda operativa y prepara el cierre de release v0.2.0.

## Siguiente paso recomendado

Fase 38 - Documentacion y checklist release v0.2.0.
MD

echo "== Validando Fase 37 =="
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git final =="
git status --short

echo "== Fase 37 aplicada correctamente =="
echo "Siguiente paso sugerido: revisar git diff, commit y merge a develop."
