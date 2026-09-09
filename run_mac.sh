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

# Ensure venv exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}[!] Virtual environment not found. Running setup first...${RESET}"
    ./setup_mac.sh
fi

source venv/bin/activate

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
read -p "Enter choice [1-6] (Default 1): " choice
choice=${choice:-1}

case $choice in
    1)
        echo -e "${GREEN}[*] Launching Streamlit Web App at http://localhost:8501...${RESET}"
        streamlit run demo/app.py
        ;;
    2)
        echo -e "${GREEN}[*] Launching FastAPI REST API at http://localhost:8000...${RESET}"
        echo -e "Interactive Swagger Documentation at: http://localhost:8000/docs"
        uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
        ;;
    3)
        if ! command -v flutter &>/dev/null; then
            echo -e "${YELLOW}[!] Flutter CLI is not installed on your system.${RESET}"
            echo -e "Please install Flutter from https://docs.flutter.dev/get-started/install/macos"
            exit 1
        fi
        cd flutter_app
        echo -e "${GREEN}[*] Launching Flutter Application in Chrome...${RESET}"
        flutter run -d chrome
        ;;
    4)
        echo -e "${GREEN}[*] Executing 10-Subsystem Verification Suite...${RESET}"
        python verify_complete_system.py
        ;;
    5)
        echo -e "${GREEN}[*] Executing FastAPI Endpoint Verification...${RESET}"
        python test_api_endpoints.py
        ;;
    6)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid selection. Defaulting to Streamlit Web App..."
        streamlit run demo/app.py
        ;;
esac
