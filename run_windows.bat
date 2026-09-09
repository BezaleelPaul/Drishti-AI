@echo off
title Drishti-AI: Windows Application Launch Center
color 0F
cls

:: Check virtual environment
if not exist "venv\Scripts\activate.bat" (
    color 0E
    echo [!] Virtual environment not found. Running 1-click setup first...
    echo.
    call setup_windows.bat
    exit /b 0
)

call venv\Scripts\activate.bat

:MENU
cls
color 0B
echo ====================================================================
echo        👁️ DRISHTI-AI: Windows Application Launch Center
echo    MathWorks SIH26038 • Multi-Platform Screening Ecosystem
echo ====================================================================
echo.
echo Select which application component to run:
echo.
echo   [1] Central Doctor Dashboard (Streamlit Web UI)  [RECOMMENDED]
echo       - Full 2-model screening, Grad-CAM++, PDF, FHIR, CSME risk
echo       - Opens automatically in browser: http://localhost:8501
echo.
echo   [2] FastAPI REST Server + Embedded Flutter Mobile App
echo       - High-speed REST backend on http://localhost:8000
echo       - Includes Flutter Web App pre-built at: http://localhost:8000/app
echo       - Swagger API documentation at: http://localhost:8000/docs
echo.
echo   [3] Flutter Mobile / Tablet Client (Native Chrome Launch)
echo       - Requires Flutter SDK installed
echo.
echo   [4] Run Full System Verification Suite (10 Subsystems)
echo       - Benchmarks Model 1, Model 2, Segmentation, CLAHE, Simulink
echo.
echo   [5] Run FastAPI Endpoint Verification Tests
echo.
echo   [6] Exit
echo.
echo ====================================================================
set /p CHOICE="Enter choice [1-6] (Default 1): "
if "%CHOICE%"=="" set CHOICE=1

if "%CHOICE%"=="1" goto STREAMLIT
if "%CHOICE%"=="2" goto API
if "%CHOICE%"=="3" goto FLUTTER
if "%CHOICE%"=="4" goto VERIFY
if "%CHOICE%"=="5" goto APITEST
if "%CHOICE%"=="6" goto EXIT

echo Invalid selection. Please choose 1 to 6.
timeout /t 2 >nul
goto MENU

:STREAMLIT
cls
echo [*] Launching Central Doctor Screening Dashboard at http://localhost:8501...
echo [*] Press Ctrl+C in this window anytime to stop the server.
echo.
start "" "http://localhost:8501" 2>nul
python -m streamlit run demo/app.py
pause
goto MENU

:API
cls
echo [*] Launching FastAPI Backend Server at http://localhost:8000...
echo [*] Pre-compiled Flutter Mobile App: http://localhost:8000/app
echo [*] Interactive Swagger Documentation: http://localhost:8000/docs
echo [*] Press Ctrl+C in this window anytime to stop the server.
echo.
start "" "http://localhost:8000/app" 2>nul
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
pause
goto MENU

:FLUTTER
cls
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    color 0E
    echo [!] Flutter CLI was not found in your system PATH.
    echo Don't worry! You can run the Flutter app directly through Option [2]
    echo which serves the pre-compiled Web version at http://localhost:8000/app
    echo.
    echo If you want to develop natively in Flutter, install from: https://docs.flutter.dev/
    echo.
    pause
    goto MENU
)
echo [*] Launching Flutter Mobile Application in Chrome...
cd flutter_app
flutter run -d chrome
cd ..
pause
goto MENU

:VERIFY
cls
echo [*] Running 10-Subsystem Verification Suite...
python verify_complete_system.py
echo.
pause
goto MENU

:APITEST
cls
echo [*] Running FastAPI REST Endpoint Verification...
python test_api_endpoints.py
echo.
pause
goto MENU

:EXIT
cls
echo Thank you for using Drishti-AI! Goodbye.
timeout /t 2 >nul
exit /b 0
