#!/usr/bin/env bash
# autosave.sh - Local file watcher (no Git sync)

set -Eeuo pipefail
IFS=$'\n\t'

AUTOSAVE_FILE="${AUTOSAVE_FILE:-$HOME/.autogit/files_autosave.txt}"
LOG_FILE="${LOG_FILE:-$HOME/.autogit/autosave.log}"
PID_FILE="${PID_FILE:-$HOME/.autogit/autosave.pid}"
INTERVAL="${INTERVAL:-0.1}" # 100 ms default poll
SCRIPT_NAME="$(basename "$0")"

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

ensure_runtime_paths() {
  mkdir -p "$(dirname "$AUTOSAVE_FILE")"
  touch "$AUTOSAVE_FILE" "$LOG_FILE"
}

is_running() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null || true)" 2>/dev/null
}

write_pid() { echo "$$" > "$PID_FILE"; }
cleanup() { rm -f "$PID_FILE"; log "Shutdown"; exit 0; }

run_loop() {
  ensure_runtime_paths
  write_pid
  trap cleanup EXIT INT TERM
  log "Startup (PID $$, interval ${INTERVAL}s)"

  if ! command -v inotifywait &>/dev/null; then
    log "ERROR: inotifywait not found. Install inotify-tools."
    exit 1
  fi

  while true; do
    mapfile -t files < <(grep -vE '^#|^$' "$AUTOSAVE_FILE" | xargs -r -d '\n' realpath 2>/dev/null || true)
    (( ${#files[@]} == 0 )) && { log "No files to watch. Sleep 10s."; sleep 10; continue; }

    inotifywait -q -e modify "${files[@]}" |
    while read -r event; do
      file="${event##* }"
      [[ -f "$file" ]] || continue
      log "Detected modification: $file"
      # write-through — read + rewrite to force flush
      tmp="$(mktemp)"
      cat "$file" > "$tmp" && mv "$tmp" "$file"
      sync -f "$file" || true
      log "Flushed $file to disk"
    done
    sleep "$INTERVAL"
  done
}

start_service() {
  ensure_runtime_paths
  if is_running; then echo "AutoSaver already running."; exit 0; fi
  nohup "$0" run-loop >/dev/null 2>&1 &
  echo "$!" > "$PID_FILE"
  echo "AutoSaver started (PID $!)"
}

stop_service() {
  if ! is_running; then echo "AutoSaver not running."; exit 0; fi
  kill "$(cat "$PID_FILE")" && rm -f "$PID_FILE"
  echo "Stopped AutoSaver"
}

status_service() {
  if is_running; then echo "AutoSaver running (PID $(cat "$PID_FILE"))"
  else echo "AutoSaver not running"; fi
}

case "${1:-}" in
  start) start_service ;;
  stop) stop_service ;;
  status) status_service ;;
  run-loop) run_loop ;;
  *) echo "Usage: $SCRIPT_NAME <start|stop|status|run-loop>"; exit 1 ;;
esac

