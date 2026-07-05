#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/antares/Proyecto/motor"
SCRIPT_REL="scripts/82_fase_32_nueva_prenda_serializable_falda_evase.sh"

cd "$ROOT"

echo "== Fase 32: Nueva prenda serializable JSON - falda_evase =="

echo "== Verificando rama =="
branch="$(git branch --show-current)"
if [ "$branch" != "feature/fase-32-nueva-prenda-serializable-falda-evase" ]; then
  echo "ERROR: rama actual inesperada: $branch"
  echo "Esperada: feature/fase-32-nueva-prenda-serializable-falda-evase"
  exit 1
fi

echo "== Verificando estado Git limpio, tolerando solo este playbook sin rastrear =="
dirty_unexpected="$(git status --porcelain | awk -v script="$SCRIPT_REL" '$2 != script { print }')"
if [ -n "$dirty_unexpected" ]; then
  echo "ERROR: el arbol de trabajo tiene cambios no esperados antes de iniciar Fase 32."
  echo "$dirty_unexpected"
  exit 1
fi

echo "== Validando base Fase 31 =="
make test
make export-universal-short

echo "== Creando definicion JSON examples/garments/falda_evase.json =="
cat > examples/garments/falda_evase.json <<'JSON'
{
  "code": "falda_evase",
  "name": "Falda evase",
  "version": "0.1",
  "measurements": [
    {"name": "waist", "label": "Cintura", "unit": "cm", "default": 73},
    {"name": "hip", "label": "Cadera", "unit": "cm", "default": 99},
    {"name": "skirt_length", "label": "Largo de falda", "unit": "cm", "default": 60},
    {"name": "ease", "label": "Amplitud evase", "unit": "cm", "default": 12}
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
        "silhouette": "evase",
        "industrial_status": "dsl_growth_validation"
      }
    }
  ],
  "metadata": {
    "category": "bottom",
    "phase": "32",
    "industrial_status": "dsl_growth_validation"
  }
}
JSON

echo "== Consolidando catalogo serializable dinamico por JSON =="
cat > engine/garments/serializable/catalog.py <<'PY'
"""Catalog helpers for serializable JSON garment definitions.

This module keeps JSON garments discoverable by code and exposes them as
runtime garment draft classes compatible with the universal registry.
"""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path
from typing import Any

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement
from engine.garments.serializable.adapter import (
    create_serializable_draft,
    create_serializable_draft_from_json,
    load_definition_from_json,
)


PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SERIALIZABLE_GARMENT_DIR = PROJECT_ROOT / "examples" / "garments"


def get_serializable_garment_path(code: str) -> Path:
    """Return the JSON definition path for a serializable garment code."""

    normalized = code.strip()
    if not normalized:
        raise ValueError("serializable garment code cannot be empty")
    return DEFAULT_SERIALIZABLE_GARMENT_DIR / f"{normalized}.json"


def load_serializable_definition_by_code(code: str):
    """Load and validate a serializable garment definition by code."""

    return load_definition_from_json(get_serializable_garment_path(code))


def create_serializable_draft_by_code(code: str):
    """Create a SerializableGarmentDraft from a JSON garment code."""

    return create_serializable_draft_from_json(get_serializable_garment_path(code))


def list_serializable_garment_codes() -> tuple[str, ...]:
    """List available serializable garment codes."""

    if not DEFAULT_SERIALIZABLE_GARMENT_DIR.exists():
        return tuple()

    return tuple(
        sorted(path.stem for path in DEFAULT_SERIALIZABLE_GARMENT_DIR.glob("*.json"))
    )


def _class_name_from_code(code: str) -> str:
    parts = [part for part in code.strip().split("_") if part]
    if not parts:
        raise ValueError("serializable garment code cannot be empty")
    return "".join(part.capitalize() for part in parts) + "SerializableDraft"


def _measurement_mapping(measurements: Any) -> dict[str, Any]:
    if isinstance(measurements, Mapping):
        return dict(measurements)

    if hasattr(measurements, "__dict__"):
        return {
            key: value
            for key, value in vars(measurements).items()
            if not key.startswith("_") and value is not None
        }

    raise TypeError("measurements must be a mapping or measurement object")


def create_serializable_draft_class(code: str) -> type[GarmentDraft]:
    """Create a universal-registry draft class backed by one JSON definition."""

    definition = load_serializable_definition_by_code(code)
    delegate = create_serializable_draft(definition)
    class_name = _class_name_from_code(definition.code)

    required_measurements = tuple(
        MeasurementRequirement(
            name=item.name,
            label=item.label,
            unit=item.unit,
            required=item.required,
            description=item.description,
        )
        for item in delegate.measurement_requirements
    )

    metadata = GarmentMetadata(
        code=definition.code,
        name=definition.name,
        description="Prenda definida mediante DSL serializable JSON.",
    )

    def __init__(self, measurements: Any) -> None:
        self.measurements = _measurement_mapping(measurements)
        self._draft = create_serializable_draft_by_code(definition.code)

    def validate_required_measurements(self, measurements: Mapping[str, Any]) -> None:
        missing = [
            requirement.name
            for requirement in required_measurements
            if requirement.required and requirement.name not in measurements
        ]
        if missing:
            joined = ", ".join(missing)
            raise ValueError(
                f"Missing required measurements for {definition.code}: {joined}"
            )

    def draft(self):
        """Generate pieces from the JSON-backed serializable draft."""

        return self._draft.generate(self.measurements)

    namespace = {
        "__doc__": f"Universal registry adapter for {definition.code} JSON garment.",
        "__module__": __name__,
        "metadata": metadata,
        "required_measurements": required_measurements,
        "__init__": __init__,
        "validate_required_measurements": validate_required_measurements,
        "draft": draft,
    }

    return type(class_name, (GarmentDraft,), namespace)


def iter_serializable_garment_draft_classes() -> tuple[type[GarmentDraft], ...]:
    """Return dynamic draft classes for every JSON garment definition."""

    return tuple(
        create_serializable_draft_class(code)
        for code in list_serializable_garment_codes()
    )
PY

echo "== Registrando prendas serializables JSON de forma dinamica en catalogo universal =="
cat > engine/garments/catalog.py <<'PY'
"""Default garment catalog."""

from __future__ import annotations

from engine.garments.pants.basic_pants import BasicPantsDraft
from engine.garments.registry import register_garment
from engine.garments.serializable.catalog import iter_serializable_garment_draft_classes
from engine.garments.skirt.basic_skirt import BasicSkirtDraft


def register_default_garments() -> None:
    """Register garments shipped with the MVP."""

    register_garment(BasicSkirtDraft, overwrite=True)
    register_garment(BasicPantsDraft, overwrite=True)

    for draft_class in iter_serializable_garment_draft_classes():
        register_garment(draft_class, overwrite=True)


register_default_garments()
PY

echo "== Actualizando script de generacion serializable directa para medidas de falda =="
cat > scripts/generate_serializable_pattern.py <<'PY'
#!/usr/bin/env python3
"""Generate a pattern directly from a serializable JSON garment definition."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


from engine.garments.serializable.adapter import (  # noqa: E402
    generate_serializable_pattern_from_json,
    summarize_serializable_result,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a pattern from a serializable JSON garment definition."
    )
    parser.add_argument(
        "--definition",
        required=True,
        help="Path to the serializable garment JSON definition.",
    )
    parser.add_argument("--waist", type=float, default=84)
    parser.add_argument("--hip", type=float, default=104)
    parser.add_argument("--outseam", type=float, default=45)
    parser.add_argument("--inseam", type=float, default=20)
    parser.add_argument("--skirt-length", type=float, default=60)
    parser.add_argument("--ease", type=float, default=12)
    parser.add_argument("--hip-depth", type=float, default=None)
    parser.add_argument("--rise", type=float, default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    measurements = {
        "waist": args.waist,
        "hip": args.hip,
        "outseam": args.outseam,
        "inseam": args.inseam,
        "skirt_length": args.skirt_length,
        "ease": args.ease,
        "hip_depth": args.hip_depth,
        "rise": args.rise,
    }
    measurements = {
        key: value
        for key, value in measurements.items()
        if value is not None
    }

    result = generate_serializable_pattern_from_json(args.definition, measurements)

    for line in summarize_serializable_result(result):
        print(line)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x scripts/generate_serializable_pattern.py

echo "== Agregando targets Makefile para falda_evase =="
python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

blocks = {
    "generate-serializable-falda-evase": "\ngenerate-serializable-falda-evase:\n\t.venv/bin/python scripts/generate_serializable_pattern.py --definition examples/garments/falda_evase.json --waist 73 --hip 99 --skirt-length 60 --ease 12\n",
    "generate-universal-falda-evase": "\ngenerate-universal-falda-evase:\n\t.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12\n",
    "export-universal-falda-evase": "\nexport-universal-falda-evase:\n\t.venv/bin/python scripts/export_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12 --output falda_evase_universal\n",
}

for target, block in blocks.items():
    if f"{target}:" not in text:
        text = text.rstrip() + "\n" + block

path.write_text(text, encoding="utf-8")
PY

echo "== Creando pruebas Fase 32 =="
cat > tests/test_serializable_dynamic_catalog.py <<'PY'
from pathlib import Path
import subprocess
import sys

from engine.garments.registry import get_garment, list_garments
from engine.generation import PatternGenerationRequest, generate_pattern


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_all_json_garments_are_registered_dynamically():
    registered = {item.code: item.name for item in list_garments()}

    assert registered["short_basico"] == "Short basico"
    assert registered["falda_evase"] == "Falda evase"

    assert get_garment("short_basico").__name__ == "ShortBasicoSerializableDraft"
    assert get_garment("falda_evase").__name__ == "FaldaEvaseSerializableDraft"


def test_falda_evase_generates_from_universal_pattern_generator():
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_evase",
            measurements={
                "waist": 73,
                "hip": 99,
                "skirt_length": 60,
                "ease": 12,
            },
        )
    )

    assert result.garment_code == "falda_evase"
    assert result.garment_name == "Falda evase"
    assert result.draft_class_name == "FaldaEvaseSerializableDraft"
    assert result.piece_count == 1
    assert result.pieces[0].name == "Falda evase delantera"
    assert len(result.pieces[0].lines) == 4
    assert result.pieces[0].points["C"] == (36.75, 60.0)
    assert result.pieces[0].points["D"] == (-12.0, 60.0)


def test_falda_evase_exports_through_universal_flow():
    output_name = "falda_evase_universal"

    for relative_path in (
        Path("exports/svg") / f"{output_name}.svg",
        Path("exports/dxf") / f"{output_name}.dxf",
        Path("exports/pdf") / f"{output_name}.pdf",
    ):
        path = PROJECT_ROOT / relative_path
        if path.exists():
            path.unlink()

    result = subprocess.run(
        [
            sys.executable,
            "scripts/export_pattern.py",
            "--garment",
            "falda_evase",
            "--waist",
            "73",
            "--hip",
            "99",
            "--skirt-length",
            "60",
            "--ease",
            "12",
            "--output",
            output_name,
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "GARMENT_CODE: falda_evase" in result.stdout
    assert "GARMENT_NAME: Falda evase" in result.stdout
    assert "DRAFT_CLASS: FaldaEvaseSerializableDraft" in result.stdout
    assert "PIECE_COUNT: 1" in result.stdout

    for relative_path in (
        Path("exports/svg") / f"{output_name}.svg",
        Path("exports/dxf") / f"{output_name}.dxf",
        Path("exports/pdf") / f"{output_name}.pdf",
    ):
        exported = PROJECT_ROOT / relative_path
        assert exported.exists(), f"No fue generado: {exported}"
        assert exported.stat().st_size > 0, f"Archivo vacio: {exported}"
PY

echo "== Documentando Fase 32 =="
cat > docs/41_Fase_32_Nueva_Prenda_Serializable_Falda_Evase.md <<'MD'
# Fase 32 - Nueva prenda serializable JSON: falda evase

## Objetivo

Validar crecimiento real del DSL serializable agregando una nueva prenda definida en JSON: `falda_evase`.

La fase evita crear una clase Python especifica por cada prenda nueva. En su lugar, el catalogo serializable crea clases dinamicas desde todos los archivos JSON ubicados en `examples/garments/`.

## Archivos principales

```text
examples/garments/falda_evase.json
engine/garments/serializable/catalog.py
engine/garments/catalog.py
scripts/generate_serializable_pattern.py
Makefile
tests/test_serializable_dynamic_catalog.py
```

## Resultado funcional

Nueva prenda registrada:

```text
falda_evase: Falda evase
```

Generacion universal esperada:

```bash
make generate-universal-falda-evase
```

Exportacion universal esperada:

```bash
make export-universal-falda-evase
```

Archivos esperados:

```text
exports/svg/falda_evase_universal.svg
exports/dxf/falda_evase_universal.dxf
exports/pdf/falda_evase_universal.pdf
```

## Contrato validado

La nueva prenda usa:

```text
waist
hip
skirt_length
ease
```

Puntos principales:

```text
A = (0, 0)
B = (waist / 4, 0)
C = (hip / 4 + ease, skirt_length)
D = (-ease, skirt_length)
```

Con medidas de prueba:

```text
waist = 73
hip = 99
skirt_length = 60
ease = 12
```

Resultado esperado:

```text
C = (36.75, 60.0)
D = (-12.0, 60.0)
```

## Validaciones

```bash
make test
make list-garments
make generate-serializable-falda-evase
make generate-universal-falda-evase
make export-universal-falda-evase
make generate-universal-short
make export-universal-short
```

## Criterio de cierre

Fase 32 queda cerrada cuando:

```text
- falda_evase aparece en list-garments.
- falda_evase genera desde JSON directo.
- falda_evase genera desde el generador universal.
- falda_evase exporta SVG/DXF/PDF.
- short_basico sigue funcionando sin clase estatica obligatoria.
- Toda la suite pasa.
```
MD

echo "== Validando sintaxis =="
.venv/bin/python -m compileall engine/garments/serializable/catalog.py engine/garments/catalog.py scripts/generate_serializable_pattern.py

echo "== Validando catalogo y generacion Fase 32 =="
make test
make list-garments | grep -q '^falda_evase: Falda evase$'
make list-garments | grep -q '^short_basico: Short basico$'
make generate-serializable-falda-evase
make generate-universal-falda-evase
make export-universal-falda-evase
make generate-universal-short
make export-universal-short

echo "== Verificando exports falda_evase =="
test -s exports/svg/falda_evase_universal.svg
test -s exports/dxf/falda_evase_universal.dxf
test -s exports/pdf/falda_evase_universal.pdf
ls -lh exports/svg/falda_evase_universal.svg exports/dxf/falda_evase_universal.dxf exports/pdf/falda_evase_universal.pdf

echo "== Estado Git =="
git status --short

echo "OK: Fase 32 aplicada y validada."
