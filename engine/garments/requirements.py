"""Measurement requirements for garment drafting contracts."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class MeasurementRequirement:
    """Defines one measurement required by a garment draft."""

    name: str
    label: str
    unit: str = "cm"
    required: bool = True
    description: str = ""
