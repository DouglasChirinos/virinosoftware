#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
EXPECTED_BRANCH="feature/fase-28-adaptador-prenda-serializable-generador-universal"

cd "$PROJECT_DIR"

echo "== Fase 28: Adaptador de prenda serializable al generador universal =="
echo "== Proyecto: $PROJECT_DIR =="

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "ERROR: rama actual '$CURRENT_BRANCH'. Debes estar en '$EXPECTED_BRANCH'."
  echo "Comandos sugeridos:"
  echo "  git switch develop"
  echo "  git pull origin develop"
  echo "  git switch -c $EXPECTED_BRANCH"
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

mkdir -p engine/garments/serializable
mkdir -p tests
mkdir -p docs
mkdir -p examples/garments

cat > engine/garments/serializable/adapter.py <<'PY'
"""Adapter from serializable garment definitions to engine pattern pieces.

This module is intentionally small and conservative. It bridges the DSL work
from Fase 26/27 with the existing universal pattern-generation contract, but it
does not register JSON garments globally yet and it does not modify the GUI.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement
from engine.garments.serializable.definition import SerializableGarmentDefinition, load_definition_from_json
from engine.garments.serializable.geometry import GeneratedSerializablePiece, generate_serializable_geometry


@dataclass(frozen=True)
class SerializablePatternPiece:
    """Engine-compatible piece produced from a serializable definition."""

    name: str
    points: dict[str, tuple[float, float]]
    lines: list[tuple[str, str]]

    def line_count(self) -> int:
        return len(self.lines)


class SerializableGarmentDraft(GarmentDraft):
    """Draft implementation backed by a SerializableGarmentDefinition."""

    definition: SerializableGarmentDefinition

    def __init__(self, definition: SerializableGarmentDefinition) -> None:
        self.definition = definition
        self.metadata = GarmentMetadata(
            code=definition.code,
            name=definition.name,
            description=getattr(definition, "description", "") or "Prenda serializable definida por DSL inicial.",
        )
        self.measurement_requirements = tuple(
            MeasurementRequirement(
                name=item.name,
                label=item.label,
                unit=item.unit,
                required=True,
                default_value=item.default,
            )
            for item in definition.measurements
        )

    def draft(self, measurements: Mapping[str, float]) -> list[SerializablePatternPiece]:
        generated = generate_serializable_geometry(self.definition, measurements)
        return [_to_pattern_piece(piece) for piece in generated]

    def generate(self, measurements: Mapping[str, float]) -> list[SerializablePatternPiece]:
        return self.draft(measurements)


@dataclass(frozen=True)
class SerializableGenerationResult:
    """Result object for direct generation from a JSON definition."""

    garment_code: str
    garment_name: str
    draft_class: str
    pieces: list[SerializablePatternPiece]

    @property
    def piece_count(self) -> int:
        return len(self.pieces)


class SerializableGarmentAdapterError(ValueError):
    """Raised when a serializable garment cannot be adapted or generated."""



def _to_pattern_piece(piece: GeneratedSerializablePiece) -> SerializablePatternPiece:
    return SerializablePatternPiece(
        name=piece.name,
        points=dict(piece.points),
        lines=list(piece.lines),
    )


def create_serializable_draft(definition: SerializableGarmentDefinition) -> SerializableGarmentDraft:
    """Create a draft object from an already validated serializable definition."""

    if not isinstance(definition, SerializableGarmentDefinition):
        raise SerializableGarmentAdapterError("definition must be a SerializableGarmentDefinition")
    return SerializableGarmentDraft(definition=definition)


def create_serializable_draft_from_json(path: str | Path) -> SerializableGarmentDraft:
    """Load a JSON garment definition and return an engine-compatible draft."""

    definition = load_definition_from_json(path)
    return create_serializable_draft(definition)


def generate_serializable_pattern(
    definition: SerializableGarmentDefinition,
    measurements: Mapping[str, float],
) -> SerializableGenerationResult:
    """Generate pattern pieces from a serializable garment definition."""

    draft = create_serializable_draft(definition)
    pieces = draft.generate(measurements)
    return SerializableGenerationResult(
        garment_code=definition.code,
        garment_name=definition.name,
        draft_class=draft.__class__.__name__,
        pieces=pieces,
    )


def generate_serializable_pattern_from_json(
    path: str | Path,
    measurements: Mapping[str, float],
) -> SerializableGenerationResult:
    """Generate pattern pieces directly from a JSON file."""

    definition = load_definition_from_json(path)
    return generate_serializable_pattern(definition, measurements)


def summarize_serializable_result(result: SerializableGenerationResult) -> list[str]:
    """Build CLI-friendly summary lines for a serializable generation result."""

    lines = [
        f"GARMENT_CODE: {result.garment_code}",
        f"GARMENT_NAME: {result.garment_name}",
        f"DRAFT_CLASS: {result.draft_class}",
        f"PIECE_COUNT: {result.piece_count}",
    ]
    for index, piece in enumerate(result.pieces, start=1):
        lines.append(f"PIECE_{index}: {piece.name} lines={piece.line_count()}")
    return lines
PY

cat > scripts/generate_serializable_pattern.py <<'PY'
#!/usr/bin/env python3
"""Generate a pattern from a serializable garment JSON definition."""

from __future__ import annotations

import argparse
from pathlib import Path

from engine.garments.serializable.adapter import (
    generate_serializable_pattern_from_json,
    summarize_serializable_result,
)
from engine.garments.serializable.definition import load_definition_from_json


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate pattern pieces from a serializable garment JSON definition."
    )
    parser.add_argument(
        "--definition",
        required=True,
        help="Path to the serializable garment JSON definition.",
    )
    parser.add_argument(
        "--measurement",
        action="append",
        default=[],
        help="Measurement override in key=value format. Can be repeated.",
    )
    return parser


def parse_measurement_pairs(pairs: list[str]) -> dict[str, float]:
    measurements: dict[str, float] = {}
    for pair in pairs:
        if "=" not in pair:
            raise SystemExit(f"Invalid --measurement '{pair}'. Expected key=value.")
        key, raw_value = pair.split("=", 1)
        key = key.strip()
        if not key:
            raise SystemExit(f"Invalid --measurement '{pair}'. Empty key.")
        try:
            measurements[key] = float(raw_value)
        except ValueError as exc:
            raise SystemExit(f"Invalid value for measurement '{key}': {raw_value}") from exc
    return measurements


def default_measurements(definition_path: Path) -> dict[str, float]:
    definition = load_definition_from_json(definition_path)
    values: dict[str, float] = {}
    for item in definition.measurements:
        if item.default is None:
            continue
        values[item.name] = float(item.default)
    return values


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    definition_path = Path(args.definition)
    measurements = default_measurements(definition_path)
    measurements.update(parse_measurement_pairs(args.measurement))

    result = generate_serializable_pattern_from_json(definition_path, measurements)
    for line in summarize_serializable_result(result):
        print(line)


if __name__ == "__main__":
    main()
PY
chmod +x scripts/generate_serializable_pattern.py

python3 - <<'PY'
from pathlib import Path
path = Path("Makefile")
text = path.read_text(encoding="utf-8")
block = """

generate-serializable-short:
	.venv/bin/python scripts/generate_serializable_pattern.py --definition examples/garments/short_basico.json
"""
if "generate-serializable-short:" not in text:
    text = text.rstrip() + block + "\n"
path.write_text(text, encoding="utf-8")
PY

cat > tests/test_serializable_garment_adapter.py <<'PY'
from pathlib import Path

from engine.garments.serializable.adapter import (
    SerializableGarmentDraft,
    create_serializable_draft_from_json,
    generate_serializable_pattern_from_json,
    summarize_serializable_result,
)


DEFINITION_PATH = Path("examples/garments/short_basico.json")


def test_create_serializable_draft_from_json_exposes_contract_metadata():
    draft = create_serializable_draft_from_json(DEFINITION_PATH)

    assert isinstance(draft, SerializableGarmentDraft)
    assert draft.metadata.code == "short_basico"
    assert draft.metadata.name == "Short basico"
    assert [item.name for item in draft.measurement_requirements] == [
        "waist",
        "hip",
        "outseam",
        "ease",
    ]


def test_generate_serializable_pattern_from_json_returns_engine_friendly_result():
    result = generate_serializable_pattern_from_json(
        DEFINITION_PATH,
        {
            "waist": 84,
            "hip": 104,
            "outseam": 45,
            "ease": 2,
        },
    )

    assert result.garment_code == "short_basico"
    assert result.garment_name == "Short basico"
    assert result.draft_class == "SerializableGarmentDraft"
    assert result.piece_count == 1
    assert result.pieces[0].name == "Short delantero"
    assert result.pieces[0].points["B"] == (23.0, 0.0)
    assert result.pieces[0].points["C"] == (28.0, 45.0)
    assert result.pieces[0].line_count() == 3


def test_summarize_serializable_result_matches_universal_cli_style():
    result = generate_serializable_pattern_from_json(
        DEFINITION_PATH,
        {
            "waist": 84,
            "hip": 104,
            "outseam": 45,
            "ease": 2,
        },
    )

    assert summarize_serializable_result(result) == [
        "GARMENT_CODE: short_basico",
        "GARMENT_NAME: Short basico",
        "DRAFT_CLASS: SerializableGarmentDraft",
        "PIECE_COUNT: 1",
        "PIECE_1: Short delantero lines=3",
    ]
PY

cat > docs/37_Fase_28_Adaptador_Prenda_Serializable_Generador_Universal.md <<'MD'
# Fase 28 - Adaptador de prenda serializable al generador universal

## Objetivo

Conectar el contrato serializable de prendas y el motor de formulas geometricas con una capa de adaptacion compatible con el flujo del generador universal.

Esta fase no registra todavia prendas JSON dentro del catalogo global y no modifica la GUI.

## Alcance implementado

Se agrego:

```text
engine/garments/serializable/adapter.py
scripts/generate_serializable_pattern.py
tests/test_serializable_garment_adapter.py
docs/37_Fase_28_Adaptador_Prenda_Serializable_Generador_Universal.md
```

Se actualizo:

```text
Makefile
```

Nuevo target:

```bash
make generate-serializable-short
```

## Flujo tecnico

```text
JSON serializable
  -> load_definition_from_json
  -> SerializableGarmentDefinition
  -> SerializableGarmentDraft
  -> generate_serializable_geometry
  -> SerializablePatternPiece
  -> SerializableGenerationResult
  -> resumen estilo CLI universal
```

## Resultado esperado

```text
GARMENT_CODE: short_basico
GARMENT_NAME: Short basico
DRAFT_CLASS: SerializableGarmentDraft
PIECE_COUNT: 1
PIECE_1: Short delantero lines=3
```

## Decisiones

- No se modifica el registro global de prendas.
- No se toca la GUI universal.
- No se exporta todavia la prenda JSON a SVG/DXF/PDF.
- El adaptador es una capa intermedia para no mezclar el DSL con las prendas Python existentes.

## Validaciones

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make generate-serializable-short
```

## Proxima fase sugerida

```text
Fase 29 - Registro de prendas serializables JSON en catalogo universal
```

En esa fase el codigo `short_basico` deberia poder resolverse desde el flujo universal por codigo de prenda, sin depender de un script separado.
MD

make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make generate-serializable-short

echo "== Fase 28 generada correctamente =="
echo "Archivos modificados/creados:"
git status --short
