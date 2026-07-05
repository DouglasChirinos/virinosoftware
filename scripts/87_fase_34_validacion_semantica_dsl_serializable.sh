#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
PHASE_BRANCH="feature/fase-34-validacion-semantica-dsl-serializable"
PLAYBOOK_NAME="87_fase_34_validacion_semantica_dsl_serializable.sh"

cd "$PROJECT_ROOT"

echo "== Fase 34: Validacion semantica del DSL serializable =="
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
  echo "ERROR: el arbol de trabajo no esta limpio antes de iniciar Fase 34."
  echo "Solo se tolera el playbook sin rastrear: scripts/$PLAYBOOK_NAME"
  git status --short
  exit 1
fi

echo "== Validando base Fase 33 =="
make test
make validate-geometry-short
make validate-geometry-falda-evase

mkdir -p engine/garments/serializable scripts tests docs

echo "== Creando validador semantico del DSL =="
cat > engine/garments/serializable/semantic_validation.py <<'PY'
"""Semantic validation for serializable garment DSL definitions.

This layer validates the quality of a garment JSON definition before geometry
is generated. Structural validation remains in ``definition.py`` and
``loader.py``; this module focuses on semantic consistency.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .definition import SerializableGarmentDefinition, SerializablePieceDefinition
from .formula import FormulaEvaluationError, evaluate_formula
from .loader import load_garment_definition_from_json
from .validation import SerializableGarmentValidationError


class SerializableGarmentSemanticValidationError(SerializableGarmentValidationError):
    """Raised when a serializable garment definition is semantically invalid."""


@dataclass(frozen=True)
class PieceSemanticReport:
    """Semantic validation summary for one piece."""

    name: str
    point_count: int
    line_count: int
    formula_count: int


@dataclass(frozen=True)
class GarmentSemanticReport:
    """Semantic validation summary for a full garment definition."""

    code: str
    name: str
    measurement_count: int
    piece_reports: tuple[PieceSemanticReport, ...]

    @property
    def piece_count(self) -> int:
        return len(self.piece_reports)

    @property
    def formula_count(self) -> int:
        return sum(report.formula_count for report in self.piece_reports)


_ALLOWED_AST_NODES: tuple[type[ast.AST], ...] = (
    ast.Expression,
    ast.BinOp,
    ast.UnaryOp,
    ast.Constant,
    ast.Name,
    ast.Load,
    ast.Add,
    ast.Sub,
    ast.Mult,
    ast.Div,
    ast.UAdd,
    ast.USub,
)


def validate_garment_definition_semantics(
    definition: SerializableGarmentDefinition,
) -> GarmentSemanticReport:
    """Validate semantic consistency for a serializable garment definition.

    Checks implemented in Fase 34:
    - top-level structural contract is still valid;
    - each formula references only declared measurements;
    - formula syntax uses only the safe arithmetic DSL;
    - each line references existing points;
    - duplicate lines are rejected, including reversed duplicates;
    - orphan points are rejected.
    """

    definition.validate()

    measurement_names = set(definition.measurement_names)
    if not measurement_names:
        raise SerializableGarmentSemanticValidationError(
            f"garment '{definition.code}' must declare at least one measurement"
        )

    piece_reports = tuple(
        _validate_piece_semantics(piece, measurement_names)
        for piece in definition.pieces
    )

    return GarmentSemanticReport(
        code=definition.code,
        name=definition.name,
        measurement_count=len(measurement_names),
        piece_reports=piece_reports,
    )


def validate_garment_definition_file(path: str | Path) -> GarmentSemanticReport:
    """Load a JSON definition and validate its semantic DSL contract."""

    definition = load_garment_definition_from_json(path)
    return validate_garment_definition_semantics(definition)


def validate_garment_definition_files(
    paths: Iterable[str | Path],
) -> tuple[GarmentSemanticReport, ...]:
    """Validate several JSON definition files."""

    reports = tuple(validate_garment_definition_file(path) for path in paths)
    if not reports:
        raise SerializableGarmentSemanticValidationError(
            "at least one garment definition path is required"
        )
    return reports


def _validate_piece_semantics(
    piece: SerializablePieceDefinition,
    measurement_names: set[str],
) -> PieceSemanticReport:
    point_names = {point.name for point in piece.points}
    if len(point_names) != len(piece.points):
        raise SerializableGarmentSemanticValidationError(
            f"piece '{piece.name}' has duplicated point names"
        )

    formula_count = 0
    for point in piece.points:
        for coordinate in point.coordinates:
            if isinstance(coordinate, str):
                formula_count += 1
                _validate_formula_expression(
                    expression=coordinate,
                    allowed_variables=measurement_names,
                    context=f"piece '{piece.name}' point '{point.name}'",
                )

    used_points: set[str] = set()
    seen_lines: set[tuple[str, str]] = set()
    for line in piece.lines:
        if line.start not in point_names or line.end not in point_names:
            missing = sorted(
                point for point in (line.start, line.end) if point not in point_names
            )
            raise SerializableGarmentSemanticValidationError(
                f"piece '{piece.name}' line references undefined point(s): "
                + ", ".join(missing)
            )

        normalized_line = tuple(sorted((line.start, line.end)))
        if normalized_line in seen_lines:
            raise SerializableGarmentSemanticValidationError(
                f"piece '{piece.name}' has duplicated line '{line.start}-{line.end}'"
            )
        seen_lines.add(normalized_line)
        used_points.update((line.start, line.end))

    orphan_points = sorted(point_names - used_points)
    if orphan_points:
        raise SerializableGarmentSemanticValidationError(
            f"piece '{piece.name}' has orphan point(s): " + ", ".join(orphan_points)
        )

    return PieceSemanticReport(
        name=piece.name,
        point_count=len(piece.points),
        line_count=len(piece.lines),
        formula_count=formula_count,
    )


def _validate_formula_expression(
    *, expression: str, allowed_variables: set[str], context: str
) -> None:
    if not expression.strip():
        raise SerializableGarmentSemanticValidationError(
            f"{context} has an empty formula expression"
        )

    try:
        tree = ast.parse(expression, mode="eval")
    except SyntaxError as exc:
        raise SerializableGarmentSemanticValidationError(
            f"{context} has invalid formula syntax: {expression}"
        ) from exc

    for node in ast.walk(tree):
        if not isinstance(node, _ALLOWED_AST_NODES):
            raise SerializableGarmentSemanticValidationError(
                f"{context} uses unsupported formula syntax: {expression}"
            )

    referenced_variables = {
        node.id for node in ast.walk(tree) if isinstance(node, ast.Name)
    }
    unknown_variables = sorted(referenced_variables - allowed_variables)
    if unknown_variables:
        raise SerializableGarmentSemanticValidationError(
            f"{context} formula references undeclared measurement(s): "
            + ", ".join(unknown_variables)
        )

    dummy_context = {name: 1.0 for name in allowed_variables}
    try:
        evaluate_formula(expression, dummy_context)
    except FormulaEvaluationError as exc:
        raise SerializableGarmentSemanticValidationError(
            f"{context} formula is not evaluable: {expression}"
        ) from exc
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/garments/serializable/__init__.py")
text = path.read_text(encoding="utf-8")

import_block = """from .semantic_validation import (\n    GarmentSemanticReport,\n    PieceSemanticReport,\n    SerializableGarmentSemanticValidationError,\n    validate_garment_definition_file,\n    validate_garment_definition_files,\n    validate_garment_definition_semantics,\n)\n"""
if "from .semantic_validation import" not in text:
    marker = "from .validation import SerializableGarmentValidationError\n"
    text = text.replace(marker, marker + import_block)

exports = [
    '"SerializableGarmentSemanticValidationError",',
    '"PieceSemanticReport",',
    '"GarmentSemanticReport",',
    '"validate_garment_definition_semantics",',
    '"validate_garment_definition_file",',
    '"validate_garment_definition_files",',
]
for item in exports:
    if item not in text:
        text = text.replace("]\n", f"    {item}\n]\n")

path.write_text(text, encoding="utf-8")
PY

echo "== Creando CLI validate_garment_definition.py =="
cat > scripts/validate_garment_definition.py <<'PY'
#!/usr/bin/env python3
"""Validate serializable garment JSON definitions before generation."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.serializable.semantic_validation import (  # noqa: E402
    validate_garment_definition_files,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate semantic contract for serializable garment JSON definitions."
    )
    parser.add_argument(
        "--definition",
        action="append",
        default=[],
        help="Path to a garment JSON definition. Can be repeated.",
    )
    parser.add_argument(
        "--definitions-dir",
        default=None,
        help="Directory containing garment JSON definitions.",
    )
    return parser


def _resolve_paths(args: argparse.Namespace) -> list[Path]:
    paths = [Path(value) for value in args.definition]
    if args.definitions_dir:
        directory = Path(args.definitions_dir)
        paths.extend(sorted(directory.glob("*.json")))
    if not paths:
        raise SystemExit("No garment definitions provided")
    return paths


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    paths = _resolve_paths(args)
    reports = validate_garment_definition_files(paths)

    for path, report in zip(paths, reports, strict=True):
        print(
            "VALID_DEFINITION: {path} code={code} measurements={measurements} "
            "pieces={pieces} formulas={formulas}".format(
                path=path,
                code=report.code,
                measurements=report.measurement_count,
                pieces=report.piece_count,
                formulas=report.formula_count,
            )
        )
        for index, piece in enumerate(report.piece_reports, start=1):
            print(
                "PIECE_{index}: {name} points={points} lines={lines} formulas={formulas}".format(
                    index=index,
                    name=piece.name,
                    points=piece.point_count,
                    lines=piece.line_count,
                    formulas=piece.formula_count,
                )
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x scripts/validate_garment_definition.py

echo "== Actualizando Makefile =="
python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

target = """
validate-garments-json:
	.venv/bin/python scripts/validate_garment_definition.py --definition examples/garments/short_basico.json --definition examples/garments/falda_evase.json
"""
if "validate-garments-json:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += target
path.write_text(text, encoding="utf-8")
PY

echo "== Creando tests de validacion semantica =="
cat > tests/test_serializable_semantic_validation.py <<'PY'
from pathlib import Path
import subprocess
import sys

import pytest

from engine.garments.serializable import (
    SerializableGarmentDefinition,
    SerializableGarmentSemanticValidationError,
    SerializableLineDefinition,
    SerializableMeasurementDefinition,
    SerializablePieceDefinition,
    SerializablePointDefinition,
    validate_garment_definition_file,
    validate_garment_definition_semantics,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_short_basico_json_passes_semantic_validation() -> None:
    report = validate_garment_definition_file(
        PROJECT_ROOT / "examples" / "garments" / "short_basico.json"
    )

    assert report.code == "short_basico"
    assert report.measurement_count == 4
    assert report.piece_count == 1
    assert report.formula_count >= 1


def test_falda_evase_json_passes_semantic_validation() -> None:
    report = validate_garment_definition_file(
        PROJECT_ROOT / "examples" / "garments" / "falda_evase.json"
    )

    assert report.code == "falda_evase"
    assert report.measurement_count == 4
    assert report.piece_count == 1
    assert report.formula_count == 5


def test_semantic_validation_rejects_undeclared_formula_measurement() -> None:
    definition = _definition_with_piece(
        SerializablePieceDefinition(
            name="Pieza con formula invalida",
            points=(
                SerializablePointDefinition("A", (0, 0)),
                SerializablePointDefinition("B", ("unknown_measure / 4", 0)),
                SerializablePointDefinition("C", (10, 10)),
            ),
            lines=(
                SerializableLineDefinition("A", "B"),
                SerializableLineDefinition("B", "C"),
                SerializableLineDefinition("C", "A"),
            ),
        )
    )

    with pytest.raises(SerializableGarmentSemanticValidationError):
        validate_garment_definition_semantics(definition)


def test_semantic_validation_rejects_orphan_point() -> None:
    definition = _definition_with_piece(
        SerializablePieceDefinition(
            name="Pieza con punto huerfano",
            points=(
                SerializablePointDefinition("A", (0, 0)),
                SerializablePointDefinition("B", (10, 0)),
                SerializablePointDefinition("C", (10, 10)),
                SerializablePointDefinition("D", (0, 10)),
            ),
            lines=(
                SerializableLineDefinition("A", "B"),
                SerializableLineDefinition("B", "C"),
            ),
        )
    )

    with pytest.raises(SerializableGarmentSemanticValidationError):
        validate_garment_definition_semantics(definition)


def test_semantic_validation_rejects_duplicate_line_even_if_reversed() -> None:
    definition = _definition_with_piece(
        SerializablePieceDefinition(
            name="Pieza con linea duplicada",
            points=(
                SerializablePointDefinition("A", (0, 0)),
                SerializablePointDefinition("B", (10, 0)),
                SerializablePointDefinition("C", (10, 10)),
            ),
            lines=(
                SerializableLineDefinition("A", "B"),
                SerializableLineDefinition("B", "A"),
                SerializableLineDefinition("B", "C"),
                SerializableLineDefinition("C", "A"),
            ),
        )
    )

    with pytest.raises(SerializableGarmentSemanticValidationError):
        validate_garment_definition_semantics(definition)


def test_validate_garment_definition_cli_validates_current_json_definitions() -> None:
    result = subprocess.run(
        [
            sys.executable,
            "scripts/validate_garment_definition.py",
            "--definition",
            "examples/garments/short_basico.json",
            "--definition",
            "examples/garments/falda_evase.json",
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "VALID_DEFINITION: examples/garments/short_basico.json" in result.stdout
    assert "VALID_DEFINITION: examples/garments/falda_evase.json" in result.stdout


def _definition_with_piece(piece: SerializablePieceDefinition) -> SerializableGarmentDefinition:
    return SerializableGarmentDefinition(
        code="test_semantic_garment",
        name="Test semantic garment",
        measurements=(
            SerializableMeasurementDefinition("waist", "Cintura"),
            SerializableMeasurementDefinition("hip", "Cadera"),
        ),
        pieces=(piece,),
    )
PY

echo "== Documentando Fase 34 =="
cat > docs/43_Fase_34_Validacion_Semantica_DSL_Serializable.md <<'MD'
# Fase 34 - Validacion semantica del DSL serializable

## Objetivo

Agregar una capa de control de calidad semantico para las definiciones JSON de prendas serializables antes de generar geometria o exportaciones.

Esta fase complementa la Fase 33:

- Fase 33 valida la geometria generada y los archivos exportados.
- Fase 34 valida que el DSL JSON sea consistente antes de generar.

## Alcance implementado

- Nuevo modulo `engine/garments/serializable/semantic_validation.py`.
- Nuevo CLI `scripts/validate_garment_definition.py`.
- Nuevo target `make validate-garments-json`.
- Tests para `short_basico.json` y `falda_evase.json`.
- Tests negativos para:
  - formula con medicion no declarada;
  - puntos huerfanos;
  - lineas duplicadas, incluyendo duplicados invertidos.

## Reglas semanticas validadas

El contrato semantico valida:

1. La estructura base sigue siendo valida segun el contrato serializable existente.
2. Toda formula usa solo mediciones declaradas en `measurements`.
3. Toda formula usa solo aritmetica segura del DSL.
4. Toda linea referencia puntos existentes.
5. No existen lineas duplicadas ni duplicadas invertidas.
6. No existen puntos huerfanos dentro de una pieza.

## Comandos principales

```bash
make validate-garments-json
```

Validacion directa por CLI:

```bash
.venv/bin/python scripts/validate_garment_definition.py \
  --definition examples/garments/short_basico.json \
  --definition examples/garments/falda_evase.json
```

Validacion por directorio:

```bash
.venv/bin/python scripts/validate_garment_definition.py \
  --definitions-dir examples/garments
```

## Resultado esperado

```text
VALID_DEFINITION: examples/garments/short_basico.json code=short_basico measurements=4 pieces=1 formulas=...
VALID_DEFINITION: examples/garments/falda_evase.json code=falda_evase measurements=4 pieces=1 formulas=5
```

## Criterio de cierre

La fase se considera cerrada si pasan:

```bash
make test
make validate-garments-json
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Siguiente paso recomendado

Despues de Fase 34, el siguiente paso logico es endurecer el DSL con un esquema versionado o agregar validacion de compatibilidad hacia atras para futuras versiones del contrato JSON.
MD

echo "== Validando Fase 34 =="
make test
make validate-garments-json
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git final =="
git status --short

echo "== Fase 34 aplicada correctamente =="
echo "Siguiente paso sugerido: revisar git diff, commit y merge a develop."
