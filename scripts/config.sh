#!/bin/sh
set -e
REPO_URL="$1"
GITHUB_TOKEN="$2"
REPO_URL_NO_PROTOCOL=$(echo "$REPO_URL" | sed -e 's/https\?:\/\///')
AUTH_REPO_URL="https://oauth2:${GITHUB_TOKEN}@${REPO_URL_NO_PROTOCOL}"
git config --global user.name "SillyTavern Backup"
git config --global user.email "backup@koyeb"
rm -rf .git
git init
git remote add origin "$AUTH_REPO_URL"
echo "Git remote configured for data repository."
