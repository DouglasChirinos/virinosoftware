from __future__ import annotations

from dataclasses import dataclass

from engine.measurements.size_profile import SizeProfile


DEFAULT_SKIRT_SIZE_PROFILES: tuple[SizeProfile, ...] = (
    SizeProfile(code="XS", label="Extra pequena", waist=64.0, hip=90.0),
    SizeProfile(code="S", label="Pequena", waist=68.0, hip=94.0),
    SizeProfile(code="M", label="Media", waist=72.0, hip=98.0),
    SizeProfile(code="L", label="Grande", waist=78.0, hip=104.0),
    SizeProfile(code="XL", label="Extra grande", waist=84.0, hip=110.0),
)


@dataclass(frozen=True)
class SizeChart:
    """Tabla de tallas nominales MVP.

    No es una tabla industrial final.
    Es una tabla controlada para comenzar v0.2.0-dev.
    """

    name: str
    profiles: tuple[SizeProfile, ...] = DEFAULT_SKIRT_SIZE_PROFILES
    unit: str = "cm"

    def __post_init__(self) -> None:
        if self.unit != "cm":
            raise ValueError("La unidad oficial de tabla de tallas es cm")

        codes = [profile.code for profile in self.profiles]
        if len(codes) != len(set(codes)):
            raise ValueError("La tabla de tallas no puede tener codigos duplicados")

    def list_codes(self) -> list[str]:
        return [profile.code for profile in self.profiles]

    def get(self, code: str) -> SizeProfile:
        normalized = code.upper().strip()
        for profile in self.profiles:
            if profile.code == normalized:
                return profile

        raise KeyError(f"Talla no encontrada: {code}")

    def as_rows(self) -> list[dict[str, float | str]]:
        return [profile.as_dict() for profile in self.profiles]


DEFAULT_SKIRT_SIZE_CHART = SizeChart(name="Falda basica MVP")
