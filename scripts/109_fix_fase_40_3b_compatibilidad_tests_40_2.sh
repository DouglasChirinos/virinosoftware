#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40.3B: compatibilidad de tests 40.2 con curvas estructurales =="
echo "== Criterio =="
echo "Fase 40.2 validaba curvas visuales punteadas. Fase 40.3B las reemplaza por curvas estructurales semanticas."
echo "El contrato correcto ahora es: debe existir curva exportada; si es estructural, no debe existir overlay punteado duplicado."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  exit 1
fi

echo "== Estado Git antes del fix =="
git status --short

cat > tests/test_fase_40_2_visual_curves.py <<'PY'
from __future__ import annotations

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern


def _export_svg_text(tmp_path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_curves_test",
            output_dir=tmp_path / garment_code,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def _assert_curve_exported(content: str, old_visual_label: str, new_structural_labels: tuple[str, ...]) -> None:
    """Validate curve export across Fase 40.2 and Fase 40.3B.

    Fase 40.2 introduced dashed visual guide curves. Fase 40.3B correctly
    promotes curves to structural contour geometry with patronage semantics.
    Therefore this historical test accepts the old visual label only when the
    export has not been upgraded, and otherwise validates the structural label.
    """

    assert "<path" in content

    has_old_visual_curve = old_visual_label in content
    has_structural_curve = 'class="structural-curve"' in content
    has_expected_structural_label = any(label in content for label in new_structural_labels)

    assert has_old_visual_curve or (has_structural_curve and has_expected_structural_label)

    if has_structural_curve:
        # Fase 40.3B: structural contour curves replace dashed guide overlays.
        assert 'stroke-dasharray="6 3"' not in content


def test_falda_basica_svg_exports_hip_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Curva cadera costado",
        new_structural_labels=("Costado curvo de cadera",),
    )


def test_falda_evase_svg_exports_hem_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Correccion suave de bajo",
        new_structural_labels=("Bajo curvo corregido",),
    )


def test_pantalon_basico_svg_exports_mvp_rise_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Curva tiro/costado MVP",
        new_structural_labels=("Curva estructural de tiro", "Curva estructural de entrepierna"),
    )


def test_short_basico_svg_exports_mvp_rise_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Curva tiro/entrepierna MVP",
        new_structural_labels=("Curva estructural tiro/entrepierna", "Boca de pierna curva MVP"),
    )
PY

cat > docs/61_Fix_Fase_40_3B_Compatibilidad_Tests_40_2.md <<'MD'
# Fix Fase 40.3B — Compatibilidad de tests 40.2

## Problema

Fase 40.3B introdujo la regla correcta de producto:

```text
Si existe curva estructural de contorno, no debe coexistir la curva visual punteada equivalente.
```

Los tests historicos de Fase 40.2 seguian esperando labels de curvas visuales punteadas:

- `Curva cadera costado`
- `Correccion suave de bajo`
- `Curva tiro/costado MVP`
- `Curva tiro/entrepierna MVP`

Por eso `make validate-fase-40-3` fallaba aunque Fase 40.3B estuviera funcionando correctamente.

## Decision

Actualizar los tests de Fase 40.2 para aceptar dos estados validos:

1. Estado historico: curva visual punteada.
2. Estado evolucionado: curva estructural semantica.

Cuando el SVG contiene `class="structural-curve"`, el test exige que no exista `stroke-dasharray="6 3"` para evitar duplicidad visual.

## Criterio tecnico

La prueba ya no valida un texto viejo. Valida el contrato de producto:

- debe existir una curva exportada;
- si es estructural, debe ser la unica curva visible del tramo;
- no debe quedar overlay punteado duplicado.

## Validacion

```bash
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness
```
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-fase-40-3b:" not in text:
    text += """

validate-fase-40-3b:
	.venv/bin/python -m pytest tests/test_fase_40_3b_curve_semantics.py -q
"""

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion puntual del fix =="
.venv/bin/python -m pytest tests/test_fase_40_2_visual_curves.py -q
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix aplicado =="
echo "Siguiente paso: reexportar los 4 SVG/PDF desde GUI para validacion visual final."
