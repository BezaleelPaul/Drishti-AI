.PHONY: help setup test test-api run api flutter docker-build docker-run clean

# Prefer the project virtualenv when present (macOS ships no `python`
# alias and system pythons lack the pinned deps); fall back to python3,
# then plain python for Windows/Git-Bash environments.
PY := $(shell if [ -x venv/bin/python ]; then echo venv/bin/python; elif command -v python3 >/dev/null 2>&1; then echo python3; else echo python; fi)

help:
	@echo "Drishti-AI / Netra-AI (SIH 2026) Command Center"
	@echo "-----------------------------------------------------"
	@echo "make setup        : Install dependencies via pip"
	@echo "make test         : Run end-to-end verification and ML tests"
	@echo "make test-api     : Test FastAPI backend bridge endpoints"
	@echo "make run          : Launch interactive Streamlit demo application"
	@echo "make api          : Launch FastAPI REST API server on port 8000"
	@echo "make flutter      : Launch Flutter Mobile/Tablet App"
	@echo "make docker-build : Build containerized image"
	@echo "make docker-run   : Run containerized platform on port 8501"
	@echo "make clean        : Remove temporary cache and build artifacts"
	@echo "Using interpreter : $(PY)"

setup:
	$(PY) -m pip install --upgrade pip
	$(PY) -m pip install -r requirements.txt

test:
	$(PY) verify_complete_system.py
	$(PY) -m pytest -q

test-api:
	$(PY) test_api_endpoints.py

run:
	$(PY) -m streamlit run demo/app.py

api:
	$(PY) -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload

flutter:
	cd flutter_app && flutter run -d chrome

docker-build:
	docker build -t drishti-ai:latest .

docker-run:
	docker run -p 8501:8501 drishti-ai:latest

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
