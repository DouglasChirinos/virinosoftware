#!/usr/bin/env bash
set -euo pipefail

echo "== Fix Fase 42: restaurar TransformError y compatibilidad Fase 41 =="
echo "== Objetivo =="
echo "- Fase 42 paso, pero sobrescribio engine/transformations/apply.py sin TransformError."
echo "- Este fix restaura el contrato publico usado por Fase 41."

echo "== Estado Git antes del fix =="
git status --short || true

python3 - <<'PY'
from pathlib import Path

path = Path("engine/transformations/apply.py")
text = path.read_text(encoding="utf-8")

if "class TransformError" not in text:
    marker = "from engine.transformations.operations import PatternVariant, TransformOperation\n"
    replacement = marker + "\n\nclass TransformError(ValueError):\n    \"\"\"Error raised when an editable pattern transformation cannot be applied.\"\"\"\n\n\n"
    if marker not in text:
        raise SystemExit("No se encontro el bloque de imports esperado en engine/transformations/apply.py")
    text = text.replace(marker, replacement, 1)

# The Fase 41 public contract expects TransformError, not raw ValueError.
text = text.replace("raise ValueError(", "raise TransformError(")

# Avoid accidental double replacement if the script is re-run.
text = text.replace("raise TransformError(f\"", "raise TransformError(f\"")

path.write_text(text, encoding="utf-8")

init_path = Path("engine/transformations/__init__.py")
init_text = init_path.read_text(encoding="utf-8") if init_path.exists() else ""

if "TransformError" not in init_text:
    init_text = '''"""Editable pattern transformation API."""\n\nfrom engine.transformations.apply import TransformError, apply_transformations\nfrom engine.transformations.operations import PatternVariant, TransformOperation\n\n__all__ = ["PatternVariant", "TransformError", "TransformOperation", "apply_transformations"]\n'''
else:
    init_text = init_text.replace(
        "from engine.transformations.apply import apply_transformations",
        "from engine.transformations.apply import TransformError, apply_transformations",
    )
    if "\"TransformError\"" not in init_text:
        init_text = init_text.replace("__all__ = [", "__all__ = [\"TransformError\", ")

init_path.write_text(init_text, encoding="utf-8")
PY

cat > docs/66_Fix_Fase_42_Restaurar_TransformError_Compatibilidad_Fase_41.md <<'MD'
# Fix Fase 42 - Restaurar TransformError y compatibilidad con Fase 41

## Contexto

La Fase 42 agrego el editor visual MVP en GUI y valido correctamente sus pruebas propias.

Sin embargo, al sobrescribir `engine/transformations/apply.py`, se perdio el simbolo publico `TransformError`, usado por los tests y el contrato de Fase 41.

## Problema

`make validate-fase-41` fallaba durante la coleccion de tests:

```text
ImportError: cannot import name 'TransformError' from 'engine.transformations.apply'
```

## Correccion

Se restaura:

```python
class TransformError(ValueError):
    """Error raised when an editable pattern transformation cannot be applied."""
```

Y se actualizan las excepciones internas del aplicador de transformaciones para usar `TransformError` en vez de `ValueError` directo.

## Criterio de aceptacion

Deben pasar:

```bash
make validate-fase-42
make validate-fase-41
```

## Regla tecnica

La Fase 42 puede ampliar el contrato de transformaciones, pero no puede romper el API publico establecido en Fase 41.
MD

echo "== Validacion Fase 42 =="
make validate-fase-42

echo "== Validacion compatibilidad Fase 41 =="
make validate-fase-41

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix Fase 42 completado =="
