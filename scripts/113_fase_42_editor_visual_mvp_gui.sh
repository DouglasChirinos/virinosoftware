#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== Fase 42: Editor visual MVP en GUI con transformaciones controladas =='
printf '%s\n' '== Alcance =='
printf '%s\n' '- Cargar patron generado en canvas/resumen GUI.'
printf '%s\n' '- Seleccionar pieza y punto.'
printf '%s\n' '- Mover punto con dx/dy.'
printf '%s\n' '- Guardar variante JSON sin modificar patron base.'
printf '%s\n' '- Exportar variante transformada SVG/DXF/PDF.'

if [ ! -d app ] || [ ! -d engine ]; then
  printf '%s\n' 'ERROR: ejecuta este script desde la raiz del proyecto /home/antares/Proyecto/motor'
  exit 1
fi

printf '%s\n' '== Estado Git antes del cambio =='
git status --short || true

mkdir -p engine/transformations app/controllers docs tests

cat > engine/transformations/operations.py <<'PY'
"""Editable transformation contracts for pattern variants.

The base generated pattern must remain immutable from the user's perspective.
Every transformation is stored as an operation that can be replayed over a fresh
copy of the generated pattern.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Literal

TransformType = Literal["move_point", "move_line", "scale_line", "adjust_curve"]


@dataclass(frozen=True)
class TransformOperation:
    """Single editable transformation requested by the user."""

    type: TransformType
    piece: str
    dx: float = 0.0
    dy: float = 0.0
    point: str | None = None
    line: str | None = None
    curve: str | None = None
    factor: float = 1.0
    control_delta: dict[str, float] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        return {key: value for key, value in data.items() if value not in (None, {}, 0.0) or key in {"type", "piece"}}


@dataclass(frozen=True)
class PatternVariant:
    """Editable variant metadata and transformation history."""

    pattern_id: str
    base_garment: str
    variant_name: str
    transformations: tuple[TransformOperation, ...] = ()
    measurements: dict[str, Any] = field(default_factory=dict)

    def append(self, operation: TransformOperation) -> "PatternVariant":
        return PatternVariant(
            pattern_id=self.pattern_id,
            base_garment=self.base_garment,
            variant_name=self.variant_name,
            transformations=(*self.transformations, operation),
            measurements=dict(self.measurements),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "pattern_id": self.pattern_id,
            "base_garment": self.base_garment,
            "variant_name": self.variant_name,
            "measurements": dict(self.measurements),
            "transformations": [operation.to_dict() for operation in self.transformations],
        }
PY

cat > engine/transformations/apply.py <<'PY'
"""Apply editable transformations over pattern-piece copies."""

from __future__ import annotations

import copy
from dataclasses import replace
from types import SimpleNamespace
from typing import Any, Iterable

from engine.geometry.point import Point
from engine.transformations.operations import PatternVariant, TransformOperation


def _line_label(line: Any) -> str:
    return str(getattr(line, "name", getattr(line, "label", "")) or "")


def _line_kind(line: Any) -> str:
    return str(getattr(line, "kind", "pattern") or "pattern")


def _make_line_like(line: Any, start: Point, end: Point) -> Any:
    label = _line_label(line)
    kind = _line_kind(line)
    if hasattr(line, "__dataclass_fields__"):
        try:
            field_names = set(line.__dataclass_fields__.keys())
            kwargs = {"start": start, "end": end}
            if "label" in field_names:
                kwargs["label"] = label
            if "name" in field_names:
                kwargs["name"] = label
            if "kind" in field_names:
                kwargs["kind"] = kind
            return line.__class__(**kwargs)
        except Exception:  # noqa: BLE001 - fallback below keeps compatibility
            pass
    return SimpleNamespace(start=start, end=end, name=label, label=label, kind=kind)


def _find_piece(pieces: list[Any], piece_name: str) -> Any:
    for piece in pieces:
        if getattr(piece, "name", "") == piece_name:
            return piece
    raise ValueError(f"Pieza no encontrada: {piece_name}")


def _point_matches(point: Point, old: Point) -> bool:
    return abs(float(point.x) - float(old.x)) < 1e-9 and abs(float(point.y) - float(old.y)) < 1e-9


def _move_point(piece: Any, point_name: str, dx: float, dy: float) -> None:
    if point_name not in piece.points:
        raise ValueError(f"Punto no encontrado en {piece.name}: {point_name}")

    old_point = piece.points[point_name]
    new_point = old_point.translate(dx=dx, dy=dy)
    piece.points[point_name] = new_point

    updated_lines = []
    for line in piece.lines:
        start = new_point if _point_matches(line.start, old_point) else line.start
        end = new_point if _point_matches(line.end, old_point) else line.end
        updated_lines.append(_make_line_like(line, start, end))
    piece.lines = updated_lines


def _move_line(piece: Any, line_name: str, dx: float, dy: float) -> None:
    updated_lines = []
    found = False
    for line in piece.lines:
        if _line_label(line) == line_name:
            found = True
            updated_lines.append(
                _make_line_like(
                    line,
                    line.start.translate(dx=dx, dy=dy),
                    line.end.translate(dx=dx, dy=dy),
                )
            )
        else:
            updated_lines.append(line)
    if not found:
        raise ValueError(f"Linea no encontrada en {piece.name}: {line_name}")
    piece.lines = updated_lines


def _scale_line(piece: Any, line_name: str, factor: float) -> None:
    if factor <= 0:
        raise ValueError("factor debe ser mayor que cero")

    updated_lines = []
    found = False
    for line in piece.lines:
        if _line_label(line) == line_name:
            found = True
            sx = float(line.start.x)
            sy = float(line.start.y)
            ex = sx + (float(line.end.x) - sx) * factor
            ey = sy + (float(line.end.y) - sy) * factor
            updated_lines.append(_make_line_like(line, line.start, Point(ex, ey)))
        else:
            updated_lines.append(line)
    if not found:
        raise ValueError(f"Linea no encontrada en {piece.name}: {line_name}")
    piece.lines = updated_lines


def _adjust_curve(piece: Any, curve_name: str, control_delta: dict[str, float]) -> None:
    curves = list(getattr(piece, "curves", []) or [])
    structural = list(getattr(piece, "metadata", {}).get("structural_curves", []) or [])

    updated = False
    for curve in structural:
        if str(curve.get("name", curve.get("label", curve.get("intent", "")))) == curve_name or str(curve.get("intent", "")) == curve_name:
            for key, value in control_delta.items():
                curve[key] = float(curve.get(key, 0.0)) + float(value)
            updated = True

    if not updated and curves:
        # Generic fallback for future BezierCurve entities.
        for index, curve in enumerate(curves):
            label = str(getattr(curve, "name", getattr(curve, "label", f"curve_{index}")) or f"curve_{index}")
            if label == curve_name:
                for attr, dx_key, dy_key in (("control1", "c1_dx", "c1_dy"), ("control2", "c2_dx", "c2_dy")):
                    point = getattr(curve, attr, None)
                    if point is not None:
                        setattr(curve, attr, point.translate(dx=float(control_delta.get(dx_key, 0.0)), dy=float(control_delta.get(dy_key, 0.0))))
                updated = True
                break

    if not updated:
        raise ValueError(f"Curva no encontrada en {piece.name}: {curve_name}")


def apply_transformations(pieces: Iterable[Any], transformations: Iterable[TransformOperation] | PatternVariant) -> list[Any]:
    """Return transformed deep copies of the given pieces."""

    transformed = copy.deepcopy(list(pieces))
    operations: Iterable[TransformOperation]

    if isinstance(transformations, PatternVariant):
        operations = transformations.transformations
    else:
        operations = transformations

    for operation in operations:
        piece = _find_piece(transformed, operation.piece)

        if operation.type == "move_point":
            if not operation.point:
                raise ValueError("move_point requiere point")
            _move_point(piece, operation.point, operation.dx, operation.dy)
        elif operation.type == "move_line":
            if not operation.line:
                raise ValueError("move_line requiere line")
            _move_line(piece, operation.line, operation.dx, operation.dy)
        elif operation.type == "scale_line":
            if not operation.line:
                raise ValueError("scale_line requiere line")
            _scale_line(piece, operation.line, operation.factor)
        elif operation.type == "adjust_curve":
            if not operation.curve:
                raise ValueError("adjust_curve requiere curve")
            _adjust_curve(piece, operation.curve, operation.control_delta)
        else:
            raise ValueError(f"Operacion no soportada: {operation.type}")

    return transformed
PY

cat > engine/transformations/__init__.py <<'PY'
"""Editable pattern transformation API."""

from engine.transformations.apply import apply_transformations
from engine.transformations.operations import PatternVariant, TransformOperation

__all__ = ["PatternVariant", "TransformOperation", "apply_transformations"]
PY

cat > app/controllers/pattern_editor_controller.py <<'PY'
"""Controller for the visual pattern editor MVP.

This layer deliberately uses controlled numeric transformations instead of
free drag-and-drop. That gives traceability, reproducibility and avoids
corrupting the generated base pattern.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.exports.structural_curves import attach_structural_curves
from engine.exports.visual_curves import attach_visual_curves
from engine.generation.exporter import (
    _arrange_pieces_for_export,
    _attach_export_metadata,
    _safe_output_name,
    normalize_pieces,
)
from engine.generation.pattern_generator import PatternGenerationRequest, PatternGenerationResult, generate_pattern
from engine.transformations import PatternVariant, TransformOperation, apply_transformations

from app.controllers.universal_pattern_controller import build_generation_options, slugify_output_name


@dataclass(frozen=True)
class EditorPatternState:
    garment_code: str
    garment_name: str
    measurements: dict[str, Any]
    pieces: list[Any]
    variant: PatternVariant
    generation_result: PatternGenerationResult


@dataclass(frozen=True)
class EditorExportSummary:
    variant_json_path: Path
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None


def _timestamp() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def _pattern_id(garment_code: str) -> str:
    return f"{slugify_output_name(garment_code)}_{_timestamp()}"


def _normalized_export_pieces(generation_result: PatternGenerationResult) -> list[Any]:
    pieces = normalize_pieces(generation_result.pieces)
    _arrange_pieces_for_export(pieces)
    _attach_export_metadata(pieces, generation_result)
    attach_structural_curves(pieces, generation_result.garment_code)
    attach_visual_curves(pieces, generation_result.garment_code)
    return pieces


def load_editor_pattern(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    variant_name: str | None = None,
) -> EditorPatternState:
    """Generate a base pattern and open a non-destructive editable variant."""

    generation_result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options=build_generation_options(garment_code),
        )
    )
    variant = PatternVariant(
        pattern_id=_pattern_id(garment_code),
        base_garment=garment_code,
        variant_name=variant_name or f"Variante {generation_result.garment_name}",
        transformations=(),
        measurements=dict(measurements),
    )
    return EditorPatternState(
        garment_code=generation_result.garment_code,
        garment_name=generation_result.garment_name,
        measurements=dict(measurements),
        pieces=_normalized_export_pieces(generation_result),
        variant=variant,
        generation_result=generation_result,
    )


def list_piece_names(state: EditorPatternState) -> list[str]:
    return [piece.name for piece in state.pieces]


def list_point_names(state: EditorPatternState, piece_name: str) -> list[str]:
    for piece in state.pieces:
        if piece.name == piece_name:
            return sorted(piece.points.keys())
    return []


def build_move_point_operation(*, piece: str, point: str, dx: float, dy: float) -> TransformOperation:
    return TransformOperation(type="move_point", piece=piece, point=point, dx=float(dx), dy=float(dy))


def apply_editor_operation(state: EditorPatternState, operation: TransformOperation) -> EditorPatternState:
    """Return a new editor state with operation appended and applied."""

    new_variant = state.variant.append(operation)
    transformed_pieces = apply_transformations(state.pieces, new_variant.transformations)
    return EditorPatternState(
        garment_code=state.garment_code,
        garment_name=state.garment_name,
        measurements=dict(state.measurements),
        pieces=transformed_pieces,
        variant=new_variant,
        generation_result=state.generation_result,
    )


def save_variant_json(state: EditorPatternState, output_dir: Path | str = Path("variants")) -> Path:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    safe_name = _safe_output_name(f"{state.variant.base_garment}_{slugify_output_name(state.variant.variant_name)}_{_timestamp()}")
    path = output_dir / f"{safe_name}.json"
    path.write_text(json.dumps(state.variant.to_dict(), ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def export_editor_variant(
    state: EditorPatternState,
    *,
    output_name: str | None = None,
    output_dir: Path | str = Path("exports"),
    export_svg_enabled: bool = True,
    export_dxf_enabled: bool = True,
    export_pdf_enabled: bool = True,
) -> EditorExportSummary:
    """Save transformation JSON and export transformed pieces."""

    output_dir = Path(output_dir)
    variant_json_path = save_variant_json(state, output_dir=Path("variants"))
    safe_name = _safe_output_name(output_name or f"{state.variant.base_garment}_{slugify_output_name(state.variant.variant_name)}_{_timestamp()}")

    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    if export_svg_enabled:
        svg_path = output_dir / "svg" / f"{safe_name}.svg"
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        export_svg(state.pieces, svg_path)

    if export_dxf_enabled:
        dxf_path = output_dir / "dxf" / f"{safe_name}.dxf"
        dxf_path.parent.mkdir(parents=True, exist_ok=True)
        export_dxf(state.pieces, dxf_path)

    if export_pdf_enabled:
        pdf_path = output_dir / "pdf" / f"{safe_name}.pdf"
        pdf_path.parent.mkdir(parents=True, exist_ok=True)
        export_pdf(state.pieces, pdf_path)

    return EditorExportSummary(variant_json_path=variant_json_path, svg_path=svg_path, dxf_path=dxf_path, pdf_path=pdf_path)
PY

cat > app/gui/universal_main_window.py <<'PY'
"""Universal CustomTkinter main window with controlled pattern editor MVP."""

from __future__ import annotations

import tkinter.messagebox as messagebox
from pathlib import Path

try:
    import customtkinter as ctk
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Falta customtkinter. Ejecuta: python3 -m pip install -r requirements.txt") from exc

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
        self.geometry("980x760")

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
        self.grid_rowconfigure(6, weight=1)

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

        self.editor_frame = ctk.CTkFrame(self)
        self.editor_frame.grid(row=5, column=0, padx=20, pady=10, sticky="ew")
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

        self.output_text = ctk.CTkTextbox(self, height=220)
        self.output_text.grid(row=6, column=0, padx=20, pady=(10, 20), sticky="nsew")

    def _selected_option(self):
        return self.garment_by_label.get(self.garment_var.get())

    def _refresh_measurements(self) -> None:
        for child in self.measurements_frame.winfo_children():
            child.destroy()

        self.measurement_entries.clear()
        self.editor_state = None
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
PY

cat > tests/test_fase_42_editor_visual_mvp_gui.py <<'PY'
from __future__ import annotations

import json
from pathlib import Path

from app.controllers.pattern_editor_controller import (
    apply_editor_operation,
    build_move_point_operation,
    export_editor_variant,
    list_piece_names,
    list_point_names,
    load_editor_pattern,
    save_variant_json,
)


def test_editor_loads_pattern_with_piece_and_point_options() -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Prueba editor",
    )

    pieces = list_piece_names(state)
    assert "Falda evase delantera" in pieces
    assert "Falda evase posterior" in pieces
    assert list_point_names(state, "Falda evase delantera")


def test_move_point_operation_does_not_mutate_base_pattern() -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Mover punto",
    )
    piece_name = "Falda evase delantera"
    point_name = list_point_names(state, piece_name)[0]
    base_piece = next(piece for piece in state.pieces if piece.name == piece_name)
    base_point = base_piece.points[point_name]

    operation = build_move_point_operation(piece=piece_name, point=point_name, dx=2.5, dy=-1.0)
    new_state = apply_editor_operation(state, operation)
    new_piece = next(piece for piece in new_state.pieces if piece.name == piece_name)

    assert base_piece.points[point_name] == base_point
    assert new_piece.points[point_name].x == base_point.x + 2.5
    assert new_piece.points[point_name].y == base_point.y - 1.0
    assert len(new_state.variant.transformations) == 1


def test_variant_json_saves_transformation_history(tmp_path: Path) -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Historial",
    )
    operation = build_move_point_operation(piece="Falda evase delantera", point="A", dx=1, dy=0)
    new_state = apply_editor_operation(state, operation)

    path = save_variant_json(new_state, output_dir=tmp_path)
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["base_garment"] == "falda_evase"
    assert payload["variant_name"] == "Historial"
    assert payload["transformations"][0]["type"] == "move_point"
    assert payload["transformations"][0]["point"] == "A"


def test_editor_exports_transformed_variant(tmp_path: Path) -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Exportar variante",
    )
    operation = build_move_point_operation(piece="Falda evase delantera", point="A", dx=1, dy=0)
    new_state = apply_editor_operation(state, operation)

    summary = export_editor_variant(
        new_state,
        output_name="fase42_editor_variant_test",
        output_dir=tmp_path / "exports",
        export_svg_enabled=True,
        export_dxf_enabled=False,
        export_pdf_enabled=False,
    )

    assert summary.variant_json_path.exists()
    assert summary.svg_path is not None
    assert summary.svg_path.exists()
    assert "<svg" in summary.svg_path.read_text(encoding="utf-8")


def test_universal_gui_source_exposes_editor_controls() -> None:
    source = Path("app/gui/universal_main_window.py").read_text(encoding="utf-8")

    assert "Cargar en editor" in source
    assert "Aplicar move_point" in source
    assert "Guardar variante JSON" in source
    assert "Exportar variante SVG/DXF/PDF" in source
PY

cat > docs/65_Fase_42_Editor_Visual_MVP_GUI.md <<'MD'
# Fase 42 - Editor visual MVP en GUI

## Objetivo

Convertir el flujo de generacion en un flujo de patronaje asistido:

```text
Generar patron base -> crear variante editable -> aplicar transformaciones -> guardar historial -> exportar variante
```

## Decision de alcance

No se implementa un CAD completo ni drag-and-drop libre en esta fase. La primera version usa campos controlados `dx/dy` para mover puntos seleccionados. Esto reduce errores, mantiene trazabilidad y permite validar el contrato de transformaciones antes de agregar interaccion directa con mouse.

## Capacidades implementadas

- Cargar un patron generado en el editor.
- Seleccionar pieza.
- Seleccionar punto.
- Aplicar `move_point` con `dx/dy` en centimetros.
- Guardar variante JSON.
- Exportar variante transformada en SVG/DXF/PDF.
- Mantener intacto el patron base.

## Regla clave

El patron generado por medidas no se modifica directamente. El usuario trabaja sobre una variante editable con historial de operaciones.

```text
patron_base
  -> variante_usuario_001
  -> variante_usuario_002
```

## Archivos principales

- `engine/transformations/operations.py`
- `engine/transformations/apply.py`
- `app/controllers/pattern_editor_controller.py`
- `app/gui/universal_main_window.py`
- `tests/test_fase_42_editor_visual_mvp_gui.py`

## Limitaciones deliberadas

- Sin drag-and-drop con mouse todavia.
- Sin seleccion grafica real sobre canvas todavia.
- Sin edicion avanzada de curvas desde GUI en esta fase.
- `move_line`, `scale_line` y `adjust_curve` quedan en contrato backend para fases posteriores de UI.

## Proxima fase recomendada

Fase 42.1 o Fase 43:

- Canvas visual real del patron.
- Seleccion grafica de puntos.
- Preview antes/despues.
- Medidas en vivo por segmento.
- Deshacer/rehacer por historial.
MD

python3 - <<'PY'
from pathlib import Path
path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-fase-42:" not in text:
    text += """

validate-fase-42:
	.venv/bin/python -m pytest tests/test_fase_42_editor_visual_mvp_gui.py -q
"""

path.write_text(text, encoding="utf-8")
PY

printf '%s\n' '== Validacion Fase 42 =='
make validate-fase-42

if grep -q '^validate-fase-41:' Makefile; then
  printf '%s\n' '== Validacion compatibilidad Fase 41 =='
  make validate-fase-41
fi

printf '%s\n' '== Estado Git despues del cambio =='
git status --short || true
printf '%s\n' '== Fase 42 aplicada. Abrir GUI con: make run-gui =='
