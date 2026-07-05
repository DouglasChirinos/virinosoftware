from __future__ import annotations

from dataclasses import dataclass

from loguru import logger

from engine.geometry.point import Point
from engine.measurements.body import BodyMeasurements
from engine.patterns.piece import PatternPiece
from engine.patterns.versioning import PatternVersion


@dataclass(frozen=True)
class BasicSkirtDraft:
    """Generador MVP de falda basica.

    Unidad oficial: centimetros (cm).

    Contrato principal:
    - draft() -> list[PatternPiece] con una pieza llamada "Falda basica delantera".
    - build() -> PatternPiece para consumidores que necesitan pieza unica.

    Contrato ampliado:
    - draft_full() -> delantero + posterior con nombres descriptivos principales.

    La API legacy `draft_basic_skirt()` adapta los nombres que esperan pruebas antiguas.
    """

    measurements: BodyMeasurements
    pattern_version: PatternVersion | None = None

    def __post_init__(self) -> None:
        if self.pattern_version is None:
            object.__setattr__(
                self,
                "pattern_version",
                PatternVersion.create(code="SKIRT_BASIC"),
            )

    def _build_piece(self, name: str, x_offset: float = 0.0) -> PatternPiece:
        m = self.measurements
        waist_quarter = m.waist / 4 + float(m.ease_waist or 0) / 2
        hip_quarter = m.hip / 4 + float(m.ease_hip or 0) / 2
        hip_depth = m.hip_depth

        logger.info(
            "Drafting piece name={} waist={} hip={} skirt_length={} unit={}",
            name,
            m.waist,
            m.hip,
            m.skirt_length,
            m.unit,
        )

        piece = PatternPiece(name=name)
        piece.metadata.update(self.pattern_version.as_dict() if self.pattern_version else {})
        piece.metadata["measurement_unit"] = m.unit
        piece.metadata["garment"] = "basic_skirt"

        a = piece.add_point("A_cintura_centro", Point(x_offset + 0, 0))
        b = piece.add_point("B_cintura_costado", Point(x_offset + waist_quarter, 0))
        c = piece.add_point("C_cadera_centro", Point(x_offset + 0, hip_depth))
        d = piece.add_point("D_cadera_costado", Point(x_offset + hip_quarter, hip_depth))
        e = piece.add_point("E_bajo_centro", Point(x_offset + 0, m.skirt_length))
        f = piece.add_point("F_bajo_costado", Point(x_offset + hip_quarter, m.skirt_length))

        piece.add_line(a, b, "cintura")
        piece.add_line(b, d, "costado cintura-cadera")
        piece.add_line(d, f, "costado")
        piece.add_line(f, e, "bajo")
        piece.add_line(e, c, "centro")
        piece.add_line(c, a, "centro superior")
        piece.add_line(c, d, "linea de cadera")

        dart_center = x_offset + waist_quarter / 2
        dart_width = min(3.0, max(1.5, (m.hip - m.waist) / 12))
        dart_length = min(12.0, max(8.0, hip_depth * 0.55))

        p1 = piece.add_point("Pinza_izq", Point(dart_center - dart_width / 2, 0))
        p2 = piece.add_point("Pinza_punta", Point(dart_center, dart_length))
        p3 = piece.add_point("Pinza_der", Point(dart_center + dart_width / 2, 0))
        piece.add_line(p1, p2, "pinza izquierda")
        piece.add_line(p2, p3, "pinza derecha")

        piece.add_annotation("MVP tecnico sin margenes de costura.")
        return piece

    def draft_front(self) -> PatternPiece:
        return self._build_piece("Falda basica delantera", x_offset=0.0)

    def draft_back(self) -> PatternPiece:
        offset = self.measurements.hip / 4 + float(self.measurements.ease_hip or 0) + 10
        return self._build_piece("Falda basica posterior", x_offset=offset)

    def draft(self) -> list[PatternPiece]:
        return [self.draft_front()]

    def draft_full(self) -> list[PatternPiece]:
        return [self.draft_front(), self.draft_back()]

    def build(self) -> PatternPiece:
        return self.draft_front()
