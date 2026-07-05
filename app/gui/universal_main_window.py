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
