#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# VirinoSoftware - Motor de Patronaje 2D
# Fase 21: Registro dinamico de prendas
#
# Objetivo:
#   Crear un registro dinamico de prendas para resolver generadores por codigo,
#   sin modificar la geometria ni crear nuevas prendas.
#
# Ruta esperada del proyecto:
#   /home/antares/Proyecto/motor
#
# Flujo Git:
#   main      -> estable / produccion
#   develop   -> integracion
#   feature/* -> trabajo incremental por fase
# ==============================================================================

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-21-registro-dinamico-prendas"
SCRIPT_PATH="scripts/61_fase_21_registro_dinamico_prendas.sh"

cd "$PROJECT_DIR"

echo "== Fase 21: Registro dinamico de prendas =="
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
  echo "Si solo son reportes generados por validaciones, puedes descartarlos con:"
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
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 7. Creando registro dinamico de prendas =="

cat > engine/garments/registry.py <<'PY'
"""Dynamic garment registry.

The registry maps garment codes to draft classes. It is intentionally small in
Fase 21: only registration and lookup are implemented. Universal generation is
reserved for Fase 22.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass

from engine.garments.base import GarmentDraft


class GarmentRegistryError(Exception):
    """Base exception for garment registry errors."""


class GarmentAlreadyRegisteredError(GarmentRegistryError):
    """Raised when a garment code is registered more than once."""


class GarmentNotFoundError(GarmentRegistryError):
    """Raised when a garment code does not exist in the registry."""


@dataclass(frozen=True)
class RegisteredGarment:
    """Read-only registry entry."""

    code: str
    name: str
    draft_class: type[GarmentDraft]


class GarmentRegistry:
    """Registry for garment draft classes."""

    def __init__(self) -> None:
        self._items: dict[str, type[GarmentDraft]] = {}

    def register(
        self,
        draft_class: type[GarmentDraft],
        *,
        overwrite: bool = False,
    ) -> type[GarmentDraft]:
        """Register a garment draft class.

        Args:
            draft_class: Garment draft class with ``metadata.code``.
            overwrite: Allow replacing an existing code.

        Returns:
            The registered class, enabling decorator usage.

        Raises:
            ValueError: If the draft class has invalid metadata.
            GarmentAlreadyRegisteredError: If the code already exists.
        """

        metadata = getattr(draft_class, "metadata", None)
        code = getattr(metadata, "code", None)

        if not code or not isinstance(code, str):
            raise ValueError("Garment draft class must define metadata.code")

        normalized_code = code.strip()

        if not normalized_code:
            raise ValueError("Garment draft metadata.code cannot be empty")

        if normalized_code in self._items and not overwrite:
            raise GarmentAlreadyRegisteredError(
                f"Garment already registered: {normalized_code}"
            )

        self._items[normalized_code] = draft_class
        return draft_class

    def get(self, code: str) -> type[GarmentDraft]:
        """Return the draft class for a garment code."""

        normalized_code = code.strip()

        try:
            return self._items[normalized_code]
        except KeyError as exc:
            raise GarmentNotFoundError(f"Garment not found: {normalized_code}") from exc

    def has(self, code: str) -> bool:
        """Return whether a garment code exists."""

        return code.strip() in self._items

    def codes(self) -> tuple[str, ...]:
        """Return registered garment codes sorted alphabetically."""

        return tuple(sorted(self._items))

    def list(self) -> tuple[RegisteredGarment, ...]:
        """Return registered garments sorted by code."""

        entries: list[RegisteredGarment] = []

        for code in self.codes():
            draft_class = self._items[code]
            metadata = draft_class.metadata
            entries.append(
                RegisteredGarment(
                    code=metadata.code,
                    name=metadata.name,
                    draft_class=draft_class,
                )
            )

        return tuple(entries)

    def clear(self) -> None:
        """Remove all entries.

        This is mainly useful for isolated tests.
        """

        self._items.clear()

    def __contains__(self, code: object) -> bool:
        if not isinstance(code, str):
            return False
        return self.has(code)

    def __iter__(self) -> Iterable[RegisteredGarment]:
        return iter(self.list())


garment_registry = GarmentRegistry()


def register_garment(
    draft_class: type[GarmentDraft],
    *,
    overwrite: bool = False,
) -> type[GarmentDraft]:
    """Register a garment draft class in the global registry."""

    return garment_registry.register(draft_class, overwrite=overwrite)


def get_garment(code: str) -> type[GarmentDraft]:
    """Return a garment draft class from the global registry."""

    return garment_registry.get(code)


def list_garments() -> tuple[RegisteredGarment, ...]:
    """Return global registered garments."""

    return garment_registry.list()


def get_garment_codes() -> tuple[str, ...]:
    """Return global registered garment codes."""

    return garment_registry.codes()
PY

cat > engine/garments/catalog.py <<'PY'
"""Default garment catalog.

Fase 21 registers the existing basic skirt as the first garment available in
the dynamic registry.
"""

from __future__ import annotations

from engine.garments.registry import register_garment
from engine.garments.skirt.basic_skirt import BasicSkirtDraft


def register_default_garments() -> None:
    """Register garments shipped with the MVP."""

    register_garment(BasicSkirtDraft, overwrite=True)


register_default_garments()
PY

cat > engine/garments/__init__.py <<'PY'
"""Garment drafting contracts, registry and implementations."""

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement
from engine.garments.registry import (
    GarmentAlreadyRegisteredError,
    GarmentNotFoundError,
    GarmentRegistry,
    RegisteredGarment,
    garment_registry,
    get_garment,
    get_garment_codes,
    list_garments,
    register_garment,
)

# Importing catalog registers built-in garments.
from engine.garments.catalog import register_default_garments

__all__ = [
    "GarmentDraft",
    "GarmentMetadata",
    "MeasurementRequirement",
    "GarmentAlreadyRegisteredError",
    "GarmentNotFoundError",
    "GarmentRegistry",
    "RegisteredGarment",
    "garment_registry",
    "register_garment",
    "get_garment",
    "get_garment_codes",
    "list_garments",
    "register_default_garments",
]
PY

echo
echo "== 8. Creando script CLI para listar prendas registradas =="

cat > scripts/list_garments.py <<'PY'
#!/usr/bin/env python3
"""List garments registered in the dynamic garment registry."""

from __future__ import annotations

from engine.garments import list_garments


def main() -> None:
    garments = list_garments()

    if not garments:
        print("NO_GARMENTS_REGISTERED")
        return

    for garment in garments:
        print(f"{garment.code}: {garment.name}")


if __name__ == "__main__":
    main()
PY

chmod +x scripts/list_garments.py

echo
echo "== 9. Actualizando Makefile si aplica =="

if ! grep -q "^list-garments:" Makefile; then
  cat >> Makefile <<'MK'

list-garments:
	.venv/bin/python scripts/list_garments.py
MK
fi

echo
echo "== 10. Creando tests de registro dinamico =="

cat > tests/test_garment_registry.py <<'PY'
"""Tests for Fase 21 dynamic garment registry."""

from __future__ import annotations

import pytest

from engine.garments import (
    GarmentAlreadyRegisteredError,
    GarmentMetadata,
    GarmentNotFoundError,
    GarmentRegistry,
    get_garment,
    get_garment_codes,
    list_garments,
)
from engine.garments.base import GarmentDraft
from engine.garments.registry import register_garment
from engine.garments.skirt.basic_skirt import BasicSkirtDraft


class DummyDraft(GarmentDraft):
    metadata = GarmentMetadata(
        code="dummy",
        name="Dummy garment",
        version="0.2.0-dev",
    )
    required_measurements = ()

    def draft(self):
        return []


def test_registry_registers_and_gets_draft_class() -> None:
    registry = GarmentRegistry()

    registry.register(DummyDraft)

    assert registry.has("dummy")
    assert registry.get("dummy") is DummyDraft
    assert registry.codes() == ("dummy",)


def test_registry_rejects_duplicate_code() -> None:
    registry = GarmentRegistry()

    registry.register(DummyDraft)

    with pytest.raises(GarmentAlreadyRegisteredError):
        registry.register(DummyDraft)


def test_registry_allows_overwrite() -> None:
    registry = GarmentRegistry()

    registry.register(DummyDraft)
    registry.register(DummyDraft, overwrite=True)

    assert registry.get("dummy") is DummyDraft


def test_registry_raises_for_unknown_code() -> None:
    registry = GarmentRegistry()

    with pytest.raises(GarmentNotFoundError):
        registry.get("missing")


def test_default_catalog_registers_basic_skirt() -> None:
    assert "falda_basica" in get_garment_codes()
    assert get_garment("falda_basica") is BasicSkirtDraft


def test_list_garments_exposes_basic_skirt_metadata() -> None:
    garments = list_garments()

    basic_skirt = [item for item in garments if item.code == "falda_basica"]

    assert len(basic_skirt) == 1
    assert basic_skirt[0].name == "Falda basica"
    assert basic_skirt[0].draft_class is BasicSkirtDraft


def test_register_garment_global_function_can_register_custom_draft() -> None:
    class LocalDraft(GarmentDraft):
        metadata = GarmentMetadata(
            code="local_test",
            name="Local test",
            version="0.2.0-dev",
        )
        required_measurements = ()

        def draft(self):
            return []

    register_garment(LocalDraft, overwrite=True)

    assert get_garment("local_test") is LocalDraft
PY

echo
echo "== 11. Documentando Fase 21 =="

cat > docs/30_Fase_21_Registro_Dinamico_Prendas.md <<'MD'
# Fase 21 - Registro dinámico de prendas

## Objetivo

Crear un registro dinámico de prendas para resolver generadores por código, sin modificar el núcleo geométrico del motor.

Esta fase prepara la base técnica para que, en fases posteriores, el sistema pueda generar patrones por tipo de prenda sin acoplarse directamente a una clase concreta.

## Alcance implementado

- Se crea `engine/garments/registry.py`.
- Se crea `GarmentRegistry`.
- Se crea `RegisteredGarment`.
- Se crean excepciones específicas:
  - `GarmentRegistryError`
  - `GarmentAlreadyRegisteredError`
  - `GarmentNotFoundError`
- Se crean funciones globales:
  - `register_garment`
  - `get_garment`
  - `list_garments`
  - `get_garment_codes`
- Se crea `engine/garments/catalog.py`.
- Se registra `BasicSkirtDraft` como primera prenda del catálogo.
- Se crea CLI `scripts/list_garments.py`.
- Se agrega target `make list-garments`.
- Se agregan tests del registro.
- No se crean nuevas prendas.
- No se crea todavía generador universal de patrones.

## Prenda registrada inicialmente

```text
falda_basica: Falda basica
```

## Uso técnico

Obtener una prenda por código:

```python
from engine.garments import get_garment

draft_class = get_garment("falda_basica")
```

Listar códigos registrados:

```python
from engine.garments import get_garment_codes

codes = get_garment_codes()
```

Listar desde CLI:

```bash
make list-garments
```

Salida esperada:

```text
falda_basica: Falda basica
```

## Decisión técnica

Fase 21 solo resuelve registro y descubrimiento de prendas.

El generador universal queda reservado para Fase 22.

## Validaciones esperadas

```bash
make test
make list-garments
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
MD

echo
echo "== 12. Eliminando respaldos temporales si existen =="
find . -name "*.bak.*" -type f -delete

echo
echo "== 13. Validaciones finales =="
make test
make list-garments
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 14. Estado final =="
git status --short
git diff --stat

echo
echo "== Fase 21 preparada =="
echo
echo "Si todo esta correcto:"
echo "  git add engine/garments scripts/list_garments.py tests/test_garment_registry.py docs/30_Fase_21_Registro_Dinamico_Prendas.md Makefile ${SCRIPT_PATH}"
echo "  git commit -m \"Fase 21 registro dinamico de prendas\""
echo "  git push -u origin $FEATURE_BRANCH"
