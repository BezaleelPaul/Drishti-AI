"""
Netra-AI / Drishti-AI: FastAPI Application Entry Point.
Binds Flutter Mobile/Tablet/Web frontend to the Python AI Screening Pipeline.
"""
from __future__ import annotations

import os
import sys

# Ensure repository root is in sys.path
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from api.database import init_db
from api.routes.patients import router as patients_router
from api.routes.risk import router as risk_router
from api.routes.retinal import router as retinal_router
from api.routes.review import router as review_router
from api.routes.sync import router as sync_router
from api.routes.system import router as system_router

# Initialize database schema and demo seeds
init_db()

app = FastAPI(
    title="Netra-AI Clinical Screening API",
    description=(
        "Production-oriented REST API connecting Flutter applications to the "
        "Diabetic Retinopathy Screening Pipeline (Model 1 Quality Gate, "
        "Model 2 EfficientNetB0 Classifier, Grad-CAM++, and Diabetes Risk Engine)."
    ),
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# -----------------------------------------------------------------------------
# CORS Configuration (Allows Flutter Web, Android 10.0.2.2, iOS, Desktop)
# -----------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------------------------------------------------
# Static Directories for Grad-CAM overlays and Sample Test Images
# -----------------------------------------------------------------------------
results_dir = os.path.join(_PROJECT_ROOT, "results", "api_screenings")
samples_dir = os.path.join(_PROJECT_ROOT, "test_samples")
sinduri_assets = os.path.join(_PROJECT_ROOT, "sinduri_uiux_kit", "assets")

flutter_web_dir = os.path.join(_PROJECT_ROOT, "flutter_app", "build", "web")

if os.path.exists(results_dir):
    app.mount("/static/results", StaticFiles(directory=results_dir), name="results")
if os.path.exists(samples_dir):
    app.mount("/static/samples", StaticFiles(directory=samples_dir), name="samples")
if os.path.exists(sinduri_assets):
    app.mount("/static/uiux", StaticFiles(directory=sinduri_assets), name="uiux")
if os.path.exists(flutter_web_dir):
    app.mount("/app", StaticFiles(directory=flutter_web_dir, html=True), name="flutter_app")

# -----------------------------------------------------------------------------
# Include API Routers
# -----------------------------------------------------------------------------
app.include_router(system_router)
app.include_router(patients_router)
app.include_router(risk_router)
app.include_router(retinal_router)
app.include_router(review_router)
app.include_router(sync_router)


@app.get("/")
def root():
    return {
        "platform": "Netra-AI Rural Health Screening Engine",
        "web_application": "/app",
        "api_documentation": "/docs",
        "api_version": "2.0.0",
        "status": "Operational",
        "architecture": "Flutter Frontend <-> FastAPI Bridge <-> Python AI Pipeline",
        "supported_cameras": "Manufacturer-Agnostic (Any JPG/PNG Fundus Camera, Remidio, Forus, Zeiss, Topcon)",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api.main:app", host="0.0.0.0", port=8000, reload=True)
