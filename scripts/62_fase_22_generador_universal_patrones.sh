#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# VirinoSoftware - Motor de Patronaje 2D
# Fase 22: Generador universal de patrones
#
# Objetivo:
#   Crear una capa universal de generación que resuelva una prenda por código
#   usando el registro dinámico de Fase 21 y ejecute su draft sin acoplarse
#   directamente a falda_basica.
#
# Ruta esperada del proyecto:
#   /home/antares/Proyecto/motor
#
# Flujo Git:
#   main      -> estable / produccion
#   develop   -> integracion
#   feature/* -> trabajo incremental por fase
# ==============================================================================

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-22-generador-universal-patrones"
SCRIPT_PATH="scripts/62_fase_22_generador_universal_patrones.sh"

cd "$PROJECT_DIR"

echo "== Fase 22: Generador universal de patrones =="
echo "== Proyecto: $PROJECT_DIR =="

echo
echo "== 1. Validando repositorio Git =="
git rev-parse --is-inside-work-tree >/dev/null

echo
echo "== 2. Estado inicial =="
git status --short
git branch --show-current
git log --oneline --decorate --max-count=10

echo
echo "== 3. Verificando arbol de trabajo =="
DIRTY_EXCLUDING_THIS_SCRIPT="$(git status --porcelain | grep -v "^?? ${SCRIPT_PATH}$" || true)"

if [[ -n "$DIRTY_EXCLUDING_THIS_SCRIPT" ]]; then
  echo
  echo "ERROR: El arbol de trabajo no esta limpio."
  echo "Cambios detectados:"
  echo "$DIRTY_EXCLUDING_THIS_SCRIPT"
  echo
  echo "Si solo son reportes regenerados por validaciones, puedes descartarlos con:"
  echo "  git restore reports/falda_basica_medidas_w73_h99_reporte.md reports/falda_basica_mvp_reporte.md"
  exit 1
fi

echo
echo "== 4. Sincronizando develop =="
git switch develop
git pull origin develop

echo
echo "== 5. Creando/cambiando a rama feature =="
if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
  git switch "$FEATURE_BRANCH"
else
  git switch -c "$FEATURE_BRANCH"
fi

echo
echo "== 6. Validacion base antes de modificar =="
make test
make list-garments
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 7. Creando capa universal de generacion =="

mkdir -p engine/generation

cat > engine/generation/__init__.py <<'PY'
"""Universal pattern generation package."""

from engine.generation.pattern_generator import (
    PatternGenerationError,
    PatternGenerationRequest,
    PatternGenerationResult,
    generate_pattern,
)

__all__ = [
    "PatternGenerationError",
    "PatternGenerationRequest",
    "PatternGenerationResult",
    "generate_pattern",
]
PY

cat > engine/generation/pattern_generator.py <<'PY'
"""Universal pattern generator.

This module resolves a garment code through the dynamic garment registry and
executes the draft class using normalized body measurements.

Fase 22 intentionally does not implement universal exports. Export orchestration
belongs to a later phase after the generator contract is stable.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from engine.garments import GarmentNotFoundError, get_garment
from engine.measurements import BodyMeasurements


class PatternGenerationError(Exception):
    """Raised when universal pattern generation fails."""


@dataclass(frozen=True)
class PatternGenerationRequest:
    """Input contract for universal pattern generation."""

    garment_code: str
    measurements: dict[str, Any]
    options: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PatternGenerationResult:
    """Output contract for universal pattern generation."""

    garment_code: str
    garment_name: str
    draft_class_name: str
    pieces: list[Any]
    measurements: BodyMeasurements
    options: dict[str, Any] = field(default_factory=dict)

    @property
    def piece_count(self) -> int:
        """Return the number of generated pattern pieces."""

        return len(self.pieces)


def _normalize_measurements(raw_measurements: dict[str, Any]) -> BodyMeasurements:
    """Convert a plain mapping into ``BodyMeasurements``.

    The current MVP measurement model is body-measurement based. This function
    keeps Fase 22 compatible with the existing falda_basica implementation while
    keeping a single universal entry point for future garments.
    """

    required = ("waist", "hip", "skirt_length")
    missing = [name for name in required if name not in raw_measurements]

    if missing:
        joined = ", ".join(missing)
        raise PatternGenerationError(f"Missing body measurements: {joined}")

    allowed = {
        "waist",
        "hip",
        "skirt_length",
        "ease",
        "hip_depth",
        "ease_hip",
        "ease_waist",
        "unit",
    }

    kwargs = {
        key: value
        for key, value in raw_measurements.items()
        if key in allowed and value is not None
    }

    try:
        return BodyMeasurements(**kwargs)
    except TypeError as exc:
        raise PatternGenerationError(
            f"Invalid measurements for BodyMeasurements: {kwargs}"
        ) from exc


def _validate_garment_requirements(draft: Any, measurements: dict[str, Any]) -> None:
    """Run the optional garment contract validation if available."""

    validator = getattr(draft, "validate_required_measurements", None)

    if callable(validator):
        validator(measurements)


def _run_draft(draft: Any) -> list[Any]:
    """Execute the best available drafting method."""

    if hasattr(draft, "draft") and callable(draft.draft):
        pieces = draft.draft()
    elif hasattr(draft, "draft_full") and callable(draft.draft_full):
        pieces = draft.draft_full()
    elif hasattr(draft, "build") and callable(draft.build):
        pieces = [draft.build()]
    else:
        raise PatternGenerationError(
            f"Draft class {draft.__class__.__name__} does not expose draft(), draft_full() or build()"
        )

    if pieces is None:
        raise PatternGenerationError(
            f"Draft class {draft.__class__.__name__} returned no pieces"
        )

    if isinstance(pieces, list):
        return pieces

    if isinstance(pieces, tuple):
        return list(pieces)

    return [pieces]


def generate_pattern(request: PatternGenerationRequest) -> PatternGenerationResult:
    """Generate a pattern using the garment registry.

    Args:
        request: Universal generation request.

    Returns:
        Universal generation result.

    Raises:
        PatternGenerationError: If the garment or measurements are invalid.
    """

    garment_code = request.garment_code.strip()

    if not garment_code:
        raise PatternGenerationError("garment_code cannot be empty")

    try:
        draft_class = get_garment(garment_code)
    except GarmentNotFoundError as exc:
        raise PatternGenerationError(f"Unknown garment code: {garment_code}") from exc

    measurements = _normalize_measurements(request.measurements)

    try:
        draft = draft_class(measurements)
    except TypeError as exc:
        raise PatternGenerationError(
            f"Could not instantiate {draft_class.__name__} with BodyMeasurements"
        ) from exc

    _validate_garment_requirements(draft, request.measurements)
    pieces = _run_draft(draft)

    metadata = getattr(draft_class, "metadata", None)
    garment_name = getattr(metadata, "name", garment_code)

    return PatternGenerationResult(
        garment_code=garment_code,
        garment_name=garment_name,
        draft_class_name=draft_class.__name__,
        pieces=pieces,
        measurements=measurements,
        options=dict(request.options),
    )
PY

echo
echo "== 8. Creando CLI universal =="

cat > scripts/generate_pattern.py <<'PY'
#!/usr/bin/env python3
"""Generate a pattern through the universal pattern generator."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from engine.generation import PatternGenerationRequest, generate_pattern


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate a garment pattern using the universal generator."
    )
    parser.add_argument(
        "--garment",
        default="falda_basica",
        help="Garment code registered in the garment registry.",
    )
    parser.add_argument("--waist", type=float, required=True, help="Waist in cm.")
    parser.add_argument("--hip", type=float, required=True, help="Hip in cm.")
    parser.add_argument(
        "--skirt-length",
        type=float,
        required=True,
        help="Skirt length in cm. Required by current MVP BodyMeasurements.",
    )
    parser.add_argument("--ease", type=float, default=None, help="Optional ease in cm.")
    parser.add_argument(
        "--hip-depth",
        type=float,
        default=None,
        help="Optional hip depth in cm.",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()

    measurements = {
        "waist": args.waist,
        "hip": args.hip,
        "skirt_length": args.skirt_length,
        "ease": args.ease,
        "hip_depth": args.hip_depth,
    }

    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=args.garment,
            measurements=measurements,
        )
    )

    print(f"GARMENT_CODE: {result.garment_code}")
    print(f"GARMENT_NAME: {result.garment_name}")
    print(f"DRAFT_CLASS: {result.draft_class_name}")
    print(f"PIECE_COUNT: {result.piece_count}")

    for index, piece in enumerate(result.pieces, start=1):
        piece_name = getattr(piece, "name", f"piece_{index}")
        line_count = len(getattr(piece, "lines", []))
        print(f"PIECE_{index}: {piece_name} lines={line_count}")


if __name__ == "__main__":
    main()
PY

chmod +x scripts/generate_pattern.py

echo
echo "== 9. Actualizando Makefile si aplica =="

if ! grep -q "^generate-pattern:" Makefile; then
  cat >> Makefile <<'MK'

generate-pattern:
	.venv/bin/python scripts/generate_pattern.py --garment falda_basica --waist 73 --hip 99 --skirt-length 60
MK
fi

echo
echo "== 10. Creando tests del generador universal =="

cat > tests/test_universal_pattern_generator.py <<'PY'
"""Tests for Fase 22 universal pattern generator."""

from __future__ import annotations

import pytest

from engine.generation import (
    PatternGenerationError,
    PatternGenerationRequest,
    PatternGenerationResult,
    generate_pattern,
)


def test_generate_pattern_uses_registered_basic_skirt() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={
                "waist": 73,
                "hip": 99,
                "skirt_length": 60,
            },
        )
    )

    assert isinstance(result, PatternGenerationResult)
    assert result.garment_code == "falda_basica"
    assert result.garment_name == "Falda basica"
    assert result.draft_class_name == "BasicSkirtDraft"
    assert result.piece_count >= 1


def test_generate_pattern_preserves_measurements() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={
                "waist": 73,
                "hip": 99,
                "skirt_length": 60,
                "ease": 2,
                "hip_depth": 20,
            },
        )
    )

    assert result.measurements.waist == 73
    assert result.measurements.hip == 99
    assert result.measurements.skirt_length == 60


def test_generate_pattern_rejects_unknown_garment() -> None:
    with pytest.raises(PatternGenerationError) as exc:
        generate_pattern(
            PatternGenerationRequest(
                garment_code="chaqueta_inexistente",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            )
        )

    assert "Unknown garment code" in str(exc.value)


def test_generate_pattern_rejects_missing_measurements() -> None:
    with pytest.raises(PatternGenerationError) as exc:
        generate_pattern(
            PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={
                    "waist": 73,
                },
            )
        )

    assert "Missing body measurements" in str(exc.value)


def test_generate_pattern_rejects_empty_garment_code() -> None:
    with pytest.raises(PatternGenerationError) as exc:
        generate_pattern(
            PatternGenerationRequest(
                garment_code=" ",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            )
        )

    assert "garment_code cannot be empty" in str(exc.value)
PY

echo
echo "== 11. Documentando Fase 22 =="

cat > docs/31_Fase_22_Generador_Universal_Patrones.md <<'MD'
# Fase 22 - Generador universal de patrones

## Objetivo

Crear una capa universal de generación de patrones que reciba un código de prenda, resuelva la clase generadora desde el registro dinámico y ejecute el draft correspondiente.

## Alcance implementado

- Se crea paquete `engine/generation/`.
- Se crea `PatternGenerationRequest`.
- Se crea `PatternGenerationResult`.
- Se crea `PatternGenerationError`.
- Se crea función `generate_pattern`.
- Se crea CLI `scripts/generate_pattern.py`.
- Se agrega target `make generate-pattern`.
- Se agregan tests del generador universal.
- Se mantiene intacta la generación legacy de falda básica.
- No se crean nuevas prendas.
- No se implementa exportación universal todavía.
- No se modifica el GUI.

## Flujo técnico

```text
garment_code
  -> get_garment(code)
  -> draft_class
  -> BodyMeasurements
  -> draft_class(measurements)
  -> draft()
  -> PatternGenerationResult
```

## Uso desde Python

```python
from engine.generation import PatternGenerationRequest, generate_pattern

result = generate_pattern(
    PatternGenerationRequest(
        garment_code="falda_basica",
        measurements={
            "waist": 73,
            "hip": 99,
            "skirt_length": 60,
        },
    )
)
```

## Uso desde CLI

```bash
make generate-pattern
```

Salida esperada:

```text
GARMENT_CODE: falda_basica
GARMENT_NAME: Falda basica
DRAFT_CLASS: BasicSkirtDraft
PIECE_COUNT: ...
```

## Decisión técnica

Fase 22 no toca exportadores ni GUI. Primero se estabiliza el contrato universal de generación.

La exportación universal y/o integración GUI deben quedar para fases posteriores.

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
MD

echo
echo "== 12. Eliminando respaldos temporales si existen =="
find . -name "*.bak.*" -type f -delete

echo
echo "== 13. Validaciones finales =="
make test
make list-garments
make generate-pattern
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 14. Estado final =="
git status --short
git diff --stat

echo
echo "== Fase 22 preparada =="
echo
echo "Si todo esta correcto:"
echo "  git restore reports/falda_basica_medidas_w73_h99_reporte.md reports/falda_basica_mvp_reporte.md || true"
echo "  git add engine/generation scripts/generate_pattern.py tests/test_universal_pattern_generator.py docs/31_Fase_22_Generador_Universal_Patrones.md Makefile ${SCRIPT_PATH}"
echo "  git commit -m \"Fase 22 generador universal de patrones\""
echo "  git push -u origin $FEATURE_BRANCH"
