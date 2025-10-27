#!/usr/bin/env bash
# ===================================================================
# AutoSave Unified Watcher — by Z3R0
# Watches files listed in ~/.autogit/files_autosave.txt
# Detects changes instantly using inotifywait and auto-saves to disk.
# ===================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# --- CONFIG ---
AUTOSAVE_FILE="${AUTOSAVE_FILE:-$HOME/.autogit/files_autosave.txt}"
LOG_FILE="${LOG_FILE:-$HOME/.autogit/autosave.log}"
PID_FILE="${PID_FILE:-$HOME/.autogit/autosave.pid}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.autogit/backups}"
INTERVAL="${INTERVAL:-0.05}"  # 50ms debounce between events

mkdir -p "$(dirname "$AUTOSAVE_FILE")" "$BACKUP_DIR"
touch "$AUTOSAVE_FILE" "$LOG_FILE"

# --- HELPERS ---
log() {
  local msg="$1"; local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$ts  $msg" | tee -a "$LOG_FILE" >/dev/null
}

is_running() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null || true)" 2>/dev/null
}

write_pid() { echo "$$" > "$PID_FILE"; }

cleanup() {
  rm -f "$PID_FILE"
  log "[⚠️] AutoSave stopped"
  exit 0
}

# --- CORE DETECTION + SAVE ---
run_saver() {
  write_pid
  trap cleanup EXIT INT TERM
  log "[🚀] AutoSave started (PID $$)"

  while true; do
    mapfile -t targets < <(grep -vE '^\s*#|^\s*$' "$AUTOSAVE_FILE" | xargs -r -d '\n' realpath 2>/dev/null || true)

    if [[ ${#targets[@]} -eq 0 ]]; then
      log "[⚠️] No files listed. Sleeping 10s..."
      sleep 10
      continue
    fi

    log "[👀] Watching ${#targets[@]} files..."
    inotifywait -q -m -e modify,close_write,move,create,delete "${targets[@]}" \
      --format '%e|%w%f' |
    while IFS='|' read -r event path; do
      [[ -z "$path" ]] && continue

      # Handle modification or creation
      if [[ "$event" =~ MODIFY|CLOSE_WRITE|CREATE ]]; then
        if [[ -f "$path" ]]; then
          backup_name="$(basename "$path")_$(date +%Y%m%d_%H%M%S).bak"
          cp "$path" "$BACKUP_DIR/$backup_name"
          log "[💾] Saved change → $path  (backup: $backup_name)"
        fi
      fi

      # Handle deletion
      if [[ "$event" =~ DELETE ]]; then
        log "[❌] File deleted → $path"
      fi

      sleep "$INTERVAL"
    done
  done
}

# --- SERVICE CONTROL ---
start_service() {
  if is_running; then
    log "[ℹ️] Already running (PID $(cat "$PID_FILE"))"
    exit 0
  fi
  nohup "$0" run >/dev/null 2>&1 &
  log "[✅] Started AutoSave in background (PID $!)"
}

stop_service() {
  if is_running; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    log "[🛑] AutoSave stopped manually"
  else
    log "[ℹ️] No active AutoSave process"
  fi
}

status_service() {
  if is_running; then
    echo "AutoSave running (PID $(cat "$PID_FILE"))"
  else
    echo "AutoSave not running"
  fi
}

# --- CLI ENTRY ---
case "${1:-}" in
  start) start_service ;;
  stop) stop_service ;;
  status) status_service ;;
  run) run_saver ;;
  *) echo "Usage: $0 {start|stop|status|run}" ;;
esac

