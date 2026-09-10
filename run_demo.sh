#!/usr/bin/env bash
set -e

echo "===================================================================="
echo "   SIH 2026: AI-Assisted Diabetes & DR Screening Pipeline"
echo "   2-Stage Preventive Care & Quality-Gated Triage System"
echo "===================================================================="

# Prefer the project venv (canonical runtime); fall back to system python3.
if [ -f venv/bin/python ]; then
    PYTHON_CMD="venv/bin/python"
elif command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
else
    echo "[ERROR] Python 3 is not installed or not in PATH."
    exit 1
fi

echo "[*] Using Python: $($PYTHON_CMD --version) ($PYTHON_CMD)"

echo "[*] Installing dependencies..."
$PYTHON_CMD -m pip install -r requirements.txt

echo "[*] Generating demo assets if missing..."
if [ ! -f test_samples/04_section24_demo_scenarios/scenario_1_good.jpg ]; then
    $PYTHON_CMD demo/generate_samples.py
else
    echo "[*] Demo assets already present — skipping regeneration (delete test_samples/ to force)."
fi

echo "===================================================================="
echo " Launching Streamlit Web Application at http://localhost:${PORT:-8501}"
echo "===================================================================="
exec $PYTHON_CMD -m streamlit run demo/app.py --server.port="${PORT:-8501}" --server.address=0.0.0.0
