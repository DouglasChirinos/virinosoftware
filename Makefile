PYTHON := .venv/bin/python
PIP := .venv/bin/pip
PYTEST := .venv/bin/pytest
RUFF := .venv/bin/ruff

.PHONY: venv install test lint generate-skirt generate-all-exports run-qa show-exports show-reports run-gui clean generate-size-skirt show-size-reports infer-size generate-measurement-skirt validate-fase-40 validate-piece-completeness validate-fase-40-1a validate-fase-40-1b validate-fase-40-2 validate-fase-40-3 validate-fase-41

venv:
	python3 -m venv .venv

install: venv
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

test:
	$(PYTEST) -q

lint:
	$(RUFF) check .

generate-skirt:
	$(PYTHON) scripts/generate_basic_skirt.py

generate-all-exports:
	$(PYTHON) scripts/generate_basic_skirt_all_exports.py

run-qa:
	$(PYTHON) scripts/run_basic_skirt_qa.py

show-exports:
	find exports -maxdepth 3 -type f -print -exec ls -lh {} \;

run-gui:
	.venv/bin/python scripts/run_gui.py
clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find exports -type f \( -name "*.svg" -o -name "*.dxf" -o -name "*.pdf" \) -delete

show-reports:
	find reports -maxdepth 2 -type f -print -exec ls -lh {} \;


generate-size-skirt:
	$(PYTHON) scripts/generate_basic_skirt_from_size.py --size M

show-size-reports:
	find reports -maxdepth 2 -type f -name '*talla*' -o -name 'tabla_tallas_mvp.md' -print -exec ls -lh {} \;


infer-size:
	$(PYTHON) scripts/infer_size.py --waist 73 --hip 99

generate-measurement-skirt:
	$(PYTHON) scripts/generate_basic_skirt_from_measurements.py --waist 73 --hip 99 --skirt-length 60

list-garments:
	.venv/bin/python scripts/list_garments.py

generate-pattern:
	.venv/bin/python scripts/generate_pattern.py --garment falda_basica --waist 73 --hip 99 --skirt-length 60

generate-basic-pants:
	.venv/bin/python scripts/generate_pattern.py --garment pantalon_basico --waist 84 --hip 104 --outseam 100 --inseam 76

export-pattern:
	.venv/bin/python scripts/export_pattern.py --garment falda_basica --waist 73 --hip 99 --skirt-length 60 --output falda_basica_universal

export-basic-pants:
	.venv/bin/python scripts/export_pattern.py --garment pantalon_basico --waist 84 --hip 104 --outseam 100 --inseam 76 --output pantalon_basico_universal

generate-serializable-short:
	.venv/bin/python scripts/generate_serializable_pattern.py --definition examples/garments/short_basico.json

generate-universal-short:
	.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20

export-universal-short:
	.venv/bin/python scripts/export_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20 --output short_basico_universal

generate-serializable-falda-evase:
	.venv/bin/python scripts/generate_serializable_pattern.py --definition examples/garments/falda_evase.json --waist 73 --hip 99 --skirt-length 60 --ease 12

generate-universal-falda-evase:
	.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12

export-universal-falda-evase:
	.venv/bin/python scripts/export_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12 --output falda_evase_universal

validate-geometry-short:
	.venv/bin/python scripts/validate_serializable_geometry.py --garment short_basico --measurement waist=84 --measurement hip=104 --measurement outseam=45 --measurement inseam=20 --output short_basico_geometry_validation

validate-geometry-falda-evase:
	.venv/bin/python scripts/validate_serializable_geometry.py --garment falda_evase --measurement waist=73 --measurement hip=99 --measurement skirt_length=60 --measurement ease=12 --output falda_evase_geometry_validation

validate-garments-json:
	.venv/bin/python scripts/validate_garment_definition.py --definitions-dir examples/garments

validate-serializable-catalog:
	.venv/bin/python scripts/validate_serializable_catalog.py --definitions-dir examples/garments

generate-serializable-catalog:
	.venv/bin/python scripts/generate_serializable_catalog.py --definitions-dir examples/garments

export-serializable-catalog:
	.venv/bin/python scripts/export_serializable_catalog.py --definitions-dir examples/garments --output-dir exports/catalog

validate-fase-40:
	.venv/bin/python -m pytest tests/test_gui_universal_controller.py tests/test_export_visual_metadata.py tests/test_fase_40_export_visual_layout.py tests/test_fase_40_1_cotas_visuales_universales.py tests/test_fase_40_1_layout_piezas_independientes.py -q
	.venv/bin/python scripts/list_garments.py
	.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20
	.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12
	.venv/bin/python scripts/generate_pattern.py --garment falda_basica --waist 73 --hip 99 --skirt-length 60 --ease 2
	@echo VALIDATE_FASE_40_1_OK

validate-piece-completeness:
	.venv/bin/python scripts/validate_piece_completeness.py

validate-fase-40-1a:
	.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py -q

validate-fase-40-1b:
	.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py tests/test_fase_40_1b_serializable_complete_pieces.py -q
	.venv/bin/python scripts/validate_piece_completeness.py
	.venv/bin/python scripts/validate_serializable_catalog.py --definitions-dir examples/garments
	.venv/bin/python scripts/generate_serializable_catalog.py --definitions-dir examples/garments

validate-fase-40-2:
	.venv/bin/python -m pytest tests/test_fase_40_2_visual_curves.py -q
	.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py tests/test_fase_40_1b_serializable_complete_pieces.py -q
	.venv/bin/python scripts/validate_piece_completeness.py

validate-fase-40-3:
	.venv/bin/python -m pytest tests/test_fase_40_3_structural_curves.py -q
	.venv/bin/python -m pytest tests/test_fase_40_2_visual_curves.py -q
	.venv/bin/python scripts/validate_piece_completeness.py


validate-fase-40-3b:
	.venv/bin/python -m pytest tests/test_fase_40_3b_curve_semantics.py -q


validate-fase-40-3c:
	.venv/bin/python -m pytest tests/test_fase_40_3c_concavity_direction.py -q


validate-fase-40-3d:
	.venv/bin/python -m pytest tests/test_fase_40_3d_crotch_extension_formula.py -q

validate-fase-41:
	.venv/bin/python -m pytest tests/test_fase_41_transformaciones_editables.py -q


validate-fase-42:
	.venv/bin/python -m pytest tests/test_fase_42_editor_visual_mvp_gui.py -q

validate-fase-43a:
	.venv/bin/python -m pytest tests/test_fase_43a_canvas_readonly.py tests/test_fase_43a_gui_tabs_contract.py -q

validate-fase-43b:
	.venv/bin/python -m pytest tests/test_fase_43b_canvas_point_selection.py -q

validate-fase-43c:
	.venv/bin/python -m pytest tests/test_fase_43c_canvas_keyboard_move.py tests/test_fase_43c_incremental_transform_stability.py -q

validate-fase-43d:
	.venv/bin/python -m pytest tests/test_fase_43d_visual_flow_export_variant.py -q

validate-fase-44a:
	.venv/bin/python -m pytest tests/test_fase_44a_usabilidad_punto_seleccionado.py -q

validate-fase-44b:
	.venv/bin/python -m pytest tests/test_fase_44b_selector_paso_micro_movimiento_gui.py -q

validate-fase-44c:
	.venv/bin/python -m pytest tests/test_fase_44c_reset_feedback_gui.py -q

validate-fase-44d:
	@test -f docs/56_Fase_44D_Prueba_Visual_Manual_Editor.md
	@grep -q "Fase 44D" docs/56_Fase_44D_Prueba_Visual_Manual_Editor.md
	@grep -q "Generar patrón" docs/56_Fase_44D_Prueba_Visual_Manual_Editor.md
	@grep -q "Restaurar punto" docs/56_Fase_44D_Prueba_Visual_Manual_Editor.md
	@grep -q "Guardar/exportar variante" docs/56_Fase_44D_Prueba_Visual_Manual_Editor.md
	@echo "FASE_44D_MANUAL_CHECKLIST_OK"
