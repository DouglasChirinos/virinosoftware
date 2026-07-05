from __future__ import annotations

from pathlib import Path

from engine.measurements.size_chart import SizeChart


def generate_size_chart_report(
    *,
    size_chart: SizeChart,
    output_path: str | Path,
    title: str = "Reporte tabla de tallas - v0.2.0-dev",
) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = [
        f"# {title}",
        "",
        f"- Tabla: `{size_chart.name}`",
        f"- Unidad: `{size_chart.unit}`",
        "",
        "## Tallas",
        "",
        "| Talla | Etiqueta | Cintura cm | Cadera cm | Notas |",
        "|---|---|---:|---:|---|",
    ]

    for row in size_chart.as_rows():
        lines.append(
            f"| {row['code']} | {row['label']} | {float(row['waist']):.2f} | "
            f"{float(row['hip']):.2f} | {row.get('notes', '')} |"
        )

    lines.extend(
        [
            "",
            "## Alcance",
            "",
            "- Esta tabla es nominal y controlada para el MVP.",
            "- No representa gradacion industrial completa.",
            "- No aplica todavia reglas por estatura, morfologia ni tipo de tela.",
            "- La unidad oficial es centimetros.",
            "",
        ]
    )

    output.write_text("\n".join(lines), encoding="utf-8")
    return output
