from __future__ import annotations

from pathlib import Path
from tkinter import messagebox

try:
    import customtkinter as ctk
except ImportError as exc:
    raise SystemExit("Falta customtkinter. Ejecuta: python3 -m pip install -r requirements.txt") from exc

from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements

PROJECT_ROOT = Path(__file__).resolve().parents[1]


class MotorPatronajeApp(ctk.CTk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Motor Patronaje 2D - MVP")
        self.geometry("520x420")

        self.waist = ctk.StringVar(value="72")
        self.hip = ctk.StringVar(value="98")
        self.length = ctk.StringVar(value="60")
        self.ease = ctk.StringVar(value="2")

        ctk.CTkLabel(self, text="Falda basica MVP", font=("Arial", 22)).pack(pady=20)

        form = ctk.CTkFrame(self)
        form.pack(padx=20, pady=10, fill="x")

        self._row(form, "Cintura cm", self.waist)
        self._row(form, "Cadera cm", self.hip)
        self._row(form, "Largo falda cm", self.length)
        self._row(form, "Holgura cm", self.ease)

        ctk.CTkButton(self, text="Generar SVG", command=self.generate_svg).pack(pady=20)

        self.output_label = ctk.CTkLabel(self, text="Salida: pendiente")
        self.output_label.pack(pady=10)

    def _row(self, parent: ctk.CTkFrame, label: str, variable: ctk.StringVar) -> None:
        row = ctk.CTkFrame(parent)
        row.pack(fill="x", padx=10, pady=8)
        ctk.CTkLabel(row, text=label, width=160, anchor="w").pack(side="left")
        ctk.CTkEntry(row, textvariable=variable).pack(side="right", fill="x", expand=True)

    def generate_svg(self) -> None:
        try:
            measurements = BodyMeasurements(
                waist=float(self.waist.get()),
                hip=float(self.hip.get()),
                skirt_length=float(self.length.get()),
                ease=float(self.ease.get()),
            )
            pieces = BasicSkirtDraft(measurements).draft()
            output = export_svg(pieces, PROJECT_ROOT / "exports/svg/falda_basica_gui.svg")
        except Exception as exc:
            messagebox.showerror("Error", str(exc))
            return

        self.output_label.configure(text=f"Salida: {output}")
        messagebox.showinfo("OK", f"SVG generado:\n{output}")


def main() -> None:
    app = MotorPatronajeApp()
    app.mainloop()


if __name__ == "__main__":
    main()
