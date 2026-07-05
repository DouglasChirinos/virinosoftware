#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
PHASE_BRANCH="feature/fase-36-generacion-masiva-catalogo-serializable"
PLAYBOOK_NAME="89_fase_36_generacion_masiva_catalogo_serializable.sh"

cd "$PROJECT_ROOT"

echo "== Fase 36: Generacion masiva del catalogo serializable =="
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
  echo "ERROR: el arbol de trabajo no esta limpio antes de iniciar Fase 36."
  echo "Solo se tolera el playbook sin rastrear: scripts/$PLAYBOOK_NAME"
  git status --short
  exit 1
fi

echo "== Validando base Fase 35 =="
make test
make validate-garments-json
make validate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase

mkdir -p engine/garments/serializable scripts tests docs

echo "== Creando generacion masiva del catalogo serializable =="
cat > engine/garments/serializable/catalog_generation.py <<'PY'
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
PY

echo "== Exponiendo API publica de generacion masiva =="
python3 - <<'PY'
from pathlib import Path

path = Path("engine/garments/serializable/__init__.py")
text = path.read_text(encoding="utf-8")

import_block = """from .catalog_generation import (\n    CatalogGeneratedDefinitionReport,\n    CatalogGenerationReport,\n    SerializableCatalogGenerationError,\n    generate_serializable_catalog,\n    generate_serializable_catalog_files,\n)\n"""
if "from .catalog_generation import" not in text:
    marker = "from .catalog_quality import (\n"
    if marker not in text:
        raise SystemExit("No se encontro import de catalog_quality en __init__.py. Fase 35 no parece estar completa.")
    text = text.replace(marker, import_block + marker)

exports = [
    '    "SerializableCatalogGenerationError",',
    '    "CatalogGeneratedDefinitionReport",',
    '    "CatalogGenerationReport",',
    '    "generate_serializable_catalog",',
    '    "generate_serializable_catalog_files",',
]
for item in exports:
    if item not in text:
        marker = "\n]\n"
        if marker not in text:
            raise SystemExit("No se encontro cierre de __all__ en __init__.py")
        text = text.replace(marker, f"\n{item}{marker}", 1)

path.write_text(text, encoding="utf-8")
PY

echo "== Creando CLI generate_serializable_catalog.py =="
cat > scripts/generate_serializable_catalog.py <<'PY'
#!/usr/bin/env python3
"""Generate all serializable garment JSON definitions in a catalog."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.serializable.catalog_generation import (  # noqa: E402
    generate_serializable_catalog,
    generate_serializable_catalog_files,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Generate every serializable garment JSON definition using default "
            "measurements and report generated geometry totals."
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
        reports = generate_serializable_catalog_files(args.definition)
        print(f"CATALOG_GENERATION_OK: explicit definitions={len(reports)}")
        definition_reports = reports
    else:
        catalog_report = generate_serializable_catalog(args.definitions_dir)
        print(
            "CATALOG_GENERATION_OK: {directory} definitions={definitions} "
            "generated_pieces={pieces} generated_points={points} generated_lines={lines}".format(
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
            "GENERATED_DEFINITION: {path} code={code} name={name} pieces={pieces} "
            "points={points} lines={lines} variables={variables}".format(
                path=report.path,
                code=report.code,
                name=report.name,
                pieces=report.piece_count,
                points=report.point_count,
                lines=report.line_count,
                variables=report.variable_count,
            )
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x scripts/generate_serializable_catalog.py

echo "== Actualizando Makefile con target generate-serializable-catalog =="
python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

target = "\ngenerate-serializable-catalog:\n\t.venv/bin/python scripts/generate_serializable_catalog.py --definitions-dir examples/garments\n"
if "generate-serializable-catalog:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += target

path.write_text(text, encoding="utf-8")
PY

echo "== Creando tests de generacion masiva del catalogo =="
cat > tests/test_serializable_catalog_generation.py <<'PY'
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
PY

echo "== Documentando Fase 36 =="
cat > docs/45_Fase_36_Generacion_Masiva_Catalogo_Serializable.md <<'MD'
# Fase 36 - Generacion masiva del catalogo serializable

## Objetivo

Crear un smoke test productivo para generar automaticamente todas las prendas JSON del catalogo serializable usando las medidas por defecto declaradas en cada definicion.

La Fase 35 valida que el catalogo JSON sea semanticamente correcto y generable como pipeline de calidad. La Fase 36 separa la generacion masiva como una capacidad propia del motor, util para QA, integracion continua y futuras exportaciones masivas.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/catalog_generation.py`.
- Nuevo CLI `scripts/generate_serializable_catalog.py`.
- Nuevo target `make generate-serializable-catalog`.
- Tests de generacion masiva por directorio.
- Tests de generacion masiva por lista explicita de archivos.
- Exposicion de API publica desde `engine.garments.serializable`.
- Documentacion tecnica de cierre.

## Contrato funcional

La generacion masiva ejecuta:

1. Descubrimiento automatico de `*.json` en `examples/garments/`.
2. Validacion semantica de cada JSON antes de generar.
3. Carga de definicion serializable.
4. Generacion de geometria usando defaults declarados en el JSON.
5. Reporte por prenda con piezas, puntos, lineas y variables usadas.

## Comando principal

```bash
make generate-serializable-catalog
```

CLI directo:

```bash
.venv/bin/python scripts/generate_serializable_catalog.py --definitions-dir examples/garments
```

## Resultado esperado

```text
CATALOG_GENERATION_OK: examples/garments definitions=2 generated_pieces=2 generated_points=8 generated_lines=8
GENERATED_DEFINITION: examples/garments/falda_evase.json code=falda_evase name=Falda evase pieces=1 points=4 lines=4 variables=4
GENERATED_DEFINITION: examples/garments/short_basico.json code=short_basico name=Short basico pieces=1 points=4 lines=4 variables=4
```

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Valor tecnico

El motor ya no depende de pruebas una por una para saber si el catalogo JSON puede generar geometria. Cualquier nueva prenda colocada en `examples/garments/` entra automaticamente al smoke test productivo de generacion.

Esto prepara la siguiente capa natural: exportacion masiva del catalogo serializable hacia SVG/DXF/PDF.

## Siguiente paso recomendado

Fase 37 - Exportacion masiva del catalogo serializable hacia SVG/DXF/PDF.
MD

echo "== Validando Fase 36 =="
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git final =="
git status --short

echo "== Fase 36 aplicada correctamente =="
echo "Siguiente paso sugerido: revisar git diff, commit y merge a develop."
