#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40.1B: normalizar puntos serializables en tests =="
echo "== Rol operativo =="
echo "Arquitecto/consultor tecnico del producto + experto en patronaje."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  exit 1
fi

echo "== Estado Git antes del fix =="
git status --short

cat > tests/test_fase_40_1b_serializable_complete_pieces.py <<'PY'
from __future__ import annotations

from typing import Any

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern, generate_pattern


def _x(point: Any) -> float:
    """Return x coordinate from Point, tuple/list or dict-like point."""

    if hasattr(point, "x"):
        return float(point.x)

    if isinstance(point, dict):
        if "x" in point:
            return float(point["x"])
        return float(point[0])

    return float(point[0])


def test_short_basico_generates_front_and_back_serializable_pieces() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="short_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        )
    )

    names = [piece.name for piece in result.pieces]

    assert result.piece_count == 2
    assert "Short basico delantero" in names
    assert "Short basico posterior" in names


def test_falda_evase_generates_front_and_back_serializable_pieces() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_evase",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        )
    )

    names = [piece.name for piece in result.pieces]

    assert result.piece_count == 2
    assert "Falda evase delantera" in names
    assert "Falda evase posterior" in names


def test_short_basico_posterior_is_mvp_differentiated_from_front() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="short_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        )
    )

    front = next(piece for piece in result.pieces if "delantero" in piece.name.lower())
    back = next(piece for piece in result.pieces if "posterior" in piece.name.lower())

    assert _x(back.points["B"]) > _x(front.points["B"])
    assert _x(back.points["C"]) > _x(front.points["C"])


def test_falda_evase_posterior_is_differentiated_from_front() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_evase",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        )
    )

    front = next(piece for piece in result.pieces if "delantera" in piece.name.lower())
    back = next(piece for piece in result.pieces if "posterior" in piece.name.lower())

    assert _x(back.points["B"]) > _x(front.points["B"])
    assert _x(back.points["C"]) > _x(front.points["C"])


def test_serializable_complete_patterns_export_svg_mentions_back_pieces(tmp_path) -> None:
    short_result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="short_basico",
                measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
            ),
            output_name="short_basico_complete_test",
            output_dir=tmp_path / "short",
            export_dxf=False,
            export_pdf=False,
        )
    )
    falda_result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_evase",
                measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
            ),
            output_name="falda_evase_complete_test",
            output_dir=tmp_path / "falda",
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert short_result.svg_path is not None
    assert falda_result.svg_path is not None
    assert "Short basico posterior" in short_result.svg_path.read_text(encoding="utf-8")
    assert "Falda evase posterior" in falda_result.svg_path.read_text(encoding="utf-8")
PY

cat > docs/57_Fix_Fase_40_1B_Normalizacion_Puntos_Serializables_Tests.md <<'MD'
# Fix Fase 40.1B - Normalizacion de puntos serializables en tests

Fecha: 2026-07-05

## Problema

Los tests de Fase 40.1B asumian que los puntos generados para prendas serializables eran objetos con atributos `.x` y `.y`.

Sin embargo, el flujo serializable puede devolver puntos como tuplas/listas antes de la normalizacion final de exportacion.

Error observado:

```text
AttributeError: 'tuple' object has no attribute 'x'
```

## Correccion

Se agrega una funcion auxiliar `_x(point)` dentro del test para leer coordenadas desde:

- objetos `Point`
- tuplas/listas
- diccionarios

## Criterio de producto/patronaje preservado

La prueba sigue validando lo importante:

- `short_basico` genera delantero + posterior.
- `falda_evase` genera delantera + posterior.
- el posterior es geometricamente diferenciado del delantero.
- el SVG exportado menciona las piezas posteriores.

## Roles obligatorios del asistente en este proyecto

- Arquitecto / consultor tecnico del producto.
- Experto en patronaje.

Una fase no se cierra solo porque los tests pasan; debe ser valida como producto y como patron.
MD

echo "== Validacion Fase 40.1B =="
make validate-fase-40-1b

echo "== Validacion de completitud final =="
make validate-piece-completeness

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix Fase 40.1B aplicado correctamente =="
