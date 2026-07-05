from __future__ import annotations

import tkinter.messagebox as messagebox
from pathlib import Path

try:
    import customtkinter as ctk
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Falta customtkinter. Ejecuta: python3 -m pip install -r requirements.txt") from exc

from app.controllers.skirt_controller import generate_basic_skirt_svg


class PatternApp(ctk.CTk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Motor Patronaje 2D - MVP")
        self.geometry("520x430")
        ctk.set_appearance_mode("System")
        ctk.set_default_color_theme("blue")

        self.grid_columnconfigure(1, weight=1)
        self._build_form()

    def _build_form(self) -> None:
        title = ctk.CTkLabel(self, text="Falda basica MVP", font=("Arial", 22, "bold"))
        title.grid(row=0, column=0, columnspan=2, padx=20, pady=(24, 18), sticky="w")

        self.entries: dict[str, ctk.CTkEntry] = {}
        fields = [
            ("waist", "Cintura cm", "72"),
            ("hip", "Cadera cm", "100"),
            ("skirt_length", "Largo falda cm", "60"),
            ("hip_depth", "Bajada cadera cm", "20"),
        ]
        for row, (key, label, value) in enumerate(fields, start=1):
            ctk.CTkLabel(self, text=label).grid(row=row, column=0, padx=20, pady=10, sticky="w")
            entry = ctk.CTkEntry(self)
            entry.insert(0, value)
            entry.grid(row=row, column=1, padx=20, pady=10, sticky="ew")
            self.entries[key] = entry

        button = ctk.CTkButton(self, text="Generar SVG", command=self._generate)
        button.grid(row=5, column=0, columnspan=2, padx=20, pady=(20, 10), sticky="ew")

        self.output_label = ctk.CTkLabel(self, text="Salida: exports/svg/falda_basica_gui.svg", wraplength=450)
        self.output_label.grid(row=6, column=0, columnspan=2, padx=20, pady=10, sticky="w")

        note = ctk.CTkLabel(
            self,
            text="Nota: este MVP genera SVG. La vista previa embebida se incorpora en una fase posterior.",
            wraplength=450,
            justify="left",
        )
        note.grid(row=7, column=0, columnspan=2, padx=20, pady=(8, 20), sticky="w")

    def _read_float(self, key: str) -> float:
        value = self.entries[key].get().strip().replace(",", ".")
        return float(value)

    def _generate(self) -> None:
        try:
            output = generate_basic_skirt_svg(
                waist=self._read_float("waist"),
                hip=self._read_float("hip"),
                skirt_length=self._read_float("skirt_length"),
                hip_depth=self._read_float("hip_depth"),
            )
        except Exception as exc:  # noqa: BLE001 - UI boundary
            messagebox.showerror("Error de validacion", str(exc))
            return

        resolved = Path(output).resolve()
        self.output_label.configure(text=f"SVG generado: {resolved}")
        messagebox.showinfo("Patron generado", f"Archivo generado:\n{resolved}")
