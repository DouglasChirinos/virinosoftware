from __future__ import annotations

from pathlib import Path

from engine.patterns.piece import PatternPiece
from engine.patterns.seam_allowance import SeamAllowanceConfig, analyze_corner_joins


def generate_seam_allowance_report(
    *,
    pieces: list[PatternPiece],
    output_path: str | Path,
    title: str = "Reporte margen de costura - Fase 16",
) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = [
        f"# {title}",
        "",
        "## Alcance",
        "",
        "- Contorno cerrado de margen por interseccion de offsets.",
        "- Control de esquinas tipo miter.",
        "- Fallback bevel cuando el miter supera el limite configurado.",
        "- Unidad: centimetros (cm).",
        "",
        "## Piezas con margen",
        "",
    ]

    for piece in pieces:
        if piece.metadata.get("seam_allowance") != "enabled":
            continue

        seam_lines = piece.seam_allowance_lines

        lines.extend(
            [
                f"### {piece.name}",
                "",
                f"- Modo: `{piece.metadata.get('seam_allowance_mode', 'N/D')}`",
                f"- Join configurado: `{piece.metadata.get('seam_corner_join', 'N/D')}`",
                f"- Limite miter cm: `{piece.metadata.get('seam_miter_limit_cm', 'N/D')}`",
                f"- Bevel fallback: `{piece.metadata.get('seam_bevel_fallback', 'N/D')}`",
                f"- Lineas de margen: {len(seam_lines)}",
                "",
                "#### Analisis de esquinas",
                "",
                "| Join | Miter previo cm | Miter actual cm | Limite cm | Excede limite |",
                "|---|---:|---:|---:|---|",
            ]
        )

        joins = analyze_corner_joins(piece, SeamAllowanceConfig())

        if not joins:
            lines.append("| N/D | 0.00 | 0.00 | 0.00 | N/D |")
        else:
            for join in joins:
                lines.append(
                    f"| {join.join_style} | "
                    f"{join.miter_distance_previous_cm:.2f} | "
                    f"{join.miter_distance_current_cm:.2f} | "
                    f"{join.miter_limit_cm:.2f} | "
                    f"{'si' if join.exceeds_limit else 'no'} |"
                )

        lines.extend(
            [
                "",
                "#### Lineas de margen",
                "",
                "| Linea | Inicio cm | Fin cm | Longitud cm |",
                "|---|---|---|---:|",
            ]
        )

        for line in seam_lines:
            lines.append(
                f"| {line.label} | "
                f"({line.start.x:.2f}, {line.start.y:.2f}) | "
                f"({line.end.x:.2f}, {line.end.y:.2f}) | "
                f"{line.length:.2f} |"
            )

        lines.append("")

    output.write_text("\n".join(lines), encoding="utf-8")
    return output
