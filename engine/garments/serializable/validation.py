"""Validation helpers for serializable garment definitions."""

from __future__ import annotations


class SerializableGarmentValidationError(ValueError):
    """Raised when a serializable garment definition is structurally invalid."""
