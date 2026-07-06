#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 40.1A: Validacion de completitud de piezas por prenda =="
echo "== Rol operativo =="
echo "Arquitecto/consultor tecnico del producto + experto en patronaje."
echo "No se cierra fase solo por tests; se valida utilidad real para usuario final."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el script para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del cambio =="
git status --short

mkdir -p engine/qa docs tests scripts

cat > engine/qa/piece_completeness.py <<'PY'
"""Product-level piece completeness checks for generated garments.

These checks are not geometry-unit tests. They validate whether a generated
pattern is complete enough to be presented to an end user as a usable garment
pattern.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from engine.generation import PatternGenerationRequest, generate_pattern


LOWER_GARMENT_CODES = {
    "falda_basica",
    "falda_evase",
    "pantalon_basico",
    "short_basico",
}


@dataclass(frozen=True)
class PieceCompletenessResult:
    garment_code: str
    piece_names: tuple[str, ...]
    has_front: bool
    has_back: bool

    @property
    def is_complete(self) -> bool:
        return self.has_front and self.has_back

    @property
    def missing_roles(self) -> tuple[str, ...]:
        missing: list[str] = []
        if not self.has_front:
            missing.append("delantero")
        if not self.has_back:
            missing.append("posterior")
        return tuple(missing)


def _normalize_name(value: str) -> str:
    return value.strip().lower()


def _has_front(piece_names: tuple[str, ...]) -> bool:
    return any("delanter" in _normalize_name(name) or "front" in _normalize_name(name) for name in piece_names)


def _has_back(piece_names: tuple[str, ...]) -> bool:
    return any("posterior" in _normalize_name(name) or "espalda" in _normalize_name(name) or "back" in _normalize_name(name) for name in piece_names)


def validate_generated_piece_completeness(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    options: dict[str, Any] | None = None,
) -> PieceCompletenessResult:
    """Generate a garment and validate front/back product completeness."""

    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options=dict(options or {}),
        )
    )
    piece_names = tuple(str(getattr(piece, "name", "")) for piece in result.pieces)

    return PieceCompletenessResult(
        garment_code=garment_code,
        piece_names=piece_names,
        has_front=_has_front(piece_names),
        has_back=_has_back(piece_names),
    )


def assert_complete_lower_garment(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    options: dict[str, Any] | None = None,
) -> PieceCompletenessResult:
    """Assert that a lower garment has at least front and back pieces."""

    check = validate_generated_piece_completeness(
        garment_code=garment_code,
        measurements=measurements,
        options=options,
    )

    if garment_code in LOWER_GARMENT_CODES and not check.is_complete:
        missing = ", ".join(check.missing_roles)
        pieces = ", ".join(check.piece_names) or "<sin piezas>"
        raise AssertionError(
            f"Patron incompleto para {garment_code}. "
            f"Faltan piezas: {missing}. Piezas generadas: {pieces}"
        )

    return check
PY

cat > scripts/validate_piece_completeness.py <<'PY'
#!/usr/bin/env python
from __future__ import annotations

from engine.qa.piece_completeness import assert_complete_lower_garment


CASES = [
    (
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    ),
    (
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        {},
    ),
    (
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        {},
    ),
    (
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        {},
    ),
]


def main() -> int:
    for garment_code, measurements, options in CASES:
        check = assert_complete_lower_garment(
            garment_code=garment_code,
            measurements=measurements,
            options=options,
        )
        print(
            f"{garment_code}: COMPLETE pieces={len(check.piece_names)} "
            f"names={', '.join(check.piece_names)}"
        )

    print("PIECE_COMPLETENESS_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x scripts/validate_piece_completeness.py

cat > tests/test_fase_40_1a_piece_completeness.py <<'PY'
from __future__ import annotations

import pytest

from engine.generation import PatternGenerationRequest, generate_pattern
from engine.qa.piece_completeness import assert_complete_lower_garment, validate_generated_piece_completeness


def test_falda_basica_gui_full_pattern_has_front_and_back() -> None:
    check = assert_complete_lower_garment(
        garment_code="falda_basica",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        options={"full_pattern": True},
    )

    assert check.is_complete
    assert any("delantera" in name.lower() for name in check.piece_names)
    assert any("posterior" in name.lower() for name in check.piece_names)


def test_pantalon_basico_has_front_and_back() -> None:
    check = assert_complete_lower_garment(
        garment_code="pantalon_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert check.is_complete


@pytest.mark.xfail(reason="Catalogo incompleto: short_basico aun no tiene pieza posterior.")
def test_short_basico_product_pattern_must_have_front_and_back() -> None:
    assert_complete_lower_garment(
        garment_code="short_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )


@pytest.mark.xfail(reason="Catalogo incompleto: falda_evase aun no tiene pieza posterior.")
def test_falda_evase_product_pattern_must_have_front_and_back() -> None:
    assert_complete_lower_garment(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )


def test_short_basico_is_currently_incomplete_and_must_not_be_closed_as_product() -> None:
    check = validate_generated_piece_completeness(
        garment_code="short_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert not check.is_complete
    assert check.has_front
    assert not check.has_back


def test_falda_evase_is_currently_incomplete_and_must_not_be_closed_as_product() -> None:
    check = validate_generated_piece_completeness(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert not check.is_complete
    assert check.has_front
    assert not check.has_back


def test_generation_result_keeps_legacy_cli_behavior_for_falda_basica_without_full_option() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        )
    )

    assert result.piece_count == 1
PY

cat > docs/55_Fase_40_1A_Validacion_Completitud_Piezas.md <<'MD'
# Fase 40.1A - Validacion de completitud de piezas por prenda

Fecha: 2026-07-05

## Roles obligatorios del asistente en este proyecto

### Rol 1 - Arquitecto / consultor tecnico del producto

Responsabilidad:

- Validar si lo generado sirve realmente para usuario final.
- No cerrar fases solo porque los tests pasan.
- Detectar inconsistencias funcionales, visuales, tecnicas y de flujo antes de cerrar una fase.

### Rol 2 - Experto en patronaje

Responsabilidad:

- Validar que los patrones generados tengan sentido tecnico de patronaje.
- Revisar piezas necesarias: delantero, posterior y piezas complementarias cuando apliquen.
- Diferenciar medidas corporales de entrada vs medidas geometricas reales de pieza.
- Validar cotas, proporciones, interpretacion para confeccion y usabilidad del patron exportado.

## Regla de cierre

Una fase no se cierra si el resultado no es valido como producto y como patron, aunque los tests tecnicos pasen.

## Hallazgo

Durante Fase 40.1 se detecto que algunas prendas generaban salidas visualmente limpias pero incompletas como patron:

- `short_basico` genera solo delantero.
- `falda_evase` genera solo delantero.
- `falda_basica` requiere `full_pattern=True` desde GUI para generar delantero + posterior.
- `pantalon_basico` declara delantero + posterior, pero requiere validacion visual de separacion, cotas y usabilidad.

## Alcance aplicado

Se agrega una validacion de producto para verificar que las prendas inferiores basicas tengan como minimo:

- pieza delantera
- pieza posterior

## Archivos agregados

- `engine/qa/piece_completeness.py`
- `scripts/validate_piece_completeness.py`
- `tests/test_fase_40_1a_piece_completeness.py`

## Resultado esperado actual

La validacion documenta explicitamente que el catalogo todavia no esta cerrado como producto:

- `falda_basica`: completo desde GUI con `full_pattern=True`.
- `pantalon_basico`: completo en piezas declaradas.
- `short_basico`: incompleto, falta posterior.
- `falda_evase`: incompleto, falta posterior.

## Proximo paso

Fase 40.1B:

- Agregar pieza posterior real para `short_basico`.
- Agregar pieza posterior real para `falda_evase`.
- Validar patronaje de cada pieza.
- Revalidar cotas visuales despues de tener patrones completos.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-piece-completeness:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += """
validate-piece-completeness:
\t.venv/bin/python scripts/validate_piece_completeness.py

validate-fase-40-1a:
\t.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py -q
"""

if ".PHONY:" in text:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith(".PHONY:"):
            for target in ("validate-piece-completeness", "validate-fase-40-1a"):
                if target not in line:
                    line += f" {target}"
            lines[i] = line
            break
    text = "\n".join(lines) + "\n"

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion Fase 40.1A =="
.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py -q

echo "== Diagnostico de completitud =="
echo "Nota: validate-piece-completeness fallara hasta corregir short_basico y falda_evase."
set +e
make validate-piece-completeness
status=$?
set -e
if [ "$status" -eq 0 ]; then
  echo "PIECE_COMPLETENESS_FULL_OK"
else
  echo "PIECE_COMPLETENESS_PENDING_OK: hay prendas incompletas detectadas correctamente."
fi

echo "== Estado Git despues del cambio =="
git status --short

echo "== Fase 40.1A aplicada: diagnostico de completitud listo =="
