#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-25-gui-universal"
SCRIPT_PATH="scripts/65_fase_25_gui_universal.sh"

cd "$PROJECT_DIR"

echo "== Fase 25: GUI universal con registro/generacion/exportacion =="
echo "== Proyecto: $PROJECT_DIR =="

echo
echo "== 1. Validando repositorio Git =="
git rev-parse --is-inside-work-tree >/dev/null

echo
echo "== 2. Estado inicial =="
git status --short
git branch --show-current
git log --oneline --decorate --max-count=10

echo
echo "== 3. Verificando arbol de trabajo =="
DIRTY_EXCLUDING_THIS_SCRIPT="$(git status --porcelain | grep -v "^?? ${SCRIPT_PATH}$" || true)"

if [[ -n "$DIRTY_EXCLUDING_THIS_SCRIPT" ]]; then
  echo
  echo "ERROR: El arbol de trabajo no esta limpio."
  echo "Cambios detectados:"
  echo "$DIRTY_EXCLUDING_THIS_SCRIPT"
  exit 1
fi

echo
echo "== 4. Sincronizando develop =="
git switch develop
git pull origin develop

echo
echo "== 5. Creando/cambiando a rama feature =="
if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
  git switch "$FEATURE_BRANCH"
else
  git switch -c "$FEATURE_BRANCH"
fi

echo
echo "== 6. Validacion base antes de modificar =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants

echo
echo "== 7. Creando controlador GUI universal =="
mkdir -p app/controllers app/gui scripts docs tests

cat > app/controllers/universal_pattern_controller.py <<'PY'
"""Controller for the universal GUI pattern flow."""

from __future__ import annotations

from dataclasses import dataclass
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

    return options


def get_default_measurements(garment_code: str) -> dict[str, float]:
    """Return practical default measurements for MVP garments."""

    if garment_code == "pantalon_basico":
        return {
            "waist": 84.0,
            "hip": 104.0,
            "outseam": 100.0,
            "inseam": 76.0,
        }

    return {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
    }


def build_output_name(garment_code: str) -> str:
    """Return default GUI output name."""

    return f"{garment_code}_gui_universal"


def parse_measurements(raw_values: dict[str, str]) -> dict[str, float]:
    """Parse GUI text inputs into numeric measurements."""

    parsed: dict[str, float] = {}

    for key, value in raw_values.items():
        value = value.strip()

        if not value:
            continue

        parsed[key] = float(value.replace(",", "."))

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

echo
echo "== 8. Creando ventana GUI universal =="

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
        self.geometry("720x560")

        ctk.set_appearance_mode("System")
        ctk.set_default_color_theme("blue")

        self.garment_options = get_garment_options()
        self.garment_by_label = {
            f"{item.code} - {item.name}": item
            for item in self.garment_options
        }
        self.measurement_entries: dict[str, ctk.CTkEntry] = {}

        self._build_layout()

        if self.garment_by_label:
            first_label = next(iter(self.garment_by_label))
            self.garment_var.set(first_label)
            self._refresh_measurements()

    def _build_layout(self) -> None:
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(4, weight=1)

        title = ctk.CTkLabel(
            self,
            text="Motor de Patronaje 2D - GUI Universal",
            font=ctk.CTkFont(size=20, weight="bold"),
        )
        title.grid(row=0, column=0, padx=20, pady=(20, 10), sticky="w")

        selector_frame = ctk.CTkFrame(self)
        selector_frame.grid(row=1, column=0, padx=20, pady=10, sticky="ew")
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

        self.measurements_frame = ctk.CTkFrame(self)
        self.measurements_frame.grid(row=2, column=0, padx=20, pady=10, sticky="ew")
        self.measurements_frame.grid_columnconfigure(1, weight=1)

        actions_frame = ctk.CTkFrame(self)
        actions_frame.grid(row=3, column=0, padx=20, pady=10, sticky="ew")
        actions_frame.grid_columnconfigure((0, 1), weight=1)

        ctk.CTkButton(actions_frame, text="Generar", command=self._on_generate).grid(
            row=0, column=0, padx=12, pady=12, sticky="ew"
        )
        ctk.CTkButton(actions_frame, text="Exportar SVG/DXF/PDF", command=self._on_export).grid(
            row=0, column=1, padx=12, pady=12, sticky="ew"
        )

        self.output_text = ctk.CTkTextbox(self, height=180)
        self.output_text.grid(row=4, column=0, padx=20, pady=(10, 20), sticky="nsew")

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

        if option.code == "pantalon_basico" and "inseam" not in measurement_names:
            measurement_names.append("inseam")

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
                ]
            )
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error de generacion", str(exc))

    def _on_export(self) -> None:
        try:
            option = self._selected_option()
            if option is None:
                raise ValueError("No hay prenda seleccionada.")

            summary = export_summary(
                garment_code=option.code,
                measurements=self._read_measurements(),
                output_name=build_output_name(option.code),
            )

            lines = [
                "EXPORTACION OK",
                f"GARMENT_CODE: {summary.garment_code}",
                f"GARMENT_NAME: {summary.garment_name}",
                f"DRAFT_CLASS: {summary.draft_class_name}",
                f"PIECE_COUNT: {summary.piece_count}",
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

echo
echo "== 9. Creando entrypoints GUI universal =="

cat > scripts/run_gui.py <<'PY'
#!/usr/bin/env python3
"""Run VirinoSoftware universal GUI."""

from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from app.gui.universal_main_window import UniversalMainWindow


def main() -> None:
    app = UniversalMainWindow()
    app.mainloop()


if __name__ == "__main__":
    main()
PY
chmod +x scripts/run_gui.py

cat > app/main_universal.py <<'PY'
"""Universal GUI entrypoint."""

from __future__ import annotations

from app.gui.universal_main_window import UniversalMainWindow


def main() -> None:
    app = UniversalMainWindow()
    app.mainloop()


if __name__ == "__main__":
    main()
PY

echo
echo "== 10. Actualizando Makefile si aplica =="
if ! grep -q "^run-gui:" Makefile; then
  cat >> Makefile <<'MK'

run-gui:
	.venv/bin/python scripts/run_gui.py
MK
fi

echo
echo "== 11. Creando tests del controlador GUI universal =="

cat > tests/test_gui_universal_controller.py <<'PY'
"""Tests for Fase 25 universal GUI controller."""

from __future__ import annotations

from pathlib import Path

from app.controllers.universal_pattern_controller import (
    build_output_name,
    export_summary,
    generate_summary,
    get_default_measurements,
    get_garment_options,
    parse_measurements,
)


def test_get_garment_options_exposes_registered_garments() -> None:
    options = get_garment_options()
    codes = {option.code for option in options}

    assert "falda_basica" in codes
    assert "pantalon_basico" in codes


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


def test_build_output_name() -> None:
    assert build_output_name("falda_basica") == "falda_basica_gui_universal"
PY

echo
echo "== 12. Documentando Fase 25 =="

cat > docs/34_Fase_25_GUI_Universal.md <<'MD'
# Fase 25 - Integración GUI con registro, generación y exportación universal

## Objetivo

Desacoplar la GUI del flujo exclusivo de `falda_basica` y conectarla al backend universal creado en las Fases 21, 22 y 24.

## Alcance implementado

- Se crea `app/controllers/universal_pattern_controller.py`.
- Se crea `app/gui/universal_main_window.py`.
- Se crea `scripts/run_gui.py`.
- Se crea `app/main_universal.py`.
- Se agrega `make run-gui`.
- La GUI lista prendas registradas.
- La GUI permite generar y exportar SVG/DXF/PDF.
- Se agregan tests de controlador GUI.
- No se elimina la GUI legacy.
- No se modifica geometría ni exportadores.

## Uso

```bash
make run-gui
```

Alternativa:

```bash
.venv/bin/python scripts/run_gui.py
```

## Flujo funcional

```text
GUI
  -> list_garments
  -> generate_pattern
  -> export_generated_pattern
  -> exports/svg
  -> exports/dxf
  -> exports/pdf
```

## Salidas esperadas desde GUI

```text
exports/svg/falda_basica_gui_universal.svg
exports/dxf/falda_basica_gui_universal.dxf
exports/pdf/falda_basica_gui_universal.pdf

exports/svg/pantalon_basico_gui_universal.svg
exports/dxf/pantalon_basico_gui_universal.dxf
exports/pdf/pantalon_basico_gui_universal.pdf
```

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make run-gui
```
MD

echo
echo "== 13. Limpieza =="
find . -name "*.bak.*" -type f -delete

echo
echo "== 14. Validaciones finales =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants

echo
echo "== 15. Estado final =="
git status --short
git diff --stat

echo
echo "== Fase 25 preparada =="
echo "Para probar GUI manualmente:"
echo "  make run-gui"
echo
echo "Si todo esta correcto:"
echo "  git restore reports/falda_basica_medidas_w73_h99_reporte.md reports/falda_basica_mvp_reporte.md || true"
echo "  git add app/controllers/universal_pattern_controller.py app/gui/universal_main_window.py app/main_universal.py scripts/run_gui.py tests/test_gui_universal_controller.py docs/34_Fase_25_GUI_Universal.md Makefile ${SCRIPT_PATH}"
echo "  git commit -m \"Fase 25 GUI universal con registro y exportacion\""
echo "  git push -u origin $FEATURE_BRANCH"
