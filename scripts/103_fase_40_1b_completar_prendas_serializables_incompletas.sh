#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 40.1B: completar prendas serializables incompletas =="
echo "== Rol operativo =="
echo "Arquitecto/consultor tecnico del producto + experto en patronaje."
echo "Criterio: MVP honesto. Completo en piezas, sin vender short como patron industrial definitivo."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el script para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del cambio =="
git status --short

mkdir -p docs tests scripts examples/garments

echo "== Actualizando short_basico.json con pieza posterior MVP diferenciada =="
cat > examples/garments/short_basico.json <<'JSON'
{
  "code": "short_basico",
  "name": "Short basico",
  "version": "0.2.1-mvp",
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
        "piece_role": "delantero",
        "industrial_status": "mvp_geometric_not_industrial",
        "notes": "Delantero MVP geometrico. No incluye curva de tiro industrial."
      }
    },
    {
      "name": "Short basico posterior",
      "points": {
        "A": [0, 0],
        "B": ["waist / 4 + 2", 0],
        "C": ["hip / 4 + 2", "outseam"],
        "D": [0, "outseam"]
      },
      "lines": [
        ["A", "B"],
        ["B", "C"],
        ["C", "D"],
        ["D", "A"]
      ],
      "metadata": {
        "side": "back",
        "piece_role": "posterior",
        "industrial_status": "mvp_geometric_not_industrial",
        "notes": "Posterior MVP diferenciado con mayor amplitud. No incluye curva de tiro industrial."
      }
    }
  ],
  "metadata": {
    "category": "bottom",
    "phase": "40.1B",
    "industrial_status": "mvp_geometric_not_industrial",
    "product_warning": "Completo en piezas delantero/posterior para GUI MVP; no es patron industrial definitivo. Pendiente short industrial con tiro y curvas."
  }
}
JSON

echo "== Actualizando falda_evase.json con pieza posterior =="
cat > examples/garments/falda_evase.json <<'JSON'
{
  "code": "falda_evase",
  "name": "Falda evase",
  "version": "0.2.1-mvp",
  "measurements": [
    {"name": "waist", "label": "Cintura", "unit": "cm", "default": 73},
    {"name": "hip", "label": "Cadera", "unit": "cm", "default": 99},
    {"name": "skirt_length", "label": "Largo falda", "unit": "cm", "default": 60},
    {"name": "ease", "label": "Holgura / Evase", "unit": "cm", "default": 12}
  ],
  "pieces": [
    {
      "name": "Falda evase delantera",
      "points": {
        "A": [0, 0],
        "B": ["waist / 4", 0],
        "C": ["hip / 4 + ease", "skirt_length"],
        "D": ["-ease", "skirt_length"]
      },
      "lines": [
        ["A", "B"],
        ["B", "C"],
        ["C", "D"],
        ["D", "A"]
      ],
      "metadata": {
        "side": "front",
        "piece_role": "delantero",
        "industrial_status": "mvp_geometric"
      }
    },
    {
      "name": "Falda evase posterior",
      "points": {
        "A": [0, 0],
        "B": ["waist / 4 + 1", 0],
        "C": ["hip / 4 + ease + 1", "skirt_length"],
        "D": ["-ease", "skirt_length"]
      },
      "lines": [
        ["A", "B"],
        ["B", "C"],
        ["C", "D"],
        ["D", "A"]
      ],
      "metadata": {
        "side": "back",
        "piece_role": "posterior",
        "industrial_status": "mvp_geometric",
        "notes": "Posterior MVP diferenciado con cintura y cadera ligeramente mayores."
      }
    }
  ],
  "metadata": {
    "category": "bottom",
    "phase": "40.1B",
    "industrial_status": "mvp_geometric",
    "product_warning": "Completo en piezas delantero/posterior para GUI MVP."
  }
}
JSON

echo "== Reforzando tests de completitud sin xfail =="
cat > tests/test_fase_40_1a_piece_completeness.py <<'PY'
from __future__ import annotations

from engine.generation import PatternGenerationRequest, generate_pattern
from engine.qa.piece_completeness import assert_complete_lower_garment


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


def test_short_basico_product_pattern_has_front_and_back_mvp() -> None:
    check = assert_complete_lower_garment(
        garment_code="short_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert check.is_complete
    assert any("delantero" in name.lower() for name in check.piece_names)
    assert any("posterior" in name.lower() for name in check.piece_names)


def test_falda_evase_product_pattern_has_front_and_back() -> None:
    check = assert_complete_lower_garment(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert check.is_complete
    assert any("delantera" in name.lower() for name in check.piece_names)
    assert any("posterior" in name.lower() for name in check.piece_names)


def test_generation_result_keeps_legacy_cli_behavior_for_falda_basica_without_full_option() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        )
    )

    assert result.piece_count == 1
PY

cat > tests/test_fase_40_1b_serializable_complete_pieces.py <<'PY'
from __future__ import annotations

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern, generate_pattern


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

    assert back.points["B"].x > front.points["B"].x
    assert back.points["C"].x > front.points["C"].x


def test_falda_evase_posterior_is_differentiated_from_front() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_evase",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        )
    )

    front = next(piece for piece in result.pieces if "delantera" in piece.name.lower())
    back = next(piece for piece in result.pieces if "posterior" in piece.name.lower())

    assert back.points["B"].x > front.points["B"].x
    assert back.points["C"].x > front.points["C"].x


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

cat > docs/56_Fase_40_1B_Completar_Prendas_Serializables_Incompletas.md <<'MD'
# Fase 40.1B - Completar prendas serializables incompletas

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

## Decision de producto

Se adopta la estrategia de **MVP honesto** para no bloquear Fase 40.

Esto significa:

- `falda_evase` debe quedar completa en piezas: delantero + posterior.
- `short_basico` debe quedar completo en piezas: delantero + posterior.
- `short_basico` se declara expresamente como **MVP geometrico no industrial**.
- Queda pendiente una futura fase de short industrial con tiro, curva de gancho, boca de pierna y ajuste completo.

## Criterio tecnico de patronaje aplicado

### Falda evase

El posterior se agrega como pieza propia:

- `Falda evase delantera`
- `Falda evase posterior`

El posterior MVP mantiene la logica base de falda evase, pero se diferencia con mayor amplitud en cintura/cadera.

### Short basico

El posterior se agrega como pieza propia:

- `Short basico delantero`
- `Short basico posterior`

El posterior MVP se diferencia con mayor amplitud en cintura/cadera/pierna.

Advertencia tecnica:

`short_basico` queda completo como patron MVP de piezas, pero no debe considerarse un patron industrial definitivo porque aun no incorpora:

- altura de tiro
- curva de gancho delantero
- curva de gancho posterior
- boca de pierna real
- curva de entrepierna

## Resultado esperado

```text
falda_basica: COMPLETE
pantalon_basico: COMPLETE
short_basico: COMPLETE
falda_evase: COMPLETE
PIECE_COMPLETENESS_OK
```

## Archivos modificados

- `examples/garments/short_basico.json`
- `examples/garments/falda_evase.json`
- `tests/test_fase_40_1a_piece_completeness.py`

## Archivos agregados

- `tests/test_fase_40_1b_serializable_complete_pieces.py`
- `docs/56_Fase_40_1B_Completar_Prendas_Serializables_Incompletas.md`

## Pendiente futuro

Crear una fase especifica para `short_basico_industrial`, con medidas adicionales y construccion real de tiro.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-fase-40-1b:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += """
validate-fase-40-1b:
\t.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py tests/test_fase_40_1b_serializable_complete_pieces.py -q
\t.venv/bin/python scripts/validate_piece_completeness.py
\t.venv/bin/python scripts/validate_serializable_catalog.py --definitions-dir examples/garments
\t.venv/bin/python scripts/generate_serializable_catalog.py --definitions-dir examples/garments
"""

if ".PHONY:" in text:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith(".PHONY:") and "validate-fase-40-1b" not in line:
            lines[i] = line + " validate-fase-40-1b"
            break
    text = "\n".join(lines) + "\n"

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion Fase 40.1B =="
make validate-fase-40-1b

echo "== Validacion Fase 40.1A despues de completar piezas =="
make validate-fase-40-1a

echo "== Validacion de completitud final =="
make validate-piece-completeness

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del cambio =="
git status --short

echo "== Fase 40.1B aplicada correctamente =="
