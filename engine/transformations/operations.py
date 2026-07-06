"""Editable transformation contracts for pattern variants.

The generated base pattern is the source of truth. User edits are persisted as
replayable operations over a deep copy so the base pattern is never mutated.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Literal

TransformType = Literal["move_point", "move_line", "scale_line", "adjust_curve"]
AnchorType = Literal["start", "end", "center"]


@dataclass(frozen=True)
class TransformOperation:
    """Single editable transformation requested by the user."""

    type: TransformType
    piece: str
    dx: float = 0.0
    dy: float = 0.0
    point: str | None = None
    start_point: str | None = None
    end_point: str | None = None
    line: str | None = None
    curve: str | None = None
    factor: float = 1.0
    anchor: AnchorType = "start"
    control_delta: dict[str, float] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        cleaned: dict[str, Any] = {}
        for key, value in data.items():
            if key in {"type", "piece"}:
                cleaned[key] = value
            elif value is None:
                continue
            elif value == {}:
                continue
            elif isinstance(value, float) and value == 0.0 and key not in {"factor"}:
                continue
            elif key == "factor" and value == 1.0:
                continue
            elif key == "anchor" and value == "start":
                continue
            else:
                cleaned[key] = value
        return cleaned


@dataclass(frozen=True)
class PatternVariant:
    """Editable variant metadata and transformation history."""

    pattern_id: str
    base_garment: str
    variant_name: str
    transformations: tuple[TransformOperation, ...] = ()
    measurements: dict[str, Any] = field(default_factory=dict)

    def append(self, operation: TransformOperation) -> "PatternVariant":
        return PatternVariant(
            pattern_id=self.pattern_id,
            base_garment=self.base_garment,
            variant_name=self.variant_name,
            transformations=(*self.transformations, operation),
            measurements=dict(self.measurements),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "pattern_id": self.pattern_id,
            "base_garment": self.base_garment,
            "variant_name": self.variant_name,
            "measurements": dict(self.measurements),
            "transformations": [operation.to_dict() for operation in self.transformations],
        }
