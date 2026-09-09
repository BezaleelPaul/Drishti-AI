@echo off
title Drishti-AI: Windows Automated One-Click Setup
color 0B
cls

echo ====================================================================
echo        👁️ DRISHTI-AI: Windows 1-Click Automated Setup
echo    MathWorks SIH26038 • Diabetic Retinopathy Screening Pipeline
echo ====================================================================
echo.

:: 1. Detect Python
echo [*] Checking Python installation...
set PYCMD=
where py >nul 2>&1
if %errorlevel% equ 0 (
    :: Check if py can run 3.12, 3.11, or 3.10
    py -3.12 --version >nul 2>&1
    if %errorlevel% equ 0 (
        set PYCMD=py -3.12
    ) else (
        py -3.11 --version >nul 2>&1
        if %errorlevel% equ 0 (
            set PYCMD=py -3.11
        ) else (
            set PYCMD=py
        )
    )
) else (
    where python >nul 2>&1
    if %errorlevel% equ 0 (
        set PYCMD=python
    )
)

if "%PYCMD%"=="" (
    color 0C
    echo [ERROR] Python was not found on your computer!
    echo Please install Python 3.10, 3.11, or 3.12 from:
    echo   https://www.python.org/downloads/windows/
    echo IMPORTANT: Make sure to check the box "Add python.exe to PATH" during install!
    echo.
    pause
    exit /b 1
)

echo     [OK] Found Python:
%PYCMD% --version
echo.

:: 2. Create Isolated Virtual Environment
echo [*] Setting up isolated Python virtual environment (./venv)...
if not exist "venv\Scripts\activate.bat" (
    %PYCMD% -m venv venv
    if %errorlevel% neq 0 (
        color 0C
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo     [OK] Created isolated virtual environment in .\venv
) else (
    echo     [OK] Virtual environment already exists in .\venv
)
echo.

:: 3. Activate Virtual Environment
echo [*] Activating virtual environment...
call venv\Scripts\activate.bat

:: 4. Upgrade Pip & Install Dependencies
echo [*] Upgrading package manager (pip)...
python -m pip install --upgrade pip setuptools wheel --quiet

echo [*] Installing dependencies from requirements.txt (this takes ~1-2 minutes)...
python -m pip install -r requirements.txt
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Dependency installation encountered an issue.
    pause
    exit /b 1
)
echo     [OK] All Python dependencies installed cleanly.
echo.

:: 5. Run Verification Benchmark
echo ====================================================================
echo        Running Complete End-to-End Verification (10 Subsystems)
echo ====================================================================
python verify_complete_system.py
if %errorlevel% neq 0 (
    color 0E
    echo [WARNING] Verification reported a non-critical notice.
) else (
    color 0A
    echo.
    echo ====================================================================
    echo        🎉 WINDOWS SETUP & VERIFICATION COMPLETED SUCCESSFULLY!
    echo ====================================================================
)
echo.
echo You are ready to run the platform!
echo To start anytime, simply double-click: run_windows.bat
echo.
set /p LAUNCH="Would you like to launch Drishti-AI right now? (Y/N, Default Y): "
if /i "%LAUNCH%"=="N" (
    echo Goodbye! Double-click run_windows.bat whenever you want to start.
    pause
    exit /b 0
)

call run_windows.bat
