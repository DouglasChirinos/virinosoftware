from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass

from engine.geometry.corners import CornerJoin, classify_corner_join
from engine.geometry.line import Line
from engine.geometry.offset import infinite_line_intersection, parallel_offset_line, polygon_signed_area
from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece


@dataclass(frozen=True)
class SeamAllowanceConfig:
    default_cm: float = 1.0
    hem_cm: float = 3.0
    waist_cm: float = 1.0
    side_cm: float = 1.5
    unit: str = "cm"
    corner_join: str = "miter"
    miter_limit_cm: float = 8.0
    bevel_fallback: bool = True

    def __post_init__(self) -> None:
        if self.unit != "cm":
            raise ValueError("La unidad oficial de margen de costura es cm")

        if self.corner_join not in {"miter", "bevel", "miter_bevel"}:
            raise ValueError("corner_join debe ser miter, bevel o miter_bevel")

        for field_name in ("default_cm", "hem_cm", "waist_cm", "side_cm", "miter_limit_cm"):
            value = getattr(self, field_name)
            if value < 0:
                raise ValueError(f"{field_name} no puede ser negativo")

    def allowance_for_label(self, label: str) -> float:
        normalized = label.lower()
        if "bajo" in normalized:
            return self.hem_cm
        if "cintura" in normalized:
            return self.waist_cm
        if "costado" in normalized or "centro" in normalized:
            return self.side_cm
        return self.default_cm


def offset_line(line: Line, distance_cm: float) -> Line:
    return parallel_offset_line(line, distance_cm, kind="seam_allowance")


def _main_contour_lines(piece: PatternPiece) -> list[Line]:
    contour_labels = [
        "cintura",
        "costado cintura-cadera",
        "costado",
        "bajo",
        "centro",
        "centro superior",
    ]

    result: list[Line] = []
    for label in contour_labels:
        for line in piece.lines:
            if line.kind == "pattern" and line.label == label:
                result.append(line)
                break
    return result


def _dedupe_consecutive_points(points: list[Point], tolerance: float = 1e-6) -> list[Point]:
    if not points:
        return []

    result = [points[0]]
    for point in points[1:]:
        if point.distance_to(result[-1]) > tolerance:
            result.append(point)

    if len(result) > 1 and result[0].distance_to(result[-1]) <= tolerance:
        result.pop()

    return result


def _offsets_for_piece(piece: PatternPiece, cfg: SeamAllowanceConfig) -> list[Line]:
    contour = _main_contour_lines(piece)
    if len(contour) < 3:
        raise ValueError("No hay suficientes lineas de contorno para generar margen cerrado")

    return [
        parallel_offset_line(line, cfg.allowance_for_label(line.label), kind="seam_allowance")
        for line in contour
    ]


def build_closed_seam_allowance_contour(
    piece: PatternPiece,
    config: SeamAllowanceConfig | None = None,
) -> list[Line]:
    cfg = config or SeamAllowanceConfig()
    offsets = _offsets_for_piece(piece, cfg)

    vertices: list[Point] = []
    total = len(offsets)

    for idx in range(total):
        previous_line = offsets[idx - 1]
        current_line = offsets[idx]
        intersection = infinite_line_intersection(previous_line, current_line)

        if intersection is None:
            if cfg.bevel_fallback:
                vertices.extend([previous_line.end, current_line.start])
                continue
            intersection = previous_line.end

        join = classify_corner_join(
            vertex=intersection,
            previous_offset=previous_line,
            current_offset=current_line,
            miter_limit_cm=cfg.miter_limit_cm,
            bevel_fallback=cfg.bevel_fallback,
        )

        if cfg.corner_join == "bevel" or join.join_style == "bevel":
            vertices.extend([previous_line.end, current_line.start])
        else:
            vertices.append(intersection)

    vertices = _dedupe_consecutive_points(vertices)

    if polygon_signed_area(vertices) < 0:
        vertices = list(reversed(vertices))

    closed_lines: list[Line] = []
    for idx, vertex in enumerate(vertices):
        nxt = vertices[(idx + 1) % len(vertices)]
        closed_lines.append(
            Line(start=vertex, end=nxt, label=f"margen cerrado {idx + 1}", kind="seam_allowance")
        )

    return closed_lines


def analyze_corner_joins(piece: PatternPiece, config: SeamAllowanceConfig | None = None) -> list[CornerJoin]:
    cfg = config or SeamAllowanceConfig()

    try:
        offsets = _offsets_for_piece(piece, cfg)
    except ValueError:
        return []

    joins: list[CornerJoin] = []
    for idx in range(len(offsets)):
        previous_line = offsets[idx - 1]
        current_line = offsets[idx]
        intersection = infinite_line_intersection(previous_line, current_line)

        if intersection is None:
            continue

        joins.append(
            classify_corner_join(
                vertex=intersection,
                previous_offset=previous_line,
                current_offset=current_line,
                miter_limit_cm=cfg.miter_limit_cm,
                bevel_fallback=cfg.bevel_fallback,
            )
        )

    return joins


def apply_seam_allowance(piece: PatternPiece, config: SeamAllowanceConfig | None = None) -> PatternPiece:
    cfg = config or SeamAllowanceConfig()
    result = deepcopy(piece)
    result.name = f"{piece.name} con margen"
    result.metadata["seam_allowance"] = "enabled"
    result.metadata["seam_allowance_unit"] = cfg.unit
    result.metadata["seam_allowance_default_cm"] = str(cfg.default_cm)
    result.metadata["seam_allowance_mode"] = "closed_contour"
    result.metadata["seam_corner_join"] = cfg.corner_join
    result.metadata["seam_miter_limit_cm"] = str(cfg.miter_limit_cm)
    result.metadata["seam_bevel_fallback"] = str(cfg.bevel_fallback)

    result.lines.extend(build_closed_seam_allowance_contour(result, cfg))
    result.add_annotation("Incluye contorno cerrado de margen con control miter/bevel.")
    return result
