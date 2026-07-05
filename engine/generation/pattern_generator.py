"""Universal pattern generator.

This module resolves a garment code through the dynamic garment registry and
executes the draft class using the most appropriate measurement payload.
"""

from __future__ import annotations

from collections.abc import Mapping
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
    measurements: Any
    options: dict[str, Any] = field(default_factory=dict)

    @property
    def piece_count(self) -> int:
        return len(self.pieces)


def _validate_class_requirements(draft_class: type[Any], raw_measurements: Mapping[str, Any]) -> None:
    requirements = getattr(draft_class, "required_measurements", ())

    missing = [
        requirement.name
        for requirement in requirements
        if getattr(requirement, "required", True)
        and requirement.name not in raw_measurements
    ]

    if missing:
        joined = ", ".join(missing)
        code = getattr(getattr(draft_class, "metadata", None), "code", draft_class.__name__)
        raise PatternGenerationError(f"Missing required measurements for {code}: {joined}")


def _can_build_body_measurements(raw_measurements: Mapping[str, Any]) -> bool:
    required = ("waist", "hip", "skirt_length")
    return all(key in raw_measurements for key in required)


def _build_body_measurements(raw_measurements: Mapping[str, Any]) -> BodyMeasurements:
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
        raise PatternGenerationError(f"Invalid measurements for BodyMeasurements: {kwargs}") from exc


def _instantiate_draft(draft_class: type[Any], raw_measurements: dict[str, Any]) -> tuple[Any, Any]:
    errors: list[str] = []

    if _can_build_body_measurements(raw_measurements):
        body_measurements = _build_body_measurements(raw_measurements)
        try:
            return draft_class(body_measurements), body_measurements
        except Exception as exc:  # noqa: BLE001
            errors.append(f"BodyMeasurements failed: {exc}")

    try:
        return draft_class(raw_measurements), raw_measurements
    except Exception as exc:  # noqa: BLE001
        errors.append(f"raw mapping failed: {exc}")

    joined = " | ".join(errors)
    raise PatternGenerationError(f"Could not instantiate {draft_class.__name__}. {joined}")


def _validate_instance_requirements(draft: Any, measurements: Mapping[str, Any]) -> None:
    validator = getattr(draft, "validate_required_measurements", None)

    if callable(validator):
        try:
            validator(measurements)
        except Exception as exc:  # noqa: BLE001
            raise PatternGenerationError(str(exc)) from exc


def _run_draft(draft: Any, options: Mapping[str, Any] | None = None) -> list[Any]:
    options = dict(options or {})
    full_pattern = bool(options.get("full_pattern"))

    if full_pattern and hasattr(draft, "draft_full") and callable(draft.draft_full):
        pieces = draft.draft_full()
    elif hasattr(draft, "draft") and callable(draft.draft):
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
        raise PatternGenerationError(f"Draft class {draft.__class__.__name__} returned no pieces")

    if isinstance(pieces, list):
        return pieces
    if isinstance(pieces, tuple):
        return list(pieces)
    return [pieces]


def generate_pattern(request: PatternGenerationRequest) -> PatternGenerationResult:
    garment_code = request.garment_code.strip()

    if not garment_code:
        raise PatternGenerationError("garment_code cannot be empty")

    try:
        draft_class = get_garment(garment_code)
    except GarmentNotFoundError as exc:
        raise PatternGenerationError(f"Unknown garment code: {garment_code}") from exc

    _validate_class_requirements(draft_class, request.measurements)

    draft, normalized_measurements = _instantiate_draft(
        draft_class=draft_class,
        raw_measurements=request.measurements,
    )

    _validate_instance_requirements(draft, request.measurements)
    pieces = _run_draft(draft, request.options)

    metadata = getattr(draft_class, "metadata", None)
    garment_name = getattr(metadata, "name", garment_code)

    return PatternGenerationResult(
        garment_code=garment_code,
        garment_name=garment_name,
        draft_class_name=draft_class.__name__,
        pieces=pieces,
        measurements=normalized_measurements,
        options=dict(request.options),
    )
