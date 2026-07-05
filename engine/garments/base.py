"""Base contract for garment drafts."""

from __future__ import annotations

from abc import ABC
from dataclasses import dataclass

from engine.garments.requirements import MeasurementRequirement


@dataclass(frozen=True)
class GarmentMetadata:
    """Business metadata for a garment draft."""

    code: str
    name: str
    version: str = "0.2.0-dev"
    description: str = ""


class GarmentDraft(ABC):
    """Base contract marker for all garment drafts."""

    metadata: GarmentMetadata
    required_measurements: tuple[MeasurementRequirement, ...]
