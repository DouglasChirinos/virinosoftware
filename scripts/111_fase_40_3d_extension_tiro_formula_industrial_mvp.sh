#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 40.3D: extension de tiro con formula industrial MVP =="
echo "== Criterio de patronaje =="
echo "La curva de tiro no se define solo por concavidad: debe usar extension de tiro basada en cadera."
echo "Delantero: hip/20..hip/16. Posterior: hip/8..hip/6. Posterior siempre mayor."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el script para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del cambio =="
git status --short

python3 - <<'PY'
from pathlib import Path

path = Path("engine/exports/structural_curves.py")
if not path.exists():
    raise SystemExit("ERROR: no existe engine/exports/structural_curves.py. Ejecuta primero Fase 40.3C.")

text = path.read_text(encoding="utf-8")

required = [
    "concavity_direction",
    "def _pants_structural_curves",
    "def _short_structural_curves",
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"ERROR: structural_curves.py no parece estar en estado Fase 40.3C. Falta: {marker}")

if "extension_formula:" not in text:
    text = text.replace(
        "    concavity_direction: CurveConcavityDirection = \"none\"\n",
        "    concavity_direction: CurveConcavityDirection = \"none\"\n"
        "    extension_formula: str = \"\"\n"
        "    extension_cm: float = 0.0\n"
        "    extension_range_cm: tuple[float, float] = (0.0, 0.0)\n"
        "    measurement_basis: str = \"\"\n",
    )

if '"extension_formula"' not in text:
    text = text.replace(
        "        \"concavity_direction\": curve.concavity_direction,\n",
        "        \"concavity_direction\": curve.concavity_direction,\n"
        "        \"extension_formula\": curve.extension_formula,\n"
        "        \"extension_cm\": round(float(curve.extension_cm), 4),\n"
        "        \"extension_range_cm\": [round(float(curve.extension_range_cm[0]), 4), round(float(curve.extension_range_cm[1]), 4)],\n"
        "        \"measurement_basis\": curve.measurement_basis,\n",
    )

helper = r'''

def _measurement_float(piece: PatternPiece, name: str) -> float | None:
    """Read a numeric measurement from piece metadata when exporter attached it."""

    measurements = (piece.metadata or {}).get("measurements", {})
    if not isinstance(measurements, dict):
        return None

    raw = measurements.get(name)
    if raw is None:
        return None

    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def _estimated_total_hip_cm(piece: PatternPiece, piece_width: float) -> float:
    """Return total hip used as base for crotch extension.

    Preference order:
    1. Real hip measurement attached by exporter.
    2. Conservative approximation from current piece width.

    The fallback keeps tests usable when structural curves are attached directly
    outside the exporter pipeline.
    """

    hip = _measurement_float(piece, "hip")
    if hip and hip > 0:
        return hip

    # Current MVP lower-body pieces represent roughly a quarter hip width.
    return max(piece_width * 4.0, 1.0)


def _crotch_extension_range_cm(total_hip_cm: float, posterior: bool) -> tuple[float, float]:
    """Industrial MVP range for crotch extension based on full hip circumference.

    Front crotch extension: 1/20..1/16 of full hip.
    Back crotch extension: 1/8..1/6 of full hip.
    """

    if posterior:
        return (total_hip_cm / 8.0, total_hip_cm / 6.0)
    return (total_hip_cm / 20.0, total_hip_cm / 16.0)


def _crotch_extension_formula(posterior: bool) -> str:
    return "hip/8..hip/6" if posterior else "hip/20..hip/16"


def _crotch_extension_depth_cm(piece: PatternPiece, piece_width: float, posterior: bool) -> tuple[float, tuple[float, float], str, str]:
    """Return working crotch extension depth and its formula metadata.

    The chosen working value is the midpoint of the industrial MVP range.
    It is still MVP because the current pants/short geometry does not yet have
    a full industrial crotch baseline, knee line, grainline, or notch system.
    """

    total_hip = _estimated_total_hip_cm(piece, piece_width)
    range_cm = _crotch_extension_range_cm(total_hip, posterior)
    depth = (range_cm[0] + range_cm[1]) / 2.0
    formula = _crotch_extension_formula(posterior)
    basis = f"hip={total_hip:.2f}cm"
    return depth, range_cm, formula, basis
'''

if "def _crotch_extension_range_cm" not in text:
    marker = "def _pants_structural_curves(piece: PatternPiece) -> list[StructuralCurve]:"
    if marker not in text:
        raise SystemExit("ERROR: no se encontro _pants_structural_curves para insertar helpers")
    text = text.replace(marker, helper + "\n\n" + marker)

# Patch pants depth block.
old = '''    inward_depth = max(piece_width * (0.11 if posterior else 0.08), 1.4)
    concavity_direction: CurveConcavityDirection = "inward_deeper" if posterior else "inward"
'''
new = '''    inward_depth, extension_range, extension_formula, measurement_basis = _crotch_extension_depth_cm(
        piece, piece_width, posterior
    )
    concavity_direction: CurveConcavityDirection = "inward_deeper" if posterior else "inward"
'''
if old in text:
    text = text.replace(old, new, 1)
elif "_crotch_extension_depth_cm(" not in text:
    raise SystemExit("ERROR: no se pudo parchear inward_depth de pantalon")

old_curve = '''            concavity_direction=concavity_direction,
            patronage_note=crotch_note,
        ),
'''
new_curve = '''            concavity_direction=concavity_direction,
            extension_formula=extension_formula,
            extension_cm=inward_depth,
            extension_range_cm=extension_range,
            measurement_basis=measurement_basis,
            patronage_note=crotch_note,
        ),
'''
if old_curve in text:
    text = text.replace(old_curve, new_curve, 1)
elif "extension_formula=extension_formula" not in text:
    raise SystemExit("ERROR: no se pudo agregar metadata de extension en pantalon")

# Patch short depth block.
old_short = '''        inward_depth = max(piece_width * (0.12 if posterior else 0.09), 1.2)
        inward_x = _inward_control_x(start, end, inward_depth)
'''
new_short = '''        inward_depth, extension_range, extension_formula, measurement_basis = _crotch_extension_depth_cm(
            piece, piece_width, posterior
        )
        inward_x = _inward_control_x(start, end, inward_depth)
'''
if old_short in text:
    text = text.replace(old_short, new_short, 1)
elif text.count("_crotch_extension_depth_cm(") < 2:
    raise SystemExit("ERROR: no se pudo parchear inward_depth de short")

old_short_curve = '''                concavity_direction=concavity_direction,
                patronage_note=(
                    "Curva concava posterior de tiro/entrepierna MVP: entra hacia dentro con mayor profundidad; pendiente patron industrial de short."
                    if posterior
                    else "Curva concava delantera de tiro/entrepierna MVP: entra hacia dentro; pendiente patron industrial de short."
                ),
            )
'''
new_short_curve = '''                concavity_direction=concavity_direction,
                extension_formula=extension_formula,
                extension_cm=inward_depth,
                extension_range_cm=extension_range,
                measurement_basis=measurement_basis,
                patronage_note=(
                    "Curva concava posterior de tiro/entrepierna MVP: entra hacia dentro con extension de tiro mayor; pendiente patron industrial de short."
                    if posterior
                    else "Curva concava delantera de tiro/entrepierna MVP: entra hacia dentro con extension de tiro menor; pendiente patron industrial de short."
                ),
            )
'''
if old_short_curve in text:
    text = text.replace(old_short_curve, new_short_curve, 1)
elif text.count("extension_formula=extension_formula") < 2:
    raise SystemExit("ERROR: no se pudo agregar metadata de extension en short")

# Make note more explicit without requiring exact old strings.
text = text.replace(
    "Curva concava de tiro posterior MVP: entra hacia dentro con mayor profundidad; pendiente metodo industrial de gancho posterior.",
    "Curva concava de tiro posterior MVP: entra hacia dentro con extension de tiro mayor; pendiente metodo industrial de gancho posterior.",
)
text = text.replace(
    "Curva concava de tiro delantero MVP: entra hacia dentro; pendiente metodo industrial de gancho delantero.",
    "Curva concava de tiro delantero MVP: entra hacia dentro con extension de tiro menor; pendiente metodo industrial de gancho delantero.",
)

path.write_text(text, encoding="utf-8")
PY

cat > tests/test_fase_40_3d_crotch_extension_formula.py <<'PY'
from __future__ import annotations

from engine.exports.structural_curves import attach_structural_curves
from engine.generation import PatternGenerationRequest
from engine.generation.exporter import normalize_pieces
from engine.generation.pattern_generator import generate_pattern


def _pieces_with_metadata(garment_code: str, measurements: dict[str, float]):
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options={},
        )
    )
    pieces = normalize_pieces(result.pieces)
    # Simulate exporter metadata because formula should prefer full hip.
    for piece in pieces:
        piece.metadata.setdefault("measurements", dict(measurements))
    attach_structural_curves(pieces, garment_code)
    return pieces


def _crotch_curves(garment_code: str, measurements: dict[str, float]) -> list[tuple[str, dict]]:
    curves: list[tuple[str, dict]] = []
    for piece in _pieces_with_metadata(garment_code, measurements):
        for curve in piece.metadata.get("structural_curves", []):
            if curve["intent"] == "crotch_curve":
                curves.append((piece.name, curve))
    return curves


def test_pants_crotch_extension_uses_hip_formula_ranges() -> None:
    hip = 104.0
    curves = _crotch_curves(
        "pantalon_basico",
        {"waist": 84, "hip": hip, "outseam": 100, "inseam": 76},
    )
    assert len(curves) == 2

    front = next(curve for piece_name, curve in curves if "delantero" in piece_name.lower())
    back = next(curve for piece_name, curve in curves if "posterior" in piece_name.lower())

    assert front["extension_formula"] == "hip/20..hip/16"
    assert back["extension_formula"] == "hip/8..hip/6"

    assert front["extension_range_cm"] == [round(hip / 20, 4), round(hip / 16, 4)]
    assert back["extension_range_cm"] == [round(hip / 8, 4), round(hip / 6, 4)]

    assert front["extension_range_cm"][0] <= front["extension_cm"] <= front["extension_range_cm"][1]
    assert back["extension_range_cm"][0] <= back["extension_cm"] <= back["extension_range_cm"][1]
    assert back["extension_cm"] > front["extension_cm"]


def test_pants_back_crotch_extension_is_materially_deeper_than_front() -> None:
    curves = _crotch_curves(
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )
    front = next(curve for piece_name, curve in curves if "delantero" in piece_name.lower())
    back = next(curve for piece_name, curve in curves if "posterior" in piece_name.lower())

    assert back["concavity_direction"] == "inward_deeper"
    assert front["concavity_direction"] == "inward"
    assert back["extension_cm"] >= front["extension_cm"] * 2.0


def test_short_crotch_extension_keeps_same_base_formula_semantics() -> None:
    hip = 104.0
    curves = _crotch_curves(
        "short_basico",
        {"waist": 84, "hip": hip, "outseam": 45, "inseam": 20},
    )
    assert len(curves) == 2

    front = next(curve for piece_name, curve in curves if "delantero" in piece_name.lower())
    back = next(curve for piece_name, curve in curves if "posterior" in piece_name.lower())

    assert front["extension_formula"] == "hip/20..hip/16"
    assert back["extension_formula"] == "hip/8..hip/6"
    assert back["extension_cm"] > front["extension_cm"]


def test_crotch_curve_controls_use_formula_extension_depth() -> None:
    curves = _crotch_curves(
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )
    for _piece_name, curve in curves:
        chord_x = min(curve["start"]["x"], curve["end"]["x"])
        expected_control_x = chord_x - curve["extension_cm"]
        assert abs(curve["control1"]["x"] - expected_control_x) < 0.01
        assert abs(curve["control2"]["x"] - expected_control_x) < 0.01
PY

cat > docs/63_Fase_40_3D_Extension_Tiro_Formula_Industrial_MVP.md <<'MD'
# Fase 40.3D — Extension de tiro con formula industrial MVP

## Decision

Fase 40.3C corrigio la direccion de concavidad del tiro, pero eso no basta. En patronaje de pantalon, la curva de tiro debe considerar la **extension de tiro** basada en el contorno total de cadera.

## Reglas incorporadas

Para una base de contextura promedio:

```text
Tiro delantero: entre 1/20 y 1/16 del contorno total de cadera.
Tiro posterior: entre 1/8 y 1/6 del contorno total de cadera.
```

Ejemplo con cadera 104 cm:

```text
Delantero: 5.20 cm a 6.50 cm.
Posterior: 13.00 cm a 17.33 cm.
```

El posterior debe ser materialmente mas profundo que el delantero.

## Cambios tecnicos

`engine/exports/structural_curves.py` agrega a cada `crotch_curve`:

```text
extension_formula
extension_cm
extension_range_cm
measurement_basis
```

Ademas, los puntos de control Bezier del tiro usan la extension calculada, no un porcentaje arbitrario del ancho de pieza.

## Estado de producto

Esto mejora el MVP estructural, pero todavia no convierte pantalon ni short en patron industrial. Faltan:

- linea base real de tiro;
- gancho delantero y posterior como entidades de patronaje;
- altura de tiro formal;
- linea de rodilla;
- aplomo / hilo de tela;
- piquetes;
- reglas por tipo de prenda, tela y silueta.

## Validacion

```bash
make validate-fase-40-3d
make validate-fase-40-3c
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness
```

Luego reexportar desde GUI:

```text
pantalon_basico
short_basico
```

Criterio visual minimo:

```text
- La curva de tiro entra hacia dentro.
- El posterior entra mas profundo que el delantero.
- No reaparecen curvas punteadas duplicadas.
- El PDF sigue legible.
```
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-fase-40-3d:" not in text:
    text += """

validate-fase-40-3d:
	.venv/bin/python -m pytest tests/test_fase_40_3d_crotch_extension_formula.py -q
"""

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion Fase 40.3D =="
make validate-fase-40-3d
make validate-fase-40-3c
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness

echo "== Estado Git despues del cambio =="
git status --short

echo "== Fase 40.3D aplicada =="
echo "Reexportar desde GUI pantalon_basico y short_basico. Validar que el posterior tenga extension mas profunda que delantero."
