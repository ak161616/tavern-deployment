#!/bin/sh
set -e
if ! git ls-remote --exit-code --heads origin main > /dev/null 2>&1; then
    echo "Remote branch 'main' not found or repo is empty. Skipping load."
    exit 0
fi
echo "Fetching latest data from remote..."
git fetch origin main
git reset --hard origin/main
echo "Load complete."
