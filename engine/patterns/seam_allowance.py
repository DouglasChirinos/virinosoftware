from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
from math import hypot

from engine.geometry.line import Line
from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece


@dataclass(frozen=True)
class SeamAllowanceConfig:
    """Configuracion base para margen de costura.

    Unidad oficial: centimetros (cm).
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
    """Crea una linea paralela simple desplazada a la derecha del vector."""

    dx = line.end.x - line.start.x
    dy = line.end.y - line.start.y
    length = hypot(dx, dy)

    if length == 0:
        raise ValueError("No se puede aplicar margen a una linea de longitud cero")

    nx = dy / length
    ny = -dx / length

    start = Point(line.start.x + nx * distance_cm, line.start.y + ny * distance_cm)
    end = Point(line.end.x + nx * distance_cm, line.end.y + ny * distance_cm)

    return Line(
        start=start,
        end=end,
        label=f"margen {line.label}".strip(),
        kind="seam_allowance",
    )


def apply_seam_allowance(piece: PatternPiece, config: SeamAllowanceConfig | None = None) -> PatternPiece:
    """Retorna una copia de la pieza con lineas de margen de costura agregadas."""

    cfg = config or SeamAllowanceConfig()
    result = deepcopy(piece)
    result.name = f"{piece.name} con margen"
    result.metadata["seam_allowance"] = "enabled"
    result.metadata["seam_allowance_unit"] = cfg.unit
    result.metadata["seam_allowance_default_cm"] = str(cfg.default_cm)

    existing = list(result.lines)
    for line in existing:
        normalized_label = line.label.lower()

        if "pinza" in normalized_label or "cadera" in normalized_label:
            continue

        distance = cfg.allowance_for_label(line.label)
        result.lines.append(offset_line(line, distance))

    result.add_annotation("Incluye lineas de margen de costura MVP por offset paralelo simple.")
    return result
