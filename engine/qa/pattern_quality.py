from __future__ import annotations

from collections import Counter
from math import isclose

from engine.geometry.line import Line
from engine.patterns.piece import PatternPiece
from engine.qa.result import QualityReport


def _line_key(line: Line) -> tuple[tuple[float, float], tuple[float, float]]:
    a = (round(line.start.x, 6), round(line.start.y, 6))
    b = (round(line.end.x, 6), round(line.end.y, 6))
    return tuple(sorted((a, b)))  # type: ignore[return-value]


def validate_no_negative_coordinates(report: QualityReport, piece: PatternPiece) -> None:
    for name, point in piece.points.items():
        if point.x < 0 or point.y < 0:
            report.add(
                code="NEGATIVE_COORDINATE",
                message=f"Punto {name} tiene coordenada negativa: ({point.x}, {point.y})",
                piece_name=piece.name,
            )


def validate_no_duplicate_lines(report: QualityReport, piece: PatternPiece) -> None:
    keys = [_line_key(line) for line in piece.lines]
    counts = Counter(keys)

    for key, count in counts.items():
        if count > 1:
            report.add(
                code="DUPLICATE_LINE",
                message=f"Linea duplicada detectada {key} repetida {count} veces",
                piece_name=piece.name,
            )


def validate_no_zero_length_lines(report: QualityReport, piece: PatternPiece) -> None:
    for line in piece.lines:
        if isclose(line.length, 0.0, abs_tol=1e-9):
            report.add(
                code="ZERO_LENGTH_LINE",
                message=f"Linea sin longitud detectada: {line.label or 'sin etiqueta'}",
                piece_name=piece.name,
            )


def validate_piece_has_minimum_geometry(report: QualityReport, piece: PatternPiece) -> None:
    if len(piece.points) < 4:
        report.add(
            code="INSUFFICIENT_POINTS",
            message="La pieza debe tener al menos 4 puntos",
            piece_name=piece.name,
        )

    if len(piece.lines) < 4:
        report.add(
            code="INSUFFICIENT_LINES",
            message="La pieza debe tener al menos 4 lineas",
            piece_name=piece.name,
        )


def validate_piece_closure(report: QualityReport, piece: PatternPiece) -> None:
    """Valida cierre topologico simple.

    Una pieza cerrada deberia tener al menos un grado 2 en la mayoria de puntos.
    La falda MVP contiene lineas auxiliares como linea de cadera y pinzas, por eso
    esta regla se maneja como warning si detecta puntos con grado 1.
    """

    degree: Counter[tuple[float, float]] = Counter()

    for line in piece.lines:
        degree[(round(line.start.x, 6), round(line.start.y, 6))] += 1
        degree[(round(line.end.x, 6), round(line.end.y, 6))] += 1

    loose_points = [point for point, count in degree.items() if count < 2]

    if loose_points:
        report.add(
            code="POSSIBLE_OPEN_CONTOUR",
            message=f"Posibles puntos abiertos detectados: {loose_points}",
            severity="warning",
            piece_name=piece.name,
        )


def validate_basic_skirt_proportions(report: QualityReport, piece: PatternPiece) -> None:
    """Valida proporciones minimas esperadas del bloque de falda MVP."""

    required = {
        "A_cintura_centro",
        "B_cintura_costado",
        "C_cadera_centro",
        "D_cadera_costado",
        "E_bajo_centro",
        "F_bajo_costado",
    }

    missing = required.difference(piece.points)

    if missing:
        report.add(
            code="MISSING_REQUIRED_POINTS",
            message=f"Faltan puntos requeridos: {sorted(missing)}",
            piece_name=piece.name,
        )
        return

    waist_width = piece.points["A_cintura_centro"].distance_to(piece.points["B_cintura_costado"])
    hip_width = piece.points["C_cadera_centro"].distance_to(piece.points["D_cadera_costado"])
    skirt_length = piece.points["A_cintura_centro"].distance_to(piece.points["E_bajo_centro"])

    if hip_width < waist_width:
        report.add(
            code="HIP_WIDTH_LESS_THAN_WAIST_WIDTH",
            message=f"Ancho de cadera {hip_width:.2f} cm menor que ancho de cintura {waist_width:.2f} cm",
            piece_name=piece.name,
        )

    if skirt_length <= 0:
        report.add(
            code="INVALID_SKIRT_LENGTH",
            message="El largo de falda debe ser mayor que cero",
            piece_name=piece.name,
        )


def run_pattern_quality_checks(pieces: list[PatternPiece]) -> QualityReport:
    report = QualityReport()

    if not pieces:
        report.add(
            code="NO_PIECES",
            message="No hay piezas para validar",
        )
        return report

    for piece in pieces:
        validate_piece_has_minimum_geometry(report, piece)
        validate_no_negative_coordinates(report, piece)
        validate_no_duplicate_lines(report, piece)
        validate_no_zero_length_lines(report, piece)
        validate_piece_closure(report, piece)
        validate_basic_skirt_proportions(report, piece)

    return report
