from __future__ import annotations
import tkinter as tk
"""Universal CustomTkinter main window with controlled pattern editor MVP."""


import tkinter.messagebox as messagebox
from pathlib import Path

try:
    import customtkinter as ctk
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Falta customtkinter. Ejecuta: python3 -m pip install -r requirements.txt") from exc

from app.gui.pattern_canvas import ReadOnlyPatternCanvas

from app.controllers.pattern_editor_controller import (
    EditorPatternState,
    apply_editor_operation,
    build_move_point_operation,
    export_editor_variant,
    list_piece_names,
    list_point_names,
    load_editor_pattern,
    save_variant_json,
)
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
    """GUI connected to generation, export and controlled editable variants."""

    def __init__(self) -> None:
        super().__init__()

        self.title("VirinoSoftware - Patronaje 2D")
        self.geometry("1280x900")

        ctk.set_appearance_mode("System")
        ctk.set_default_color_theme("blue")

        self.garment_options = get_garment_options()
        self.garment_by_label = {
            f"{item.code} - {item.name}": item
            for item in self.garment_options
        }
        self.measurement_entries: dict[str, ctk.CTkEntry] = {}
        self.pattern_name_var = ctk.StringVar(value="")
        self.variant_name_var = ctk.StringVar(value="variante_usuario_001")
        self.editor_piece_var = ctk.StringVar(value="")
        self.editor_point_var = ctk.StringVar(value="")
        self.editor_dx_var = ctk.StringVar(value="0")
        self.editor_dy_var = ctk.StringVar(value="0")
        self.editor_state: EditorPatternState | None = None

        self._build_layout()

        if self.garment_by_label:
            first_label = next(iter(self.garment_by_label))
            self.garment_var.set(first_label)
            self._refresh_measurements()

    def _build_layout(self) -> None:
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        title = ctk.CTkLabel(
            self,
            text="VirinoSoftware - Patronaje 2D",
            font=ctk.CTkFont(size=22, weight="bold"),
        )
        title.grid(row=0, column=0, padx=20, pady=(20, 4), sticky="w")

        subtitle = ctk.CTkLabel(
            self,
            text="Generacion, exportacion y transformacion controlada de patrones",
        )
        subtitle.grid(row=1, column=0, padx=20, pady=(0, 10), sticky="w")

        self.main_tabs = ctk.CTkTabview(self)
        self.main_tabs.grid(row=2, column=0, padx=20, pady=(10, 20), sticky="nsew")

        self.editor_tab = self.main_tabs.add("Generacion / Editor")
        self.pattern_tab = self.main_tabs.add("Vista patron")

        self.editor_tab.grid_columnconfigure(0, weight=1)
        self.editor_tab.grid_rowconfigure(5, weight=1)
        self.pattern_tab.grid_columnconfigure(0, weight=1)
        self.pattern_tab.grid_rowconfigure(0, weight=1)

        selector_frame = ctk.CTkFrame(self.editor_tab)
        selector_frame.grid(row=0, column=0, padx=12, pady=10, sticky="ew")
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

        self.measurements_frame = ctk.CTkFrame(self.editor_tab)
        self.measurements_frame.grid(row=1, column=0, padx=12, pady=10, sticky="ew")
        self.measurements_frame.grid_columnconfigure(1, weight=1)

        actions_frame = ctk.CTkFrame(self.editor_tab)
        actions_frame.grid(row=2, column=0, padx=12, pady=10, sticky="ew")
        actions_frame.grid_columnconfigure((0, 1), weight=1)

        ctk.CTkButton(actions_frame, text="Generar", command=self._on_generate).grid(
            row=0, column=0, padx=12, pady=12, sticky="ew"
        )
        ctk.CTkButton(actions_frame, text="Exportar SVG/DXF/PDF", command=self._on_export).grid(
            row=0, column=1, padx=12, pady=12, sticky="ew"
        )

        self.editor_frame = ctk.CTkFrame(self.editor_tab)
        self.editor_frame.grid(row=3, column=0, padx=12, pady=10, sticky="ew")
        self.editor_frame.grid_columnconfigure((1, 3, 5), weight=1)

        ctk.CTkLabel(
            self.editor_frame,
            text="Editor MVP - variante editable sin modificar patron base",
            font=ctk.CTkFont(size=14, weight="bold"),
        ).grid(row=0, column=0, columnspan=6, padx=12, pady=(12, 4), sticky="w")

        ctk.CTkLabel(self.editor_frame, text="Variante").grid(row=1, column=0, padx=12, pady=8, sticky="w")
        ctk.CTkEntry(self.editor_frame, textvariable=self.variant_name_var).grid(row=1, column=1, columnspan=5, padx=12, pady=8, sticky="ew")

        ctk.CTkButton(self.editor_frame, text="Cargar en editor", command=self._on_editor_load).grid(row=2, column=0, padx=12, pady=8, sticky="ew")

        ctk.CTkLabel(self.editor_frame, text="Pieza").grid(row=2, column=1, padx=12, pady=8, sticky="w")
        self.editor_piece_menu = ctk.CTkOptionMenu(
            self.editor_frame,
            variable=self.editor_piece_var,
            values=["Cargar primero"],
            command=lambda _: self._refresh_editor_points(),
        )
        self.editor_piece_menu.grid(row=2, column=2, padx=12, pady=8, sticky="ew")

        ctk.CTkLabel(self.editor_frame, text="Punto").grid(row=2, column=3, padx=12, pady=8, sticky="w")
        self.editor_point_menu = ctk.CTkOptionMenu(
            self.editor_frame,
            variable=self.editor_point_var,
            values=["Cargar primero"],
        )
        self.editor_point_menu.grid(row=2, column=4, padx=12, pady=8, sticky="ew")

        ctk.CTkLabel(self.editor_frame, text="dx cm").grid(row=3, column=0, padx=12, pady=8, sticky="w")
        ctk.CTkEntry(self.editor_frame, textvariable=self.editor_dx_var).grid(row=3, column=1, padx=12, pady=8, sticky="ew")
        ctk.CTkLabel(self.editor_frame, text="dy cm").grid(row=3, column=2, padx=12, pady=8, sticky="w")
        ctk.CTkEntry(self.editor_frame, textvariable=self.editor_dy_var).grid(row=3, column=3, padx=12, pady=8, sticky="ew")

        ctk.CTkButton(self.editor_frame, text="Aplicar move_point", command=self._on_editor_apply_move_point).grid(row=3, column=4, padx=12, pady=8, sticky="ew")
        ctk.CTkButton(self.editor_frame, text="Guardar variante JSON", command=self._on_editor_save_variant).grid(row=4, column=0, columnspan=3, padx=12, pady=8, sticky="ew")
        ctk.CTkButton(self.editor_frame, text="Exportar variante SVG/DXF/PDF", command=self._on_editor_export_variant).grid(row=4, column=3, columnspan=3, padx=12, pady=8, sticky="ew")

        self.output_text = ctk.CTkTextbox(self.editor_tab, height=160)
        self.output_text.grid(row=4, column=0, padx=12, pady=(10, 12), sticky="ew")

        self.pattern_canvas = ReadOnlyPatternCanvas(
            self.pattern_tab,
            height=680,
            on_point_selected=self._on_canvas_point_selected,
            on_point_move_requested=self._on_canvas_point_move_requested,
            keyboard_step_cm=0.5,
        )
        self.pattern_canvas.grid(row=0, column=0, padx=12, pady=12, sticky="nsew")
        self.pattern_canvas.clear()
        self._build_micro_movement_controls()

    def _selected_option(self):
        return self.garment_by_label.get(self.garment_var.get())

    def _refresh_measurements(self) -> None:
        for child in self.measurements_frame.winfo_children():
            child.destroy()

        self.measurement_entries.clear()
        self.editor_state = None
        if hasattr(self, "pattern_canvas"):
            self.pattern_canvas.clear()
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

    def _on_canvas_point_selected(self, piece_name: str, point_name: str) -> None:
        """Synchronize canvas point selection with existing editor controls."""

        self.editor_piece_var.set(piece_name)
        self._refresh_editor_points()
        self.editor_point_var.set(point_name)

        self.output_text.delete("1.0", "end")
        self.output_text.insert(
            "1.0",
            "\n".join(
                [
                    "SELECCION VISUAL OK",
                    f"PIEZA: {piece_name}",
                    f"PUNTO: {point_name}",
                    "",
                    "Fase 43B solo selecciona puntos.",
                    "El movimiento visual corresponde a Fase 43C.",
                ]
            ),
        )

    def _on_canvas_point_move_requested(self, piece_name: str, point_name: str, dx: float, dy: float) -> None:
        """Apply keyboard point movement through the transformation contract."""

        if self.editor_state is None:
            return

        try:
            self.editor_piece_var.set(piece_name)
            self._refresh_editor_points()
            self.editor_point_var.set(point_name)
            self.editor_dx_var.set(str(dx))
            self.editor_dy_var.set(str(dy))

            operation = build_move_point_operation(
                piece=piece_name,
                point=point_name,
                dx=float(dx),
                dy=float(dy),
            )
            self.editor_state = apply_editor_operation(self.editor_state, operation)

            self.pattern_canvas.draw_pattern(self.editor_state.pieces)
            self.main_tabs.set("Vista patron")

            self.output_text.delete("1.0", "end")
            self.output_text.insert(
                "1.0",
                "\n".join(
                    [
                        "MOVIMIENTO VISUAL OK",
                        f"PIEZA: {piece_name}",
                        f"PUNTO: {point_name}",
                        f"DX_CM: {dx}",
                        f"DY_CM: {dy}",
                        "",
                        "Operacion registrada como transformacion no destructiva.",
                        "El patron base no se modifica.",
                    ]
                ),
            )
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error de movimiento visual", str(exc))

    def _write_output(self, lines: list[str]) -> None:
        self.output_text.delete("1.0", "end")
        self.output_text.insert("1.0", "\n".join(lines))
        if hasattr(self, "pattern_canvas") and self.editor_state is not None:
            self.pattern_canvas.draw_pattern(self.editor_state.pieces)
            if hasattr(self, "main_tabs"):
                self.main_tabs.set("Vista patron")

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
                    "Use Cargar en editor para crear una variante editable.",
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

    def _refresh_editor_points(self) -> None:
        if self.editor_state is None:
            return
        points = list_point_names(self.editor_state, self.editor_piece_var.get())
        values = points or ["Sin puntos"]
        self.editor_point_menu.configure(values=values)
        self.editor_point_var.set(values[0])

    def _on_editor_load(self) -> None:
        try:
            option = self._selected_option()
            if option is None:
                raise ValueError("No hay prenda seleccionada.")
            self.editor_state = load_editor_pattern(
                garment_code=option.code,
                measurements=self._read_measurements(),
                variant_name=self.variant_name_var.get().strip() or "variante_usuario_001",
            )
            pieces = list_piece_names(self.editor_state)
            values = pieces or ["Sin piezas"]
            self.editor_piece_menu.configure(values=values)
            self.editor_piece_var.set(values[0])
            self._refresh_editor_points()
            self._write_output([
                "EDITOR OK",
                f"Patron base cargado: {self.editor_state.garment_code}",
                f"Variante: {self.editor_state.variant.variant_name}",
                f"Piezas: {', '.join(pieces)}",
                "",
                "Seleccione pieza, punto y dx/dy para aplicar move_point.",
            ])
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error editor", str(exc))

    def _on_editor_apply_move_point(self) -> None:
        try:
            if self.editor_state is None:
                raise ValueError("Primero cargue el patron en el editor.")
            operation = build_move_point_operation(
                piece=self.editor_piece_var.get(),
                point=self.editor_point_var.get(),
                dx=float(self.editor_dx_var.get().replace(",", ".")),
                dy=float(self.editor_dy_var.get().replace(",", ".")),
            )
            self.editor_state = apply_editor_operation(self.editor_state, operation)
            self._write_output([
                "TRANSFORMACION OK",
                f"Operacion: {operation.type}",
                f"Pieza: {operation.piece}",
                f"Punto: {operation.point}",
                f"dx: {operation.dx} cm",
                f"dy: {operation.dy} cm",
                f"Historial operaciones: {len(self.editor_state.variant.transformations)}",
            ])
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error transformacion", str(exc))

    def _on_editor_save_variant(self) -> None:
        try:
            if self.editor_state is None:
                raise ValueError("Primero cargue el patron en el editor.")
            path = save_variant_json(self.editor_state)
            self._write_output([
                "VARIANTE JSON OK",
                f"Archivo: {path.resolve()}",
                f"Operaciones: {len(self.editor_state.variant.transformations)}",
            ])
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error guardar variante", str(exc))

    def _on_editor_export_variant(self) -> None:
        try:
            if self.editor_state is None:
                raise ValueError("Primero cargue el patron en el editor.")
            output_name = build_output_name(self.editor_state.garment_code, self.editor_state.variant.variant_name)
            summary = export_editor_variant(self.editor_state, output_name=output_name)
            lines = [
                "EXPORTACION VARIANTE OK",
                f"JSON: {summary.variant_json_path.resolve()}",
            ]
            for label, path in (("SVG", summary.svg_path), ("DXF", summary.dxf_path), ("PDF", summary.pdf_path)):
                if path:
                    lines.append(f"{label}: {path.resolve()}")
            self._write_output(lines)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Error exportar variante", str(exc))

    # ---- Fase 44B: micro movement controls ----
    def _build_micro_movement_controls(self):
        self.micro_move_step_var = tk.StringVar(value="0.5")
        self.selected_point_summary_var = tk.StringVar(
            value=_fase44a_build_selection_summary(None, 0.5)
        )

        self.micro_move_frame = ctk.CTkFrame(self.pattern_tab)
        self.micro_move_frame.grid(row=1, column=0, padx=12, pady=(0, 12), sticky="ew")
        self.micro_move_frame.grid_columnconfigure(3, weight=1)
        self.active_variant_feedback_var = tk.StringVar(
            value=_fase44c_build_variant_feedback(False)
        )

        ctk.CTkLabel(
            self.micro_move_frame,
            text="Micro-movimiento del punto seleccionado",
        ).grid(row=0, column=0, columnspan=8, padx=8, pady=(8, 4), sticky="w")

        ctk.CTkLabel(self.micro_move_frame, text="Paso").grid(
            row=1, column=0, padx=(8, 4), pady=4, sticky="w"
        )

        self.micro_move_step_selector = ctk.CTkOptionMenu(
            self.micro_move_frame,
            values=list(_fase44b_step_values()),
            variable=self.micro_move_step_var,
            command=lambda _value: self._refresh_selected_point_summary(),
        )
        self.micro_move_step_selector.grid(row=1, column=1, padx=4, pady=4, sticky="w")

        ctk.CTkLabel(self.micro_move_frame, text="cm").grid(
            row=1, column=2, padx=(0, 8), pady=4, sticky="w"
        )

        self.micro_move_left_button = ctk.CTkButton(
            self.micro_move_frame,
            text="Izq",
            width=56,
            command=lambda: self._move_selected_point_micro("left"),
        )
        self.micro_move_left_button.grid(row=1, column=4, padx=3, pady=4)

        self.micro_move_right_button = ctk.CTkButton(
            self.micro_move_frame,
            text="Der",
            width=56,
            command=lambda: self._move_selected_point_micro("right"),
        )
        self.micro_move_right_button.grid(row=1, column=5, padx=3, pady=4)

        self.micro_move_up_button = ctk.CTkButton(
            self.micro_move_frame,
            text="Arriba",
            width=70,
            command=lambda: self._move_selected_point_micro("up"),
        )
        self.micro_move_up_button.grid(row=1, column=6, padx=3, pady=4)

        self.micro_move_down_button = ctk.CTkButton(
            self.micro_move_frame,
            text="Abajo",
            width=70,
            command=lambda: self._move_selected_point_micro("down"),
        )
        self.micro_move_down_button.grid(row=1, column=7, padx=3, pady=4)

        self.micro_move_reset_button = ctk.CTkButton(
            self.micro_move_frame,
            text="Restaurar punto",
            width=120,
            command=self._reset_selected_point_micro,
        )
        self.micro_move_reset_button.grid(row=1, column=8, padx=(3, 8), pady=4)

        self.selected_point_summary_label = ctk.CTkLabel(
            self.micro_move_frame,
            textvariable=self.selected_point_summary_var,
            anchor="w",
        )
        self.selected_point_summary_label.grid(
            row=2, column=0, columnspan=9, padx=8, pady=(4, 2), sticky="ew"
        )

        self.active_variant_feedback_label = ctk.CTkLabel(
            self.micro_move_frame,
            textvariable=self.active_variant_feedback_var,
            anchor="w",
        )
        self.active_variant_feedback_label.grid(
            row=3, column=0, columnspan=9, padx=8, pady=(2, 8), sticky="ew"
        )

    def _get_selected_step_cm(self) -> float:
        return _fase44b_normalize_step(self.micro_move_step_var.get())

    def _refresh_selected_point_summary(self):
        selection_info = _fase44a_get_canvas_selection_info(self.pattern_canvas)
        summary = _fase44a_build_selection_summary(
            selection_info,
            step_cm=self._get_selected_step_cm(),
        )
        self.selected_point_summary_var.set(summary)
        return summary

    def _move_selected_point_micro(self, direction: str) -> bool:
        deltas = _fase44b_build_move_deltas(self._get_selected_step_cm())
        if direction not in deltas:
            return False

        dx, dy = deltas[direction]
        moved = self.pattern_canvas.move_selected_point_by(dx, dy)
        self._refresh_selected_point_summary()
        if moved:
            self._mark_active_variant_dirty("Punto movido")
        return moved


    # ---- Fase 44C: reset and active variant feedback ----
    def _mark_active_variant_dirty(self, reason: str = "Cambios pendientes"):
        self.active_variant_feedback_var.set(
            _fase44c_build_variant_feedback(True, reason=reason)
        )

    def _mark_active_variant_clean(self):
        self.active_variant_feedback_var.set(_fase44c_build_variant_feedback(False))

    def _reset_selected_point_micro(self) -> bool:
        restored = self.pattern_canvas.reset_selected_point_to_baseline()
        self._refresh_selected_point_summary()
        self.active_variant_feedback_var.set(_fase44c_build_reset_result_message(restored))
        return restored

    # ---- End Fase 44C ----

    # ---- End Fase 44B ----


# ---- Fase 44A helpers: selected point usability panel ----
def _fase44a_format_coordinate(value):
    if value is None or value == "":
        return "-"
    try:
        return f"{float(value):.2f} cm"
    except (TypeError, ValueError):
        return str(value)


def _fase44a_get_canvas_selection_info(canvas):
    if canvas is None:
        return {
            "has_selection": False,
            "piece_name": "",
            "point_id": "",
            "human_name": "Sin punto seleccionado",
            "x": None,
            "y": None,
        }
    getter = getattr(canvas, "get_selected_point_info", None)
    if callable(getter):
        return getter()
    return {
        "has_selection": False,
        "piece_name": "",
        "point_id": "",
        "human_name": "Sin punto seleccionado",
        "x": None,
        "y": None,
    }


def _fase44a_build_selection_summary(selection_info, step_cm=0.5):
    if not selection_info or not selection_info.get("has_selection"):
        return "Punto seleccionado: ninguno | Paso: %.1f cm" % float(step_cm)
    return (
        f"Pieza: {selection_info.get('piece_name') or '-'} | "
        f"Punto: {selection_info.get('human_name') or selection_info.get('point_id') or '-'} | "
        f"Tecnico: {selection_info.get('point_id') or '-'} | "
        f"X: {_fase44a_format_coordinate(selection_info.get('x'))} | "
        f"Y: {_fase44a_format_coordinate(selection_info.get('y'))} | "
        f"Paso: {float(step_cm):.1f} cm"
    )

# ---- Fase 44B GUI helpers ----
def _fase44b_step_values():
    return ("0.1", "0.5", "1.0")


def _fase44b_normalize_step(value, default=0.5):
    try:
        step = float(value)
    except (TypeError, ValueError):
        return float(default)
    if step in (0.1, 0.5, 1.0):
        return step
    return float(default)


def _fase44b_build_move_deltas(step_cm):
    step = _fase44b_normalize_step(step_cm)
    return {
        "left": (-step, 0.0),
        "right": (step, 0.0),
        "up": (0.0, -step),
        "down": (0.0, step),
    }

# ---- End Fase 44B GUI helpers ----


# ---- Fase 44C GUI helpers ----
def _fase44c_build_variant_feedback(is_dirty, reason="Cambios pendientes"):
    if is_dirty:
        return f"Variante activa: con cambios sin guardar ({reason})."
    return "Variante activa: sin cambios pendientes."


def _fase44c_build_reset_result_message(restored):
    if restored:
        return "Variante activa: punto restaurado; hay cambios sin guardar."
    return "Variante activa: no hay punto seleccionado o no existe movimiento para restaurar."

# ---- End Fase 44C GUI helpers ----
