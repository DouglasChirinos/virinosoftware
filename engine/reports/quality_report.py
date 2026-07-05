from __future__ import annotations

from pathlib import Path

from engine.patterns.piece import PatternPiece
from engine.qa.result import QualityReport


def generate_quality_report(
    *,
    pieces: list[PatternPiece],
    quality_report: QualityReport,
    output_path: str | Path,
    title: str = "Reporte QA - Patron generado",
) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = [
        f"# {title}",
        "",
        "## Resultado",
        "",
        f"- Estado: {'APROBADO' if quality_report.passed else 'RECHAZADO'}",
        f"- Errores: {len(quality_report.errors)}",
        f"- Advertencias: {len(quality_report.warnings)}",
        "",
        "## Piezas evaluadas",
        "",
    ]

    for piece in pieces:
        lines.extend(
            [
                f"### {piece.name}",
                "",
                f"- Puntos: {len(piece.points)}",
                f"- Lineas: {len(piece.lines)}",
                f"- Curvas: {len(piece.curves)}",
                "",
            ]
        )

    lines.extend(
        [
            "## Hallazgos",
            "",
        ]
    )

    if not quality_report.issues:
        lines.append("- Sin hallazgos. QA geometrico aprobado.")
    else:
        lines.extend(
            [
                "| Severidad | Codigo | Pieza | Mensaje |",
                "|---|---|---|---|",
            ]
        )

        for issue in quality_report.issues:
            lines.append(
                f"| {issue.severity} | {issue.code} | {issue.piece_name or 'N/D'} | {issue.message} |"
            )

    output.write_text("\n".join(lines), encoding="utf-8")
    return output
