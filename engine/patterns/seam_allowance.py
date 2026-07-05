from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass

from engine.geometry.line import Line
from engine.geometry.offset import infinite_line_intersection, parallel_offset_line, polygon_signed_area
from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece


@dataclass(frozen=True)
class SeamAllowanceConfig:
    """Configuracion base para margen de costura.

    Unidad oficial: centimetros (cm).

    Fase 15:
    - genera contorno cerrado de margen para el bloque principal.
    - usa intersecciones de offsets consecutivos.
    - deja miter/fillet avanzado para fases futuras.
    """

    default_cm: float = 1.0
    hem_cm: float = 3.0
    waist_cm: float = 1.0
    side_cm: float = 1.5
    unit: str = "cm"

    def __post_init__(self) -> None:
        if self.unit != "cm":
            raise ValueError("La unidad oficial de margen de costura es cm")

        for field_name in ("default_cm", "hem_cm", "waist_cm", "side_cm"):
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
    """Compatibilidad: offset paralelo simple."""

    return parallel_offset_line(line, distance_cm, kind="seam_allowance")


def _main_contour_lines(piece: PatternPiece) -> list[Line]:
    """Devuelve el contorno principal de la falda MVP.

    Excluye pinzas y lineas auxiliares como linea de cadera.
    """

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
            if line.kind != "pattern":
                continue
            if line.label == label:
                result.append(line)
                break

    return result


def build_closed_seam_allowance_contour(
    piece: PatternPiece,
    config: SeamAllowanceConfig | None = None,
) -> list[Line]:
    """Construye un contorno cerrado de margen usando intersecciones de offsets.

    Algoritmo:
    1. Toma el contorno principal en orden.
    2. Genera offset por linea.
    3. Intersecta offsets consecutivos como lineas infinitas.
    4. Une los vertices resultantes en un contorno cerrado.
    """

    cfg = config or SeamAllowanceConfig()
    contour = _main_contour_lines(piece)

    if len(contour) < 3:
        raise ValueError("No hay suficientes lineas de contorno para generar margen cerrado")

    offsets: list[Line] = [
        parallel_offset_line(line, cfg.allowance_for_label(line.label), kind="seam_allowance")
        for line in contour
    ]

    vertices: list[Point] = []
    total = len(offsets)

    for idx in range(total):
        previous_line = offsets[idx - 1]
        current_line = offsets[idx]
        intersection = infinite_line_intersection(previous_line, current_line)

        if intersection is None:
            intersection = previous_line.end

        vertices.append(intersection)

    if polygon_signed_area(vertices) < 0:
        vertices = list(reversed(vertices))

    closed_lines: list[Line] = []
    for idx, vertex in enumerate(vertices):
        nxt = vertices[(idx + 1) % len(vertices)]
        closed_lines.append(
            Line(
                start=vertex,
                end=nxt,
                label=f"margen cerrado {idx + 1}",
                kind="seam_allowance",
            )
        )

    return closed_lines


def apply_seam_allowance(piece: PatternPiece, config: SeamAllowanceConfig | None = None) -> PatternPiece:
    """Retorna una copia de la pieza con contorno cerrado de margen de costura."""

    cfg = config or SeamAllowanceConfig()
    result = deepcopy(piece)
    result.name = f"{piece.name} con margen"
    result.metadata["seam_allowance"] = "enabled"
    result.metadata["seam_allowance_unit"] = cfg.unit
    result.metadata["seam_allowance_default_cm"] = str(cfg.default_cm)
    result.metadata["seam_allowance_mode"] = "closed_contour"

    result.lines.extend(build_closed_seam_allowance_contour(result, cfg))

    result.add_annotation("Incluye contorno cerrado de margen de costura por interseccion de offsets.")
    return result
