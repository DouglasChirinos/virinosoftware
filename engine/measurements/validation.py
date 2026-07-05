from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class MeasurementValidationIssue:
    field: str
    message: str
    severity: str = "error"


class MeasurementValidationError(ValueError):
    def __init__(self, issues: list[MeasurementValidationIssue]) -> None:
        self.issues = issues
        detail = "; ".join(f"{issue.field}: {issue.message}" for issue in issues)
        super().__init__(detail)


def validate_body_measurements(
    *,
    waist: float,
    hip: float,
    skirt_length: float,
    ease: float,
    hip_depth: float,
    ease_hip: float | None = None,
    ease_waist: float | None = None,
) -> None:
    """Valida medidas para el MVP de falda basica.

    Unidad oficial del motor: centimetros.

    Rango conservador MVP:
    - cintura: 40 a 180 cm
    - cadera: 50 a 220 cm
    - largo falda: 20 a 140 cm
    - holgura: 0 a 20 cm
    - profundidad cadera: 10 a 35 cm
    """

    issues: list[MeasurementValidationIssue] = []

    def check_range(field: str, value: float, minimum: float, maximum: float) -> None:
        if value < minimum or value > maximum:
            issues.append(
                MeasurementValidationIssue(
                    field=field,
                    message=f"debe estar entre {minimum:g} y {maximum:g} cm; valor recibido: {value:g}",
                )
            )

    check_range("waist", waist, 40, 180)
    check_range("hip", hip, 50, 220)
    check_range("skirt_length", skirt_length, 20, 140)
    check_range("ease", ease, 0, 20)
    check_range("hip_depth", hip_depth, 10, 35)

    if ease_hip is not None:
        check_range("ease_hip", ease_hip, 0, 20)

    if ease_waist is not None:
        check_range("ease_waist", ease_waist, 0, 20)

    if hip < waist:
        issues.append(
            MeasurementValidationIssue(
                field="hip",
                message="la cadera no deberia ser menor que la cintura para este bloque MVP",
            )
        )

    if hip_depth >= skirt_length:
        issues.append(
            MeasurementValidationIssue(
                field="hip_depth",
                message="la profundidad de cadera debe ser menor que el largo de falda",
            )
        )

    if issues:
        raise MeasurementValidationError(issues)
