#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# VirinoSoftware - Motor de Patronaje 2D
# Fase 23: Segunda prenda base - pantalon basico MVP
#
# Objetivo:
#   Agregar una segunda prenda base al motor usando el contrato, el registro
#   dinamico y el generador universal ya existentes.
#
# Alcance:
#   - Crear pantalon_basico como prenda registrable.
#   - Adaptar el generador universal para soportar prendas que no dependan
#     exclusivamente de BodyMeasurements/skirt_length.
#   - Mantener compatibilidad con falda_basica.
#   - No tocar GUI.
#   - No implementar exportacion universal todavia.
# ==============================================================================

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-23-segunda-prenda-base"
SCRIPT_PATH="scripts/63_fase_23_segunda_prenda_base.sh"

cd "$PROJECT_DIR"

echo "== Fase 23: Segunda prenda base - pantalon basico MVP =="
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
make generate-pattern
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 7. Creando segunda prenda: pantalon basico =="

mkdir -p engine/garments/pants

cat > engine/garments/pants/basic_pants.py <<'PY'
"""Basic pants draft MVP.

The pants draft is intentionally simple: it proves that the architecture can
host a second garment without modifying the skirt implementation.

Fase 23 does not implement industrial-grade pants drafting, curves, notches or
universal export orchestration. Those belong to later phases.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement


@dataclass(frozen=True)
class PantsMeasurements:
    """Measurements required by the basic pants MVP."""

    waist: float
    hip: float
    outseam: float
    inseam: float | None = None
    rise: float | None = None
    ease: float = 2.0
    unit: str = "cm"

    @classmethod
    def from_mapping(cls, values: Mapping[str, Any]) -> "PantsMeasurements":
        """Build pants measurements from a plain mapping."""

        missing = [key for key in ("waist", "hip", "outseam") if key not in values]

        if missing:
            joined = ", ".join(missing)
            raise ValueError(f"Missing pants measurements: {joined}")

        return cls(
            waist=float(values["waist"]),
            hip=float(values["hip"]),
            outseam=float(values["outseam"]),
            inseam=(
                float(values["inseam"])
                if values.get("inseam") is not None
                else None
            ),
            rise=(
                float(values["rise"])
                if values.get("rise") is not None
                else None
            ),
            ease=float(values.get("ease", 2.0) or 2.0),
            unit=str(values.get("unit", "cm") or "cm"),
        )


@dataclass(frozen=True)
class DraftPoint:
    """Simple drafting point for MVP garments not yet tied to exporters."""

    x: float
    y: float


@dataclass(frozen=True)
class DraftLine:
    """Simple drafting line for MVP garments not yet tied to exporters."""

    start: DraftPoint
    end: DraftPoint
    name: str = ""


@dataclass(frozen=True)
class DraftPiece:
    """Simple pattern piece returned by the basic pants draft."""

    name: str
    lines: tuple[DraftLine, ...]
    metadata: dict[str, Any]


class BasicPantsDraft(GarmentDraft):
    """Basic pants draft MVP."""

    metadata = GarmentMetadata(
        code="pantalon_basico",
        name="Pantalon basico",
        version="0.2.0-dev",
        description="Pantalon basico MVP para validar segunda prenda en arquitectura universal.",
    )

    required_measurements = (
        MeasurementRequirement(
            name="waist",
            label="Cintura",
            description="Contorno de cintura.",
        ),
        MeasurementRequirement(
            name="hip",
            label="Cadera",
            description="Contorno de cadera.",
        ),
        MeasurementRequirement(
            name="outseam",
            label="Largo exterior",
            description="Largo exterior del pantalon desde cintura hasta bajo.",
        ),
        MeasurementRequirement(
            name="inseam",
            label="Entrepierna",
            required=False,
            description="Largo interno de pierna.",
        ),
        MeasurementRequirement(
            name="rise",
            label="Tiro",
            required=False,
            description="Altura de tiro.",
        ),
        MeasurementRequirement(
            name="ease",
            label="Holgura",
            required=False,
            description="Holgura aplicada al patron.",
        ),
    )

    def __init__(self, measurements: PantsMeasurements | Mapping[str, Any]) -> None:
        if isinstance(measurements, PantsMeasurements):
            self.measurements = measurements
        elif isinstance(measurements, Mapping):
            self.measurements = PantsMeasurements.from_mapping(measurements)
        else:
            raise TypeError(
                "BasicPantsDraft expects PantsMeasurements or a measurements mapping"
            )

    @property
    def code(self) -> str:
        return self.metadata.code

    @property
    def name(self) -> str:
        return self.metadata.name

    def validate_required_measurements(self, measurements: Mapping[str, Any]) -> None:
        missing = [
            requirement.name
            for requirement in self.required_measurements
            if requirement.required and requirement.name not in measurements
        ]

        if missing:
            joined = ", ".join(missing)
            raise ValueError(f"Missing required measurements for {self.code}: {joined}")

    def draft(self) -> list[DraftPiece]:
        """Generate front and back MVP pants pieces."""

        return [self._build_front_piece(), self._build_back_piece()]

    def _build_front_piece(self) -> DraftPiece:
        m = self.measurements
        half_hip = (m.hip + m.ease) / 4
        waist_width = (m.waist + m.ease) / 4
        outseam = m.outseam
        rise = m.rise if m.rise is not None else max(22.0, m.hip * 0.25)
        hem_width = max(16.0, half_hip * 0.55)

        points = {
            "waist_left": DraftPoint(0.0, 0.0),
            "waist_right": DraftPoint(waist_width, 0.0),
            "hip_right": DraftPoint(half_hip, rise),
            "hem_right": DraftPoint(hem_width, outseam),
            "hem_left": DraftPoint(0.0, outseam),
        }

        lines = (
            DraftLine(points["waist_left"], points["waist_right"], "cintura"),
            DraftLine(points["waist_right"], points["hip_right"], "costado_superior"),
            DraftLine(points["hip_right"], points["hem_right"], "costado_exterior"),
            DraftLine(points["hem_right"], points["hem_left"], "bajo"),
            DraftLine(points["hem_left"], points["waist_left"], "tiro_interior_referencia"),
        )

        return DraftPiece(
            name="Pantalon basico delantero",
            lines=lines,
            metadata={
                "garment_code": self.code,
                "piece_type": "front",
                "unit": m.unit,
                "draft_level": "mvp",
            },
        )

    def _build_back_piece(self) -> DraftPiece:
        m = self.measurements
        half_hip = (m.hip + m.ease) / 4
        waist_width = ((m.waist + m.ease) / 4) + 2.0
        outseam = m.outseam
        rise = (m.rise if m.rise is not None else max(22.0, m.hip * 0.25)) + 2.0
        hem_width = max(17.0, half_hip * 0.60)

        points = {
            "waist_left": DraftPoint(0.0, 0.0),
            "waist_right": DraftPoint(waist_width, 0.0),
            "hip_right": DraftPoint(half_hip + 2.0, rise),
            "hem_right": DraftPoint(hem_width, outseam),
            "hem_left": DraftPoint(0.0, outseam),
        }

        lines = (
            DraftLine(points["waist_left"], points["waist_right"], "cintura"),
            DraftLine(points["waist_right"], points["hip_right"], "costado_superior"),
            DraftLine(points["hip_right"], points["hem_right"], "costado_exterior"),
            DraftLine(points["hem_right"], points["hem_left"], "bajo"),
            DraftLine(points["hem_left"], points["waist_left"], "tiro_interior_referencia"),
        )

        return DraftPiece(
            name="Pantalon basico posterior",
            lines=lines,
            metadata={
                "garment_code": self.code,
                "piece_type": "back",
                "unit": m.unit,
                "draft_level": "mvp",
            },
        )
PY

cat > engine/garments/pants/__init__.py <<'PY'
"""Pants garment implementations."""

from engine.garments.pants.basic_pants import (
    BasicPantsDraft,
    DraftLine,
    DraftPiece,
    DraftPoint,
    PantsMeasurements,
)

__all__ = [
    "BasicPantsDraft",
    "PantsMeasurements",
    "DraftPoint",
    "DraftLine",
    "DraftPiece",
]
PY

echo
echo "== 8. Actualizando catalogo de prendas =="

cat > engine/garments/catalog.py <<'PY'
"""Default garment catalog."""

from __future__ import annotations

from engine.garments.pants.basic_pants import BasicPantsDraft
from engine.garments.registry import register_garment
from engine.garments.skirt.basic_skirt import BasicSkirtDraft


def register_default_garments() -> None:
    """Register garments shipped with the MVP."""

    register_garment(BasicSkirtDraft, overwrite=True)
    register_garment(BasicPantsDraft, overwrite=True)


register_default_garments()
PY

echo
echo "== 9. Adaptando generador universal para multiples modelos de medidas =="

cat > engine/generation/pattern_generator.py <<'PY'
"""Universal pattern generator.

This module resolves a garment code through the dynamic garment registry and
executes the draft class using the most appropriate measurement payload.

Fase 23 keeps backward compatibility with ``falda_basica`` while enabling
garments that use their own measurement mappings, such as ``pantalon_basico``.
"""

from __future__ import annotations

from collections.abc import Mapping
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
    measurements: Any
    options: dict[str, Any] = field(default_factory=dict)

    @property
    def piece_count(self) -> int:
        """Return the number of generated pattern pieces."""

        return len(self.pieces)


def _validate_class_requirements(
    draft_class: type[Any],
    raw_measurements: Mapping[str, Any],
) -> None:
    """Validate class-level required measurements before instantiation."""

    requirements = getattr(draft_class, "required_measurements", ())

    missing = [
        requirement.name
        for requirement in requirements
        if getattr(requirement, "required", True)
        and requirement.name not in raw_measurements
    ]

    if missing:
        joined = ", ".join(missing)
        code = getattr(getattr(draft_class, "metadata", None), "code", draft_class.__name__)
        raise PatternGenerationError(
            f"Missing required measurements for {code}: {joined}"
        )


def _can_build_body_measurements(raw_measurements: Mapping[str, Any]) -> bool:
    required = ("waist", "hip", "skirt_length")
    return all(key in raw_measurements for key in required)


def _build_body_measurements(raw_measurements: Mapping[str, Any]) -> BodyMeasurements:
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


def _instantiate_draft(draft_class: type[Any], raw_measurements: dict[str, Any]) -> tuple[Any, Any]:
    """Instantiate a draft class with the best compatible measurement payload."""

    errors: list[str] = []

    if _can_build_body_measurements(raw_measurements):
        body_measurements = _build_body_measurements(raw_measurements)

        try:
            return draft_class(body_measurements), body_measurements
        except Exception as exc:  # noqa: BLE001 - preserve fallback diagnostics.
            errors.append(f"BodyMeasurements failed: {exc}")

    try:
        return draft_class(raw_measurements), raw_measurements
    except Exception as exc:  # noqa: BLE001
        errors.append(f"raw mapping failed: {exc}")

    joined = " | ".join(errors)
    raise PatternGenerationError(
        f"Could not instantiate {draft_class.__name__}. {joined}"
    )


def _validate_instance_requirements(draft: Any, measurements: Mapping[str, Any]) -> None:
    """Run optional instance validation if available."""

    validator = getattr(draft, "validate_required_measurements", None)

    if callable(validator):
        try:
            validator(measurements)
        except Exception as exc:  # noqa: BLE001
            raise PatternGenerationError(str(exc)) from exc


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
    """Generate a pattern using the garment registry."""

    garment_code = request.garment_code.strip()

    if not garment_code:
        raise PatternGenerationError("garment_code cannot be empty")

    try:
        draft_class = get_garment(garment_code)
    except GarmentNotFoundError as exc:
        raise PatternGenerationError(f"Unknown garment code: {garment_code}") from exc

    _validate_class_requirements(draft_class, request.measurements)

    draft, normalized_measurements = _instantiate_draft(
        draft_class=draft_class,
        raw_measurements=request.measurements,
    )

    _validate_instance_requirements(draft, request.measurements)

    pieces = _run_draft(draft)

    metadata = getattr(draft_class, "metadata", None)
    garment_name = getattr(metadata, "name", garment_code)

    return PatternGenerationResult(
        garment_code=garment_code,
        garment_name=garment_name,
        draft_class_name=draft_class.__name__,
        pieces=pieces,
        measurements=normalized_measurements,
        options=dict(request.options),
    )
PY

echo
echo "== 10. Adaptando CLI universal para falda y pantalon =="

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
        default=None,
        help="Skirt length in cm. Required by falda_basica.",
    )
    parser.add_argument(
        "--outseam",
        type=float,
        default=None,
        help="Outer pants length in cm. Required by pantalon_basico.",
    )
    parser.add_argument(
        "--inseam",
        type=float,
        default=None,
        help="Optional pants inseam in cm.",
    )
    parser.add_argument(
        "--rise",
        type=float,
        default=None,
        help="Optional pants rise in cm.",
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
        "outseam": args.outseam,
        "inseam": args.inseam,
        "rise": args.rise,
        "ease": args.ease,
        "hip_depth": args.hip_depth,
    }

    measurements = {
        key: value
        for key, value in measurements.items()
        if value is not None
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
echo "== 11. Actualizando Makefile si aplica =="

if ! grep -q "^generate-basic-pants:" Makefile; then
  cat >> Makefile <<'MK'

generate-basic-pants:
	.venv/bin/python scripts/generate_pattern.py --garment pantalon_basico --waist 84 --hip 104 --outseam 100 --inseam 76
MK
fi

echo
echo "== 12. Creando tests de pantalon basico =="

cat > tests/test_basic_pants.py <<'PY'
"""Tests for Fase 23 basic pants draft."""

from __future__ import annotations

from engine.garments import get_garment, get_garment_codes
from engine.garments.pants import BasicPantsDraft, PantsMeasurements
from engine.generation import PatternGenerationRequest, generate_pattern


def test_basic_pants_is_registered() -> None:
    assert "pantalon_basico" in get_garment_codes()
    assert get_garment("pantalon_basico") is BasicPantsDraft


def test_basic_pants_generates_front_and_back_pieces() -> None:
    draft = BasicPantsDraft(
        PantsMeasurements(
            waist=84,
            hip=104,
            outseam=100,
            inseam=76,
        )
    )

    pieces = draft.draft()

    assert len(pieces) == 2
    assert pieces[0].name == "Pantalon basico delantero"
    assert pieces[1].name == "Pantalon basico posterior"
    assert len(pieces[0].lines) >= 5
    assert len(pieces[1].lines) >= 5


def test_universal_generator_generates_basic_pants() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="pantalon_basico",
            measurements={
                "waist": 84,
                "hip": 104,
                "outseam": 100,
                "inseam": 76,
            },
        )
    )

    assert result.garment_code == "pantalon_basico"
    assert result.garment_name == "Pantalon basico"
    assert result.draft_class_name == "BasicPantsDraft"
    assert result.piece_count == 2
    assert result.pieces[0].name == "Pantalon basico delantero"
    assert result.pieces[1].name == "Pantalon basico posterior"


def test_universal_generator_keeps_basic_skirt_compatibility() -> None:
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

    assert result.garment_code == "falda_basica"
    assert result.draft_class_name == "BasicSkirtDraft"
    assert result.piece_count >= 1
PY

echo
echo "== 13. Documentando Fase 23 =="

cat > docs/32_Fase_23_Segunda_Prenda_Base.md <<'MD'
# Fase 23 - Segunda prenda base

## Objetivo

Agregar una segunda prenda base al motor para validar que la arquitectura creada en Fases 20, 21 y 22 escala más allá de `falda_basica`.

La prenda seleccionada es:

```text
pantalon_basico
```

## Alcance implementado

- Se crea paquete `engine/garments/pants/`.
- Se crea `BasicPantsDraft`.
- Se crea `PantsMeasurements`.
- Se crean piezas MVP:
  - `Pantalon basico delantero`
  - `Pantalon basico posterior`
- Se registra `pantalon_basico` en el catálogo global.
- Se adapta el generador universal para soportar prendas con distintos modelos de medidas.
- Se actualiza `scripts/generate_pattern.py`.
- Se agrega target `make generate-basic-pants`.
- Se agregan tests de la segunda prenda.
- Se mantiene compatibilidad con `falda_basica`.

## Qué no incluye esta fase

- No implementa trazado industrial completo de pantalón.
- No implementa curvas avanzadas.
- No implementa pinzas, bolsillos, pretina ni aplomos.
- No implementa exportación universal.
- No modifica el GUI.

## Uso

Listar prendas:

```bash
make list-garments
```

Salida esperada:

```text
falda_basica: Falda basica
pantalon_basico: Pantalon basico
```

Generar falda desde generador universal:

```bash
make generate-pattern
```

Generar pantalón básico desde generador universal:

```bash
make generate-basic-pants
```

Salida esperada:

```text
GARMENT_CODE: pantalon_basico
GARMENT_NAME: Pantalon basico
DRAFT_CLASS: BasicPantsDraft
PIECE_COUNT: 2
PIECE_1: Pantalon basico delantero lines=5
PIECE_2: Pantalon basico posterior lines=5
```

## Decisión técnica

Fase 23 valida extensibilidad arquitectónica, no perfección industrial del pantalón.

La exportación universal debe abordarse después, cuando el contrato de piezas entre prendas esté suficientemente estable.

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
MD

echo
echo "== 14. Eliminando respaldos temporales si existen =="
find . -name "*.bak.*" -type f -delete

echo
echo "== 15. Validaciones finales =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 16. Estado final =="
git status --short
git diff --stat

echo
echo "== Fase 23 preparada =="
echo
echo "Si todo esta correcto:"
echo "  git restore reports/falda_basica_medidas_w73_h99_reporte.md reports/falda_basica_mvp_reporte.md || true"
echo "  git add engine/garments/pants engine/garments/catalog.py engine/generation/pattern_generator.py scripts/generate_pattern.py tests/test_basic_pants.py docs/32_Fase_23_Segunda_Prenda_Base.md Makefile ${SCRIPT_PATH}"
echo "  git commit -m \"Fase 23 segunda prenda base pantalon basico\""
echo "  git push -u origin $FEATURE_BRANCH"
