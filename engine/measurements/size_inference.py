from __future__ import annotations

from dataclasses import dataclass, field
from math import sqrt

from engine.measurements.body import BodyMeasurements
from engine.measurements.size_chart import DEFAULT_SKIRT_SIZE_CHART, SizeChart
from engine.measurements.size_profile import SizeProfile


@dataclass(frozen=True)
class MeasurementDifference:
    """Diferencia entre medida real y medida nominal de una talla."""

    name: str
    user_value: float
    profile_value: float
    difference: float
    unit: str = "cm"

    @property
    def abs_difference(self) -> float:
        return abs(self.difference)

    @property
    def signed_label(self) -> str:
        sign = "+" if self.difference >= 0 else ""
        return f"{sign}{self.difference:.2f} {self.unit}"


@dataclass(frozen=True)
class SizeInferenceResult:
    """Resultado de inferir talla desde medidas reales."""

    recommended_profile: SizeProfile
    score: float
    differences: tuple[MeasurementDifference, ...]
    nearest_profiles: tuple[SizeProfile, ...] = field(default_factory=tuple)
    is_between_sizes: bool = False
    notes: tuple[str, ...] = field(default_factory=tuple)

    @property
    def recommended_size(self) -> str:
        return self.recommended_profile.code

    @property
    def max_abs_difference(self) -> float:
        if not self.differences:
            return 0.0
        return max(diff.abs_difference for diff in self.differences)

    def difference_for(self, name: str) -> MeasurementDifference:
        normalized = name.lower().strip()
        for diff in self.differences:
            if diff.name == normalized:
                return diff
        raise KeyError(f"Diferencia no encontrada: {name}")

    def as_dict(self) -> dict[str, object]:
        return {
            "recommended_size": self.recommended_size,
            "score": self.score,
            "is_between_sizes": self.is_between_sizes,
            "nearest_profiles": [profile.code for profile in self.nearest_profiles],
            "differences": [
                {
                    "name": diff.name,
                    "user_value": diff.user_value,
                    "profile_value": diff.profile_value,
                    "difference": diff.difference,
                    "unit": diff.unit,
                }
                for diff in self.differences
            ],
            "notes": list(self.notes),
        }


def _distance_to_profile(
    *,
    waist: float,
    hip: float,
    profile: SizeProfile,
    waist_weight: float,
    hip_weight: float,
) -> float:
    waist_delta = (waist - profile.waist) * waist_weight
    hip_delta = (hip - profile.hip) * hip_weight
    return sqrt((waist_delta**2) + (hip_delta**2))


def infer_size_from_measurements(
    *,
    waist: float | None = None,
    hip: float | None = None,
    measurements: BodyMeasurements | None = None,
    size_chart: SizeChart = DEFAULT_SKIRT_SIZE_CHART,
    waist_weight: float = 1.0,
    hip_weight: float = 1.0,
    between_threshold_cm: float = 1.25,
) -> SizeInferenceResult:
    """Infiere la talla nominal mas cercana desde cintura/cadera.

    Regla MVP:
    - Compara cintura y cadera contra todos los perfiles disponibles.
    - Calcula distancia euclidiana ponderada.
    - Selecciona el perfil con menor distancia.
    - Marca `is_between_sizes` cuando las dos mejores tallas quedan muy cercanas.
    """

    if measurements is not None:
        waist = measurements.waist
        hip = measurements.hip

    if waist is None or hip is None:
        raise ValueError("Debe indicar waist y hip, o measurements")

    if waist <= 0:
        raise ValueError("waist debe ser mayor que cero")

    if hip <= 0:
        raise ValueError("hip debe ser mayor que cero")

    scored: list[tuple[float, SizeProfile]] = []
    for profile in size_chart.profiles:
        score = _distance_to_profile(
            waist=waist,
            hip=hip,
            profile=profile,
            waist_weight=waist_weight,
            hip_weight=hip_weight,
        )
        scored.append((score, profile))

    scored.sort(key=lambda item: item[0])

    best_score, best_profile = scored[0]
    nearest_profiles = tuple(profile for _, profile in scored[:2])

    is_between_sizes = False
    notes: list[str] = []

    if len(scored) > 1:
        second_score, second_profile = scored[1]
        if abs(second_score - best_score) <= between_threshold_cm:
            is_between_sizes = True
            notes.append(
                f"Medidas cercanas entre {best_profile.code} y {second_profile.code}"
            )

    differences = (
        MeasurementDifference(
            name="waist",
            user_value=float(waist),
            profile_value=best_profile.waist,
            difference=float(waist) - best_profile.waist,
        ),
        MeasurementDifference(
            name="hip",
            user_value=float(hip),
            profile_value=best_profile.hip,
            difference=float(hip) - best_profile.hip,
        ),
    )

    if differences[0].abs_difference > 2.0:
        notes.append("La cintura se aleja mas de 2 cm de la talla nominal recomendada")

    if differences[1].abs_difference > 2.0:
        notes.append("La cadera se aleja mas de 2 cm de la talla nominal recomendada")

    return SizeInferenceResult(
        recommended_profile=best_profile,
        score=best_score,
        differences=differences,
        nearest_profiles=nearest_profiles,
        is_between_sizes=is_between_sizes,
        notes=tuple(notes),
    )
