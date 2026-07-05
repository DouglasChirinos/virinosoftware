from __future__ import annotations

from dataclasses import dataclass

from engine.measurements.validation import validate_body_measurements


@dataclass(frozen=True)
class BodyMeasurements:
    """Medidas corporales base para patronaje 2D.

    Unidad oficial: centimetros (cm).

    Contrato actual:
    - waist: cintura
    - hip: cadera
    - skirt_length: largo de falda
    - ease: holgura general

    Compatibilidad heredada:
    - hip_depth
    - ease_hip
    - ease_waist
    """

    waist: float
    hip: float
    skirt_length: float
    ease: float = 2.0
    hip_depth: float = 20.0
    ease_hip: float | None = None
    ease_waist: float | None = None
    unit: str = "cm"

    def __post_init__(self) -> None:
        if self.unit != "cm":
            raise ValueError("La unidad oficial del motor MVP es cm")

        if self.ease_hip is None:
            object.__setattr__(self, "ease_hip", self.ease)

        if self.ease_waist is None:
            object.__setattr__(self, "ease_waist", self.ease)

        validate_body_measurements(
            waist=self.waist,
            hip=self.hip,
            skirt_length=self.skirt_length,
            ease=self.ease,
            hip_depth=self.hip_depth,
            ease_hip=self.ease_hip,
            ease_waist=self.ease_waist,
        )

    def as_dict(self) -> dict[str, float | str]:
        return {
            "waist": self.waist,
            "hip": self.hip,
            "skirt_length": self.skirt_length,
            "ease": self.ease,
            "hip_depth": self.hip_depth,
            "ease_hip": self.ease_hip,
            "ease_waist": self.ease_waist,
            "unit": self.unit,
        }
