from __future__ import annotations

from pathlib import Path
from tkinter import messagebox

try:
    import customtkinter as ctk
except ImportError as exc:
    raise SystemExit("Falta customtkinter. Ejecuta: python3 -m pip install -r requirements.txt") from exc

from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.logging.config import configure_logging
from engine.measurements.body import BodyMeasurements
from engine.measurements.validation import MeasurementValidationError
from engine.reports.pattern_report import generate_pattern_report

PROJECT_ROOT = Path(__file__).resolve().parents[1]
configure_logging(PROJECT_ROOT)


class MotorPatronajeApp(ctk.CTk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Motor Patronaje 2D - MVP")
        self.geometry("560x460")

        self.waist = ctk.StringVar(value="72")
        self.hip = ctk.StringVar(value="98")
        self.length = ctk.StringVar(value="60")
        self.ease = ctk.StringVar(value="2")

        ctk.CTkLabel(self, text="Falda basica MVP", font=("Arial", 22)).pack(pady=20)
        ctk.CTkLabel(self, text="Unidad oficial: centimetros (cm)").pack(pady=4)

        form = ctk.CTkFrame(self)
        form.pack(padx=20, pady=10, fill="x")

        self._row(form, "Cintura cm", self.waist)
        self._row(form, "Cadera cm", self.hip)
        self._row(form, "Largo falda cm", self.length)
        self._row(form, "Holgura cm", self.ease)

        ctk.CTkButton(self, text="Generar SVG + reporte", command=self.generate_svg).pack(pady=20)

        self.output_label = ctk.CTkLabel(self, text="Salida: pendiente")
        self.output_label.pack(pady=10)

    def _row(self, parent: ctk.CTkFrame, label: str, variable: ctk.StringVar) -> None:
        row = ctk.CTkFrame(parent)
        row.pack(fill="x", padx=10, pady=8)
        ctk.CTkLabel(row, text=label, width=170, anchor="w").pack(side="left")
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
            svg_output = export_svg(pieces, PROJECT_ROOT / "exports/svg/falda_basica_gui.svg")
            report_output = generate_pattern_report(
                pieces=pieces,
                measurements=measurements,
                output_path=PROJECT_ROOT / "reports/falda_basica_gui_reporte.md",
            )
        except MeasurementValidationError as exc:
            messagebox.showerror("Medidas invalidas", str(exc))
            return
        except Exception as exc:
            messagebox.showerror("Error", str(exc))
            return

        self.output_label.configure(text=f"SVG: {svg_output}")
        messagebox.showinfo("OK", f"SVG generado:\n{svg_output}\n\nReporte:\n{report_output}")


def main() -> None:
    app = MotorPatronajeApp()
    app.mainloop()


if __name__ == "__main__":
    main()
