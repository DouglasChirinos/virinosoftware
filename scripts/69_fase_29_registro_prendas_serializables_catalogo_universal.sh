#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
cd "$PROJECT_DIR"

echo "== Fase 29: Registro de prendas serializables JSON en catalogo universal =="
echo "== Proyecto: $PROJECT_DIR =="

if [[ ! -d .git ]]; then
  echo "ERROR: no estas en un repositorio Git valido: $PROJECT_DIR"
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "feature/fase-29-registro-prendas-serializables-catalogo-universal" ]]; then
  echo "ERROR: rama actual invalida: $CURRENT_BRANCH"
  echo "Debes estar en: feature/fase-29-registro-prendas-serializables-catalogo-universal"
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

mkdir -p engine/garments/serializable scripts tests docs

cat > engine/garments/serializable/catalog.py <<'PY'
"""Catalog helpers for JSON-backed serializable garments.

Fase 29 connects JSON garment definitions to the universal garment catalog
without replacing the existing Python garment classes.
"""

from __future__ import annotations

from pathlib import Path

from engine.garments.serializable.adapter import create_serializable_draft_from_json

PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SERIALIZABLE_GARMENTS_DIR = PROJECT_ROOT / "examples" / "garments"


def list_serializable_definition_paths(
    directory: str | Path = DEFAULT_SERIALIZABLE_GARMENTS_DIR,
) -> tuple[Path, ...]:
    """Return JSON definition paths from a directory in deterministic order."""

    base_dir = Path(directory)
    if not base_dir.exists():
        return ()

    return tuple(sorted(base_dir.glob("*.json")))


def load_serializable_garment_entries(
    directory: str | Path = DEFAULT_SERIALIZABLE_GARMENTS_DIR,
):
    """Yield ``(code, name, draft_class)`` tuples for serializable garments.

    The returned draft class is a zero-argument factory class compatible with
    the existing registry flow used by Python-native garments.
    """

    for path in list_serializable_definition_paths(directory):
        draft = create_serializable_draft_from_json(path)
        definition = draft.definition

        class SerializableDraftFactory:  # noqa: D401 - small adapter class
            """Factory wrapper bound to one JSON garment definition."""

            metadata = draft.metadata
            measurement_requirements = draft.measurement_requirements

            def __init__(self) -> None:
                self._draft = create_serializable_draft_from_json(path)
                self.metadata = self._draft.metadata
                self.measurement_requirements = self._draft.measurement_requirements

            def draft(self, measurements):
                return self._draft.draft(measurements)

            def generate(self, measurements):
                return self._draft.generate(measurements)

        SerializableDraftFactory.__name__ = f"SerializableDraft_{definition.code}"
        SerializableDraftFactory.__qualname__ = SerializableDraftFactory.__name__

        yield definition.code, definition.name, SerializableDraftFactory
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/garments/catalog.py")
text = path.read_text(encoding="utf-8")

if "load_serializable_garment_entries" not in text:
    text = text.replace(
        "from engine.garments.pants.basic_pants import BasicPantsDraft\n",
        "from engine.garments.pants.basic_pants import BasicPantsDraft\n"
        "from engine.garments.serializable.catalog import load_serializable_garment_entries\n",
    )

# Try to append registrations after the existing Python registrations while keeping the file style.
if "# Fase 29: serializable JSON garments" not in text:
    marker_candidates = [
        "register_garment(\n    code=\"pantalon_basico\"",
        "register_garment(code=\"pantalon_basico\"",
    ]

    if "GARMENT_REGISTRY" in text and "register_garment" in text:
        append_block = '''

# Fase 29: serializable JSON garments
for _serializable_code, _serializable_name, _serializable_draft_class in load_serializable_garment_entries():
    register_garment(
        code=_serializable_code,
        name=_serializable_name,
        draft_class=_serializable_draft_class,
    )
'''
        text = text.rstrip() + append_block
    else:
        raise SystemExit("ERROR: no se reconoce el estilo de engine/garments/catalog.py")

path.write_text(text, encoding="utf-8")
print("OK: catalog.py conectado a prendas serializables JSON.")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/generation/pattern_generator.py")
text = path.read_text(encoding="utf-8")

# Existing Python drafts may use constructor args; serializable draft factories are zero-arg and expose generate/draft.
# Make the generator tolerant without breaking existing behavior.
if "# Fase 29 compatibility: instantiate zero-argument serializable drafts" not in text:
    old_candidates = [
        "draft = registered.draft_class(**request.measurements)",
        "draft = garment.draft_class(**request.measurements)",
    ]
    replaced = False
    for old in old_candidates:
        if old in text:
            new = '''# Fase 29 compatibility: instantiate zero-argument serializable drafts
    try:
        draft = registered.draft_class(**request.measurements)
    except TypeError:
        draft = registered.draft_class()
'''
            text = text.replace(old, new, 1)
            replaced = True
            break

    if not replaced:
        # Do not fail if the project already uses a compatible generator.
        print("WARN: no se encontro constructor directo por kwargs en pattern_generator.py; se deja sin parche de instanciacion.")

# Ensure piece generation can call generate(measurements) for serializable drafts if needed.
if "# Fase 29 compatibility: generate pieces from serializable draft" not in text:
    if "pieces = draft.draft()" in text:
        text = text.replace(
            "pieces = draft.draft()",
            '''# Fase 29 compatibility: generate pieces from serializable draft
    try:
        pieces = draft.draft()
    except TypeError:
        pieces = draft.draft(request.measurements)''',
            1,
        )
    elif "pieces = draft.generate()" in text:
        text = text.replace(
            "pieces = draft.generate()",
            '''# Fase 29 compatibility: generate pieces from serializable draft
    try:
        pieces = draft.generate()
    except TypeError:
        pieces = draft.generate(request.measurements)''',
            1,
        )
    elif "pieces = draft.generate(request.measurements)" not in text and "pieces = draft.draft(request.measurements)" not in text:
        print("WARN: no se encontro llamada simple draft/generate en pattern_generator.py; revisar manualmente si falla make test.")

path.write_text(text, encoding="utf-8")
print("OK: pattern_generator.py revisado para compatibilidad serializable.")
PY

cat > scripts/generate_short_universal.py <<'PY'
"""Generate short_basico through the universal pattern generator."""

from __future__ import annotations

from engine.generation.pattern_generator import PatternGenerationRequest, generate_pattern


def main() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="short_basico",
            measurements={
                "waist": 84,
                "hip": 104,
                "outseam": 45,
                "inseam": 20,
            },
        )
    )

    print(f"GARMENT_CODE: {result.garment_code}")
    print(f"GARMENT_NAME: {result.garment_name}")
    print(f"DRAFT_CLASS: {result.draft_class}")
    print(f"PIECE_COUNT: {result.piece_count}")
    for index, piece in enumerate(result.pieces, start=1):
        line_count = piece.line_count() if hasattr(piece, "line_count") else len(piece.lines)
        print(f"PIECE_{index}: {piece.name} lines={line_count}")


if __name__ == "__main__":
    main()
PY
chmod +x scripts/generate_short_universal.py

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "generate-universal-short:" not in text:
    text = text.rstrip() + '''

generate-universal-short:
	.venv/bin/python scripts/generate_short_universal.py
'''

path.write_text(text + "\n", encoding="utf-8")
print("OK: Makefile actualizado con generate-universal-short.")
PY

cat > tests/test_serializable_garment_catalog_registration.py <<'PY'
from engine.garments.registry import get_garment, list_garments
from engine.generation.pattern_generator import PatternGenerationRequest, generate_pattern


def test_short_basico_is_registered_in_universal_catalog():
    garments = list_garments()
    codes = [garment.code for garment in garments]

    assert "short_basico" in codes

    registered = get_garment("short_basico")
    assert registered.code == "short_basico"
    assert registered.name == "Short basico"


def test_short_basico_generates_from_universal_pattern_generator():
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="short_basico",
            measurements={
                "waist": 84,
                "hip": 104,
                "outseam": 45,
                "inseam": 20,
            },
        )
    )

    assert result.garment_code == "short_basico"
    assert result.garment_name == "Short basico"
    assert result.piece_count == 1
    assert result.pieces[0].name == "Short basico delantero"
    assert result.pieces[0].line_count() == 4
PY

cat > docs/38_Fase_29_Registro_Prendas_Serializables_Catalogo_Universal.md <<'MD'
# Fase 29 - Registro de prendas serializables JSON en catalogo universal

## Objetivo

Conectar las prendas definidas mediante DSL/JSON al catalogo universal del motor de patronaje.

A partir de esta fase, `short_basico` deja de depender solo del script especifico `generate_serializable_pattern.py` y queda visible desde el registro global de prendas.

## Alcance

Se implemento:

- Catalogo auxiliar para definiciones JSON serializables.
- Carga automatica desde `examples/garments/*.json`.
- Registro de `short_basico` dentro de `engine/garments/catalog.py`.
- Adaptador factory compatible con el registro existente.
- Generacion universal mediante `generate_pattern`.
- Target `make generate-universal-short`.
- Tests de registro y generacion universal.

## Fuera de alcance

No se implemento todavia:

- Exportacion universal SVG/DXF/PDF para prendas JSON.
- Integracion GUI para prendas serializables.
- Descubrimiento configurable externo de directorios JSON.
- DSL industrial completo.

## Validaciones

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make generate-serializable-short
make generate-universal-short
```

## Resultado esperado

```text
falda_basica: Falda basica
pantalon_basico: Pantalon basico
short_basico: Short basico
```

Y:

```text
GARMENT_CODE: short_basico
GARMENT_NAME: Short basico
DRAFT_CLASS: SerializableDraft_short_basico
PIECE_COUNT: 1
PIECE_1: Short basico delantero lines=4
```

## Siguiente fase sugerida

Fase 30 - Exportacion universal SVG/DXF/PDF para prendas serializables JSON.
MD

echo "== Validando Fase 29 =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make generate-serializable-short
make generate-universal-short

echo "== Fase 29 completada. Revisa cambios con: git status --short =="
