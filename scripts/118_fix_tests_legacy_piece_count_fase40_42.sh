#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== Fix tests legacy: actualizar expectativas a piezas completas Fase 40.1B+ =='
printf '%s\n' '== Objetivo =='
printf '%s\n' '- Los tests historicos aun esperaban 1 pieza en short/falda_evase serializables.'
printf '%s\n' '- Desde Fase 40.1B el contrato correcto es delantero + posterior = 2 piezas.'
printf '%s\n' '- Este fix actualiza pruebas legacy sin tocar logica de motor.'

printf '%s\n' '== Estado Git antes del fix =='
git status --short || true

python3 - <<'PY'
from pathlib import Path

replacements = {
    "tests/test_gui_universal_controller.py": [
        ("assert summary.piece_count == 1", "assert summary.piece_count == 2"),
    ],
    "tests/test_serializable_dynamic_catalog.py": [
        ("assert result.piece_count == 1", "assert result.piece_count == 2"),
        ('assert "PIECE_COUNT: 1" in result.stdout', 'assert "PIECE_COUNT: 2" in result.stdout'),
    ],
    "tests/test_serializable_formula_interpreter.py": [
        ("assert pattern.piece_count == 1", "assert pattern.piece_count == 2"),
        ("assert len(piece.lines) == 4", "assert len(piece.lines) == 4\n    assert pattern.pieces[1].name == \"Short basico posterior\"\n    assert len(pattern.pieces[1].lines) == 4"),
    ],
    "tests/test_serializable_garment_adapter.py": [
        ("assert result.piece_count == 1", "assert result.piece_count == 2"),
        ('"PIECE_COUNT: 1",', '"PIECE_COUNT: 2",'),
        ('"PIECE_1: Short basico delantero lines=4",\n    ]', '"PIECE_1: Short basico delantero lines=4",\n        "PIECE_2: Short basico posterior lines=4",\n    ]'),
    ],
    "tests/test_serializable_garment_definition.py": [
        ('assert definition.version == "0.1"', 'assert definition.version == "0.2.1-mvp"'),
        ("assert len(definition.pieces) == 1", "assert len(definition.pieces) == 2"),
    ],
    "tests/test_serializable_geometry_validation.py": [
        ("assert report.piece_count == 1", "assert report.piece_count == 2"),
        ("assert piece.width == pytest.approx(26.0)", "assert piece.width == pytest.approx(26.0)\n    posterior = report.piece_reports[1]\n    assert posterior.line_count == 4\n    assert posterior.point_count == 4\n    assert posterior.width == pytest.approx(28.0)"),
        ("assert piece.max_x == pytest.approx(36.75)", "assert piece.max_x == pytest.approx(36.75)\n    posterior = report.piece_reports[1]\n    assert posterior.line_count == 4\n    assert posterior.point_count == 4\n    assert posterior.width == pytest.approx(49.75)\n    assert posterior.min_x == pytest.approx(-12.0)\n    assert posterior.max_x == pytest.approx(37.75)"),
    ],
    "tests/test_serializable_semantic_validation.py": [
        ("assert report.piece_count == 1", "assert report.piece_count == 2"),
        ("assert report.formula_count == 5", "assert report.formula_count == 10"),
    ],
    "tests/test_serializable_universal_exports.py": [
        ('assert "PIECE_COUNT: 1" in result.stdout', 'assert "PIECE_COUNT: 2" in result.stdout'),
    ],
}

for file_name, pairs in replacements.items():
    path = Path(file_name)
    if not path.exists():
        raise SystemExit(f"No existe archivo esperado: {file_name}")
    text = path.read_text(encoding="utf-8")
    original = text
    for old, new in pairs:
        if old not in text:
            print(f"WARN: patron no encontrado en {file_name}: {old!r}")
        text = text.replace(old, new)
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"UPDATED: {file_name}")
    else:
        print(f"UNCHANGED: {file_name}")
PY

cat > docs/70_Fix_Tests_Legacy_Piece_Count_Fase40_42.md <<'MD'
# Fix tests legacy — piezas completas Fase 40.1B+

## Contexto

La bateria completa detecto pruebas antiguas que aun esperaban una sola pieza en prendas serializables `short_basico` y `falda_evase`.

Desde Fase 40.1A/40.1B el criterio de producto cambio: una prenda inferior basica no se considera completa si no tiene delantero y posterior.

## Decision

Actualizar pruebas legacy para aceptar el contrato vigente:

- `short_basico`: 2 piezas, delantero y posterior.
- `falda_evase`: 2 piezas, delantero y posterior.
- `short_basico.json`: version `0.2.1-mvp`.
- CLI universal: `PIECE_COUNT: 2`.
- Validacion semantica: formula count ajustado al total de ambas piezas.

## Regla de producto

No se debe volver a validar como correcta una prenda inferior basica con una sola pieza cuando el objetivo de producto es patron usable para usuario final.

## Alcance

Este fix no cambia el motor. Solo sincroniza pruebas heredadas con el contrato vigente de piezas completas.
MD

printf '%s\n' '== Validacion puntual tests legacy corregidos =='
.venv/bin/python -m pytest \
  tests/test_gui_universal_controller.py::test_generate_summary_for_serializable_short \
  tests/test_serializable_dynamic_catalog.py::test_falda_evase_generates_from_universal_pattern_generator \
  tests/test_serializable_dynamic_catalog.py::test_falda_evase_exports_through_universal_flow \
  tests/test_serializable_formula_interpreter.py::test_generates_geometry_from_short_basico_json_defaults \
  tests/test_serializable_garment_adapter.py::test_generate_serializable_pattern_from_json_returns_engine_friendly_result \
  tests/test_serializable_garment_adapter.py::test_summarize_serializable_result_matches_universal_cli_style \
  tests/test_serializable_garment_definition.py::test_load_serializable_garment_from_json_example \
  tests/test_serializable_geometry_validation.py::test_short_basico_geometry_report_has_positive_bbox \
  tests/test_serializable_geometry_validation.py::test_falda_evase_geometry_report_has_expected_expanded_bbox \
  tests/test_serializable_semantic_validation.py::test_short_basico_json_passes_semantic_validation \
  tests/test_serializable_semantic_validation.py::test_falda_evase_json_passes_semantic_validation \
  tests/test_serializable_universal_exports.py::test_short_basico_exports_through_universal_flow \
  -q

printf '%s\n' '== Validacion integrada principal =='
make test
make validate-fase-40
make validate-fase-41
make validate-fase-42
make validate-piece-completeness

printf '%s\n' '== Estado Git despues del fix =='
git status --short
