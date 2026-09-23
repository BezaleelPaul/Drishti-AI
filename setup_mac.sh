#!/usr/bin/env bash
# ==============================================================================
# Drishti-AI / Netra-AI (SIH 2026) — Automated macOS Setup Script
# Works on: Apple Silicon (M1/M2/M3/M4) & Intel Macs
# ==============================================================================

set -e

# Always resolve paths relative to this checkout, even when launched from another directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

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

# 2. Check for a supported Python 3 interpreter
echo -e "[*] Checking Python installation..."
PYTHON_CMD=""
for candidate in "${DRISHTI_PYTHON:-}" python3.11 python3.12 python3; do
    if [ -n "$candidate" ] && command -v "$candidate" &>/dev/null; then
        candidate_path=$(command -v "$candidate")
        candidate_major=$("$candidate_path" -c 'import sys; print(sys.version_info[0])')
        candidate_minor=$("$candidate_path" -c 'import sys; print(sys.version_info[1])')
        if [ "$candidate_major" -eq 3 ] && [ "$candidate_minor" -ge 10 ] && [ "$candidate_minor" -le 12 ]; then
            PYTHON_CMD="$candidate_path"
            break
        fi
    fi
done

if [ -n "$PYTHON_CMD" ]; then
    PY_VERSION=$("$PYTHON_CMD" --version 2>&1)
    echo -e "    ${GREEN}✓ Found $PY_VERSION${RESET}"
else
    echo -e "${RED}[ERROR] Supported Python 3.10, 3.11, or 3.12 was not found on your Mac.${RESET}"
    echo -e "Please install Python using Homebrew: ${BOLD}brew install python@3.11${RESET}"
    echo -e "Or download from: https://www.python.org/downloads/macos/"
    exit 1
fi

# 3. Create isolated virtual environment (Solves PEP 668 externally-managed-environment on macOS)
echo -e "[*] Creating isolated Python virtual environment (./venv)..."
VENV_VALID=0
if [ -x "venv/bin/python" ]; then
    VENV_VALID=$(HOST_ARCH="$ARCH" venv/bin/python -c 'import os, platform, sys; print(int(sys.version_info[:2] in ((3, 10), (3, 11), (3, 12)) and platform.machine() == os.environ["HOST_ARCH"]))' 2>/dev/null || echo 0)
fi
if [ "$VENV_VALID" -ne 1 ]; then
    if [ -d "venv" ]; then
        echo -e "    ${YELLOW}Existing venv was created for another Python version or CPU architecture; rebuilding it.${RESET}"
    fi
    "$PYTHON_CMD" -m venv --clear venv
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
venv/bin/python -m pip install --upgrade pip setuptools wheel --quiet

# 6. Install project dependencies
echo -e "[*] Installing the macOS runtime and Keras model dependencies..."
venv/bin/python -m pip install -r requirements-runtime.txt -r requirements-keras.txt

# 7. Check optional Flutter CLI
echo -e "[*] Checking Flutter SDK (for mobile app)..."
if command -v flutter &>/dev/null; then
    FLUTTER_VER=$(flutter --version 2>&1 | head -n 1)
    echo -e "    ${GREEN}✓ Found $FLUTTER_VER${RESET}"
else
    echo -e "    ${YELLOW}ℹ Flutter SDK not detected. The pre-built Flutter app and Python API will still run.${RESET}"
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
    venv/bin/python verify_complete_system.py
fi

echo ""
echo -e "${BOLD}${GREEN}====================================================================${RESET}"
echo -e "${BOLD}${GREEN}       🎉 INSTALLATION & VERIFICATION COMPLETED SUCCESSFULLY!        ${RESET}"
echo -e "${BOLD}${GREEN}====================================================================${RESET}"
echo ""
echo -e "${BOLD}How to launch Drishti-AI:${RESET}"
echo -e "${YELLOW}NOTE: 'source venv/bin/activate' above applied only inside this script."
echo -e "Run ${BOLD}source venv/bin/activate${RESET}${YELLOW} in each new terminal before Python or uvicorn commands.${RESET}"
echo -e "  1. Quick Launch Menu:  ${BOLD}./run_mac.sh${RESET}"
echo -e "  2. Flutter App + API:  ${BOLD}source venv/bin/activate && uvicorn api.main:app --reload${RESET}"
echo -e "     Open the app at:    ${BOLD}http://localhost:8000/app${RESET}"
echo ""
