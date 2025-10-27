#!/usr/bin/env bash
# autosave.sh - file watcher and saver

set -Eeuo pipefail
IFS=$'\n\t'

# ----- CONFIG (override via env) ---------------------------------------------
AUTOSAVE_FILE="${AUTOSAVE_FILE:-"$HOME"/.autogit/files_autosave.txt}"
LOG_FILE="${LOG_FILE:-"$HOME"/.autogit/autosave.log}"
PID_FILE="${PID_FILE:-"$HOME"/.autogit/autosave.pid}"
INTERVAL="${INTERVAL:-0.1}" # 100ms

SCRIPT_NAME="$(basename "$0")"

# ----- Logging / helpers ------------------------------------------------------
log() {
  local msg="$1"; local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s %s\n' "$ts" "$msg" >> "$LOG_FILE"
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <start|stop|status|run-loop>

Options:
  -h, --help                Show this help message

Environment overrides:
  AUTOSAVE_FILE, LOG_FILE, PID_FILE, INTERVAL
EOF
}

ensure_runtime_paths() {
  mkdir -p "$(dirname "$AUTOSAVE_FILE")" \
           "$(dirname "$LOG_FILE")"   "$(dirname "$PID_FILE")"
  touch "$AUTOSAVE_FILE" "$LOG_FILE"
}

is_process_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid; pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

write_pid() { echo "$$ " > "$PID_FILE"; }

cleanup_and_exit() {
  trap - EXIT INT TERM
  if [[ -f "$PID_FILE" ]] && [[ "$(cat "$PID_FILE" 2>/dev/null || true)" = "$$ " ]]; then
    rm -f "$PID_FILE"
    log "Shutdown"
  fi
  exit 0
}

# ----- Main Loop --------------------------------------------------------------
run_loop() {
  ensure_runtime_paths
  if is_process_running; then exit 0; fi
  write_pid
  log "Startup (PID $$ , interval ${INTERVAL}s)"
  trap 'cleanup_and_exit' EXIT INT TERM

  if ! command -v inotifywait &> /dev/null; then
    log "ERROR: inotifywait command not found. Please install inotify-tools."
    exit 1
  fi

  while true; do
    files=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | xargs) # trim whitespace
        if [[ -n "$line" && ! "$line" =~ ^# && -f "$line" ]]; then
            files+=("$line")
        fi
    done < "$AUTOSAVE_FILE"

    if [ ${#files[@]} -eq 0 ]; then
        log "No files to watch. Sleeping for 10 seconds."
        sleep 10
        continue
    fi

    inotifywait -q -e modify "${files[@]}" --timefmt '%Y-%m-%d %H:%M:%S' --format '%T %w %e' |
    while read -r date time file event; do
        log "Modification detected on '$file', saving..."
        # The file is already saved by the editor, so we just log it.
        # In a real scenario, you might add a command here to force a save if needed.
    done
    sleep "$INTERVAL"
  done
}

# ----- Service Commands ------------------------------------------------------
start_service() {
  ensure_runtime_paths
  if is_process_running; then
    printf 'AutoSaver already running (PID %s)\n' "$(cat "$PID_FILE")"; return 0; fi

  nohup env AUTOSAVE_FILE="$AUTOSAVE_FILE" LOG_FILE="$LOG_FILE" \
    PID_FILE="$PID_FILE" INTERVAL="$INTERVAL" "$0" run-loop >/dev/null 2>&1 &

  printf 'AutoSaver started (PID %s)\n' "$!"
}

stop_service() {
  if [[ ! -f "$PID_FILE" ]]; then printf 'AutoSaver not running\n'; return 0; fi
  local pid; pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PID_FILE"; printf 'AutoSaver not running\n'; return 0; fi
  kill "$pid" 2>/dev/null || true
  printf 'Sent termination to AutoSaver (PID %s)\n' "$pid"
}

status_service() {
  if is_process_running;
    then
    printf 'AutoSaver running (PID %s)\n' "$(cat "$PID_FILE")"
  else
    printf 'AutoSaver not running\n'
  fi
}

# ----- CLI --------------------------------------------------------------------
case "${1:-}" in
  start)    start_service ;; 
  stop)     stop_service ;; 
  status)   status_service ;; 
  run-loop) run_loop ;; 
  *) usage; exit 1 ;; 
esac
