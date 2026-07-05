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
