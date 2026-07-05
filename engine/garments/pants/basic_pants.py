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
