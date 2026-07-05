"""Contratos base para generadores de patrones."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class PatternDraft(ABC):
    """Clase base para todo patron generable."""

    @abstractmethod
    def generate(self) -> dict[str, Any]:
        """Genera la representacion geometrica del patron."""
