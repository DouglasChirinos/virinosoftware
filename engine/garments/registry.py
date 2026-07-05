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
