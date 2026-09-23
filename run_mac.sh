#!/usr/bin/env bash
# ==============================================================================
# Drishti-AI / Netra-AI — macOS Quick Launch Center
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Ensure a usable venv exists (directory alone is not enough)
if [ ! -f "venv/bin/activate" ] || [ ! -x "venv/bin/python" ] || ! venv/bin/python -c 'import sys; raise SystemExit(0 if sys.version_info[:2] in ((3, 10), (3, 11), (3, 12)) else 1)' 2>/dev/null; then
    echo -e "${YELLOW}[!] Usable virtual environment not found. Running setup first...${RESET}"
    ./setup_mac.sh
fi

source venv/bin/activate
PYBIN="venv/bin/python"

echo -e "${BOLD}${BLUE}====================================================================${RESET}"
echo -e "${BOLD}${BLUE}       👁️ DRISHTI-AI: macOS Application Launch Menu                ${RESET}"
echo -e "${BOLD}${BLUE}====================================================================${RESET}"
echo "Select which application service to launch:"
echo ""
echo "  [1] FastAPI Backend + Flutter App (Port 8000) [RECOMMENDED]"
echo "  [2] Flutter Mobile/Tablet Application (Chrome or macOS Native)"
echo "  [3] Run Full Verification Test Suite (10 Subsystems)"
echo "  [4] Run API Endpoint Tests"
echo "  [5] Exit"
echo ""
read -r -p "Enter choice [1-5] (Default 1): " choice
choice=${choice:-1}

case $choice in
    1)
        echo -e "${GREEN}[*] Launching Flutter App via FastAPI at http://localhost:8000/app...${RESET}"
        (command -v open >/dev/null && open "http://localhost:8000/app") 2>/dev/null \
            || (command -v xdg-open >/dev/null && xdg-open "http://localhost:8000/app") 2>/dev/null || true
        exec "$PYBIN" -m uvicorn api.main:app --host 127.0.0.1 --port "${PORT:-8000}"
        ;;
    2)
        if command -v flutter &>/dev/null; then
            echo -e "${GREEN}[*] Flutter SDK detected. Launching Flutter Application in Chrome...${RESET}"
            (cd flutter_app && flutter run -d chrome)
        else
            echo -e "${YELLOW}[!] Flutter CLI is not installed. Launching pre-compiled ASHA Mobile Client in browser...${RESET}"
            echo -e "${YELLOW}Run option 1 to serve the pre-compiled app at http://localhost:8000/app.${RESET}"
        fi
        ;;
    3)
        echo -e "${GREEN}[*] Executing 10-Subsystem Verification Suite...${RESET}"
        "$PYBIN" verify_complete_system.py
        ;;
    4)
        echo -e "${GREEN}[*] Executing FastAPI Endpoint Verification...${RESET}"
        "$PYBIN" test_api_endpoints.py
        ;;
    5)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${YELLOW}[!] Invalid selection: '$choice'. Expected 1-5.${RESET}" >&2
        exit 1
        ;;
esac
