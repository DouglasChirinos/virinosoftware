from __future__ import annotations

from pathlib import Path

from engine.patterns.piece import PatternPiece


def generate_seam_allowance_report(
    *,
    pieces: list[PatternPiece],
    output_path: str | Path,
    title: str = "Reporte margen de costura - Fase 15",
) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = [
        f"# {title}",
        "",
        "## Alcance",
        "",
        "- Contorno cerrado de margen por interseccion de offsets.",
        "- Unidad: centimetros (cm).",
        "- Miter/fillet avanzado queda preparado para fase posterior.",
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
                f"- Lineas de margen: {len(seam_lines)}",
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
