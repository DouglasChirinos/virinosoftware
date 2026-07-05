#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
PHASE_BRANCH="feature/fase-35-validacion-masiva-catalogo-serializable"
PLAYBOOK_NAME="88_fase_35_validacion_masiva_catalogo_serializable.sh"

cd "$PROJECT_ROOT"

echo "== Fase 35: Validacion masiva del catalogo serializable =="
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
  echo "ERROR: el arbol de trabajo no esta limpio antes de iniciar Fase 35."
  echo "Solo se tolera el playbook sin rastrear: scripts/$PLAYBOOK_NAME"
  git status --short
  exit 1
fi

echo "== Validando base Fase 34 =="
make test
make validate-garments-json
make validate-geometry-short
make validate-geometry-falda-evase

mkdir -p engine/garments/serializable scripts tests docs

echo "== Creando pipeline de calidad masiva del catalogo serializable =="
cat > engine/garments/serializable/catalog_quality.py <<'PY'
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
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/garments/serializable/__init__.py")
text = path.read_text(encoding="utf-8")

import_block = """from .catalog_quality import (\n    CatalogDefinitionReport,\n    CatalogQualityReport,\n    SerializableCatalogQualityError,\n    discover_garment_definition_files,\n    validate_serializable_catalog,\n    validate_serializable_catalog_files,\n)\n"""
if "from .catalog_quality import" not in text:
    marker = "from .semantic_validation import (\n"
    if marker not in text:
        raise SystemExit("No se encontro import de semantic_validation en __init__.py. Fase 34 no parece estar completa.")
    text = text.replace(marker, import_block + marker)

exports = [
    '"SerializableCatalogQualityError",',
    '"CatalogDefinitionReport",',
    '"CatalogQualityReport",',
    '"discover_garment_definition_files",',
    '"validate_serializable_catalog",',
    '"validate_serializable_catalog_files",',
]
for item in exports:
    if item not in text:
        text = text.replace("]\n", f"    {item}\n]\n")

path.write_text(text, encoding="utf-8")
PY

echo "== Creando CLI validate_serializable_catalog.py =="
cat > scripts/validate_serializable_catalog.py <<'PY'
#!/usr/bin/env python3
"""Validate the full serializable garment JSON catalog."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.serializable.catalog_quality import (  # noqa: E402
    validate_serializable_catalog,
    validate_serializable_catalog_files,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Validate all serializable garment JSON definitions and run default "
            "geometry generation as a catalog quality pipeline."
        )
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
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.definition:
        reports = validate_serializable_catalog_files(args.definition)
        print(f"CATALOG_OK: explicit definitions={len(reports)}")
        definition_reports = reports
    else:
        catalog_report = validate_serializable_catalog(args.definitions_dir)
        print(
            "CATALOG_OK: {directory} definitions={definitions} generated_pieces={pieces} "
            "generated_points={points} generated_lines={lines}".format(
                directory=catalog_report.definitions_dir,
                definitions=catalog_report.definition_count,
                pieces=catalog_report.generated_piece_count,
                points=catalog_report.generated_point_count,
                lines=catalog_report.generated_line_count,
            )
        )
        definition_reports = catalog_report.definition_reports

    for report in definition_reports:
        print(
            "CATALOG_DEFINITION: {path} code={code} measurements={measurements} "
            "pieces={pieces} formulas={formulas} generated_pieces={generated_pieces} "
            "generated_points={generated_points} generated_lines={generated_lines}".format(
                path=report.path,
                code=report.code,
                measurements=report.measurement_count,
                pieces=report.piece_count,
                formulas=report.formula_count,
                generated_pieces=report.generated_piece_count,
                generated_points=report.generated_point_count,
                generated_lines=report.generated_line_count,
            )
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x scripts/validate_serializable_catalog.py

echo "== Actualizando Makefile para validacion por descubrimiento automatico =="
python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

old = "validate-garments-json:\n\t.venv/bin/python scripts/validate_garment_definition.py --definition examples/garments/short_basico.json --definition examples/garments/falda_evase.json\n"
new = "validate-garments-json:\n\t.venv/bin/python scripts/validate_garment_definition.py --definitions-dir examples/garments\n"
if old in text:
    text = text.replace(old, new)
elif "validate-garments-json:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += new

catalog_target = "\nvalidate-serializable-catalog:\n\t.venv/bin/python scripts/validate_serializable_catalog.py --definitions-dir examples/garments\n"
if "validate-serializable-catalog:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += catalog_target

path.write_text(text, encoding="utf-8")
PY

echo "== Creando tests de validacion masiva del catalogo =="
cat > tests/test_serializable_catalog_quality.py <<'PY'
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
PY

echo "== Documentando Fase 35 =="
cat > docs/44_Fase_35_Validacion_Masiva_Catalogo_Serializable.md <<'MD'
# Fase 35 - Validacion masiva del catalogo serializable

## Objetivo

Crear un pipeline de calidad para validar automaticamente todas las prendas JSON del catalogo serializable sin declarar cada archivo manualmente en el Makefile.

Esta fase convierte el flujo de validacion de prendas JSON en un proceso escalable para crecer de dos prendas a muchas prendas sin deuda operativa.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/catalog_quality.py`.
- Nuevo CLI `scripts/validate_serializable_catalog.py`.
- Nuevo target `make validate-serializable-catalog`.
- Actualizacion de `make validate-garments-json` para usar descubrimiento por directorio.
- Tests de descubrimiento automatico del catalogo.
- Tests del pipeline semantico + generacion por defecto.
- Documentacion tecnica de cierre.

## Contrato funcional

El pipeline de catalogo ejecuta:

1. Descubrimiento automatico de `*.json` en `examples/garments/`.
2. Validacion semantica de cada definicion JSON.
3. Generacion geometrica usando defaults declarados en cada JSON.
4. Validacion de unicidad de `code` dentro del catalogo.
5. Resumen operativo por cada prenda.

## Comandos principales

Validar semantica de todos los JSON por directorio:

```bash
make validate-garments-json
```

Validar catalogo completo con semantica + generacion por defecto:

```bash
make validate-serializable-catalog
```

Ejecutar CLI directo:

```bash
.venv/bin/python scripts/validate_serializable_catalog.py --definitions-dir examples/garments
```

## Resultado esperado

```text
CATALOG_OK: examples/garments definitions=2 generated_pieces=2 generated_points=8 generated_lines=8
CATALOG_DEFINITION: examples/garments/falda_evase.json code=falda_evase ...
CATALOG_DEFINITION: examples/garments/short_basico.json code=short_basico ...
```

El orden puede variar segun orden alfabetico de archivos, pero debe ser deterministico.

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Valor tecnico

Antes de esta fase, el Makefile conocia explicitamente cada JSON. Eso no escala.

Despues de esta fase, una nueva prenda serializable colocada en `examples/garments/` entra automaticamente al pipeline de calidad del catalogo, siempre que tenga defaults suficientes para generar geometria base.

## Siguiente paso recomendado

Despues de Fase 35, el siguiente paso logico es versionar formalmente el DSL JSON o agregar fixtures de catalogo invalido para blindar compatibilidad hacia atras.
MD

echo "== Validando Fase 35 =="
make test
make validate-garments-json
make validate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git final =="
git status --short

echo "== Fase 35 aplicada correctamente =="
echo "Siguiente paso sugerido: revisar git diff, commit y merge a develop."
