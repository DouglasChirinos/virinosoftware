#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-27-motor-interpretacion-formulas-geometricas"
SERIALIZABLE_DIR="engine/garments/serializable"
DOC_FILE="docs/36_Fase_27_Motor_Interpretacion_Formulas_Geometricas.md"
TEST_FILE="tests/test_serializable_formula_interpreter.py"

cd "$PROJECT_DIR"

echo "== Fase 27: Motor de interpretacion de formulas geometricas =="
echo "== Proyecto: $PROJECT_DIR =="

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$FEATURE_BRANCH" ]]; then
  echo "ERROR: rama actual '$CURRENT_BRANCH'. Debes estar en '$FEATURE_BRANCH'."
  echo "Ejecuta:"
  echo "  git switch develop"
  echo "  git pull origin develop"
  echo "  git switch -c $FEATURE_BRANCH"
  exit 1
fi

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_RELATIVE_PATH="$(realpath --relative-to="$PROJECT_DIR" "$SCRIPT_PATH" 2>/dev/null || true)"
GIT_STATUS_FILTERED="$(git status --porcelain | grep -v -F "?? $SCRIPT_RELATIVE_PATH" || true)"

if [[ -n "$GIT_STATUS_FILTERED" ]]; then
  echo "ERROR: arbol de trabajo no limpio. Archivos detectados:"
  echo "$GIT_STATUS_FILTERED"
  echo "Revisa con: git status --short"
  exit 1
fi

if [[ ! -d "$SERIALIZABLE_DIR" ]]; then
  echo "ERROR: no existe $SERIALIZABLE_DIR. Integra primero Fase 26 en develop."
  exit 1
fi

mkdir -p "$SERIALIZABLE_DIR" docs tests

cat > "$SERIALIZABLE_DIR/formula.py" <<'PY'
"""Safe formula interpreter for the serializable patternmaking DSL.

The interpreter evaluates arithmetic expressions such as:

- waist / 4
- hip / 4 + ease
- outseam

It intentionally avoids Python eval/exec. Only a small AST subset is allowed.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from typing import Mapping


Number = int | float
FormulaValue = Number | str


class FormulaEvaluationError(ValueError):
    """Raised when a DSL formula cannot be evaluated safely."""


@dataclass(frozen=True)
class FormulaEvaluationResult:
    """Result of evaluating one formula expression."""

    expression: str
    value: float


_ALLOWED_BINARY_OPERATORS: tuple[type[ast.operator], ...] = (
    ast.Add,
    ast.Sub,
    ast.Mult,
    ast.Div,
)
_ALLOWED_UNARY_OPERATORS: tuple[type[ast.unaryop], ...] = (ast.UAdd, ast.USub)


def evaluate_formula(expression: str, variables: Mapping[str, Number]) -> float:
    """Evaluate a safe arithmetic formula using a variable context.

    Parameters
    ----------
    expression:
        Arithmetic DSL expression. Example: ``"hip / 4 + ease"``.
    variables:
        Mapping of allowed variable names to numeric values.

    Returns
    -------
    float
        Numeric result.

    Raises
    ------
    FormulaEvaluationError
        If the expression is unsafe, invalid, references unknown variables, or
        does not evaluate to a numeric value.
    """

    if not isinstance(expression, str) or not expression.strip():
        raise FormulaEvaluationError("formula expression must be a non-empty string")

    try:
        tree = ast.parse(expression, mode="eval")
    except SyntaxError as exc:
        raise FormulaEvaluationError(f"invalid formula syntax: {expression}") from exc

    value = _evaluate_node(tree.body, variables, expression)
    if not isinstance(value, (int, float)):
        raise FormulaEvaluationError(f"formula did not return a numeric value: {expression}")
    return float(value)


def resolve_formula_value(value: FormulaValue, variables: Mapping[str, Number]) -> float:
    """Resolve a numeric coordinate or formula string into a float."""

    if isinstance(value, bool):
        raise FormulaEvaluationError("boolean values are not valid formula numbers")
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        return evaluate_formula(value, variables)
    raise FormulaEvaluationError("formula value must be numeric or string expression")


def _evaluate_node(node: ast.AST, variables: Mapping[str, Number], expression: str) -> Number:
    if isinstance(node, ast.Constant):
        if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
            raise FormulaEvaluationError(f"invalid constant in formula: {expression}")
        return node.value

    if isinstance(node, ast.Name):
        if node.id not in variables:
            raise FormulaEvaluationError(f"unknown variable '{node.id}' in formula: {expression}")
        variable_value = variables[node.id]
        if isinstance(variable_value, bool) or not isinstance(variable_value, (int, float)):
            raise FormulaEvaluationError(f"variable '{node.id}' must be numeric")
        return variable_value

    if isinstance(node, ast.UnaryOp):
        if not isinstance(node.op, _ALLOWED_UNARY_OPERATORS):
            raise FormulaEvaluationError(f"unsupported unary operator in formula: {expression}")
        operand = _evaluate_node(node.operand, variables, expression)
        if isinstance(node.op, ast.USub):
            return -operand
        return +operand

    if isinstance(node, ast.BinOp):
        if not isinstance(node.op, _ALLOWED_BINARY_OPERATORS):
            raise FormulaEvaluationError(f"unsupported operator in formula: {expression}")
        left = _evaluate_node(node.left, variables, expression)
        right = _evaluate_node(node.right, variables, expression)
        if isinstance(node.op, ast.Add):
            return left + right
        if isinstance(node.op, ast.Sub):
            return left - right
        if isinstance(node.op, ast.Mult):
            return left * right
        if isinstance(node.op, ast.Div):
            if right == 0:
                raise FormulaEvaluationError(f"division by zero in formula: {expression}")
            return left / right

    raise FormulaEvaluationError(f"unsupported expression in formula: {expression}")
PY

cat > "$SERIALIZABLE_DIR/geometry.py" <<'PY'
"""Geometry generation from serializable garment definitions.

This module turns the Fase 26 serializable contract into resolved points and
lines. It does not yet register JSON garments in the universal garment catalog
and it does not modify the GUI.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Mapping

from .definition import SerializableGarmentDefinition, SerializablePieceDefinition
from .formula import FormulaEvaluationError, resolve_formula_value
from .validation import SerializableGarmentValidationError


Number = int | float


class SerializableGeometryGenerationError(ValueError):
    """Raised when serializable geometry cannot be generated."""


@dataclass(frozen=True)
class GeneratedSerializablePoint:
    """Resolved geometric point."""

    name: str
    x: float
    y: float


@dataclass(frozen=True)
class GeneratedSerializableLine:
    """Resolved line referencing two generated point names."""

    start: str
    end: str
    kind: str = "line"


@dataclass(frozen=True)
class GeneratedSerializablePiece:
    """Resolved piece built from points and lines."""

    name: str
    points: tuple[GeneratedSerializablePoint, ...]
    lines: tuple[GeneratedSerializableLine, ...]
    metadata: dict = field(default_factory=dict)


@dataclass(frozen=True)
class GeneratedSerializablePattern:
    """Resolved pattern generated from a serializable definition."""

    garment_code: str
    garment_name: str
    pieces: tuple[GeneratedSerializablePiece, ...]
    variables: dict[str, float]

    @property
    def piece_count(self) -> int:
        return len(self.pieces)


def build_formula_context(
    definition: SerializableGarmentDefinition,
    measurement_values: Mapping[str, Number] | None = None,
    extra_variables: Mapping[str, Number] | None = None,
) -> dict[str, float]:
    """Build the formula variable context for one serializable definition.

    Measurement defaults come from the JSON definition. Runtime measurement
    values override defaults. Extra variables are allowed for construction
    factors such as ``ease`` while the DSL evolves.
    """

    _validate_definition(definition)
    measurement_values = measurement_values or {}
    extra_variables = extra_variables or {}

    context: dict[str, float] = {}
    known_measurements = {measurement.name for measurement in definition.measurements}

    unknown_measurements = set(measurement_values) - known_measurements
    if unknown_measurements:
        names = ", ".join(sorted(unknown_measurements))
        raise SerializableGeometryGenerationError(f"unknown measurement value(s): {names}")

    for measurement in definition.measurements:
        raw_value = measurement_values.get(measurement.name, measurement.default)
        if raw_value is None and measurement.required:
            raise SerializableGeometryGenerationError(
                f"missing required measurement '{measurement.name}'"
            )
        if raw_value is not None:
            context[measurement.name] = _as_float(raw_value, measurement.name)

    for name, value in extra_variables.items():
        if not isinstance(name, str) or not name.strip():
            raise SerializableGeometryGenerationError("extra variable names must be non-empty")
        context[name] = _as_float(value, name)

    return context


def generate_geometry_from_definition(
    definition: SerializableGarmentDefinition,
    measurement_values: Mapping[str, Number] | None = None,
    extra_variables: Mapping[str, Number] | None = None,
) -> GeneratedSerializablePattern:
    """Generate resolved geometry from a serializable garment definition."""

    context = build_formula_context(definition, measurement_values, extra_variables)

    pieces = tuple(_generate_piece(piece, context) for piece in definition.pieces)
    return GeneratedSerializablePattern(
        garment_code=definition.code,
        garment_name=definition.name,
        pieces=pieces,
        variables=context,
    )


def _generate_piece(
    piece: SerializablePieceDefinition,
    variables: Mapping[str, float],
) -> GeneratedSerializablePiece:
    generated_points: list[GeneratedSerializablePoint] = []

    for point in piece.points:
        try:
            x = resolve_formula_value(point.coordinates[0], variables)
            y = resolve_formula_value(point.coordinates[1], variables)
        except FormulaEvaluationError as exc:
            raise SerializableGeometryGenerationError(
                f"cannot resolve point '{point.name}' in piece '{piece.name}': {exc}"
            ) from exc
        generated_points.append(GeneratedSerializablePoint(point.name, x, y))

    point_names = {point.name for point in generated_points}
    generated_lines: list[GeneratedSerializableLine] = []
    for line in piece.lines:
        if line.start not in point_names or line.end not in point_names:
            raise SerializableGeometryGenerationError(
                f"line references undefined point in piece '{piece.name}'"
            )
        generated_lines.append(GeneratedSerializableLine(line.start, line.end, line.kind))

    return GeneratedSerializablePiece(
        name=piece.name,
        points=tuple(generated_points),
        lines=tuple(generated_lines),
        metadata=dict(piece.metadata),
    )


def _validate_definition(definition: SerializableGarmentDefinition) -> None:
    try:
        definition.validate()
    except SerializableGarmentValidationError as exc:
        raise SerializableGeometryGenerationError(str(exc)) from exc


def _as_float(value: Number, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SerializableGeometryGenerationError(f"variable '{name}' must be numeric")
    return float(value)
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/garments/serializable/__init__.py")
text = path.read_text(encoding="utf-8")

formula_import = """from .formula import FormulaEvaluationError, evaluate_formula, resolve_formula_value\n"""
geometry_import = """from .geometry import (\n    GeneratedSerializableLine,\n    GeneratedSerializablePattern,\n    GeneratedSerializablePiece,\n    GeneratedSerializablePoint,\n    SerializableGeometryGenerationError,\n    build_formula_context,\n    generate_geometry_from_definition,\n)\n"""

if "from .formula import" not in text:
    marker = "from .loader import load_garment_definition_from_dict, load_garment_definition_from_json\n"
    text = text.replace(marker, marker + formula_import + geometry_import)

exports = [
    "FormulaEvaluationError",
    "evaluate_formula",
    "resolve_formula_value",
    "SerializableGeometryGenerationError",
    "GeneratedSerializablePoint",
    "GeneratedSerializableLine",
    "GeneratedSerializablePiece",
    "GeneratedSerializablePattern",
    "build_formula_context",
    "generate_geometry_from_definition",
]
for name in exports:
    line = f'    "{name}",\n'
    if line not in text:
        text = text.replace("]\n", line + "]\n")

path.write_text(text, encoding="utf-8")
PY

cat > "$TEST_FILE" <<'PY'
from pathlib import Path

import pytest

from engine.garments.serializable import (
    FormulaEvaluationError,
    SerializableGeometryGenerationError,
    build_formula_context,
    evaluate_formula,
    generate_geometry_from_definition,
    load_garment_definition_from_dict,
    load_garment_definition_from_json,
)


def test_evaluates_basic_formula_with_measurement():
    assert evaluate_formula("waist / 4", {"waist": 84}) == 21.0


def test_evaluates_formula_with_ease_variable():
    assert evaluate_formula("hip / 4 + ease", {"hip": 104, "ease": 2}) == 28.0


def test_evaluates_plain_measurement_name():
    assert evaluate_formula("outseam", {"outseam": 45}) == 45.0


@pytest.mark.parametrize(
    "expression",
    [
        "__import__('os').system('echo bad')",
        "open('/tmp/x')",
        "waist.__class__",
        "items[0]",
        "waist ** 2",
    ],
)
def test_rejects_unsafe_or_unsupported_expressions(expression):
    with pytest.raises(FormulaEvaluationError):
        evaluate_formula(expression, {"waist": 84, "items": 1})


def test_rejects_unknown_variable():
    with pytest.raises(FormulaEvaluationError, match="unknown variable"):
        evaluate_formula("hip / 4", {"waist": 84})


def test_rejects_division_by_zero():
    with pytest.raises(FormulaEvaluationError, match="division by zero"):
        evaluate_formula("waist / divisor", {"waist": 84, "divisor": 0})


def test_build_formula_context_uses_defaults_and_runtime_overrides():
    definition = load_garment_definition_from_json(Path("examples/garments/short_basico.json"))

    context = build_formula_context(
        definition,
        measurement_values={"waist": 88},
        extra_variables={"ease": 2},
    )

    assert context["waist"] == 88.0
    assert context["hip"] == 104.0
    assert context["outseam"] == 45.0
    assert context["ease"] == 2.0


def test_generates_geometry_from_short_basico_json_defaults():
    definition = load_garment_definition_from_json(Path("examples/garments/short_basico.json"))

    pattern = generate_geometry_from_definition(definition)

    assert pattern.garment_code == "short_basico"
    assert pattern.garment_name == "Short basico"
    assert pattern.piece_count == 1
    piece = pattern.pieces[0]
    points = {point.name: point for point in piece.points}
    assert points["A"].x == 0.0
    assert points["A"].y == 0.0
    assert points["B"].x == 21.0
    assert points["B"].y == 0.0
    assert points["C"].x == 26.0
    assert points["C"].y == 45.0
    assert len(piece.lines) == 4


def test_generates_geometry_with_ease_formula():
    payload = {
        "code": "top_basico",
        "name": "Top basico",
        "measurements": [
            {"name": "chest", "label": "Pecho", "default": 96},
            {"name": "length", "label": "Largo", "default": 60},
        ],
        "pieces": [
            {
                "name": "Top delantero",
                "points": {
                    "A": [0, 0],
                    "B": ["chest / 4 + ease", 0],
                    "C": ["chest / 4 + ease", "length"],
                    "D": [0, "length"],
                },
                "lines": [["A", "B"], ["B", "C"], ["C", "D"], ["D", "A"]],
            }
        ],
    }
    definition = load_garment_definition_from_dict(payload)

    pattern = generate_geometry_from_definition(definition, extra_variables={"ease": 3})

    points = {point.name: point for point in pattern.pieces[0].points}
    assert points["B"].x == 27.0
    assert points["C"].y == 60.0


def test_generating_geometry_requires_missing_required_measurement():
    payload = {
        "code": "pieza_test",
        "name": "Pieza test",
        "measurements": [{"name": "waist", "label": "Cintura"}],
        "pieces": [
            {
                "name": "Pieza",
                "points": {"A": [0, 0], "B": ["waist", 0]},
                "lines": [["A", "B"]],
            }
        ],
    }
    definition = load_garment_definition_from_dict(payload)

    with pytest.raises(SerializableGeometryGenerationError, match="missing required"):
        generate_geometry_from_definition(definition)


def test_generating_geometry_rejects_unknown_measurement_override():
    definition = load_garment_definition_from_json(Path("examples/garments/short_basico.json"))

    with pytest.raises(SerializableGeometryGenerationError, match="unknown measurement"):
        generate_geometry_from_definition(definition, measurement_values={"unknown": 10})
PY

cat > "$DOC_FILE" <<'MD'
# Fase 27 - Motor de interpretacion de formulas geometricas

## Objetivo

Convertir expresiones serializadas del DSL inicial en coordenadas numericas reales para poder generar geometria desde JSON/dict.

Ejemplos soportados:

```text
waist / 4
hip / 4 + ease
outseam
```

## Alcance implementado

Se agregaron los modulos:

```text
engine/garments/serializable/formula.py
engine/garments/serializable/geometry.py
```

Se actualizo:

```text
engine/garments/serializable/__init__.py
```

Se agregaron pruebas:

```text
tests/test_serializable_formula_interpreter.py
```

## Componentes creados

### Interpretador seguro de formulas

```text
FormulaEvaluationError
evaluate_formula
resolve_formula_value
```

El interpretador usa `ast.parse(..., mode="eval")` y solo acepta un subconjunto aritmetico controlado:

```text
+  -  *  /
parentesis
numeros
variables declaradas en contexto
signo positivo/negativo
```

No usa `eval` ni `exec`.

Bloquea expresiones como:

```text
__import__('os')
open('/tmp/x')
waist.__class__
items[0]
waist ** 2
```

### Generador de geometria serializable

```text
SerializableGeometryGenerationError
GeneratedSerializablePoint
GeneratedSerializableLine
GeneratedSerializablePiece
GeneratedSerializablePattern
build_formula_context
generate_geometry_from_definition
```

La funcion principal es:

```python
generate_geometry_from_definition(definition, measurement_values=None, extra_variables=None)
```

## Contexto de formulas

El contexto se arma con:

1. Defaults declarados en el JSON.
2. Valores de medicion pasados en runtime.
3. Variables extra de construccion, por ejemplo `ease`.

Ejemplo:

```python
pattern = generate_geometry_from_definition(
    definition,
    measurement_values={"waist": 88},
    extra_variables={"ease": 2},
)
```

## Resultado tecnico

El JSON de `short_basico` de Fase 26 ya puede resolverse a puntos numericos.

Ejemplo conceptual:

```text
B = ["waist / 4", 0]
waist = 84
B = [21.0, 0.0]
```

## Limites intencionales

Esta fase no registra prendas JSON en el catalogo universal.

Esta fase no exporta SVG/DXF/PDF desde JSON.

Esta fase no modifica la GUI.

Esta fase no implementa curvas, piquetes, margenes de costura ni reglas industriales avanzadas.

## Validaciones

Ejecutar:

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
```

## Proxima fase recomendada

```text
Fase 28 - Adaptador de prenda serializable al generador universal
```

Objetivo sugerido:

```text
Permitir registrar una definicion JSON como prenda generable por el flujo universal existente.
```
MD

echo "== Archivos creados/actualizados =="
printf '%s\n' \
  "$SERIALIZABLE_DIR/formula.py" \
  "$SERIALIZABLE_DIR/geometry.py" \
  "$SERIALIZABLE_DIR/__init__.py" \
  "$TEST_FILE" \
  "$DOC_FILE"

echo "== Ejecutando pruebas base =="
make test

echo "== Validando que el flujo universal existente no se rompio =="
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants

echo "== Estado Git =="
git status --short

echo "== Fase 27 preparada =="
echo "Revisa el diff: git diff --stat"
echo "Si todo esta OK:"
echo "  git add $SERIALIZABLE_DIR/formula.py $SERIALIZABLE_DIR/geometry.py $SERIALIZABLE_DIR/__init__.py $TEST_FILE $DOC_FILE"
echo "  git commit -m 'Fase 27 motor de interpretacion de formulas geometricas'"
echo "  git push -u origin $FEATURE_BRANCH"
