"""Interactive read-only/selection pattern canvas for VirinoSoftware.

Fase 43A:
- Render generated pattern pieces in a dedicated GUI canvas.

Fase 43B:
- Select a point visually with mouse click.
- Highlight selected point.
- Notify the main GUI so existing piece/point controls stay synchronized.

No movement, drag-and-drop or CAD editing is implemented here yet.
"""

from __future__ import annotations

import math
import tkinter as tk
from dataclasses import dataclass
from typing import Any, Callable, Iterable

try:
    import customtkinter as ctk
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Falta customtkinter. Ejecuta: python3 -m pip install -r requirements.txt") from exc


PointSelectionCallback = Callable[[str, str], None]
PointMoveCallback = Callable[[str, str, float, float], None]


@dataclass(frozen=True)
class CanvasTransform:
    """Mapping from pattern coordinates in cm to canvas pixels."""

    min_x: float
    min_y: float
    scale: float
    offset_x: float
    offset_y: float
    canvas_height: int


@dataclass(frozen=True)
class CanvasHitPoint:
    """Screen-space selectable point."""

    piece_name: str
    point_name: str
    x: float
    y: float


def _coord(value: Any, attr: str) -> float | None:
    if hasattr(value, attr):
        return float(getattr(value, attr))
    if isinstance(value, dict) and attr in value:
        return float(value[attr])
    return None


def point_xy(point: Any) -> tuple[float, float] | None:
    """Return x/y for point-like values used by the motor."""

    if point is None:
        return None

    x = _coord(point, "x")
    y = _coord(point, "y")
    if x is not None and y is not None:
        return x, y

    if isinstance(point, (tuple, list)) and len(point) >= 2:
        return float(point[0]), float(point[1])

    return None


def _resolve_point(value: Any, points: dict[str, Any]) -> tuple[float, float] | None:
    if isinstance(value, str):
        return point_xy(points.get(value))
    return point_xy(value)


def _iter_piece_points(piece: Any) -> Iterable[tuple[str, float, float]]:
    points = getattr(piece, "points", None)
    if isinstance(points, dict):
        for name, point in points.items():
            xy = point_xy(point)
            if xy is not None:
                yield str(name), xy[0], xy[1]


def iter_pattern_points(pieces: Iterable[Any]) -> Iterable[tuple[str, str, float, float]]:
    """Yield piece name, point name, x, y for all drawable points."""

    for piece in pieces:
        piece_name = str(getattr(piece, "name", "Pieza"))
        for point_name, x, y in _iter_piece_points(piece):
            yield piece_name, point_name, x, y


def get_pattern_bounds(pieces: Iterable[Any]) -> tuple[float, float, float, float]:
    """Return min_x, min_y, max_x, max_y for all points in all pieces."""

    coords = [(x, y) for _, _, x, y in iter_pattern_points(pieces)]
    if not coords:
        return 0.0, 0.0, 1.0, 1.0

    xs = [x for x, _ in coords]
    ys = [y for _, y in coords]
    min_x = min(xs)
    min_y = min(ys)
    max_x = max(xs)
    max_y = max(ys)

    if max_x == min_x:
        max_x = min_x + 1.0
    if max_y == min_y:
        max_y = min_y + 1.0

    return min_x, min_y, max_x, max_y


def build_canvas_transform(
    pieces: Iterable[Any],
    *,
    canvas_width: int,
    canvas_height: int,
    padding: int = 36,
) -> CanvasTransform:
    """Build a transform that fits the full pattern inside the canvas."""

    min_x, min_y, max_x, max_y = get_pattern_bounds(pieces)
    usable_width = max(canvas_width - (padding * 2), 1)
    usable_height = max(canvas_height - (padding * 2), 1)
    pattern_width = max(max_x - min_x, 1.0)
    pattern_height = max(max_y - min_y, 1.0)

    scale = min(usable_width / pattern_width, usable_height / pattern_height)
    drawn_width = pattern_width * scale
    drawn_height = pattern_height * scale

    offset_x = padding + ((usable_width - drawn_width) / 2)
    offset_y = padding + ((usable_height - drawn_height) / 2)

    return CanvasTransform(
        min_x=min_x,
        min_y=min_y,
        scale=scale,
        offset_x=offset_x,
        offset_y=offset_y,
        canvas_height=canvas_height,
    )


def transform_point(x: float, y: float, transform: CanvasTransform) -> tuple[float, float]:
    """Transform pattern cm coordinates to canvas pixels.

    Pattern y grows downward in the current motor, so this keeps that orientation.
    """

    return (
        transform.offset_x + ((x - transform.min_x) * transform.scale),
        transform.offset_y + ((y - transform.min_y) * transform.scale),
    )


def find_nearest_hit_point(
    hit_points: Iterable[CanvasHitPoint],
    *,
    x: float,
    y: float,
    tolerance_px: float = 12.0,
) -> CanvasHitPoint | None:
    """Find nearest point within click tolerance."""

    nearest: CanvasHitPoint | None = None
    nearest_distance = float("inf")

    for hit_point in hit_points:
        distance = math.hypot(hit_point.x - x, hit_point.y - y)
        if distance <= tolerance_px and distance < nearest_distance:
            nearest = hit_point
            nearest_distance = distance

    return nearest


def _line_endpoints(line: Any, points: dict[str, Any]) -> tuple[tuple[float, float], tuple[float, float]] | None:
    candidate_names = (
        ("start", "end"),
        ("p1", "p2"),
        ("point_a", "point_b"),
        ("start_point", "end_point"),
        ("from_point", "to_point"),
    )

    for start_attr, end_attr in candidate_names:
        if hasattr(line, start_attr) and hasattr(line, end_attr):
            start = _resolve_point(getattr(line, start_attr), points)
            end = _resolve_point(getattr(line, end_attr), points)
            if start is not None and end is not None:
                return start, end

    if isinstance(line, dict):
        for start_attr, end_attr in candidate_names:
            if start_attr in line and end_attr in line:
                start = _resolve_point(line[start_attr], points)
                end = _resolve_point(line[end_attr], points)
                if start is not None and end is not None:
                    return start, end

    return None


def _curve_points(curve: Any, points: dict[str, Any]) -> list[tuple[float, float]]:
    candidate_attrs = (
        "points",
        "polyline",
        "sampled_points",
        "control_points",
    )

    for attr in candidate_attrs:
        raw = getattr(curve, attr, None)
        if raw is None and isinstance(curve, dict):
            raw = curve.get(attr)
        if raw:
            resolved = [_resolve_point(item, points) for item in raw]
            coords = [item for item in resolved if item is not None]
            if len(coords) >= 2:
                return coords

    ordered = []
    for attr in ("start", "control", "end", "start_point", "control_point", "end_point"):
        raw = getattr(curve, attr, None)
        if raw is None and isinstance(curve, dict):
            raw = curve.get(attr)
        xy = _resolve_point(raw, points)
        if xy is not None:
            ordered.append(xy)

    return ordered if len(ordered) >= 2 else []


class ReadOnlyPatternCanvas(ctk.CTkFrame):
    """Canvas widget that draws pattern pieces and selects points visually."""

    def __init__(
        self,
        master: Any,
        *,
        height: int = 300,
        on_point_selected: PointSelectionCallback | None = None,
        on_point_move_requested: PointMoveCallback | None = None,
        keyboard_step_cm: float = 0.5,
    ) -> None:
        super().__init__(master)
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)

        self.title_label = ctk.CTkLabel(
            self,
            text="Canvas Fase 43B - vista de patron / seleccion de puntos",
            font=ctk.CTkFont(size=14, weight="bold"),
        )
        self.title_label.grid(row=0, column=0, padx=12, pady=(10, 4), sticky="w")

        self.canvas = tk.Canvas(self, height=height, background="white", highlightthickness=1)
        self.canvas.grid(row=1, column=0, padx=12, pady=(4, 12), sticky="nsew")
        self.canvas.bind("<Configure>", lambda _event: self._redraw())
        self.canvas.bind("<Button-1>", self._on_canvas_click)
        self.canvas.bind("<Left>", lambda _event: self._request_keyboard_move(dx=-self._keyboard_step_cm, dy=0.0))
        self.canvas.bind("<Right>", lambda _event: self._request_keyboard_move(dx=self._keyboard_step_cm, dy=0.0))
        self.canvas.bind("<Up>", lambda _event: self._request_keyboard_move(dx=0.0, dy=-self._keyboard_step_cm))
        self.canvas.bind("<Down>", lambda _event: self._request_keyboard_move(dx=0.0, dy=self._keyboard_step_cm))

        self._pieces: list[Any] = []
        self._hit_points: list[CanvasHitPoint] = []
        self._selected: tuple[str, str] | None = None
        self._on_point_selected = on_point_selected
        self._on_point_move_requested = on_point_move_requested
        self._keyboard_step_cm = float(keyboard_step_cm)

    def clear(self) -> None:
        self._pieces = []
        self._hit_points = []
        self._selected = None
        self.title_label.configure(text="Canvas Fase 43B - vista de patron / seleccion de puntos")
        self.canvas.delete("all")
        self.canvas.create_text(
            24,
            24,
            text="Cargue un patron en el editor para visualizarlo aqui.",
            anchor="nw",
        )

    def draw_pattern(self, pieces: Iterable[Any]) -> None:
        self._pieces = list(pieces)
        self._hit_points = []
        self._redraw()

    def selected_point(self) -> tuple[str, str] | None:
        return self._selected

    def _on_canvas_click(self, event: tk.Event) -> None:
        selected = find_nearest_hit_point(self._hit_points, x=float(event.x), y=float(event.y))
        if selected is None:
            return

        self._selected = (selected.piece_name, selected.point_name)
        self.canvas.focus_set()
        self.title_label.configure(
            text=f"Canvas Fase 43B - seleccionado: {selected.piece_name} / {selected.point_name}"
        )

        if self._on_point_selected is not None:
            self._on_point_selected(selected.piece_name, selected.point_name)

        self._redraw()

    def _request_keyboard_move(self, *, dx: float, dy: float) -> None:
        """Ask the controller to move the selected point.

        The canvas does not mutate pattern geometry directly. It delegates the
        request to the main window so the existing non-destructive
        TransformOperation(move_point) contract remains the single source of
        truth.
        """

        if self._selected is None or self._on_point_move_requested is None:
            return

        piece_name, point_name = self._selected
        self._on_point_move_requested(piece_name, point_name, float(dx), float(dy))

    def _redraw(self) -> None:
        self.canvas.delete("all")
        self._hit_points = []

        if not self._pieces:
            self.canvas.create_text(
                24,
                24,
                text="Cargue un patron en el editor para visualizarlo aqui.",
                anchor="nw",
            )
            return

        width = max(self.canvas.winfo_width(), 200)
        height = max(self.canvas.winfo_height(), 200)
        transform = build_canvas_transform(
            self._pieces,
            canvas_width=width,
            canvas_height=height,
            padding=36,
        )

        for piece in self._pieces:
            self._draw_piece(piece, transform)

    def _draw_piece(self, piece: Any, transform: CanvasTransform) -> None:
        piece_name = str(getattr(piece, "name", "Pieza"))
        points = getattr(piece, "points", {})
        if not isinstance(points, dict):
            points = {}

        for line in getattr(piece, "lines", []) or []:
            endpoints = _line_endpoints(line, points)
            if endpoints is None:
                continue
            start, end = endpoints
            x1, y1 = transform_point(start[0], start[1], transform)
            x2, y2 = transform_point(end[0], end[1], transform)
            self.canvas.create_line(x1, y1, x2, y2, width=2)

        curve_sources = []
        for attr in ("structural_curves", "visual_curves", "curves"):
            raw = getattr(piece, attr, None)
            if raw:
                curve_sources.extend(raw)
        metadata = getattr(piece, "metadata", None)
        if isinstance(metadata, dict):
            for key in ("structural_curves", "visual_curves", "curves"):
                raw = metadata.get(key)
                if raw:
                    curve_sources.extend(raw)

        for curve in curve_sources:
            coords = _curve_points(curve, points)
            if len(coords) < 2:
                continue
            flat: list[float] = []
            for x, y in coords:
                cx, cy = transform_point(x, y, transform)
                flat.extend([cx, cy])
            self.canvas.create_line(*flat, width=2, smooth=True, dash=(4, 2))

        label_x = None
        label_y = None
        for point_name, x, y in _iter_piece_points(piece):
            cx, cy = transform_point(x, y, transform)
            self._hit_points.append(
                CanvasHitPoint(
                    piece_name=piece_name,
                    point_name=point_name,
                    x=cx,
                    y=cy,
                )
            )

            label_x = cx if label_x is None else min(label_x, cx)
            label_y = cy if label_y is None else min(label_y, cy)

            is_selected = self._selected == (piece_name, point_name)
            radius = 6 if is_selected else 3
            fill = "red" if is_selected else "black"
            self.canvas.create_oval(cx - radius, cy - radius, cx + radius, cy + radius, fill=fill)

        if label_x is not None and label_y is not None:
            self.canvas.create_text(label_x, max(label_y - 18, 10), text=piece_name, anchor="w")
