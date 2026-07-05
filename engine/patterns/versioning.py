from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone


@dataclass(frozen=True)
class PatternVersion:
    """Version interna de un patron generado."""

    code: str
    version: str
    engine_version: str
    created_at: str
    unit: str = "cm"

    @classmethod
    def create(cls, *, code: str, version: str = "0.1.0", engine_version: str = "mvp-0.1.0") -> "PatternVersion":
        return cls(
            code=code,
            version=version,
            engine_version=engine_version,
            created_at=datetime.now(timezone.utc).isoformat(),
            unit="cm",
        )

    def as_dict(self) -> dict[str, str]:
        return {
            "code": self.code,
            "version": self.version,
            "engine_version": self.engine_version,
            "created_at": self.created_at,
            "unit": self.unit,
        }
