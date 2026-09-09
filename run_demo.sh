#!/usr/bin/env bash
set -e

echo "===================================================================="
echo "   SIH 2026: AI-Assisted Diabetes & DR Screening Pipeline"
echo "   2-Stage Preventive Care & Quality-Gated Triage System"
echo "===================================================================="

# Check Python
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
else
    echo "[ERROR] Python 3 is not installed or not in PATH."
    exit 1
fi

echo "[*] Using Python: $($PYTHON_CMD --version)"

echo "[*] Installing dependencies..."
$PYTHON_CMD -m pip install -r requirements.txt --quiet

echo "[*] Generating demo assets if missing..."
$PYTHON_CMD demo/generate_samples.py

echo "===================================================================="
echo " Launching Streamlit Web Application at http://localhost:8501"
echo "===================================================================="
$PYTHON_CMD -m streamlit run demo/app.py
