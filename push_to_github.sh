#!/usr/bin/env bash
# ==============================================================================
# Drishti-AI: Push to GitHub Helper (macOS / Linux)
# Target: https://github.com/BezaleelPaul/Drishti-AI.git
# ==============================================================================

echo "===================================================================="
echo "        Pushing Drishti-AI to GitHub (macOS / Linux)"
echo "        Target: https://github.com/BezaleelPaul/Drishti-AI.git"
echo "===================================================================="
echo ""

echo "[*] Pushing branch master to origin..."
git push -u origin master

if [ $? -ne 0 ]; then
    echo ""
    echo "[!] Push failed. Please check:"
    echo "    1. You are authenticated with GitHub (run: gh auth login or configure personal access token)."
    echo "    2. The repository exists at: https://github.com/BezaleelPaul/Drishti-AI"
else
    echo ""
    echo "[OK] Successfully pushed all files to GitHub!"
fi
echo ""