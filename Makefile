.PHONY: help setup test test-api run api flutter docker-build docker-run clean

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

setup:
	python -m pip install --upgrade pip
	python -m pip install -r requirements.txt

test:
	python verify_complete_system.py

test-api:
	python test_api_endpoints.py

run:
	python -m streamlit run demo/app.py

api:
	python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload

flutter:
	cd flutter_app && flutter run -d chrome

docker-build:
	docker build -t drishti-ai:latest .

docker-run:
	docker run -p 8501:8501 drishti-ai:latest

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
