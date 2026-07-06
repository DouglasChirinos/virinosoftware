#!/usr/bin/env bash
set -euo pipefail

echo "== Fix Fase 42: metadata faltante de Fase 41 =="
echo "== Objetivo =="
echo "- Restaurar edit_history dentro de structural_curves ajustadas."
echo "- Restaurar editable_variant en metadata de pieza cuando se aplica PatternVariant."
echo "- Mantener compatibilidad Fase 42."

echo "== Estado Git antes del fix =="
git status --short || true

python3 - <<'PY'
from pathlib import Path

path = Path('engine/transformations/apply.py')
text = path.read_text(encoding='utf-8')

# Patch 1: ensure adjust_curve appends edit_history to curve.
old = '''        if "control1" in curve:
            curve["control1"] = {
                "x": float(curve["control1"].get("x", 0.0)) + float(delta.get("c1_dx", 0.0)),
                "y": float(curve["control1"].get("y", 0.0)) + float(delta.get("c1_dy", 0.0)),
            }
        if "control2" in curve:
            curve["control2"] = {
                "x": float(curve["control2"].get("x", 0.0)) + float(delta.get("c2_dx", 0.0)),
                "y": float(curve["control2"].get("y", 0.0)) + float(delta.get("c2_dy", 0.0)),
            }
        return
'''
new = '''        if "control1" in curve:
            curve["control1"] = {
                "x": float(curve["control1"].get("x", 0.0)) + float(delta.get("c1_dx", 0.0)),
                "y": float(curve["control1"].get("y", 0.0)) + float(delta.get("c1_dy", 0.0)),
            }
        if "control2" in curve:
            curve["control2"] = {
                "x": float(curve["control2"].get("x", 0.0)) + float(delta.get("c2_dx", 0.0)),
                "y": float(curve["control2"].get("y", 0.0)) + float(delta.get("c2_dy", 0.0)),
            }
        curve.setdefault("edit_history", []).append(
            {
                "type": "adjust_curve",
                "curve": curve_name,
                "control_delta": dict(delta),
            }
        )
        return
'''
if old in text:
    text = text.replace(old, new)
elif 'curve.setdefault("edit_history", [])' not in text:
    marker = '        return\n\n    raise TransformError(f"Curve \'{curve_name}\' not found in piece \'{piece.name}\'")'
    replacement = '''        curve.setdefault("edit_history", []).append(
            {
                "type": "adjust_curve",
                "curve": curve_name,
                "control_delta": dict(delta),
            }
        )
        return

    raise TransformError(f"Curve '{curve_name}' not found in piece '{piece.name}'")'''
    if marker in text:
        text = text.replace(marker, replacement)
    else:
        raise SystemExit('No pude ubicar bloque adjust_curve para insertar edit_history')

# Patch 2: ensure editable_variant metadata is emitted when variant is provided.
if 'metadata["editable_variant"]' not in text:
    old2 = '''    for piece in transformed:
        metadata = _ensure_metadata(piece)
        metadata["base_pattern_preserved"] = True
        metadata["transformation_history"] = history
        if variant is not None:
            metadata["variant"] = variant.to_dict()

    return transformed
'''
    new2 = '''    for piece in transformed:
        metadata = _ensure_metadata(piece)
        metadata["base_pattern_preserved"] = True
        metadata["transformation_history"] = history
        if variant is not None:
            variant_payload = variant.to_dict()
            metadata["variant"] = variant_payload
            metadata["editable_variant"] = variant_payload

    return transformed
'''
    if old2 in text:
        text = text.replace(old2, new2)
    else:
        # Fallback: add editable_variant after metadata["variant"] assignment.
        old3 = '            metadata["variant"] = variant.to_dict()\n'
        new3 = '            variant_payload = variant.to_dict()\n            metadata["variant"] = variant_payload\n            metadata["editable_variant"] = variant_payload\n'
        if old3 in text:
            text = text.replace(old3, new3)
        else:
            raise SystemExit('No pude ubicar bloque variant metadata para insertar editable_variant')

path.write_text(text, encoding='utf-8')
PY

cat > docs/68_Fix_Fase_42_Metadata_Editable_Variant_Fase41.md <<'MD'
# Fix Fase 42 — Metadata editable_variant y edit_history de Fase 41

## Objetivo

Restaurar dos partes del contrato validado en Fase 41 que fueron afectadas durante la integracion del editor MVP de Fase 42:

- `edit_history` dentro de cada curva estructural ajustada con `adjust_curve`.
- `editable_variant` dentro de `piece.metadata` cuando `apply_transformations(..., variant=...)` recibe una variante editable.

## Criterio

Fase 42 puede consumir el contrato de transformaciones editables, pero no puede reducirlo ni cambiar sus claves publicas.

## Validacion

```bash
make validate-fase-41
make validate-fase-42
```
MD

echo "== Validacion Fase 41 =="
make validate-fase-41

echo "== Validacion Fase 42 =="
make validate-fase-42

echo "== Estado Git despues del fix =="
git status --short || true

echo "FIX_FASE_42_METADATA_EDITABLE_VARIANT_OK"
