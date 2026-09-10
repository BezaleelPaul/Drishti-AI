#!/usr/bin/env bash
# ==============================================================================
# Drishti-AI / Netra-AI — macOS Quick Launch Center
# ==============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Ensure a usable venv exists (directory alone is not enough)
if [ ! -f "venv/bin/activate" ] || [ ! -x "venv/bin/python" ]; then
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
echo "  [1] Streamlit Central Screening Dashboard (Port 8501) [RECOMMENDED]"
echo "  [2] FastAPI REST Backend Server (Port 8000)"
echo "  [3] Flutter Mobile/Tablet Application (Chrome or macOS Native)"
echo "  [4] Run Full Verification Test Suite (10 Subsystems)"
echo "  [5] Run API Endpoint Tests"
echo "  [6] Exit"
echo ""
read -r -p "Enter choice [1-6] (Default 1): " choice
choice=${choice:-1}

case $choice in
    1)
        echo -e "${GREEN}[*] Launching Streamlit Web App at http://localhost:8501...${RESET}"
        exec "$PYBIN" -m streamlit run demo/app.py --server.port="${PORT:-8501}" --server.address=0.0.0.0
        ;;
    2)
        echo -e "${GREEN}[*] Launching FastAPI REST API at http://localhost:8000...${RESET}"
        echo -e "Interactive Swagger Documentation at: http://localhost:8000/docs"
        exec "$PYBIN" -m uvicorn api.main:app --host 0.0.0.0 --port 8000
        ;;
    3)
        if command -v flutter &>/dev/null; then
            echo -e "${GREEN}[*] Flutter SDK detected. Launching Flutter Application in Chrome...${RESET}"
            (cd flutter_app && flutter run -d chrome)
        else
            echo -e "${YELLOW}[!] Flutter CLI is not installed. Launching pre-compiled ASHA Mobile Client in browser...${RESET}"
            echo -e "${GREEN}[*] Starting FastAPI Backend Bridge and opening http://localhost:8000/app ...${RESET}"
            (command -v open >/dev/null && open "http://localhost:8000/app") 2>/dev/null \
                || (command -v xdg-open >/dev/null && xdg-open "http://localhost:8000/app") 2>/dev/null || true
            exec "$PYBIN" -m uvicorn api.main:app --host 0.0.0.0 --port 8000
        fi
        ;;
    4)
        echo -e "${GREEN}[*] Executing 10-Subsystem Verification Suite...${RESET}"
        "$PYBIN" verify_complete_system.py
        ;;
    5)
        echo -e "${GREEN}[*] Executing FastAPI Endpoint Verification...${RESET}"
        "$PYBIN" test_api_endpoints.py
        ;;
    6)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${YELLOW}[!] Invalid selection: '$choice'. Expected 1-6.${RESET}" >&2
        exit 1
        ;;
esac
