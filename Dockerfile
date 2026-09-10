# ==============================================================================
# SIH 2026: Drishti-AI / Netra-AI Screening Pipeline
# Production Dockerfile for Zero-Configuration Offline Edge Deployment
# ==============================================================================
FROM python:3.11-slim

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PORT=8501

WORKDIR /app

# Install system dependencies (headless OpenCV needs no libGL).
# tini provides correct PID-1 signal handling for streamlit/uvicorn.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libglib2.0-0 \
    libgomp1 \
    curl \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency specifications and install the LEAN shipped stack:
# runtime + Keras backend (final_model.keras). PyTorch is an optional
# backend only — add `-r requirements-torch.txt` if a .pt checkpoint is used.
COPY requirements-runtime.txt requirements-keras.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements-runtime.txt -r requirements-keras.txt

# Copy complete project code and pre-trained models
COPY . .

# Run as a non-root user (results/, data/ stay writable under /app)
RUN useradd -m -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

# Expose Streamlit dashboard and FastAPI backend ports
EXPOSE 8000 8501

# Healthcheck to verify cold-start responsiveness (TF/torch cold-start
# on edge hardware takes 30-60s, so allow a generous start-period)
HEALTHCHECK --interval=30s --timeout=15s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

# tini as PID 1; CMD honors $PORT so `-e PORT=8000` works.
# docker-compose `command:` replaces this CMD (not the ENTRYPOINT),
# e.g. uvicorn for the backend service.
ENTRYPOINT ["tini", "--"]
CMD ["sh", "-c", "exec streamlit run demo/app.py --server.port=${PORT:-8501} --server.address=0.0.0.0 --server.headless=true"]
