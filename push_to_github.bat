@echo off
title Push Drishti-AI to GitHub
color 0B
cls
echo ====================================================================
echo         Pushing Drishti-AI to GitHub
echo         Target: https://github.com/BezaleelPaul/Drishti-AI.git
echo ====================================================================
echo.
echo [*] Pushing branch master to origin...
git push -u origin master
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [!] If push failed, make sure you created the empty repository at:
    echo     https://github.com/new
    echo     with the Repository Name: Drishti-AI
) else (
    color 0A
    echo.
    echo [OK] Successfully pushed all files to GitHub!
)
echo.
pause
