"""Default garment catalog."""

from __future__ import annotations

from engine.garments.pants.basic_pants import BasicPantsDraft
from engine.garments.registry import register_garment
from engine.garments.serializable.short_basico import ShortBasicoSerializableDraft
from engine.garments.skirt.basic_skirt import BasicSkirtDraft


def register_default_garments() -> None:
    """Register garments shipped with the MVP."""

    register_garment(BasicSkirtDraft, overwrite=True)
    register_garment(BasicPantsDraft, overwrite=True)
    register_garment(ShortBasicoSerializableDraft, overwrite=True)


register_default_garments()
