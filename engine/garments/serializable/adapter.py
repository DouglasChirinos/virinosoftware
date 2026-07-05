"""Adapter from serializable garment definitions to engine pattern pieces.

This module is intentionally small and conservative. It bridges the DSL work
from Fase 26/27 with the existing universal pattern-generation contract, but it
does not register JSON garments globally yet and it does not modify the GUI.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import json
from typing import Any, Iterable, Mapping

from engine.garments.base import GarmentDraft, GarmentMetadata
from engine.garments.requirements import MeasurementRequirement
from engine.garments.serializable.definition import SerializableGarmentDefinition
from engine.garments.serializable.geometry import GeneratedSerializablePiece, generate_serializable_geometry


def load_definition_from_json(path: str | Path) -> SerializableGarmentDefinition:
    """Load a serializable garment definition from a JSON file."""
    json_path = Path(path)

    with json_path.open("r", encoding="utf-8") as file:
        raw_definition = json.load(file)

    return SerializableGarmentDefinition.from_dict(raw_definition)


@dataclass(frozen=True)
class SerializablePatternPiece:
    """Engine-compatible piece produced from a serializable definition."""

    name: str
    points: dict[str, tuple[float, float]]
    lines: list[tuple[str, str]]

    def line_count(self) -> int:
        return len(self.lines)


class SerializableGarmentDraft(GarmentDraft):
    """Draft implementation backed by a SerializableGarmentDefinition."""

    definition: SerializableGarmentDefinition

    def __init__(self, definition: SerializableGarmentDefinition) -> None:
        self.definition = definition
        self.metadata = GarmentMetadata(
            code=definition.code,
            name=definition.name,
            description=getattr(definition, "description", "") or "Prenda serializable definida por DSL inicial.",
        )
        self.measurement_requirements = tuple(
            MeasurementRequirement(
                name=item.name,
                label=item.label,
                unit=item.unit,
                required=item.required,
                description=f"Default: {item.default}" if item.default is not None else "",
            )
            for item in definition.measurements
        )

    def draft(self, measurements: Mapping[str, float]) -> list[SerializablePatternPiece]:
        generated = generate_serializable_geometry(self.definition, measurements)
        return [_to_pattern_piece(piece) for piece in generated]

    def generate(self, measurements: Mapping[str, float]) -> list[SerializablePatternPiece]:
        return self.draft(measurements)


@dataclass(frozen=True)
class SerializableGenerationResult:
    """Result object for direct generation from a JSON definition."""

    garment_code: str
    garment_name: str
    draft_class: str
    pieces: list[SerializablePatternPiece]

    @property
    def piece_count(self) -> int:
        return len(self.pieces)


class SerializableGarmentAdapterError(ValueError):
    """Raised when a serializable garment cannot be adapted or generated."""



def _to_pattern_piece(piece: GeneratedSerializablePiece) -> SerializablePatternPiece:
    return SerializablePatternPiece(
        name=piece.name,
        points=dict(piece.points),
        lines=list(piece.lines),
    )


def create_serializable_draft(definition: SerializableGarmentDefinition) -> SerializableGarmentDraft:
    """Create a draft object from an already validated serializable definition."""

    if not isinstance(definition, SerializableGarmentDefinition):
        raise SerializableGarmentAdapterError("definition must be a SerializableGarmentDefinition")
    return SerializableGarmentDraft(definition=definition)


def create_serializable_draft_from_json(path: str | Path) -> SerializableGarmentDraft:
    """Load a JSON garment definition and return an engine-compatible draft."""

    definition = load_definition_from_json(path)
    return create_serializable_draft(definition)


def generate_serializable_pattern(
    definition: SerializableGarmentDefinition,
    measurements: Mapping[str, float],
) -> SerializableGenerationResult:
    """Generate pattern pieces from a serializable garment definition."""

    draft = create_serializable_draft(definition)
    pieces = draft.generate(measurements)
    return SerializableGenerationResult(
        garment_code=definition.code,
        garment_name=definition.name,
        draft_class=draft.__class__.__name__,
        pieces=pieces,
    )


def generate_serializable_pattern_from_json(
    path: str | Path,
    measurements: Mapping[str, float],
) -> SerializableGenerationResult:
    """Generate pattern pieces directly from a JSON file."""

    definition = load_definition_from_json(path)
    return generate_serializable_pattern(definition, measurements)


def summarize_serializable_result(result: SerializableGenerationResult) -> list[str]:
    """Build CLI-friendly summary lines for a serializable generation result."""

    lines = [
        f"GARMENT_CODE: {result.garment_code}",
        f"GARMENT_NAME: {result.garment_name}",
        f"DRAFT_CLASS: {result.draft_class}",
        f"PIECE_COUNT: {result.piece_count}",
    ]
    for index, piece in enumerate(result.pieces, start=1):
        lines.append(f"PIECE_{index}: {piece.name} lines={piece.line_count()}")
    return lines
