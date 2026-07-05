#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# VirinoSoftware - Motor de Patronaje 2D
# Fase 20: Contrato base de prendas
#
# Objetivo:
#   Crear una arquitectura común para prendas, sin romper compatibilidad existente
#   de la falda básica ni avanzar todavía al registro dinámico de prendas.
#
# Ruta esperada del proyecto:
#   /home/antares/Proyecto/motor
#
# Flujo Git:
#   main      -> estable / producción
#   develop   -> integración
#   feature/* -> trabajo incremental por fase
# ==============================================================================

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-20-contrato-base-prendas"

cd "$PROJECT_DIR"

echo "== Fase 20: Contrato base de prendas =="
echo "== Proyecto: $PROJECT_DIR =="

echo
echo "== 1. Validando repositorio Git =="
git rev-parse --is-inside-work-tree >/dev/null

echo
echo "== 2. Estado inicial =="
git status --short
git branch --show-current
git log --oneline --decorate --max-count=10

if [[ -n "$(git status --porcelain)" ]]; then
  echo
  echo "ERROR: El arbol de trabajo no esta limpio."
  echo "Resuelve cambios pendientes antes de iniciar Fase 20."
  exit 1
fi

echo
echo "== 3. Sincronizando develop =="
git switch develop
git pull origin develop

echo
echo "== 4. Creando/cambiando a rama feature =="
if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
  git switch "$FEATURE_BRANCH"
else
  git switch -c "$FEATURE_BRANCH"
fi

echo
echo "== 5. Validacion base antes de modificar =="
make test
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 6. Creando estructura de contrato de prendas =="
mkdir -p engine/garments/skirt
mkdir -p docs

cat > engine/garments/requirements.py <<'PY'
"""Measurement requirements for garment drafting contracts."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class MeasurementRequirement:
    """Defines one measurement required by a garment draft.

    Attributes:
        name: Internal measurement key, for example ``waist`` or ``hip``.
        label: Human-readable label.
        unit: Measurement unit. The MVP uses centimeters.
        required: Whether the measurement is mandatory.
        description: Optional business/technical description.
    """

    name: str
    label: str
    unit: str = "cm"
    required: bool = True
    description: str = ""
PY

cat > engine/garments/base.py <<'PY'
"""Base contract for garment drafts."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

from engine.garments.requirements import MeasurementRequirement


@dataclass(frozen=True)
class GarmentMetadata:
    """Business metadata for a garment draft."""

    code: str
    name: str
    version: str = "0.1.0"
    description: str = ""


class GarmentDraft(ABC):
    """Base contract for all garment drafts.

    A garment draft declares its metadata, required measurements and a ``draft``
    method that returns the generated pattern structure.

    Fase 20 intentionally does not implement a dynamic registry. That belongs
    to Fase 21.
    """

    metadata: GarmentMetadata
    required_measurements: tuple[MeasurementRequirement, ...]

    @property
    def code(self) -> str:
        return self.metadata.code

    @property
    def name(self) -> str:
        return self.metadata.name

    def validate_required_measurements(self, measurements: dict[str, Any]) -> None:
        """Validate that all required measurements are present.

        Args:
            measurements: Mapping with measurement keys and values.

        Raises:
            ValueError: If a mandatory measurement is missing.
        """

        missing = [
            requirement.name
            for requirement in self.required_measurements
            if requirement.required and requirement.name not in measurements
        ]
        if missing:
            joined = ", ".join(missing)
            raise ValueError(f"Missing required measurements for {self.code}: {joined}")

    @abstractmethod
    def draft(self, *args: Any, **kwargs: Any) -> Any:
        """Generate the garment pattern."""
PY

cat > engine/garments/__init__.py <<'PY'
"""Garment drafting contracts and implementations."""

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement

__all__ = [
    "GarmentDraft",
    "GarmentMetadata",
    "MeasurementRequirement",
]
PY

cat > engine/garments/skirt/basic_skirt.py <<'PY'
"""Basic skirt garment contract adapter.

This module exposes the existing basic skirt as a garment-compatible draft
without removing or renaming the legacy API.
"""

from __future__ import annotations

from typing import Any

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement


class BasicSkirtDraft(GarmentDraft):
    """Contract adapter for the existing basic skirt draft."""

    metadata = GarmentMetadata(
        code="falda_basica",
        name="Falda basica",
        version="0.2.0-dev",
        description="Falda basica delantera MVP compatible con contrato de prendas.",
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
            name="skirt_length",
            label="Largo de falda",
            description="Largo total de la falda.",
        ),
        MeasurementRequirement(
            name="ease",
            label="Holgura",
            required=False,
            description="Holgura aplicada al patron.",
        ),
        MeasurementRequirement(
            name="hip_depth",
            label="Altura de cadera",
            required=False,
            description="Distancia vertical desde cintura hasta cadera.",
        ),
    )

    def draft(self, *args: Any, **kwargs: Any) -> Any:
        """Delegate drafting to the existing skirt implementation.

        The project has evolved through several module names. To avoid breaking
        compatibility, this adapter tries the known public entry points in order.
        """

        candidates = (
            ("engine.patterns.basic_skirt", "draft_basic_skirt"),
            ("engine.patterns.basic_skirt", "create_basic_skirt_pattern"),
            ("engine.patterns.skirt", "draft_basic_skirt"),
            ("engine.drafts.basic_skirt", "draft_basic_skirt"),
        )

        last_error: Exception | None = None

        for module_name, function_name in candidates:
            try:
                module = __import__(module_name, fromlist=[function_name])
                draft_function = getattr(module, function_name)
                return draft_function(*args, **kwargs)
            except (ImportError, AttributeError) as exc:
                last_error = exc

        raise RuntimeError(
            "No se encontro una funcion publica compatible para generar falda basica. "
            "Ajusta engine/garments/skirt/basic_skirt.py al nombre real del generador."
        ) from last_error
PY

cat > engine/garments/skirt/__init__.py <<'PY'
"""Skirt garment implementations."""

from engine.garments.skirt.basic_skirt import BasicSkirtDraft

__all__ = ["BasicSkirtDraft"]
PY

echo
echo "== 7. Creando tests de contrato =="
cat > tests/test_garment_contract.py <<'PY'
"""Tests for Fase 20 garment base contract."""

from __future__ import annotations

import pytest

from engine.garments import GarmentDraft, GarmentMetadata, MeasurementRequirement
from engine.garments.skirt import BasicSkirtDraft


def test_measurement_requirement_defaults() -> None:
    requirement = MeasurementRequirement(name="waist", label="Cintura")

    assert requirement.name == "waist"
    assert requirement.label == "Cintura"
    assert requirement.unit == "cm"
    assert requirement.required is True


def test_basic_skirt_declares_garment_contract() -> None:
    draft = BasicSkirtDraft()

    assert isinstance(draft, GarmentDraft)
    assert isinstance(draft.metadata, GarmentMetadata)
    assert draft.code == "falda_basica"
    assert draft.name == "Falda basica"

    required_names = {item.name for item in draft.required_measurements}

    assert {"waist", "hip", "skirt_length"}.issubset(required_names)
    assert "ease" in required_names
    assert "hip_depth" in required_names


def test_basic_skirt_required_measurement_validation_passes() -> None:
    draft = BasicSkirtDraft()

    draft.validate_required_measurements(
        {
            "waist": 72,
            "hip": 98,
            "skirt_length": 60,
        }
    )


def test_basic_skirt_required_measurement_validation_fails() -> None:
    draft = BasicSkirtDraft()

    with pytest.raises(ValueError) as exc:
        draft.validate_required_measurements({"waist": 72})

    message = str(exc.value)

    assert "falda_basica" in message
    assert "hip" in message
    assert "skirt_length" in message
PY

echo
echo "== 8. Documentando Fase 20 =="
cat > docs/29_Fase_20_Contrato_Base_Prendas.md <<'MD'
# Fase 20 - Contrato base de prendas

## Objetivo

Crear una arquitectura común para que nuevas prendas puedan agregarse sin modificar el núcleo del motor.

Esta fase prepara la extensibilidad del proyecto dentro del ciclo `v0.2.0-dev`.

## Alcance implementado

- Se crea el paquete `engine/garments/`.
- Se define `GarmentDraft` como contrato base.
- Se define `GarmentMetadata` para metadata técnica y funcional de la prenda.
- Se define `MeasurementRequirement` para declarar medidas requeridas.
- Se adapta la falda básica mediante `BasicSkirtDraft`.
- Se agregan tests de contrato.
- Se mantiene la compatibilidad de scripts existentes.
- No se crea registro dinámico de prendas.
- No se crean nuevas prendas.

## Archivos principales

```text
engine/garments/__init__.py
engine/garments/base.py
engine/garments/requirements.py
engine/garments/skirt/__init__.py
engine/garments/skirt/basic_skirt.py
tests/test_garment_contract.py
docs/29_Fase_20_Contrato_Base_Prendas.md
```

## Contrato base

```python
class GarmentDraft:
    metadata: GarmentMetadata
    required_measurements: tuple[MeasurementRequirement, ...]

    def draft(self):
        ...
```

## Prenda adaptada

```text
falda_basica
```

Medidas declaradas:

```text
waist
hip
skirt_length
ease
hip_depth
```

## Decisión técnica

El registro dinámico de prendas queda fuera de esta fase y debe implementarse en Fase 21.

## Validaciones esperadas

```bash
make test
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```

## Resultado esperado

La falda básica queda compatible con un contrato común de prendas, sin romper el MVP existente ni alterar el flujo de generación actual.
MD

echo
echo "== 9. Eliminando respaldos temporales si existen =="
find . -name "*.bak.*" -type f -delete

echo
echo "== 10. Validaciones finales =="
make test
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 11. Estado final =="
git status --short

echo
echo "== Fase 20 preparada =="
echo "Revisa el diff:"
echo "  git diff --stat"
echo "  git diff"
echo
echo "Si todo esta correcto:"
echo "  git add engine/garments tests/test_garment_contract.py docs/29_Fase_20_Contrato_Base_Prendas.md"
echo "  git commit -m \"Fase 20 contrato base de prendas\""
echo "  git push -u origin $FEATURE_BRANCH"
