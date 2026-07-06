"""Product-level piece completeness checks for generated garments.

These checks are not geometry-unit tests. They validate whether a generated
pattern is complete enough to be presented to an end user as a usable garment
pattern.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from engine.generation import PatternGenerationRequest, generate_pattern


LOWER_GARMENT_CODES = {
    "falda_basica",
    "falda_evase",
    "pantalon_basico",
    "short_basico",
}


@dataclass(frozen=True)
class PieceCompletenessResult:
    garment_code: str
    piece_names: tuple[str, ...]
    has_front: bool
    has_back: bool

    @property
    def is_complete(self) -> bool:
        return self.has_front and self.has_back

    @property
    def missing_roles(self) -> tuple[str, ...]:
        missing: list[str] = []
        if not self.has_front:
            missing.append("delantero")
        if not self.has_back:
            missing.append("posterior")
        return tuple(missing)


def _normalize_name(value: str) -> str:
    return value.strip().lower()


def _has_front(piece_names: tuple[str, ...]) -> bool:
    return any("delanter" in _normalize_name(name) or "front" in _normalize_name(name) for name in piece_names)


def _has_back(piece_names: tuple[str, ...]) -> bool:
    return any("posterior" in _normalize_name(name) or "espalda" in _normalize_name(name) or "back" in _normalize_name(name) for name in piece_names)


def validate_generated_piece_completeness(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    options: dict[str, Any] | None = None,
) -> PieceCompletenessResult:
    """Generate a garment and validate front/back product completeness."""

    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options=dict(options or {}),
        )
    )
    piece_names = tuple(str(getattr(piece, "name", "")) for piece in result.pieces)

    return PieceCompletenessResult(
        garment_code=garment_code,
        piece_names=piece_names,
        has_front=_has_front(piece_names),
        has_back=_has_back(piece_names),
    )


def assert_complete_lower_garment(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    options: dict[str, Any] | None = None,
) -> PieceCompletenessResult:
    """Assert that a lower garment has at least front and back pieces."""

    check = validate_generated_piece_completeness(
        garment_code=garment_code,
        measurements=measurements,
        options=options,
    )

    if garment_code in LOWER_GARMENT_CODES and not check.is_complete:
        missing = ", ".join(check.missing_roles)
        pieces = ", ".join(check.piece_names) or "<sin piezas>"
        raise AssertionError(
            f"Patron incompleto para {garment_code}. "
            f"Faltan piezas: {missing}. Piezas generadas: {pieces}"
        )

    return check
