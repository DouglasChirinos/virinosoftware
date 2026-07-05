#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-26-contrato-serializable-prendas"
DOC_FILE="docs/35_Fase_26_Contrato_Serializable_Prendas.md"
TEST_FILE="tests/test_serializable_garment_definition.py"
SERIALIZABLE_DIR="engine/garments/serializable"
EXAMPLES_DIR="examples/garments"
EXAMPLE_FILE="examples/garments/short_basico.json"

cd "$PROJECT_DIR"

echo "== Fase 26: Contrato serializable de prendas / DSL inicial =="
echo "== Proyecto: $PROJECT_DIR =="

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$FEATURE_BRANCH" ]]; then
  echo "ERROR: rama actual '$CURRENT_BRANCH'. Debes estar en '$FEATURE_BRANCH'."
  echo "Ejecuta: git switch $FEATURE_BRANCH"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: arbol de trabajo no limpio. Revisa con: git status --short"
  exit 1
fi

mkdir -p "$SERIALIZABLE_DIR" "$EXAMPLES_DIR" docs tests

cat > "$SERIALIZABLE_DIR/__init__.py" <<'PY'
"""Serializable garment definitions for the initial patternmaking DSL."""

from .definition import (
    SerializableGarmentDefinition,
    SerializableLineDefinition,
    SerializableMeasurementDefinition,
    SerializablePieceDefinition,
    SerializablePointDefinition,
)
from .loader import load_garment_definition_from_dict, load_garment_definition_from_json
from .validation import SerializableGarmentValidationError

__all__ = [
    "SerializableGarmentDefinition",
    "SerializableLineDefinition",
    "SerializableMeasurementDefinition",
    "SerializablePieceDefinition",
    "SerializablePointDefinition",
    "SerializableGarmentValidationError",
    "load_garment_definition_from_dict",
    "load_garment_definition_from_json",
]
PY

cat > "$SERIALIZABLE_DIR/validation.py" <<'PY'
"""Validation helpers for serializable garment definitions."""

from __future__ import annotations


class SerializableGarmentValidationError(ValueError):
    """Raised when a serializable garment definition is structurally invalid."""
PY

cat > "$SERIALIZABLE_DIR/definition.py" <<'PY'
"""Dataclass contract for serializable garment definitions.

This module intentionally validates only the first DSL contract. It does not
interpret formulas or generate geometry yet. Formula evaluation belongs to the
next phase.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .validation import SerializableGarmentValidationError


PointCoordinate = int | float | str
PointCoordinates = tuple[PointCoordinate, PointCoordinate]


@dataclass(frozen=True)
class SerializableMeasurementDefinition:
    """Measurement required by a serializable garment definition."""

    name: str
    label: str
    unit: str = "cm"
    default: float | None = None
    required: bool = True

    def validate(self) -> None:
        _require_identifier(self.name, "measurement.name")
        _require_non_empty(self.label, "measurement.label")
        _require_non_empty(self.unit, "measurement.unit")
        if self.default is not None and not isinstance(self.default, (int, float)):
            raise SerializableGarmentValidationError(
                f"measurement '{self.name}' default must be numeric"
            )


@dataclass(frozen=True)
class SerializablePointDefinition:
    """Named point for a serializable piece.

    Coordinates can be numbers or formula strings. Formula strings are only
    stored and validated as non-empty values in this phase.
    """

    name: str
    coordinates: PointCoordinates

    def validate(self) -> None:
        _require_identifier(self.name, "point.name")
        if not isinstance(self.coordinates, tuple) or len(self.coordinates) != 2:
            raise SerializableGarmentValidationError(
                f"point '{self.name}' coordinates must be a tuple of two values"
            )
        for coordinate in self.coordinates:
            if isinstance(coordinate, str):
                _require_non_empty(coordinate, f"point '{self.name}' coordinate")
            elif not isinstance(coordinate, (int, float)):
                raise SerializableGarmentValidationError(
                    f"point '{self.name}' coordinate must be numeric or formula string"
                )


@dataclass(frozen=True)
class SerializableLineDefinition:
    """Line between two named points."""

    start: str
    end: str
    kind: str = "line"

    def validate(self, point_names: set[str]) -> None:
        _require_identifier(self.start, "line.start")
        _require_identifier(self.end, "line.end")
        _require_non_empty(self.kind, "line.kind")
        if self.start == self.end:
            raise SerializableGarmentValidationError("line start and end cannot be equal")
        missing = [point for point in (self.start, self.end) if point not in point_names]
        if missing:
            raise SerializableGarmentValidationError(
                f"line references undefined point(s): {', '.join(missing)}"
            )


@dataclass(frozen=True)
class SerializablePieceDefinition:
    """Serializable piece composed of points and lines."""

    name: str
    points: tuple[SerializablePointDefinition, ...]
    lines: tuple[SerializableLineDefinition, ...]
    metadata: dict[str, Any] = field(default_factory=dict)

    def validate(self) -> None:
        _require_non_empty(self.name, "piece.name")
        if not self.points:
            raise SerializableGarmentValidationError(f"piece '{self.name}' must define points")
        point_names: set[str] = set()
        for point in self.points:
            point.validate()
            if point.name in point_names:
                raise SerializableGarmentValidationError(
                    f"piece '{self.name}' has duplicated point '{point.name}'"
                )
            point_names.add(point.name)
        for line in self.lines:
            line.validate(point_names)


@dataclass(frozen=True)
class SerializableGarmentDefinition:
    """Top-level serializable garment definition.

    The contract is intentionally strict enough to keep future generation safe,
    but small enough to avoid prematurely designing the full DSL engine.
    """

    code: str
    name: str
    measurements: tuple[SerializableMeasurementDefinition, ...]
    pieces: tuple[SerializablePieceDefinition, ...]
    version: str = "0.1"
    metadata: dict[str, Any] = field(default_factory=dict)

    def validate(self) -> None:
        _require_identifier(self.code, "garment.code")
        _require_non_empty(self.name, "garment.name")
        _require_non_empty(self.version, "garment.version")
        if not self.measurements:
            raise SerializableGarmentValidationError("garment must define measurements")
        if not self.pieces:
            raise SerializableGarmentValidationError("garment must define pieces")

        measurement_names: set[str] = set()
        for measurement in self.measurements:
            measurement.validate()
            if measurement.name in measurement_names:
                raise SerializableGarmentValidationError(
                    f"duplicated measurement '{measurement.name}'"
                )
            measurement_names.add(measurement.name)

        piece_names: set[str] = set()
        for piece in self.pieces:
            piece.validate()
            if piece.name in piece_names:
                raise SerializableGarmentValidationError(
                    f"duplicated piece '{piece.name}'"
                )
            piece_names.add(piece.name)

    @property
    def measurement_names(self) -> tuple[str, ...]:
        return tuple(measurement.name for measurement in self.measurements)

    @property
    def piece_names(self) -> tuple[str, ...]:
        return tuple(piece.name for piece in self.pieces)


def _require_non_empty(value: str, field_name: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise SerializableGarmentValidationError(f"{field_name} must be a non-empty string")


def _require_identifier(value: str, field_name: str) -> None:
    _require_non_empty(value, field_name)
    if not value.replace("_", "").isalnum() or value[0].isdigit():
        raise SerializableGarmentValidationError(
            f"{field_name} must be an identifier-like string"
        )
PY

cat > "$SERIALIZABLE_DIR/loader.py" <<'PY'
"""Load serializable garment definitions from dict or JSON."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .definition import (
    SerializableGarmentDefinition,
    SerializableLineDefinition,
    SerializableMeasurementDefinition,
    SerializablePieceDefinition,
    SerializablePointDefinition,
)
from .validation import SerializableGarmentValidationError


def load_garment_definition_from_json(path: str | Path) -> SerializableGarmentDefinition:
    """Load and validate a garment definition from a JSON file."""

    json_path = Path(path)
    try:
        payload = json.loads(json_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SerializableGarmentValidationError(f"JSON file not found: {json_path}") from exc
    except json.JSONDecodeError as exc:
        raise SerializableGarmentValidationError(f"Invalid JSON file: {json_path}") from exc
    return load_garment_definition_from_dict(payload)


def load_garment_definition_from_dict(payload: dict[str, Any]) -> SerializableGarmentDefinition:
    """Load and validate a garment definition from a dictionary."""

    if not isinstance(payload, dict):
        raise SerializableGarmentValidationError("garment payload must be a dictionary")

    measurements = tuple(
        SerializableMeasurementDefinition(
            name=item["name"],
            label=item.get("label", item["name"]),
            unit=item.get("unit", "cm"),
            default=item.get("default"),
            required=item.get("required", True),
        )
        for item in _require_list(payload, "measurements")
    )

    pieces = tuple(_load_piece(item) for item in _require_list(payload, "pieces"))

    definition = SerializableGarmentDefinition(
        code=payload["code"],
        name=payload["name"],
        version=payload.get("version", "0.1"),
        measurements=measurements,
        pieces=pieces,
        metadata=payload.get("metadata", {}),
    )
    definition.validate()
    return definition


def _load_piece(payload: dict[str, Any]) -> SerializablePieceDefinition:
    if not isinstance(payload, dict):
        raise SerializableGarmentValidationError("piece payload must be a dictionary")

    points_payload = payload.get("points")
    if not isinstance(points_payload, dict):
        raise SerializableGarmentValidationError("piece.points must be a dictionary")

    points = tuple(
        SerializablePointDefinition(name=name, coordinates=_as_coordinates(value, name))
        for name, value in points_payload.items()
    )

    lines = tuple(_load_line(value) for value in _require_list(payload, "lines"))

    return SerializablePieceDefinition(
        name=payload["name"],
        points=points,
        lines=lines,
        metadata=payload.get("metadata", {}),
    )


def _load_line(value: Any) -> SerializableLineDefinition:
    if isinstance(value, list) and len(value) == 2:
        return SerializableLineDefinition(start=value[0], end=value[1])
    if isinstance(value, dict):
        return SerializableLineDefinition(
            start=value["start"],
            end=value["end"],
            kind=value.get("kind", "line"),
        )
    raise SerializableGarmentValidationError(
        "line must be a two-item list or a dictionary with start/end"
    )


def _as_coordinates(value: Any, point_name: str) -> tuple[int | float | str, int | float | str]:
    if not isinstance(value, list) or len(value) != 2:
        raise SerializableGarmentValidationError(
            f"point '{point_name}' coordinates must be a two-item list"
        )
    return (value[0], value[1])


def _require_list(payload: dict[str, Any], key: str) -> list[Any]:
    value = payload.get(key)
    if not isinstance(value, list):
        raise SerializableGarmentValidationError(f"{key} must be a list")
    return value
PY

cat > "$EXAMPLE_FILE" <<'JSON'
{
  "code": "short_basico",
  "name": "Short basico",
  "version": "0.1",
  "measurements": [
    {"name": "waist", "label": "Cintura", "unit": "cm", "default": 84},
    {"name": "hip", "label": "Cadera", "unit": "cm", "default": 104},
    {"name": "outseam", "label": "Largo exterior", "unit": "cm", "default": 45},
    {"name": "inseam", "label": "Entrepierna", "unit": "cm", "default": 20}
  ],
  "pieces": [
    {
      "name": "Short basico delantero",
      "points": {
        "A": [0, 0],
        "B": ["waist / 4", 0],
        "C": ["hip / 4", "outseam"],
        "D": [0, "outseam"]
      },
      "lines": [
        ["A", "B"],
        ["B", "C"],
        ["C", "D"],
        ["D", "A"]
      ],
      "metadata": {
        "side": "front",
        "industrial_status": "contract_only"
      }
    }
  ],
  "metadata": {
    "category": "bottom",
    "phase": "26",
    "industrial_status": "dsl_contract_only"
  }
}
JSON

cat > "$TEST_FILE" <<'PY'
from pathlib import Path

import pytest

from engine.garments.serializable import (
    SerializableGarmentValidationError,
    load_garment_definition_from_dict,
    load_garment_definition_from_json,
)


VALID_PAYLOAD = {
    "code": "short_basico",
    "name": "Short basico",
    "measurements": [
        {"name": "waist", "label": "Cintura", "unit": "cm", "default": 84},
        {"name": "hip", "label": "Cadera", "unit": "cm", "default": 104},
    ],
    "pieces": [
        {
            "name": "Short delantero",
            "points": {
                "A": [0, 0],
                "B": ["waist / 4", 0],
                "C": ["hip / 4", 45],
            },
            "lines": [["A", "B"], ["B", "C"], ["C", "A"]],
        }
    ],
}


def test_load_serializable_garment_from_dict():
    definition = load_garment_definition_from_dict(VALID_PAYLOAD)

    assert definition.code == "short_basico"
    assert definition.name == "Short basico"
    assert definition.measurement_names == ("waist", "hip")
    assert definition.piece_names == ("Short delantero",)
    assert definition.pieces[0].points[1].coordinates == ("waist / 4", 0)


def test_load_serializable_garment_from_json_example():
    definition = load_garment_definition_from_json(
        Path("examples/garments/short_basico.json")
    )

    assert definition.code == "short_basico"
    assert definition.version == "0.1"
    assert len(definition.measurements) == 4
    assert len(definition.pieces) == 1


def test_rejects_duplicated_measurements():
    payload = {
        **VALID_PAYLOAD,
        "measurements": [
            {"name": "waist", "label": "Cintura"},
            {"name": "waist", "label": "Cintura duplicada"},
        ],
    }

    with pytest.raises(SerializableGarmentValidationError, match="duplicated measurement"):
        load_garment_definition_from_dict(payload)


def test_rejects_lines_with_undefined_points():
    payload = {
        **VALID_PAYLOAD,
        "pieces": [
            {
                "name": "Short delantero",
                "points": {"A": [0, 0], "B": [10, 0]},
                "lines": [["A", "Z"]],
            }
        ],
    }

    with pytest.raises(SerializableGarmentValidationError, match="undefined point"):
        load_garment_definition_from_dict(payload)


def test_rejects_invalid_garment_code():
    payload = {**VALID_PAYLOAD, "code": "123-short"}

    with pytest.raises(SerializableGarmentValidationError, match="identifier-like"):
        load_garment_definition_from_dict(payload)
PY

cat > "$DOC_FILE" <<'MD'
# Fase 26 - Contrato serializable de prendas / DSL inicial

## Objetivo

Crear el primer contrato serializable para declarar prendas simples mediante estructuras tipo JSON/dict, reduciendo la necesidad de crear una clase Python completa por cada prenda basica.

Esta fase no crea un motor geometrico completo. Solo define y valida el contrato inicial.

## Alcance implementado

Se agrego el modulo:

```text
engine/garments/serializable/
```

Componentes creados:

```text
SerializableGarmentDefinition
SerializableMeasurementDefinition
SerializablePieceDefinition
SerializablePointDefinition
SerializableLineDefinition
SerializableGarmentValidationError
load_garment_definition_from_dict
load_garment_definition_from_json
```

Ejemplo creado:

```text
examples/garments/short_basico.json
```

Pruebas creadas:

```text
tests/test_serializable_garment_definition.py
```

## Decisiones tecnicas

1. Las coordenadas de puntos aceptan numeros o formulas como texto.
2. Las formulas no se interpretan todavia.
3. Las lineas validan que sus puntos existan dentro de la pieza.
4. El codigo de prenda y los nombres internos de puntos/medidas deben ser identificadores simples.
5. La fase queda desacoplada de la GUI universal.
6. La fase queda desacoplada del generador universal actual.

## Ejemplo conceptual

```json
{
  "code": "short_basico",
  "name": "Short basico",
  "measurements": [
    {"name": "waist", "label": "Cintura", "unit": "cm", "default": 84},
    {"name": "hip", "label": "Cadera", "unit": "cm", "default": 104}
  ],
  "pieces": [
    {
      "name": "Short delantero",
      "points": {
        "A": [0, 0],
        "B": ["waist / 4", 0],
        "C": ["hip / 4", 45]
      },
      "lines": [["A", "B"], ["B", "C"], ["C", "A"]]
    }
  ]
}
```

## Que no hace esta fase

No interpreta formulas como:

```text
waist / 4
hip / 4 + ease
outseam
```

No genera piezas geometricas reales desde JSON.

No registra `short_basico` en el catalogo universal.

No modifica la GUI.

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
Fase 27 - Motor de interpretacion de formulas geometricas
```

Objetivo de Fase 27:

```text
Convertir formulas serializadas en coordenadas reales y generar piezas desde JSON.
```
MD

echo "== Archivos creados =="
printf '%s\n' \
  "$SERIALIZABLE_DIR/__init__.py" \
  "$SERIALIZABLE_DIR/validation.py" \
  "$SERIALIZABLE_DIR/definition.py" \
  "$SERIALIZABLE_DIR/loader.py" \
  "$EXAMPLE_FILE" \
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

echo "== Fase 26 preparada =="
echo "Revisa el diff: git diff --stat"
echo "Si todo esta OK:"
echo "  git add $SERIALIZABLE_DIR $EXAMPLES_DIR $TEST_FILE $DOC_FILE"
echo "  git commit -m 'Fase 26 contrato serializable de prendas'"
echo "  git push -u origin $FEATURE_BRANCH"
