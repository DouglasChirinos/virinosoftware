from __future__ import annotations

from dataclasses import dataclass

from engine.measurements.body import BodyMeasurements


@dataclass(frozen=True)
class SizeProfile:
    """Perfil de talla base para patronaje.

    Unidad oficial: centimetros (cm).

    Esta clase NO implementa gradacion industrial.
    Solo convierte una talla nominal en medidas corporales base.
    """

    code: str
    label: str
    waist: float
    hip: float
    unit: str = "cm"
    notes: str = ""

    def __post_init__(self) -> None:
        if self.unit != "cm":
            raise ValueError("La unidad oficial de tallaje es cm")

        if not self.code:
            raise ValueError("La talla debe tener codigo")

        if self.waist <= 0:
            raise ValueError("waist debe ser mayor que cero")

        if self.hip <= 0:
            raise ValueError("hip debe ser mayor que cero")

        if self.hip < self.waist:
            raise ValueError("hip no debe ser menor que waist")

    def to_body_measurements(
        self,
        *,
        skirt_length: float,
        ease: float = 2.0,
        hip_depth: float = 20.0,
    ) -> BodyMeasurements:
        return BodyMeasurements(
            waist=self.waist,
            hip=self.hip,
            skirt_length=skirt_length,
            ease=ease,
            hip_depth=hip_depth,
            unit=self.unit,
        )

    def as_dict(self) -> dict[str, float | str]:
        return {
            "code": self.code,
            "label": self.label,
            "waist": self.waist,
            "hip": self.hip,
            "unit": self.unit,
            "notes": self.notes,
        }
