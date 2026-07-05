PYTHON := .venv/bin/python
PIP := .venv/bin/pip
PYTEST := .venv/bin/pytest
RUFF := .venv/bin/ruff

.PHONY: venv install test lint generate-skirt generate-all-exports show-exports show-reports run-gui clean

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

show-exports:
	find exports -maxdepth 3 -type f -print -exec ls -lh {} \;

run-gui:
	$(PYTHON) -m app.main

clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find exports -type f \( -name "*.svg" -o -name "*.dxf" -o -name "*.pdf" \) -delete

show-reports:
	find reports -maxdepth 2 -type f -print -exec ls -lh {} \;
