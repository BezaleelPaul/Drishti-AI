# ==============================================================================
# SIH 2026: Drishti-AI / Netra-AI Screening Pipeline
# Production Dockerfile for Zero-Configuration Offline Edge Deployment
# ==============================================================================
FROM python:3.10-slim

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PORT=8501

WORKDIR /app

# Install system dependencies for OpenCV and ReportLab
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency specification and install
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy complete project code and pre-trained models
COPY . .

# Expose Streamlit web server port
EXPOSE 8501

# Healthcheck to verify cold-start responsiveness
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

# Launch Streamlit Application
ENTRYPOINT ["streamlit", "run", "demo/app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.headless=true"]
