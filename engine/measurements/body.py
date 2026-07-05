from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class BodyMeasurements:
    """Medidas corporales base para patronaje 2D, expresadas en centimetros.

    Contrato actual:
    - waist
    - hip
    - skirt_length
    - ease

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

    def __post_init__(self) -> None:
        for field_name in ("waist", "hip", "skirt_length", "hip_depth"):
            value = getattr(self, field_name)
            if value <= 0:
                raise ValueError(f"{field_name} debe ser mayor que cero")

        if self.ease < 0:
            raise ValueError("ease no puede ser negativo")

        if self.ease_hip is None:
            object.__setattr__(self, "ease_hip", self.ease)

        if self.ease_waist is None:
            object.__setattr__(self, "ease_waist", self.ease)
