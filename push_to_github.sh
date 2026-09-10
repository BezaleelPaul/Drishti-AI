#!/usr/bin/env bash
set -euo pipefail
# ==============================================================================
# Drishti-AI: Push to GitHub Helper (macOS / Linux)
# Target: https://github.com/BezaleelPaul/Drishti-AI.git
# ==============================================================================

echo "===================================================================="
echo "        Pushing Drishti-AI to GitHub (macOS / Linux)"
echo "        Target: https://github.com/BezaleelPaul/Drishti-AI.git"
echo "===================================================================="
echo ""

BRANCH="$(git branch --show-current)"
if [ -z "$BRANCH" ]; then
  echo "[!] Not on any branch (detached HEAD?) — refusing to push."
  exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "[!] No 'origin' remote configured."
  exit 1
fi

echo "[*] Pushing branch $BRANCH to origin..."
git push -u origin "$BRANCH"

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