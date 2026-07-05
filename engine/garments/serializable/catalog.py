"""Catalog helpers for serializable JSON garment definitions."""

from __future__ import annotations

from pathlib import Path

from engine.garments.serializable.adapter import create_serializable_draft_from_json


PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SERIALIZABLE_GARMENT_DIR = PROJECT_ROOT / "examples" / "garments"


def get_serializable_garment_path(code: str) -> Path:
    """Return the JSON definition path for a serializable garment code."""
    return DEFAULT_SERIALIZABLE_GARMENT_DIR / f"{code}.json"


def create_serializable_draft_by_code(code: str):
    """Create a SerializableGarmentDraft from a JSON garment code."""
    return create_serializable_draft_from_json(get_serializable_garment_path(code))


def list_serializable_garment_codes() -> tuple[str, ...]:
    """List available serializable garment codes."""
    if not DEFAULT_SERIALIZABLE_GARMENT_DIR.exists():
        return tuple()

    return tuple(
        sorted(path.stem for path in DEFAULT_SERIALIZABLE_GARMENT_DIR.glob("*.json"))
    )
