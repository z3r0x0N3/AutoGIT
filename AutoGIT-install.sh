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
AUTOSAVE_FILE="$AUTOGIT_DIR/autosave_dirs_main.txt"
AUTOSAVE_CLONE_FILE="$AUTOGIT_DIR/autosave_dirs_clone.txt"
GIT_SCRIPT_NAME="autogit.sh"
SAVE_SCRIPT_NAME="autosave_dirwatch.sh"
GIT_SERVICE_FILE="$SERVICE_DIR/autogit.service"
SAVE_SERVICE_FILE="$SERVICE_DIR/autosave.service"
INSTALL_DIR="$(pwd)"

# === FUNCTIONS ===
log() { echo -e "\033[1;32m[*]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

# === 1. CHECK DEPENDENCIES ===
# inotify-tools is optional; scripts use polling by default.
if ! command -v inotifywait &> /dev/null; then
    warn "'inotifywait' not found. Proceeding without it (optional)."
fi


# === 2. CHECK IF ALREADY INSTALLED ===
if [[ -f "$BIN_DIR/$GIT_SCRIPT_NAME" && -f "$TOKEN_FILE" && -f "$MAIN_FILE" ]]; then
    warn "AutoGit appears to be already installed."
    warn "If you wish to reinstall, delete ~/.autogit, ~/.AUTH, and ~/bin/autogit.sh first."
    exit 0
fi

# === 3. PROMPT FOR USER INPUT ===
echo "=== AutoGit Setup ==="
read -rp "Enter your GitHub username: " GIT_USER
read -rsp "Enter your GitHub Personal Access Token (with 'repo' scope): " TOKEN
echo

# === 4. CREATE FOLDERS ===
mkdir -p "$AUTOGIT_DIR" "$AUTH_DIR" "$BIN_DIR" "$SERVICE_DIR"

# === 5. WRITE TOKEN FILE ===
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    log "Saved GitHub token to $TOKEN_FILE"
else
    warn "Token file already exists, skipping."
fi

# === 6. CREATE WATCH FILES ===
for f in "$MAIN_FILE" "$CLONE_FILE" "$AUTOSAVE_FILE" "$AUTOSAVE_CLONE_FILE"; do
    if [[ ! -f "$f" ]]; then
        echo "# Auto-generated file" > "$f"
        log "Created $f"
    fi
done

# === 7. MOVE SCRIPTS ===
for script in "$GIT_SCRIPT_NAME" "$SAVE_SCRIPT_NAME"; do
    if [[ -f "$INSTALL_DIR/$script" ]]; then
        cp "$INSTALL_DIR/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
        log "Installed $BIN_DIR/$script"
    else
        err "$script not found in current directory!"
        exit 1
    fi
done

# === 8. CREATE SYSTEMD SERVICES ===
cat > "$GIT_SERVICE_FILE" <<EOF
[Unit]
Description=AutoGit Backup Daemon
After=network-online.target

[Service]
ExecStart=$BIN_DIR/$GIT_SCRIPT_NAME run-loop
Restart=always
RestartSec=5
Environment=GIT_USER=$GIT_USER
Environment=TOKEN_FILE=$TOKEN_FILE

[Install]
WantedBy=default.target
EOF
log "Created user service: $GIT_SERVICE_FILE"

cat > "$SAVE_SERVICE_FILE" <<EOF
[Unit]
Description=AutoGit File Saver Daemon

[Service]
ExecStart=$BIN_DIR/$SAVE_SCRIPT_NAME run-loop
Restart=always
RestartSec=1

[Install]
WantedBy=default.target
EOF
log "Created user service: $SAVE_SERVICE_FILE"

# === 9. RELOAD AND ENABLE SERVICES ===
systemctl --user daemon-reload
systemctl --user enable --now autogit.service
systemctl --user enable --now autosave.service
log "AutoGit services started successfully."

# === 10. SUMMARY ===
cat <<EOM

✅ AutoGit installation complete!

GitHub user: $GIT_USER
Token file: $TOKEN_FILE
Watch list: $MAIN_FILE
Autosave list: $AUTOSAVE_FILE
Log files: $AUTOGIT_DIR/
Services: autogit.service, autosave.service

Use 'systemctl --user [status|start|stop] [autogit|autosave].service' to manage.

EOM
