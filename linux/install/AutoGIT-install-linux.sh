#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="default"
NO_START=0
BRANCH="${BRANCH:-main}"
INTERVAL="${INTERVAL:-5}"
AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-0.2}"
REMOTE_NAME="${REMOTE_NAME:-origin}"
PRESERVE_EXISTING_REMOTE="${PRESERVE_EXISTING_REMOTE:-1}"
REPO_VISIBILITY="${REPO_VISIBILITY:-public}"
API_URL="${API_URL:-https://api.github.com}"

AUTOGIT_DIR="${AUTOGIT_DIR:-$HOME/.autogit}"
AUTH_DIR="${AUTH_DIR:-$HOME/.AUTH}"
BIN_DIR="${BIN_DIR:-$HOME/bin}"
SERVICE_DIR="${SERVICE_DIR:-$HOME/.config/systemd/user}"
TOKEN_FILE="${TOKEN_FILE:-$AUTH_DIR/.GIT_token}"
MAIN_FILE="${MAIN_FILE:-$AUTOGIT_DIR/dirs_main.txt}"
CLONE_FILE="${CLONE_FILE:-$AUTOGIT_DIR/dirs_clone.txt}"
AUTOSAVE_FILE="${AUTOSAVE_FILE:-$AUTOGIT_DIR/autosave_dirs_main.txt}"
AUTOSAVE_CLONE_FILE="${AUTOSAVE_CLONE_FILE:-$AUTOGIT_DIR/autosave_dirs_clone.txt}"
IGNORE_FILE="${IGNORE_FILE:-$AUTOGIT_DIR/ignore_globs.txt}"
AUTOGIT_LOG_FILE="${AUTOGIT_LOG_FILE:-$AUTOGIT_DIR/auto_git.log}"
AUTOGIT_PID_FILE="${AUTOGIT_PID_FILE:-$AUTOGIT_DIR/auto_git.pid}"
AUTOSAVE_LOG_FILE="${AUTOSAVE_LOG_FILE:-$AUTOGIT_DIR/dirwatch.log}"
AUTOSAVE_PID_FILE="${AUTOSAVE_PID_FILE:-$AUTOGIT_DIR/autosave.pid}"
GNOSIS_DISCOVERY_FILE="${GNOSIS_DISCOVERY_FILE:-$AUTOGIT_DIR/gnosis_autogit.env}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$LINUX_DIR/core"
WRAPPER_DIR="$LINUX_DIR/wrappers"
SYSTEMD_DIR="$LINUX_DIR/systemd"
PROFILE_DIR="$LINUX_DIR/profiles"

GIT_SCRIPT_NAME="autogit.sh"
GIT_WRAPPER_NAME="autogit_dirwatch.sh"
SAVE_SCRIPT_NAME="autosave_dirwatch.sh"

GIT_SERVICE_FILE="$SERVICE_DIR/autogit.service"
SAVE_SERVICE_FILE="$SERVICE_DIR/autosave.service"
AUTOGIT_EXECUTABLE="$BIN_DIR/autogit"

log() { echo -e "\033[1;32m[*]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --profile <default|gnosis>  Install preset profile entries (default: default)
  --no-start                  Install services but do not start them
  -h, --help                  Show this help

Environment overrides:
  GIT_USER, BRANCH, INTERVAL, REMOTE_NAME, PRESERVE_EXISTING_REMOTE,
  REPO_VISIBILITY, API_URL, TOKEN_FILE
USAGE
}

require_file() {
  local file_path="$1"
  [[ -f "$file_path" ]] || { err "Missing required file: $file_path"; exit 1; }
}

apply_template() {
  local src="$1" dst="$2"
  sed \
    -e "s|__BIN_DIR__|$BIN_DIR|g" \
    -e "s|__WATCH_FILE__|$MAIN_FILE|g" \
    -e "s|__CLONE_FILE__|$CLONE_FILE|g" \
    -e "s|__LOG_FILE__|$AUTOGIT_LOG_FILE|g" \
    -e "s|__PID_FILE__|$AUTOGIT_PID_FILE|g" \
    -e "s|__IGNORE_FILE__|$IGNORE_FILE|g" \
    -e "s|__INTERVAL__|$INTERVAL|g" \
    -e "s|__BRANCH__|$BRANCH|g" \
    -e "s|__REMOTE_NAME__|$REMOTE_NAME|g" \
    -e "s|__PRESERVE_EXISTING_REMOTE__|$PRESERVE_EXISTING_REMOTE|g" \
    -e "s|__REPO_VISIBILITY__|$REPO_VISIBILITY|g" \
    -e "s|__GIT_USER__|$GIT_USER|g" \
    -e "s|__TOKEN_FILE__|$TOKEN_FILE|g" \
    -e "s|__API_URL__|$API_URL|g" \
    -e "s|__AUTOSAVE_WATCH_FILE__|$AUTOSAVE_FILE|g" \
    -e "s|__AUTOSAVE_CLONE_FILE__|$AUTOSAVE_CLONE_FILE|g" \
    -e "s|__AUTOSAVE_LOG_FILE__|$AUTOSAVE_LOG_FILE|g" \
    -e "s|__AUTOSAVE_PID_FILE__|$AUTOSAVE_PID_FILE|g" \
    -e "s|__AUTOSAVE_INTERVAL__|$AUTOSAVE_INTERVAL|g" \
    "$src" > "$dst"
}

append_unique_entries() {
  local source_file="$1" target_file="$2"
  [[ -f "$source_file" ]] || return 0
  touch "$target_file"
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    local line="$raw"
    line="${line//__HOME__/$HOME}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if ! grep -Fqx "$line" "$target_file"; then
      printf '%s\n' "$line" >> "$target_file"
    fi
  done < "$source_file"
}

ensure_path_entry() {
  local rc_file="$1"
  local line='export PATH="$HOME/bin:$PATH"'
  [[ -f "$rc_file" ]] || : > "$rc_file"
  grep -Fqx "$line" "$rc_file" || printf '%s\n' "$line" >> "$rc_file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      shift
      [[ $# -gt 0 ]] || { err "Missing value for --profile"; exit 1; }
      PROFILE="$1"
      ;;
    --no-start)
      NO_START=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${GIT_USER:-}" ]]; then
  read -rp "Enter your GitHub username: " GIT_USER
fi

if [[ ! -f "$TOKEN_FILE" || ! -s "$TOKEN_FILE" ]]; then
  read -rsp "Enter your GitHub Personal Access Token (repo scope): " TOKEN
  echo
fi

mkdir -p "$AUTOGIT_DIR" "$AUTH_DIR" "$BIN_DIR" "$SERVICE_DIR"

if [[ -n "${TOKEN:-}" ]]; then
  printf '%s\n' "$TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  log "Saved token to $TOKEN_FILE"
fi

for f in "$MAIN_FILE" "$CLONE_FILE" "$AUTOSAVE_FILE" "$AUTOSAVE_CLONE_FILE" "$IGNORE_FILE"; do
  [[ -f "$f" ]] || : > "$f"
done

require_file "$CORE_DIR/$GIT_SCRIPT_NAME"
require_file "$WRAPPER_DIR/$GIT_WRAPPER_NAME"
require_file "$WRAPPER_DIR/$SAVE_SCRIPT_NAME"
require_file "$SYSTEMD_DIR/autogit.service.tpl"
require_file "$SYSTEMD_DIR/autosave.service.tpl"

cp "$CORE_DIR/$GIT_SCRIPT_NAME" "$BIN_DIR/$GIT_SCRIPT_NAME"
cp "$WRAPPER_DIR/$GIT_WRAPPER_NAME" "$BIN_DIR/$GIT_WRAPPER_NAME"
cp "$WRAPPER_DIR/$SAVE_SCRIPT_NAME" "$BIN_DIR/$SAVE_SCRIPT_NAME"
chmod +x "$BIN_DIR/$GIT_SCRIPT_NAME" "$BIN_DIR/$GIT_WRAPPER_NAME" "$BIN_DIR/$SAVE_SCRIPT_NAME"

cat > "$AUTOGIT_EXECUTABLE" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
exec "$BIN_DIR/$GIT_WRAPPER_NAME" "\$@"
EOF
chmod +x "$AUTOGIT_EXECUTABLE"
ensure_path_entry "$HOME/.profile"
ensure_path_entry "$HOME/.zshrc"

cat > "$GNOSIS_DISCOVERY_FILE" <<EOF
AUTOGIT_EXECUTABLE=$AUTOGIT_EXECUTABLE
AUTOGIT_WRAPPER=$BIN_DIR/$GIT_WRAPPER_NAME
AUTOGIT_CORE=$BIN_DIR/$GIT_SCRIPT_NAME
AUTOGIT_INSTALL_OS=linux
AUTOGIT_WATCH_FILE=$MAIN_FILE
AUTOGIT_AUTOSAVE_FILE=$AUTOSAVE_FILE
EOF
log "Installed watcher scripts into $BIN_DIR"

if [[ "$PROFILE" == "gnosis" ]]; then
  append_unique_entries "$PROFILE_DIR/gnosis/dirs_main.txt" "$MAIN_FILE"
  append_unique_entries "$PROFILE_DIR/gnosis/autosave_dirs_main.txt" "$AUTOSAVE_FILE"
  append_unique_entries "$PROFILE_DIR/gnosis/ignore_globs.txt" "$IGNORE_FILE"
  log "Applied GNOSIS profile entries"
elif [[ "$PROFILE" != "default" ]]; then
  err "Unsupported profile: $PROFILE"
  exit 1
fi

apply_template "$SYSTEMD_DIR/autogit.service.tpl" "$GIT_SERVICE_FILE"
apply_template "$SYSTEMD_DIR/autosave.service.tpl" "$SAVE_SERVICE_FILE"
log "Wrote user services in $SERVICE_DIR"

systemctl --user daemon-reload
if [[ "$NO_START" == "1" ]]; then
  log "Skipped service start (--no-start requested)"
else
  systemctl --user enable --now autogit.service
  systemctl --user enable --now autosave.service
  log "Enabled and started autogit.service + autosave.service"
fi

cat <<EOM

AutoGIT Linux installation complete.

Profile: $PROFILE
GitHub user: $GIT_USER
Watch file: $MAIN_FILE
Autosave file: $AUTOSAVE_FILE
Ignore globs: $IGNORE_FILE
GNOSIS discovery: $GNOSIS_DISCOVERY_FILE
Autogit executable: $AUTOGIT_EXECUTABLE

Manage services:
  systemctl --user status autogit.service
  systemctl --user status autosave.service

Ad-hoc run:
  $BIN_DIR/autogit_dirwatch.sh run-once
  $BIN_DIR/autosave_dirwatch.sh run-once
EOM
