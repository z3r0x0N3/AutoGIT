#!/usr/bin/env bash
# autosave_dirwatch.sh
#
# Unified directory watcher for AutoSave.  It uses the same
# deterministic change-detection logic as AutoGit (a 16-digit integer
# derived from directory contents) but performs no Git operations.  The
# script reads a list of watched directories from a main file,
# computes a new hash for each directory, and writes an updated clone
# file.  If any directory’s hash has changed, the script replaces the
# entire main file with the clone file so the main list always
# reflects the latest state.

set -Eeuo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# CONFIGURATION
#
# Adjust these variables via environment overrides if you want to use
# different locations.  WATCH_FILE holds the primary list of watched
# directories and their last-known hashes.  CLONE_FILE holds the
# current cycle’s complete snapshot.  On each cycle the script will
# write a temporary clone file and, if any hash mismatch is detected,
# will atomically replace WATCH_FILE with the updated clone.
#
WATCH_FILE="${WATCH_FILE:-$HOME/.autogit/autosave_dirs_main.txt}"
CLONE_FILE="${CLONE_FILE:-$HOME/.autogit/autosave_dirs_clone.txt}"
LOG_FILE="${LOG_FILE:-$HOME/.autogit/dirwatch.log}"
INTERVAL="${INTERVAL:-.2}"  # seconds between detection cycles

# ---------------------------------------------------------------------------
# Ensure necessary directories and files exist.  The watch and clone
# directories are created as needed.  An empty main file is created if
# none exists.
ensure_paths() {
  mkdir -p "$(dirname "$WATCH_FILE")"
  touch "$WATCH_FILE" "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Compute a deterministic 16-digit integer based on directory metadata.
# This function hashes the size and mtime of all files under the
# directory (excluding any .git folder), produces a SHA-256, encodes
# it with base64, extracts digits, and pads/truncates to 16 digits.
calc_int_for_dir() {
  local dir="$1"
  local raw digits
  raw="$(find "$dir" -type f -not -path '*/.git/*' -printf '%s %T@ ' 2>/dev/null | sha256sum | base64 || true)"
  digits="$(printf '%s' "$raw" | tr -dc '0-9' | head -c 16)"
  while [ "${#digits}" -lt 16 ]; do
    digits="0$digits"
  done
  printf '%s\n' "$digits"
}

# ---------------------------------------------------------------------------
# Write a line to the new clone snapshot.  Called by single_cycle().
update_clone_line() {
  local dir="$1" new_int="$2"
  printf '%s - [ %s ]\n' "$dir" "$new_int" >> "$CLONE_TMP"
}

# ---------------------------------------------------------------------------
# Determine whether the main file differs from the new clone.  If any
# difference exists, atomically replace the main file with the clone
# snapshot.  This ensures the main file always reflects the current
# state without partial updates.
update_main_if_needed() {
  # If main and clone are identical, do nothing
  if cmp -s "$CLONE_TMP" "$WATCH_FILE"; then
    return
  fi
  mv "$CLONE_TMP" "$WATCH_FILE"
  cp "$WATCH_FILE" "$CLONE_FILE"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "[REPLACED] Updated $WATCH_FILE from new clone" >> "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Process one full detection cycle.  Read each non-comment line from
# WATCH_FILE, compute its new integer, append the line to the clone
# snapshot, and track if any hash mismatches occur.
single_cycle() {
  : > "$CLONE_TMP"
  mapfile -t lines < "$WATCH_FILE" || true
  local changes=0
  for line in "${lines[@]}"; do
    # Trim whitespace
    local trimmed="${line#${line%%[![:space:]]*}}"
    trimmed="${trimmed%${trimmed##*[![:space:]]}}"
    # Skip blank lines and comments
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
    local dir old_int
    if [[ "$trimmed" == *" - ["* ]]; then
      dir="${trimmed%% - [*}"
      old_int="$(printf '%s\n' "$trimmed" | grep -oE '\[[0-9]{1,16}\]' | tr -dc '0-9' || true)"
      [[ -z "$old_int" ]] && old_int="0000000000000000"
    else
      dir="$trimmed"
      old_int="0000000000000000"
    fi
    # Only process existing directories
    [[ -d "$dir" ]] || continue
    local new_int
    new_int="$(calc_int_for_dir "$dir")"
    update_clone_line "$dir" "$new_int"
    if [[ "$new_int" != "$old_int" ]]; then
      changes=$((changes + 1))
      printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "[CHANGE] $dir: $old_int -> $new_int" >> "$LOG_FILE"
    fi
  done
  # Replace main file if any changes detected
  update_main_if_needed
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "[INFO] Cycle complete (changes=$changes)" >> "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Run detection cycles indefinitely at INTERVAL seconds.  A temporary
# clone file is created for each cycle.  The log captures both
# replacements and normal cycle completions.
run_loop() {
  ensure_paths
  while true; do
    CLONE_TMP="$(mktemp -p "$(dirname "$CLONE_FILE")" autosave_clone.XXXXXX)"
    single_cycle
    rm -f "$CLONE_TMP" 2>/dev/null || true
    sleep "$INTERVAL"
  done
}

# ---------------------------------------------------------------------------
# CLI dispatch.  Use run-loop for continuous monitoring, or run-once
# for a single detection pass (useful for testing or manual update).
case "${1:-}" in
  run-loop) run_loop ;;
  run-once)
    ensure_paths
    CLONE_TMP="$(mktemp -p "$(dirname "$CLONE_FILE")" autosave_clone.XXXXXX)"
    single_cycle
    rm -f "$CLONE_TMP" 2>/dev/null || true
    ;;
  *)
    echo "Usage: $0 run-loop | run-once" >&2
    exit 1
    ;;
esac
