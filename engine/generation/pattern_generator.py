"""Universal pattern generator.

This module resolves a garment code through the dynamic garment registry and
executes the draft class using normalized body measurements.

Fase 22 intentionally does not implement universal exports. Export orchestration
belongs to a later phase after the generator contract is stable.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from engine.garments import GarmentNotFoundError, get_garment
from engine.measurements import BodyMeasurements


class PatternGenerationError(Exception):
    """Raised when universal pattern generation fails."""


@dataclass(frozen=True)
class PatternGenerationRequest:
    """Input contract for universal pattern generation."""

    garment_code: str
    measurements: dict[str, Any]
    options: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PatternGenerationResult:
    """Output contract for universal pattern generation."""

    garment_code: str
    garment_name: str
    draft_class_name: str
    pieces: list[Any]
    measurements: BodyMeasurements
    options: dict[str, Any] = field(default_factory=dict)

    @property
    def piece_count(self) -> int:
        """Return the number of generated pattern pieces."""

        return len(self.pieces)


def _normalize_measurements(raw_measurements: dict[str, Any]) -> BodyMeasurements:
    """Convert a plain mapping into ``BodyMeasurements``.

    The current MVP measurement model is body-measurement based. This function
    keeps Fase 22 compatible with the existing falda_basica implementation while
    keeping a single universal entry point for future garments.
    """

    required = ("waist", "hip", "skirt_length")
    missing = [name for name in required if name not in raw_measurements]

    if missing:
        joined = ", ".join(missing)
        raise PatternGenerationError(f"Missing body measurements: {joined}")

    allowed = {
        "waist",
        "hip",
        "skirt_length",
        "ease",
        "hip_depth",
        "ease_hip",
        "ease_waist",
        "unit",
    }

    kwargs = {
        key: value
        for key, value in raw_measurements.items()
        if key in allowed and value is not None
    }

    try:
        return BodyMeasurements(**kwargs)
    except TypeError as exc:
        raise PatternGenerationError(
            f"Invalid measurements for BodyMeasurements: {kwargs}"
        ) from exc


def _validate_garment_requirements(draft: Any, measurements: dict[str, Any]) -> None:
    """Run the optional garment contract validation if available."""

    validator = getattr(draft, "validate_required_measurements", None)

    if callable(validator):
        validator(measurements)


def _run_draft(draft: Any) -> list[Any]:
    """Execute the best available drafting method."""

    if hasattr(draft, "draft") and callable(draft.draft):
        pieces = draft.draft()
    elif hasattr(draft, "draft_full") and callable(draft.draft_full):
        pieces = draft.draft_full()
    elif hasattr(draft, "build") and callable(draft.build):
        pieces = [draft.build()]
    else:
        raise PatternGenerationError(
            f"Draft class {draft.__class__.__name__} does not expose draft(), draft_full() or build()"
        )

    if pieces is None:
        raise PatternGenerationError(
            f"Draft class {draft.__class__.__name__} returned no pieces"
        )

    if isinstance(pieces, list):
        return pieces

    if isinstance(pieces, tuple):
        return list(pieces)

    return [pieces]


def generate_pattern(request: PatternGenerationRequest) -> PatternGenerationResult:
    """Generate a pattern using the garment registry.

    Args:
        request: Universal generation request.

    Returns:
        Universal generation result.

    Raises:
        PatternGenerationError: If the garment or measurements are invalid.
    """

    garment_code = request.garment_code.strip()

    if not garment_code:
        raise PatternGenerationError("garment_code cannot be empty")

    try:
        draft_class = get_garment(garment_code)
    except GarmentNotFoundError as exc:
        raise PatternGenerationError(f"Unknown garment code: {garment_code}") from exc

    measurements = _normalize_measurements(request.measurements)

    try:
        draft = draft_class(measurements)
    except TypeError as exc:
        raise PatternGenerationError(
            f"Could not instantiate {draft_class.__name__} with BodyMeasurements"
        ) from exc

    _validate_garment_requirements(draft, request.measurements)
    pieces = _run_draft(draft)

    metadata = getattr(draft_class, "metadata", None)
    garment_name = getattr(metadata, "name", garment_code)

    return PatternGenerationResult(
        garment_code=garment_code,
        garment_name=garment_name,
        draft_class_name=draft_class.__name__,
        pieces=pieces,
        measurements=measurements,
        options=dict(request.options),
    )
