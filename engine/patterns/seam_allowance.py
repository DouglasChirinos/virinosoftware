from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SeamAllowanceConfig:
    """Configuracion base para margen de costura.

    Todavia no aplica offset geometrico real.
    Esta clase deja el contrato preparado para la siguiente fase.
    """

    default_cm: float = 1.0
    hem_cm: float = 3.0
    waist_cm: float = 1.0
    side_cm: float = 1.5

    def __post_init__(self) -> None:
        for field_name in ("default_cm", "hem_cm", "waist_cm", "side_cm"):
            value = getattr(self, field_name)
            if value < 0:
                raise ValueError(f"{field_name} no puede ser negativo")
