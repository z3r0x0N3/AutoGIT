#!/usr/bin/env bash
# autogit_dirwatch.sh — thin wrapper to manage the AutoGit daemon
# Provides a consistent CLI like autosave_dirwatch.sh while delegating
# to autogit.sh for the actual work (watch, commit, push).

set -Eeuo pipefail
IFS=$'\n\t'

# Defaults align with autogit.sh
WATCH_FILE="${WATCH_FILE:-$HOME/.autogit/dirs_main.txt}"
CLONE_FILE="${CLONE_FILE:-$HOME/.autogit/dirs_clone.txt}"
LOG_FILE="${LOG_FILE:-$HOME/.autogit/auto_git.log}"
PID_FILE="${PID_FILE:-$HOME/.autogit/auto_git.pid}"
IGNORE_FILE="${IGNORE_FILE:-$HOME/.autogit/ignore_globs.txt}"
INTERVAL="${INTERVAL:-5}"
BRANCH="${BRANCH:-main}"
# Only respect GIT_USER if the caller explicitly sets it.
# Do NOT default to the local $USER here, to avoid overriding
# autogit.sh's intended default GitHub username.
GIT_USER="${GIT_USER-}"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.AUTH/.GIT_token}"
API_URL="${API_URL:-https://api.github.com}"

SCRIPT_NAME="$(basename "$0")"

# Locate autogit.sh (prefer user bin, then alongside this wrapper)
AUTOGIT_BIN="${AUTOGIT_BIN:-$HOME/bin/autogit.sh}"
if [[ ! -x "$AUTOGIT_BIN" ]]; then
  ALT="$(cd "$(dirname "$0")" && pwd)/autogit.sh"
  [[ -x "$ALT" ]] && AUTOGIT_BIN="$ALT"
fi

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options] <start|stop|status|run-loop|run-once>

Options:
  -i, --interval <seconds>  Override cycle interval (default: ${INTERVAL})
  -b, --branch <name>       Git branch (default: ${BRANCH})
  -h, --help                Show this help message

Environment overrides are forwarded to autogit.sh:
  WATCH_FILE, CLONE_FILE, LOG_FILE, PID_FILE, IGNORE_FILE, INTERVAL,
  BRANCH, GIT_USER, TOKEN_FILE, API_URL
EOF
}

forward() {
  local subcmd="$1"; shift || true
  if [[ ! -x "$AUTOGIT_BIN" ]]; then
    printf 'Cannot find autogit.sh (looked at %s)\n' "$AUTOGIT_BIN" >&2
    exit 1
  fi
  env \
    WATCH_FILE="$WATCH_FILE" \
    CLONE_FILE="$CLONE_FILE" \
    LOG_FILE="$LOG_FILE" \
    PID_FILE="$PID_FILE" \
    IGNORE_FILE="$IGNORE_FILE" \
    INTERVAL="$INTERVAL" \
    BRANCH="$BRANCH" \
    GIT_USER="$GIT_USER" \
    TOKEN_FILE="$TOKEN_FILE" \
    API_URL="$API_URL" \
    "$AUTOGIT_BIN" "$subcmd" "$@"
}

parse_args_and_dispatch() {
  local args=("$@") cmd="" idx=0 count="${#args[@]}"
  while [[ "$idx" -lt "$count" ]]; do
    local t="${args[$idx]}"; case "$t" in
      start|stop|status|run-loop|run-once) cmd="$t"; idx=$((idx+1)); break;;
      -i|--interval) idx=$((idx+1)); [[ $idx -lt $count ]] || { echo "Missing value for $t" >&2; exit 1; }; INTERVAL="${args[$idx]}" ;;
      -b|--branch)   idx=$((idx+1)); [[ $idx -lt $count ]] || { echo "Missing value for $t" >&2; exit 1; }; BRANCH="${args[$idx]}" ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $t" >&2; usage; exit 1 ;;
    esac
    idx=$((idx+1))
  done
  [[ -n "$cmd" ]] || { usage; exit 1; }
  case "$cmd" in
    start)    forward start ;;
    stop)     forward stop ;;
    status)   forward status ;;
    run-loop) forward run-loop ;;
    run-once) forward run-once ;;
    *) usage; exit 1 ;;
  esac
}

parse_args_and_dispatch "$@"

