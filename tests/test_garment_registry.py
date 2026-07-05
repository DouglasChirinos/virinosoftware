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
