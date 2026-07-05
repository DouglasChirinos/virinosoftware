PYTHON := .venv/bin/python
PIP := .venv/bin/pip
PYTEST := .venv/bin/pytest
RUFF := .venv/bin/ruff

.PHONY: venv install test lint generate-skirt generate-all-exports run-qa show-exports show-reports run-gui clean generate-size-skirt show-size-reports infer-size generate-measurement-skirt

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

