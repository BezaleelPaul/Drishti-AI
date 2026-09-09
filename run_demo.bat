@echo off
title SIH 2026: AI-Assisted Diabetes & Retinal Screening
cls
echo ====================================================================
echo    SIH 2026: AI-Assisted Diabetes & DR Screening Pipeline
echo    2-Stage Preventive Care & Quality-Gated Triage System
echo ====================================================================
echo.

:: Check for Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    where py >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Python is not installed or not found in system PATH.
        echo Please install Python 3.10+ from https://www.python.org/
        pause
        exit /b 1
    ) else (
        set PYCMD=py
    )
) else (
    set PYCMD=python
)

echo [*] Using Python command: %PYCMD%
%PYCMD% --version

echo [*] Checking and installing required packages...
%PYCMD% -m pip install -r requirements.txt --quiet

echo.
echo [*] Generating demo assets if missing...
%PYCMD% demo/generate_samples.py

echo.
echo ====================================================================
echo  Launching Streamlit Web Application at http://localhost:8501
echo  Press Ctrl+C in this terminal window to stop the server anytime.
echo ====================================================================
echo.
%PYCMD% -m streamlit run demo/app.py

pause
