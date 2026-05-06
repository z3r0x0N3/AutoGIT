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
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
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
AUTOGIT_STDOUT="${AUTOGIT_STDOUT:-$AUTOGIT_DIR/autogit.launchd.out.log}"
AUTOGIT_STDERR="${AUTOGIT_STDERR:-$AUTOGIT_DIR/autogit.launchd.err.log}"
AUTOSAVE_STDOUT="${AUTOSAVE_STDOUT:-$AUTOGIT_DIR/autosave.launchd.out.log}"
AUTOSAVE_STDERR="${AUTOSAVE_STDERR:-$AUTOGIT_DIR/autosave.launchd.err.log}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MAC_DIR/.." && pwd)"
LAUNCHD_TPL_DIR="$MAC_DIR/launchd"
PROFILE_DIR="$MAC_DIR/profiles"

GIT_SCRIPT_SRC="$REPO_ROOT/autogit.sh"
GIT_WRAPPER_SRC="$REPO_ROOT/autogit_dirwatch.sh"
SAVE_SCRIPT_SRC="$REPO_ROOT/autosave_dirwatch.sh"

AUTOGIT_PLIST="$LAUNCH_AGENTS_DIR/com.autogit.agent.plist"
AUTOSAVE_PLIST="$LAUNCH_AGENTS_DIR/com.autosave.agent.plist"

log() { echo -e "\033[1;32m[*]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --profile <default|gnosis>  Install preset profile entries (default: default)
  --no-start                  Install launch agents but do not start them
  -h, --help                  Show this help
USAGE
}

require_file() {
  local file_path="$1"
  [[ -f "$file_path" ]] || { err "Missing required file: $file_path"; exit 1; }
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

render_plist() {
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
    -e "s|__AUTOGIT_STDOUT__|$AUTOGIT_STDOUT|g" \
    -e "s|__AUTOGIT_STDERR__|$AUTOGIT_STDERR|g" \
    -e "s|__AUTOSAVE_STDOUT__|$AUTOSAVE_STDOUT|g" \
    -e "s|__AUTOSAVE_STDERR__|$AUTOSAVE_STDERR|g" \
    "$src" > "$dst"
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

mkdir -p "$AUTOGIT_DIR" "$AUTH_DIR" "$BIN_DIR" "$LAUNCH_AGENTS_DIR"
[[ -n "${TOKEN:-}" ]] && { printf '%s\n' "$TOKEN" > "$TOKEN_FILE"; chmod 600 "$TOKEN_FILE"; }

for f in "$MAIN_FILE" "$CLONE_FILE" "$AUTOSAVE_FILE" "$AUTOSAVE_CLONE_FILE" "$IGNORE_FILE"; do
  [[ -f "$f" ]] || : > "$f"
done

require_file "$GIT_SCRIPT_SRC"
require_file "$GIT_WRAPPER_SRC"
require_file "$SAVE_SCRIPT_SRC"
require_file "$LAUNCHD_TPL_DIR/com.autogit.agent.plist.tpl"
require_file "$LAUNCHD_TPL_DIR/com.autosave.agent.plist.tpl"

cp "$GIT_SCRIPT_SRC" "$BIN_DIR/autogit.sh"
cp "$GIT_WRAPPER_SRC" "$BIN_DIR/autogit_dirwatch.sh"
cp "$SAVE_SCRIPT_SRC" "$BIN_DIR/autosave_dirwatch.sh"
chmod +x "$BIN_DIR/autogit.sh" "$BIN_DIR/autogit_dirwatch.sh" "$BIN_DIR/autosave_dirwatch.sh"

if [[ "$PROFILE" == "gnosis" ]]; then
  append_unique_entries "$PROFILE_DIR/gnosis/dirs_main.txt" "$MAIN_FILE"
  append_unique_entries "$PROFILE_DIR/gnosis/autosave_dirs_main.txt" "$AUTOSAVE_FILE"
  append_unique_entries "$PROFILE_DIR/gnosis/ignore_globs.txt" "$IGNORE_FILE"
  log "Applied GNOSIS profile entries"
elif [[ "$PROFILE" != "default" ]]; then
  err "Unsupported profile: $PROFILE"
  exit 1
fi

render_plist "$LAUNCHD_TPL_DIR/com.autogit.agent.plist.tpl" "$AUTOGIT_PLIST"
render_plist "$LAUNCHD_TPL_DIR/com.autosave.agent.plist.tpl" "$AUTOSAVE_PLIST"

launchctl bootout "gui/$UID" "$AUTOGIT_PLIST" 2>/dev/null || true
launchctl bootout "gui/$UID" "$AUTOSAVE_PLIST" 2>/dev/null || true

if [[ "$NO_START" == "1" ]]; then
  log "Launch agents installed (not started)"
else
  launchctl bootstrap "gui/$UID" "$AUTOGIT_PLIST"
  launchctl bootstrap "gui/$UID" "$AUTOSAVE_PLIST"
  launchctl kickstart -k "gui/$UID/com.autogit.agent" || true
  launchctl kickstart -k "gui/$UID/com.autosave.agent" || true
  log "Launch agents loaded and started"
fi

cat <<EOM

AutoGIT macOS installation complete.

Profile: $PROFILE
GitHub user: $GIT_USER
Watch file: $MAIN_FILE
Autosave file: $AUTOSAVE_FILE

Manage agents:
  launchctl print gui/$UID/com.autogit.agent
  launchctl print gui/$UID/com.autosave.agent
EOM
