#!/usr/bin/env bash
# autosave_dirwatch.sh
# Watch directories listed in a local file, detect changes using a 16‑digit
# hash of their contents, and update both the main and clone files.  No Git.

set -Eeuo pipefail
IFS=$'\n\t'

# --- CONFIG: adjust these if you want different file locations -------------
WATCH_FILE="${WATCH_FILE:-$HOME/.autogit/autosave_dirs_main.txt}"
CLONE_FILE="${CLONE_FILE:-$HOME/.autogit/dirs_autosave_clone.txt}"
LOG_FILE="${LOG_FILE:-$HOME/.autogit/dirwatch.log}"
INTERVAL="${INTERVAL:-2}"    # seconds between scans

# --- Helpers ---------------------------------------------------------------
ensure_paths() {
  mkdir -p "$(dirname "$WATCH_FILE")"
  touch "$WATCH_FILE" "$CLONE_FILE" "$LOG_FILE"
}

# Compute a deterministic 16‑digit integer hash for a directory.
calc_int_for_dir() {
  local dir="$1"
  local raw digits
  raw="$(find "$dir" -type f -not -path '*/.git/*' -printf '%s %T@ ' 2>/dev/null \
        | sha256sum | base64 || true)"
  digits="$(printf '%s' "$raw" | tr -dc '0-9' | head -c 16)"
  # Pad to 16 digits if needed
  while [ "${#digits}" -lt 16 ]; do digits="0$digits"; done
  printf '%s\n' "$digits"
}

# Write a line to the clone file (temporary buffer).
update_clone_line() {
  local dir="$1" new_int="$2"
  printf '%s - [ %s ]\n' "$dir" "$new_int" >> "$CLONE_FILE.tmp"
}

# Replace or append a line in the main watch file.
replace_main_line() {
  local dir="$1" new_int="$2"
  local tmp="$WATCH_FILE.tmp"
  local replaced=0
  while IFS='' read -r line || [ -n "$line" ]; do
    if [[ "$line" == "$dir - ["* ]]; then
      printf '%s - [ %s ]\n' "$dir" "$new_int" >> "$tmp"
      replaced=1
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$WATCH_FILE"
  # Append if it wasn’t found
  if [[ "$replaced" -eq 0 ]]; then
    printf '%s - [ %s ]\n' "$dir" "$new_int" >> "$tmp"
  fi
  mv "$tmp" "$WATCH_FILE"
}

# Process one full cycle: compute new hashes and update files.
single_cycle() {
  mapfile -t lines < "$WATCH_FILE" || true
  : > "$CLONE_FILE.tmp"
  local processed=0
  for line in "${lines[@]}"; do
    # Trim whitespace
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    # Skip empty lines and comments
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

    # Parse directory and existing hash
    local dir old_int
    if [[ "$trimmed" == *" - ["* ]]; then
      dir="${trimmed%% - [*}"
      old_int="$(printf '%s\n' "$trimmed" \
                 | grep -oE '\[[0-9]{1,16}\]' | tr -dc '0-9' || true)"
      [[ -z "$old_int" ]] && old_int="0000000000000000"
    else
      dir="$trimmed"
      old_int="0000000000000000"
    fi

    # Only act on real directories
    [[ -d "$dir" ]] || continue

    local new_int
    new_int="$(calc_int_for_dir "$dir")"
    update_clone_line "$dir" "$new_int"
    processed=$((processed + 1))
    if [[ "$new_int" != "$old_int" ]]; then
      replace_main_line "$dir" "$new_int"
      echo "$(date '+%H:%M:%S') [CHANGE] $dir: $old_int → $new_int" \
        >> "$LOG_FILE"
    fi
  done
  mv "$CLONE_FILE.tmp" "$CLONE_FILE"
  echo "$(date '+%H:%M:%S') [INFO] Cycle complete (processed $processed dirs)" \
    >> "$LOG_FILE"
}

# Main loop: keep scanning until stopped
run_loop() {
  ensure_paths
  while true; do
    single_cycle
    sleep "$INTERVAL"
  done
}

# --- CLI entrypoints ---------------------------------------------------------
case "${1:-}" in
  run-loop)  run_loop ;;
  run-once)  ensure_paths; single_cycle ;;
  *)
    echo "Usage: $0 run-loop | run-once"
    ;;
esac

