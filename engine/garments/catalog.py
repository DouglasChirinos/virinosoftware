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
