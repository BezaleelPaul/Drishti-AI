#!/usr/bin/env bash
# ==============================================================================
# Drishti-AI / Netra-AI (SIH 2026) — Automated macOS Setup Script
# Works on: Apple Silicon (M1/M2/M3/M4) & Intel Macs
# ==============================================================================

set -e

# ANSI Color codes
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}${BLUE}====================================================================${RESET}"
echo -e "${BOLD}${BLUE}       👁️ DRISHTI-AI: macOS Automatic Installation & Setup         ${RESET}"
echo -e "${BOLD}${BLUE}   MathWorks SIH26038 • Diabetic Retinopathy Screening Pipeline     ${RESET}"
echo -e "${BOLD}${BLUE}====================================================================${RESET}"
echo ""

# 1. Architecture Detection
ARCH=$(uname -m)
echo -e "[*] Hardware Architecture: ${BOLD}${ARCH}${RESET}"
if [ "$ARCH" = "arm64" ]; then
    echo -e "    ${GREEN}✓ Apple Silicon (M-Series) detected. High efficiency mode enabled.${RESET}"
else
    echo -e "    ${YELLOW}✓ Intel x86_64 architecture detected.${RESET}"
fi

# 2. Check for Python 3
echo -e "[*] Checking Python installation..."
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version 2>&1)
    echo -e "    ${GREEN}✓ Found $PY_VERSION${RESET}"
    PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info[0])')
    PY_MINOR=$(python3 -c 'import sys; print(sys.version_info[1])')
    if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
        echo -e "${RED}[ERROR] Python >= 3.10 is required (TensorFlow/torch wheels unavailable below).${RESET}"
        exit 1
    fi
    if [ "$PY_MINOR" -gt 11 ]; then
        echo -e "${YELLOW}[!] Python 3.$PY_MINOR detected: TF 2.15/torch 2.1 wheels may be missing; 3.11 recommended.${RESET}"
    fi
else
    echo -e "${RED}[ERROR] Python 3 was not found on your Mac.${RESET}"
    echo -e "Please install Python using Homebrew: ${BOLD}brew install python@3.11${RESET}"
    echo -e "Or download from: https://www.python.org/downloads/macos/"
    exit 1
fi

# 3. Create isolated virtual environment (Solves PEP 668 externally-managed-environment on macOS)
echo -e "[*] Creating isolated Python virtual environment (./venv)..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "    ${GREEN}✓ Virtual environment created.${RESET}"
else
    echo -e "    ${YELLOW}✓ Virtual environment already exists.${RESET}"
fi

# 4. Activate virtual environment
echo -e "[*] Activating virtual environment..."
source venv/bin/activate
echo -e "    ${GREEN}✓ Active Python: $(which python)${RESET}"

# 5. Upgrade pip, wheel, setuptools
echo -e "[*] Upgrading package managers..."
pip install --upgrade pip setuptools wheel --quiet

# 6. Install project dependencies
echo -e "[*] Installing dependencies from requirements.txt (this takes ~1-2 minutes)..."
pip install -r requirements.txt

# 7. Check optional Flutter CLI
echo -e "[*] Checking Flutter SDK (for mobile app)..."
if command -v flutter &>/dev/null; then
    FLUTTER_VER=$(flutter --version 2>&1 | head -n 1)
    echo -e "    ${GREEN}✓ Found $FLUTTER_VER${RESET}"
else
    echo -e "    ${YELLOW}ℹ Flutter SDK not detected. The Web Dashboard and Python API will run normally.${RESET}"
    echo -e "      (If you wish to test the Flutter mobile app later, install from flutter.dev)${RESET}"
fi

# 8. Run End-to-End System Verification
echo ""
echo -e "${BOLD}${BLUE}====================================================================${RESET}"
echo -e "${BOLD}${BLUE}       Running End-to-End Verification of All 10 Subsystems         ${RESET}"
echo -e "${BOLD}${BLUE}====================================================================${RESET}"
if [ "${SKIP_VERIFY:-0}" = "1" ]; then
    echo -e "${YELLOW}[*] SKIP_VERIFY=1 — skipping end-to-end verification.${RESET}"
else
    python verify_complete_system.py
fi

echo ""
echo -e "${BOLD}${GREEN}====================================================================${RESET}"
echo -e "${BOLD}${GREEN}       🎉 INSTALLATION & VERIFICATION COMPLETED SUCCESSFULLY!        ${RESET}"
echo -e "${BOLD}${GREEN}====================================================================${RESET}"
echo ""
echo -e "${BOLD}How to launch Drishti-AI:${RESET}"
echo -e "${YELLOW}NOTE: 'source venv/bin/activate' above applied only inside this script."
echo -e "Run ${BOLD}source venv/bin/activate${RESET}${YELLOW} in each new terminal before python/streamlit/uvicorn commands.${RESET}"
echo -e "  1. Quick Launch Menu:  ${BOLD}./run_mac.sh${RESET}"
echo -e "  2. Central Dashboard:  ${BOLD}source venv/bin/activate && streamlit run demo/app.py${RESET}"
echo -e "  3. FastAPI REST API:   ${BOLD}source venv/bin/activate && uvicorn api.main:app --reload${RESET}"
echo ""
