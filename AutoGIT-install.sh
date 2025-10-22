#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
AUTOGIT_DIR="$HOME/.autogit"
AUTH_DIR="$HOME/.AUTH"
BIN_DIR="$HOME/bin"
SERVICE_DIR="$HOME/.config/systemd/user"
TOKEN_FILE="$AUTH_DIR/.GIT_token"
MAIN_FILE="$AUTOGIT_DIR/dirs_main.txt"
CLONE_FILE="$AUTOGIT_DIR/dirs_clone.txt"
SCRIPT_NAME="autogit.sh"
SERVICE_FILE="$SERVICE_DIR/autogit.service"
INSTALL_DIR="$(pwd)"

# === FUNCTIONS ===
log() { echo -e "\033[1;32m[*]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

# === 1. CHECK IF ALREADY INSTALLED ===
if [[ -f "$BIN_DIR/$SCRIPT_NAME" && -f "$TOKEN_FILE" && -f "$MAIN_FILE" ]]; then
    warn "AutoGit appears to be already installed."
    warn "Use the following commands:

  systemctl --user status autogit.service     # check status
  systemctl --user stop autogit.service       # stop
  systemctl --user start autogit.service      # start
  tail -f ~/.autogit/auto_git.log             # watch activity log

To manually add a new directory:
  echo '/path/to/project - [0000000000000000]' >> ~/.autogit/dirs_main.txt"
    echo
    echo "If you wish to reinstall, delete ~/.autogit, ~/.AUTH, and ~/bin/autogit.sh first."
    exit 0
fi

# === 2. PROMPT FOR USER INPUT ===
echo "=== AutoGit Setup ==="
read -rp "Enter your GitHub username: " GIT_USER
read -rsp "Enter your GitHub Personal Access Token (with 'repo' scope): " TOKEN
echo

# === 3. CREATE FOLDERS ===
mkdir -p "$AUTOGIT_DIR" "$AUTH_DIR" "$BIN_DIR" "$SERVICE_DIR"

# === 4. WRITE TOKEN FILE ===
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    log "Saved GitHub token to $TOKEN_FILE"
else
    warn "Token file already exists, skipping."
fi

# === 5. CREATE WATCH FILES ===
if [[ ! -f "$MAIN_FILE" ]]; then
    echo "# /abs/path/to/repo - [0000000000000000]" > "$MAIN_FILE"
    log "Created $MAIN_FILE"
fi

if [[ ! -f "$CLONE_FILE" ]]; then
    cp "$MAIN_FILE" "$CLONE_FILE"
    log "Created $CLONE_FILE"
fi

# === 6. MOVE autogit.sh SCRIPT ===
if [[ -f "$INSTALL_DIR/autogit.sh" ]]; then
    cp "$INSTALL_DIR/autogit.sh" "$BIN_DIR/"
    chmod +x "$BIN_DIR/autogit.sh"
    log "Installed $BIN_DIR/autogit.sh"
else
    err "autogit.sh not found in current directory!"
    exit 1
fi

# === 7. CREATE SYSTEMD SERVICE ===
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AutoGit Backup Daemon
After=network-online.target

[Service]
ExecStart=$BIN_DIR/autogit.sh run-loop
Restart=always
RestartSec=5
Environment=GIT_USER=$GIT_USER
Environment=TOKEN_FILE=$TOKEN_FILE
Environment=BRANCH=main
Environment=WATCH_FILE=$MAIN_FILE
Environment=CLONE_FILE=$CLONE_FILE
Environment=LOG_FILE=$AUTOGIT_DIR/auto_git.log
Environment=PID_FILE=$AUTOGIT_DIR/auto_git.pid

[Install]
WantedBy=default.target
EOF

log "Created user service: $SERVICE_FILE"

# === 8. RELOAD AND ENABLE SERVICE ===
systemctl --user daemon-reload
systemctl --user enable --now autogit.service
log "AutoGit systemd service started successfully."

# === 9. SUMMARY ===
cat <<EOM

✅ AutoGit installation complete!

GitHub user: $GIT_USER
Token file: $TOKEN_FILE
Watch list: $MAIN_FILE
Log file: $AUTOGIT_DIR/auto_git.log
Service: $SERVICE_FILE

Use the following commands:

  systemctl --user status autogit.service     # check status
  systemctl --user stop autogit.service       # stop
  systemctl --user start autogit.service      # start
  tail -f ~/.autogit/auto_git.log             # watch activity log

To manually add a new directory:
  echo "/path/to/project - [0000000000000000]" >> ~/.autogit/dirs_main.txt

EOM

