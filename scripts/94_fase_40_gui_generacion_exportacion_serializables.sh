#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 40: GUI para generar/exportar prendas existentes =="

echo "== Validando rama base =="
git switch develop
git pull origin develop

if git rev-parse --verify "$FEATURE_BRANCH" >/dev/null 2>&1; then
  git switch "$FEATURE_BRANCH"
else
  git switch -c "$FEATURE_BRANCH"
fi

mkdir -p scripts docs tests app/controllers app/gui

cat > app/controllers/universal_pattern_controller.py <<'PY'
"""Controller for the universal GUI pattern flow."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from engine.garments import list_garments
from engine.generation import (
    PatternExportRequest,
    PatternGenerationRequest,
    export_generated_pattern,
    generate_pattern,
)


@dataclass(frozen=True)
class GarmentOption:
    """GUI-friendly garment option."""

    code: str
    name: str
    required_measurements: tuple[str, ...]


@dataclass(frozen=True)
class GuiGenerationSummary:
    """Summary returned to the GUI after generation/export."""

    garment_code: str
    garment_name: str
    draft_class_name: str
    piece_count: int
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None


_DEFAULT_MEASUREMENTS_BY_GARMENT: dict[str, dict[str, float]] = {
    "falda_basica": {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
        "ease": 2.0,
    },
    "pantalon_basico": {
        "waist": 84.0,
        "hip": 104.0,
        "outseam": 100.0,
        "inseam": 76.0,
    },
    "short_basico": {
        "waist": 84.0,
        "hip": 104.0,
        "outseam": 45.0,
        "inseam": 20.0,
    },
    "falda_evase": {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
        "ease": 12.0,
    },
}


def get_garment_options() -> list[GarmentOption]:
    """Return registered garments with required measurement names."""

    options: list[GarmentOption] = []

    for garment in list_garments():
        requirements = getattr(garment.draft_class, "required_measurements", ())
        required_measurements = tuple(
            requirement.name
            for requirement in requirements
            if getattr(requirement, "required", True)
        )
        options.append(
            GarmentOption(
                code=garment.code,
                name=garment.name,
                required_measurements=required_measurements,
            )
        )

    return sorted(options, key=lambda item: item.code)


def get_default_measurements(garment_code: str) -> dict[str, float]:
    """Return practical default measurements for MVP garments."""

    defaults = _DEFAULT_MEASUREMENTS_BY_GARMENT.get(garment_code)
    if defaults is not None:
        return dict(defaults)

    return {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
    }


def slugify_output_name(value: str) -> str:
    """Return a filesystem-safe output name fragment."""

    normalized = value.strip().lower().replace("ñ", "n")
    normalized = re.sub(r"[^a-z0-9_-]+", "_", normalized)
    normalized = re.sub(r"_+", "_", normalized).strip("_")
    return normalized


def build_output_name(garment_code: str, pattern_name: str | None = None) -> str:
    """Return a safe GUI output name without overwriting previous exports by default."""

    garment = slugify_output_name(garment_code)
    custom = slugify_output_name(pattern_name or "")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    if custom:
        return f"{garment}_{custom}_{timestamp}"

    return f"{garment}_gui_{timestamp}"


def parse_measurements(raw_values: dict[str, str]) -> dict[str, float]:
    """Parse GUI text inputs into numeric measurements."""

    parsed: dict[str, float] = {}

    for key, value in raw_values.items():
        value = value.strip()

        if not value:
            continue

        try:
            parsed[key] = float(value.replace(",", "."))
        except ValueError as exc:
            raise ValueError(f"Medida invalida para {key}: {value!r}") from exc

    return parsed


def generate_summary(
    *,
    garment_code: str,
    measurements: dict[str, Any],
) -> GuiGenerationSummary:
    """Generate pattern only and return a summary."""

    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
        )
    )

    return GuiGenerationSummary(
        garment_code=result.garment_code,
        garment_name=result.garment_name,
        draft_class_name=result.draft_class_name,
        piece_count=result.piece_count,
    )


def export_summary(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    output_name: str | None = None,
) -> GuiGenerationSummary:
    """Generate and export pattern, then return GUI summary."""

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
            ),
            output_name=output_name or build_output_name(garment_code),
        )
    )

    generation = result.generation_result

    return GuiGenerationSummary(
        garment_code=generation.garment_code,
        garment_name=generation.garment_name,
        draft_class_name=generation.draft_class_name,
        piece_count=generation.piece_count,
        svg_path=result.svg_path,
        dxf_path=result.dxf_path,
        pdf_path=result.pdf_path,
    )
PY

cat > app/gui/universal_main_window.py <<'PY'
"""Universal CustomTkinter main window."""

from __future__ import annotations

import tkinter.messagebox as messagebox
from pathlib import Path

try:
    import customtkinter as ctk
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Falta customtkinter. Ejecuta: python3 -m pip install -r requirements.txt") from exc

from app.controllers.universal_pattern_controller import (
    build_output_name,
    export_summary,
    generate_summary,
    get_default_measurements,
    get_garment_options,
    parse_measurements,
)


MEASUREMENT_LABELS = {
    "waist": "Cintura",
    "hip": "Cadera",
    "skirt_length": "Largo falda",
    "outseam": "Largo exterior",
    "inseam": "Entrepierna",
    "rise": "Tiro",
    "ease": "Holgura",
    "hip_depth": "Altura cadera",
}


class UniversalMainWindow(ctk.CTk):
    """GUI connected to the universal pattern backend."""

    def __init__(self) -> None:
        super().__init__()

        self.title("VirinoSoftware - Patronaje 2D")
        self.geometry("820x640")

        ctk.set_appearance_mode("System")
        ctk.set_default_color_theme("blue")

        self.garment_options = get_garment_options()
        self.garment_by_label = {
            f"{item.code} - {item.name}": item
            for item in self.garment_options
        }
        self.measurement_entries: dict[str, ctk.CTkEntry] = {}
        self.pattern_name_var = ctk.StringVar(value="")

        self._build_layout()

        if self.garment_by_label:
            first_label = next(iter(self.garment_by_label))
            self.garment_var.set(first_label)
            self._refresh_measurements()

    def _build_layout(self) -> None:
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(5, weight=1)

        title = ctk.CTkLabel(
            self,
            text="VirinoSoftware - Patronaje 2D",
            font=ctk.CTkFont(size=22, weight="bold"),
        )
        title.grid(row=0, column=0, padx=20, pady=(20, 4), sticky="w")

        subtitle = ctk.CTkLabel(
            self,
            text="Generacion y exportacion de prendas existentes sin terminal",
        )
        subtitle.grid(row=1, column=0, padx=20, pady=(0, 10), sticky="w")

        selector_frame = ctk.CTkFrame(self)
        selector_frame.grid(row=2, column=0, padx=20, pady=10, sticky="ew")
        selector_frame.grid_columnconfigure(1, weight=1)

        ctk.CTkLabel(selector_frame, text="Prenda").grid(
            row=0, column=0, padx=12, pady=12, sticky="w"
        )

        self.garment_var = ctk.StringVar(value="")
        self.garment_menu = ctk.CTkOptionMenu(
            selector_frame,
            variable=self.garment_var,
            values=list(self.garment_by_label.keys()) or ["Sin prendas registradas"],
            command=lambda _: self._refresh_measurements(),
        )
        self.garment_menu.grid(row=0, column=1, padx=12, pady=12, sticky="ew")

        ctk.CTkLabel(selector_frame, text="Nombre patron").grid(
            row=1, column=0, padx=12, pady=12, sticky="w"
        )
        ctk.CTkEntry(
            selector_frame,
            textvariable=self.pattern_name_var,
            placeholder_text="Opcional. Ejemplo: short_cliente_maria",
        ).grid(row=1, column=1, padx=12, pady=12, sticky="ew")

        self.measurements_frame = ctk.CTkFrame(self)
        self.measurements_frame.grid(row=3, column=0, padx=20, pady=10, sticky="ew")
        self.measurements_frame.grid_columnconfigure(1, weight=1)

        actions_frame = ctk.CTkFrame(self)
        actions_frame.grid(row=4, column=0, padx=20, pady=10, sticky="ew")
        actions_frame.grid_columnconfigure((0, 1), weight=1)

        ctk.CTkButton(actions_frame, text="Generar", command=self._on_generate).grid(
            row=0, column=0, padx=12, pady=12, sticky="ew"
        )
        ctk.CTkButton(actions_frame, text="Exportar SVG/DXF/PDF", command=self._on_export).grid(
            row=0, column=1, padx=12, pady=12, sticky="ew"
        )

        self.output_text = ctk.CTkTextbox(self, height=220)
        self.output_text.grid(row=5, column=0, padx=20, pady=(10, 20), sticky="nsew")

    def _selected_option(self):
        return self.garment_by_label.get(self.garment_var.get())

    def _refresh_measurements(self) -> None:
        for child in self.measurements_frame.winfo_children():
            child.destroy()

        self.measurement_entries.clear()
        option = self._selected_option()

        if option is None:
            return

        defaults = get_default_measurements(option.code)
        measurement_names = list(option.required_measurements)

        for row, name in enumerate(measurement_names):
            ctk.CTkLabel(self.measurements_frame, text=MEASUREMENT_LABELS.get(name, name)).grid(
                row=row, column=0, padx=12, pady=8, sticky="w"
            )
            entry = ctk.CTkEntry(self.measurements_frame)
            entry.insert(0, str(defaults.get(name, "")))
            entry.grid(row=row, column=1, padx=12, pady=8, sticky="ew")
            self.measurement_entries[name] = entry

    def _read_measurements(self) -> dict[str, float]:
        return parse_measurements(
            {name: entry.get() for name, entry in self.measurement_entries.items()}
        )

    def _write_output(self, lines: list[str]) -> None:
        self.output_text.delete("1.0", "end")
        self.output_text.insert("1.0", "\n".join(lines))

    def _on_generate(self) -> None:
        try:
            option = self._selected_option()
            if option is None:
                raise ValueError("No hay prenda seleccionada.")

            summary = generate_summary(
                garment_code=option.code,
                measurements=self._read_measurements(),
            )
            self._write_output(
                [
                    "GENERACION OK",
                    f"GARMENT_CODE: {summary.garment_code}",
                    f"GARMENT_NAME: {summary.garment_name}",
                    f"DRAFT_CLASS: {summary.draft_class_name}",
                    f"PIECE_COUNT: {summary.piece_count}",
                    "",
                    "Use Exportar SVG/DXF/PDF para generar archivos imprimibles.",
                ]
            )
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error de generacion", str(exc))

    def _on_export(self) -> None:
        try:
            option = self._selected_option()
            if option is None:
                raise ValueError("No hay prenda seleccionada.")

            output_name = build_output_name(option.code, self.pattern_name_var.get())
            summary = export_summary(
                garment_code=option.code,
                measurements=self._read_measurements(),
                output_name=output_name,
            )

            lines = [
                "EXPORTACION OK",
                f"GARMENT_CODE: {summary.garment_code}",
                f"GARMENT_NAME: {summary.garment_name}",
                f"DRAFT_CLASS: {summary.draft_class_name}",
                f"PIECE_COUNT: {summary.piece_count}",
                f"OUTPUT_NAME: {output_name}",
                "",
            ]

            for label, path in (
                ("SVG", summary.svg_path),
                ("DXF", summary.dxf_path),
                ("PDF", summary.pdf_path),
            ):
                if path:
                    lines.append(f"{label}: {Path(path).resolve()}")

            self._write_output(lines)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error de exportacion", str(exc))
PY

cat > tests/test_gui_universal_controller.py <<'PY'
"""Tests for Fase 40 universal GUI controller."""

from __future__ import annotations

import re
from pathlib import Path

from app.controllers.universal_pattern_controller import (
    build_output_name,
    export_summary,
    generate_summary,
    get_default_measurements,
    get_garment_options,
    parse_measurements,
    slugify_output_name,
)


def test_get_garment_options_exposes_registered_garments() -> None:
    options = get_garment_options()
    codes = {option.code for option in options}

    assert "falda_basica" in codes
    assert "pantalon_basico" in codes
    assert "short_basico" in codes
    assert "falda_evase" in codes


def test_default_measurements_for_basic_skirt() -> None:
    measurements = get_default_measurements("falda_basica")

    assert measurements["waist"] == 73.0
    assert measurements["hip"] == 99.0
    assert measurements["skirt_length"] == 60.0


def test_default_measurements_for_basic_pants() -> None:
    measurements = get_default_measurements("pantalon_basico")

    assert measurements["waist"] == 84.0
    assert measurements["hip"] == 104.0
    assert measurements["outseam"] == 100.0
    assert measurements["inseam"] == 76.0


def test_default_measurements_for_serializable_short() -> None:
    measurements = get_default_measurements("short_basico")

    assert measurements == {
        "waist": 84.0,
        "hip": 104.0,
        "outseam": 45.0,
        "inseam": 20.0,
    }


def test_default_measurements_for_serializable_falda_evase() -> None:
    measurements = get_default_measurements("falda_evase")

    assert measurements == {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
        "ease": 12.0,
    }


def test_parse_measurements_accepts_decimal_comma() -> None:
    measurements = parse_measurements(
        {
            "waist": "73,5",
            "hip": "99.0",
            "skirt_length": "60",
            "empty": "",
        }
    )

    assert measurements["waist"] == 73.5
    assert measurements["hip"] == 99.0
    assert measurements["skirt_length"] == 60.0
    assert "empty" not in measurements


def test_parse_measurements_reports_invalid_value() -> None:
    try:
        parse_measurements({"waist": "setenta"})
    except ValueError as exc:
        assert "Medida invalida para waist" in str(exc)
    else:  # pragma: no cover
        raise AssertionError("Expected invalid measurement error")


def test_slugify_output_name() -> None:
    assert slugify_output_name(" Short Cliente María 01 ") == "short_cliente_maria_01"


def test_build_output_name_without_custom_name_is_unique_and_safe() -> None:
    output_name = build_output_name("falda_evase")

    assert re.match(r"^falda_evase_gui_\d{8}_\d{6}$", output_name)


def test_build_output_name_with_custom_name_is_unique_and_safe() -> None:
    output_name = build_output_name("short_basico", "Cliente María / prueba")

    assert re.match(r"^short_basico_cliente_maria_prueba_\d{8}_\d{6}$", output_name)


def test_generate_summary_for_serializable_short() -> None:
    summary = generate_summary(
        garment_code="short_basico",
        measurements={
            "waist": 84,
            "hip": 104,
            "outseam": 45,
            "inseam": 20,
        },
    )

    assert summary.garment_code == "short_basico"
    assert summary.piece_count == 1


def test_generate_summary_for_basic_pants() -> None:
    summary = generate_summary(
        garment_code="pantalon_basico",
        measurements={
            "waist": 84,
            "hip": 104,
            "outseam": 100,
            "inseam": 76,
        },
    )

    assert summary.garment_code == "pantalon_basico"
    assert summary.draft_class_name == "BasicPantsDraft"
    assert summary.piece_count == 2


def test_export_summary_creates_universal_gui_exports() -> None:
    output_name = "test_gui_pantalon_basico"

    summary = export_summary(
        garment_code="pantalon_basico",
        measurements={
            "waist": 84,
            "hip": 104,
            "outseam": 100,
            "inseam": 76,
        },
        output_name=output_name,
    )

    assert summary.svg_path is not None
    assert summary.dxf_path is not None
    assert summary.pdf_path is not None

    for path in (summary.svg_path, summary.dxf_path, summary.pdf_path):
        assert Path(path).exists()
        assert Path(path).stat().st_size > 0
PY

cat > docs/51_Fase_40_GUI_Generacion_Exportacion_Serializables.md <<'MD'
# Fase 40 - GUI para generar/exportar prendas existentes

## Objetivo

Convertir la GUI universal en una primera pantalla de producto para usuario final, enfocada en usar prendas existentes sin terminal.

## Alcance implementado

- La GUI lista prendas registradas desde el catalogo universal.
- Incluye prendas Python y prendas serializables JSON.
- Muestra medidas requeridas segun la prenda seleccionada.
- Precarga valores demo por prenda:
  - `falda_basica`
  - `pantalon_basico`
  - `short_basico`
  - `falda_evase`
- Permite ingresar nombre opcional de patron.
- Genera patron desde pantalla.
- Exporta SVG, DXF y PDF desde pantalla.
- Genera nombres de salida seguros con timestamp para evitar sobrescritura accidental.
- Muestra rutas absolutas de archivos exportados.
- Refuerza validacion de valores numericos ingresados.

## Fuera de alcance

- Registro historico local de patrones generados.
- Consulta de patrones guardados.
- Impresion directa desde GUI.
- Creacion de prendas nuevas desde GUI.
- Editor visual de puntos y lineas.

Estos puntos pertenecen a Fases 41, 42, 43, 44 y 45.

## Comando de uso

```bash
cd /home/antares/Proyecto/motor
make run-gui
```

## Validacion recomendada

```bash
cd /home/antares/Proyecto/motor

make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog

rm -rf exports
git status --short
```

## Criterio de aceptacion

Un usuario final puede abrir la GUI, seleccionar una prenda existente, ingresar medidas, generar el patron y exportar SVG/DXF/PDF sin editar JSON ni usar terminal.
MD

python3 - <<'PY'
from pathlib import Path
path = Path('Makefile')
text = path.read_text(encoding='utf-8')
block = """
validate-fase-40:
	.venv/bin/python -m pytest tests/test_gui_universal_controller.py -q
	.venv/bin/python scripts/list_garments.py
	.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20
	.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12
"""
if 'validate-fase-40:' not in text:
    text = text.rstrip() + "\n" + block
path.write_text(text + ("" if text.endswith("\n") else "\n"), encoding='utf-8')
PY

echo "== Limpieza de salidas generadas =="
rm -rf exports
find . -type d -name "__pycache__" -prune -exec rm -rf {} +
find . -type d -name ".pytest_cache" -prune -exec rm -rf {} +

echo "== Validaciones Fase 40 =="
make validate-fase-40
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog

rm -rf exports

echo "== Estado Git =="
git status --short

echo "== Fase 40 aplicada. Revisar cambios, probar make run-gui y commitear en feature si todo esta OK. =="
