#!/usr/bin/env bash
# === git-auto.sh ===
# Automates git add/commit/push using a stored GitHub token for HTTPS repos

set -euo pipefail

# ---------- CONFIG ----------
GIT_USER="z3r0x0N3"
REPO_URL="https://github.com/${GIT_USER}/z3r0-Theme.git"
BRANCH="main"
TOKEN_FILE="${HOME}/.AUTH/.GIT_token"
# ----------------------------

if [ ! -f "$TOKEN_FILE" ]; then
    echo "[!] No GitHub token found."
    echo "    Generate one at: https://github.com/settings/tokens"
    echo "    -> Fine-grained or classic, scopes: repo, write:packages"
    echo
    read -rsp "Paste your token: " TOKEN
    echo
    echo "$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo "[+] Token saved to $TOKEN_FILE"
fi

TOKEN=$(<"$TOKEN_FILE")

# Extract repo name automatically if not set
CURRENT_REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [ -z "$CURRENT_REPO_URL" ]; then
    echo "[*] Setting remote to $REPO_URL"
    git remote add origin "$REPO_URL"
fi

# Use the stored token to authenticate
git config credential.helper store
git config user.name "$GIT_USER"
git config user.email "${GIT_USER}@users.noreply.github.com"

# Update stored credentials silently
CRED_FILE="${HOME}/.git-credentials"
if ! grep -q "${REPO_URL}" "$CRED_FILE" 2>/dev/null; then
    echo "https://${GIT_USER}:${TOKEN}@github.com/${GIT_USER}/z3r0-Theme.git" >> "$CRED_FILE"
fi

# Auto add + commit
git add -A
COMMIT_MSG="${1:-Auto commit $(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
git commit -m "$COMMIT_MSG" || echo "[i] No changes to commit."

# Always pull/rebase before pushing to prevent rejection
git pull --rebase origin "$BRANCH" || echo "[i] Nothing to rebase."

# Push silently
git push -u origin "$BRANCH"
echo "[✓] Synced with GitHub as ${GIT_USER}/z3r0-Theme"

