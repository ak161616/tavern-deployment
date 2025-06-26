#!/bin/sh
set -e
git add .
if git diff --cached --quiet; then
    echo "No changes to save."
    exit 0
fi
git commit -m "SillyTavern Auto-Backup: $(date)"
git push -f origin HEAD:main
echo "Save complete."
