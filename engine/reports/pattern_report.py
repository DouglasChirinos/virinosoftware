from __future__ import annotations

from pathlib import Path

from engine.measurements.body import BodyMeasurements
from engine.patterns.piece import PatternPiece


def generate_pattern_report(
    *,
    pieces: list[PatternPiece],
    measurements: BodyMeasurements,
    output_path: str | Path,
    title: str = "Reporte tecnico - Falda basica MVP",
) -> Path:
    """Genera reporte tecnico Markdown del patron.

    El reporte es deliberadamente simple y versionable en Git.
    """

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    metadata = pieces[0].metadata if pieces else {}

    lines: list[str] = [
        f"# {title}",
        "",
        "## Unidad de medida",
        "",
        "- Unidad oficial del motor: **centimetros (cm)**.",
        "- Las coordenadas internas del patron estan expresadas en cm.",
        "- Los exportadores pueden convertir escala para visualizacion, pero no deben cambiar la unidad logica.",
        "",
        "## Version del patron",
        "",
        f"- Codigo: `{metadata.get('code', 'N/D')}`",
        f"- Version patron: `{metadata.get('version', 'N/D')}`",
        f"- Version motor: `{metadata.get('engine_version', 'N/D')}`",
        f"- Generado UTC: `{metadata.get('created_at', 'N/D')}`",
        "",
        "## Medidas de entrada",
        "",
        "| Campo | Valor | Unidad |",
        "|---|---:|---|",
    ]

    for key, value in measurements.as_dict().items():
        if key == "unit":
            continue
        lines.append(f"| {key} | {value} | cm |")

    lines.extend(
        [
            "",
            "## Piezas generadas",
            "",
        ]
    )

    for piece in pieces:
        lines.extend(
            [
                f"### {piece.name}",
                "",
                f"- Puntos: {len(piece.points)}",
                f"- Lineas: {len(piece.lines)}",
                f"- Curvas: {len(piece.curves)}",
                "",
                "#### Puntos",
                "",
                "| Nombre | X cm | Y cm |",
                "|---|---:|---:|",
            ]
        )

        for name, point in piece.points.items():
            lines.append(f"| {name} | {point.x:.2f} | {point.y:.2f} |")

        lines.extend(
            [
                "",
                "#### Lineas",
                "",
                "| Etiqueta | Inicio | Fin | Longitud cm |",
                "|---|---|---|---:|",
            ]
        )

        for line in piece.lines:
            lines.append(
                f"| {line.label or 'sin etiqueta'} | "
                f"({line.start.x:.2f}, {line.start.y:.2f}) | "
                f"({line.end.x:.2f}, {line.end.y:.2f}) | "
                f"{line.length:.2f} |"
            )

        if piece.annotations:
            lines.extend(["", "#### Anotaciones", ""])
            for annotation in piece.annotations:
                lines.append(f"- {annotation}")

        lines.append("")

    output.write_text("\n".join(lines), encoding="utf-8")
    return output
