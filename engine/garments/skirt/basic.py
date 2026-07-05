from __future__ import annotations

from copy import deepcopy

from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements
from engine.patterns.piece import PatternPiece


def draft_basic_skirt(measurements: BodyMeasurements) -> list[PatternPiece]:
    """API heredada: genera delantero y posterior con nombres legacy exactos.

    Se usa deepcopy para no mutar piezas creadas por el contrato principal.
    """

    pieces = deepcopy(BasicSkirtDraft(measurements).draft_full())
    pieces[0].name = "Falda basica - delantero"
    pieces[1].name = "Falda basica - posterior"
    return pieces
