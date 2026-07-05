from __future__ import annotations

from pathlib import Path

from engine.measurements.size_inference import SizeInferenceResult


def generate_size_inference_report(
    *,
    result: SizeInferenceResult,
    output_path: str | Path,
    title: str = "Reporte inferencia de talla",
) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = [
        f"# {title}",
        "",
        f"- Talla recomendada: `{result.recommended_size}`",
        f"- Score: `{result.score:.2f}`",
        f"- Entre tallas: `{'si' if result.is_between_sizes else 'no'}`",
        f"- Tallas cercanas: `{', '.join(profile.code for profile in result.nearest_profiles)}`",
        "",
        "## Diferencias contra talla recomendada",
        "",
        "| Medida | Usuario cm | Talla cm | Diferencia |",
        "|---|---:|---:|---:|",
    ]

    for diff in result.differences:
        lines.append(
            f"| {diff.name} | {diff.user_value:.2f} | {diff.profile_value:.2f} | {diff.signed_label} |"
        )

    lines.extend(
        [
            "",
            "## Notas",
            "",
        ]
    )

    if result.notes:
        for note in result.notes:
            lines.append(f"- {note}")
    else:
        lines.append("- Sin observaciones.")

    lines.extend(
        [
            "",
            "## Alcance",
            "",
            "- La inferencia selecciona la talla nominal mas cercana.",
            "- No reemplaza ajuste personalizado de patron.",
            "- No implementa gradacion industrial completa.",
            "- La unidad oficial es centimetros.",
            "",
        ]
    )

    output.write_text("\n".join(lines), encoding="utf-8")
    return output
