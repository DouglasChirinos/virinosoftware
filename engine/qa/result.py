from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class QualityIssue:
    code: str
    message: str
    severity: str = "error"
    piece_name: str = ""


@dataclass
class QualityReport:
    """Resultado de control de calidad geometrico del patron."""

    issues: list[QualityIssue] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not any(issue.severity == "error" for issue in self.issues)

    @property
    def warnings(self) -> list[QualityIssue]:
        return [issue for issue in self.issues if issue.severity == "warning"]

    @property
    def errors(self) -> list[QualityIssue]:
        return [issue for issue in self.issues if issue.severity == "error"]

    def add(self, code: str, message: str, severity: str = "error", piece_name: str = "") -> None:
        self.issues.append(
            QualityIssue(
                code=code,
                message=message,
                severity=severity,
                piece_name=piece_name,
            )
        )
