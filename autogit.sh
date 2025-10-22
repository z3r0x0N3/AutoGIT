#!/usr/bin/env bash
# autogit.sh — checksum-driven multi-repo backup daemon
# - Watches dirs listed in ~/.autogit/dirs_main.txt
# - Computes deterministic 16-digit int (from file metadata) per dir
# - On change: updates main list, ensures a PUBLIC GitHub repo exists,
#   initializes local git if needed, and pushes to origin/<BRANCH>
# - CLI: start | stop | status | run-once | run-loop
# - Logs: ~/.autogit/auto_git.log

set -Eeuo pipefail
IFS=$'\n\t'

# ----- CONFIG (override via env) ---------------------------------------------
WATCH_FILE="${WATCH_FILE:-$HOME/.autogit/dirs_main.txt}"
CLONE_FILE="${CLONE_FILE:-$HOME/.autogit/dirs_clone.txt}"
LOG_FILE="${LOG_FILE:-$HOME/.autogit/auto_git.log}"
PID_FILE="${PID_FILE:-$HOME/.autogit/auto_git.pid}"
IGNORE_FILE="${IGNORE_FILE:-$HOME/.autogit/ignore_globs.txt}"
INTERVAL="${INTERVAL:-5}"
BRANCH="${BRANCH:-main}"

# GitHub settings
GIT_USER="${GIT_USER:-z3r0x0N3}"                  # <--- CHANGE if needed
TOKEN_FILE="${TOKEN_FILE:-$HOME/.AUTH/.GIT_token}" # expects a PAT
API_URL="${API_URL:-https://api.github.com}"
GITHUB_HOST="github.com"

SCRIPT_NAME="$(basename "$0")"
CURRENT_CLONE_TMP=""

# ----- Logging / helpers ------------------------------------------------------
log() {
  local msg="$1"; local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s %s\n' "$ts" "$msg" >> "$LOG_FILE"
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options] <start|stop|status|run-once|run-loop>

Options:
  -i, --interval <seconds>  Override cycle interval (default: ${INTERVAL})
  -h, --help                Show this help message

Environment overrides:
  WATCH_FILE, CLONE_FILE, LOG_FILE, PID_FILE, IGNORE_FILE, INTERVAL, BRANCH,
  GIT_USER, TOKEN_FILE, API_URL
EOF
}

ensure_runtime_paths() {
  mkdir -p "$(dirname "$WATCH_FILE")" "$(dirname "$CLONE_FILE")" \
           "$(dirname "$LOG_FILE")"   "$(dirname "$PID_FILE")"
  touch "$WATCH_FILE" "$CLONE_FILE" "$LOG_FILE"
}

validate_interval() {
  [[ "$INTERVAL" =~ ^[0-9]+$ ]] && [ "$INTERVAL" -gt 0 ] || {
    printf 'Invalid INTERVAL: %s\n' "$INTERVAL" >&2; exit 1; }
}

is_process_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid; pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

write_pid() { echo "$$" > "$PID_FILE"; }

cleanup_and_exit() {
  trap - EXIT INT TERM
  if [[ -f "$PID_FILE" ]] && [[ "$(cat "$PID_FILE" 2>/dev/null || true)" = "$$" ]]; then
    rm -f "$PID_FILE"
    log "Shutdown"
  fi
  exit 0
}

# ----- Ignore patterns --------------------------------------------------------
read_ignore_patterns() {
  local patterns=()
  if [[ -f "$IGNORE_FILE" ]]; then
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
      local line="$raw_line"
      line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" || "$line" == \#* ]] && continue
      [[ "$line" != /* ]] && line="*/${line}"
      line="${line//\*\*/\*}"   # collapse ** to *
      patterns+=("$line")
    done < "$IGNORE_FILE"
  fi
  printf '%s\n' "${patterns[@]}" 2>/dev/null || true
}

# ----- Deterministic 16-digit int from metadata (size + mtime) ----------------
calc_int_for_dir() {
  local dir="$1"
  local ignore_patterns
  mapfile -t ignore_patterns < <(read_ignore_patterns) || true

  local find_cmd=(find "$dir" -type f -not -path '*/.git/*')
  local p
  for p in "${ignore_patterns[@]}"; do
    find_cmd+=(-not -path "$p")
  done

  local raw digits
  raw="$("${find_cmd[@]}" -printf '%s %T@ ' 2>/dev/null | sha256sum | base64 || true)"
  digits="$(printf '%s' "$raw" | tr -dc '0-9' | head -c 16)"
  while [ "${#digits}" -lt 16 ]; do digits="0${digits}"; done
  printf '%s\n' "$digits"
}

# ----- Clone / main file operations ------------------------------------------
update_clone_line() {
  local dir="$1" new_int="$2"
  printf '%s - [ %s ]\n' "$dir" "$new_int" >> "$CURRENT_CLONE_TMP"
}

replace_main_line() {
  local dir="$1" new_int="$2"
  local tmp; tmp="$(mktemp "$(dirname "$WATCH_FILE")/main.XXXXXX")"
  local replaced=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$dir - ["* ]]; then
      printf '%s - [ %s ]\n' "$dir" "$new_int" >> "$tmp"; replaced=1
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$WATCH_FILE"
  [[ "$replaced" -eq 0 ]] && printf '%s - [ %s ]\n' "$dir" "$new_int" >> "$tmp"
  mv "$tmp" "$WATCH_FILE"
}

# ===== GitHub + Git integration (PUBLIC repo auto-creation) ===================

ensure_token() {
  if [[ ! -f "$TOKEN_FILE" ]]; then
    log "No GitHub token at $TOKEN_FILE"
    return 1
  fi
  return 0
}

# Writes a credential line for GitHub into ~/.git-credentials if missing
ensure_credential_entry() {
  local repo_name="$1"
  local token; token="$(<"$TOKEN_FILE")"
  local cred_file="$HOME/.git-credentials"
  local cred_line="https://${GIT_USER}:${token}@${GITHUB_HOST}/${GIT_USER}/${repo_name}.git"

  # Avoid duplicates
  if ! grep -Fq "${GITHUB_HOST}/${GIT_USER}/${repo_name}.git" "$cred_file" 2>/dev/null; then
    mkdir -p "$(dirname "$cred_file")"
    printf '%s\n' "$cred_line" >> "$cred_file"
    chmod 600 "$cred_file" || true
  fi
}

# Ensure GitHub repo exists (PUBLIC). If 404, create it.
ensure_remote_repo_exists_public() {
  local repo_name="$1"
  local token; token="$(<"$TOKEN_FILE")"
  local status
  status="$(curl -s -o /dev/null -w '%{http_code}' \
    -H "Authorization: token ${token}" \
    "${API_URL}/repos/${GIT_USER}/${repo_name}")"

  if [[ "$status" == "404" ]]; then
    log "Creating PUBLIC GitHub repo: ${repo_name}"
    curl -s -H "Authorization: token ${token}" \
         -d "{\"name\":\"${repo_name}\", \"private\":false}" \
         "${API_URL}/user/repos" >/dev/null
  fi
}

# Ensure local repo + remote configured to PUBLIC GitHub repo
ensure_local_repo_and_remote() {
  local dir="$1"
  local repo_name repo_url
  repo_name="$(basename "$dir" | tr ' ' '_' | tr -cd '[:alnum:]_-')"
  repo_url="https://${GITHUB_HOST}/${GIT_USER}/${repo_name}.git"

  # init local repo if missing
  if [[ ! -d "$dir/.git" ]]; then
    log "Initializing local git repo in $dir"
    git -C "$dir" init -b "$BRANCH" >/dev/null 2>&1
  fi

  # set identity + credential helper
  git -C "$dir" config user.name "$GIT_USER"
  git -C "$dir" config user.email "${GIT_USER}@users.noreply.github.com"
  git -C "$dir" config credential.helper store

  ensure_credential_entry "$repo_name"
  ensure_remote_repo_exists_public "$repo_name"

  # set remote
  local existing
  existing="$(git -C "$dir" config --get remote.origin.url || true)"
  if [[ -z "$existing" ]]; then
    git -C "$dir" remote add origin "$repo_url" 2>/dev/null || \
    git -C "$dir" remote set-url origin "$repo_url"
  elif [[ "$existing" != *"/${repo_name}.git" ]]; then
    git -C "$dir" remote set-url origin "$repo_url"
  fi
}

commit_and_push() {
  local dir="$1"
  # stage/commit if any staged deltas; silence harmless “nothing to commit”
  git -C "$dir" add -A >/dev/null 2>&1 || { log "git add failed: $dir"; return 1; }

  if git -C "$dir" diff --cached --quiet >/dev/null 2>&1; then
    log "No staged changes for $dir"; return 0
  fi

  local msg="Auto backup: $(date '+%Y-%m-%d %H:%M:%S')"
  git -C "$dir" commit -m "$msg" >/dev/null 2>&1 || { log "git commit failed: $dir"; return 1; }

  # best-effort rebase (noisy failures are fine)
  git -C "$dir" pull --rebase origin "$BRANCH" >/dev/null 2>&1 || true

  if git -C "$dir" push -u origin "$BRANCH" >/dev/null 2>&1; then
    log "Pushed $dir → origin/$BRANCH"
    return 0
  else
    log "git push failed: $dir"
    return 1
  fi
}

# ----- Main reconciliation on change -----------------------------------------
update_main_and_commit() {
  local dir="$1" new_int="$2" old_int="$3"
  replace_main_line "$dir" "$new_int"
  log "Change detected for $dir ($old_int -> $new_int)"

  # Ensure token present
  if ! ensure_token; then
    log "Skipping git actions (missing token: $TOKEN_FILE)"
    return
  fi

  # Ensure local repo + PUBLIC remote
  ensure_local_repo_and_remote "$dir"

  # Commit/push
  commit_and_push "$dir"
}

# ----- One cycle --------------------------------------------------------------
single_cycle() {
  ensure_runtime_paths

  local lines=()
  [[ -f "$WATCH_FILE" ]] && mapfile -t lines < "$WATCH_FILE" || true

  local tmp_clone; tmp_clone="$(mktemp "$(dirname "$CLONE_FILE")/clone.XXXXXX")"
  CURRENT_CLONE_TMP="$tmp_clone"

  local processed=0
  local line dir trimmed old_int new_int

  for line in "${lines[@]}"; do
    trimmed="$line"
    trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

    if [[ "$trimmed" == *" - ["* ]]; then
      dir="${trimmed%% - [*}"
    else
      dir="$trimmed"
    fi

    [[ -z "$dir" ]] && { log "Skipping malformed line: $trimmed"; continue; }
    [[ -d "$dir" ]] || { log "Directory not found: $dir"; continue; }

    old_int="$(printf '%s\n' "$trimmed" | grep -oE '\[[0-9]{1,16}\]' | tr -dc '0-9' || true)"
    [[ -z "$old_int" ]] && old_int="0000000000000000"

    if ! new_int="$(calc_int_for_dir "$dir")"; then
      log "Failed to hash metadata for $dir"; continue
    fi

    update_clone_line "$dir" "$new_int"
    processed=$((processed + 1))

    if [[ "$new_int" != "$old_int" ]]; then
      update_main_and_commit "$dir" "$new_int" "$old_int"
    fi
  done

  mv "$tmp_clone" "$CLONE_FILE"
  CURRENT_CLONE_TMP=""

  log "Cycle complete (processed $processed directories)"
}

# ----- Loop / Service ---------------------------------------------------------
run_loop() {
  ensure_runtime_paths
  if is_process_running; then exit 0; fi
  write_pid
  log "Startup (PID $$, interval ${INTERVAL}s, branch $BRANCH, user $GIT_USER)"
  trap 'cleanup_and_exit' EXIT INT TERM

  while true; do
    single_cycle || log "Cycle encountered errors"
    sleep "$INTERVAL"
  done
}

start_service() {
  ensure_runtime_paths; validate_interval
  if is_process_running; then
    printf 'AutoGit already running (PID %s)\n' "$(cat "$PID_FILE")"; return 0; fi

  nohup env INTERVAL="$INTERVAL" BRANCH="$BRANCH" WATCH_FILE="$WATCH_FILE" \
    CLONE_FILE="$CLONE_FILE" LOG_FILE="$LOG_FILE" PID_FILE="$PID_FILE" \
    IGNORE_FILE="$IGNORE_FILE" GIT_USER="$GIT_USER" TOKEN_FILE="$TOKEN_FILE" \
    API_URL="$API_URL" "$0" run-loop >/dev/null 2>&1 &

  printf 'AutoGit started (PID %s)\n' "$!"
}

stop_service() {
  if [[ ! -f "$PID_FILE" ]]; then printf 'AutoGit not running\n'; return 0; fi
  local pid; pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PID_FILE"; printf 'AutoGit not running\n'; return 0; fi
  kill "$pid" 2>/dev/null || true
  printf 'Sent termination to AutoGit (PID %s)\n' "$pid"
}

status_service() {
  if is_process_running; then
    printf 'AutoGit running (PID %s)\n' "$(cat "$PID_FILE")"
  else
    printf 'AutoGit not running\n'
  fi
}

run_once() { ensure_runtime_paths; validate_interval; single_cycle; }

# ----- CLI --------------------------------------------------------------------
parse_args_and_dispatch() {
  local args=("$@") cmd="" idx=0 count="${#args[@]}"
  while [[ "$idx" -lt "$count" ]]; do
    local t="${args[$idx]}"
    case "$t" in
      start|stop|status|run-once|run-loop) cmd="$t"; idx=$((idx+1)); break;;
      -i|--interval) idx=$((idx+1)); [[ "$idx" -lt "$count" ]] || { printf 'Missing value for %s\n' "$t" >&2; exit 1; }
                     INTERVAL="${args[$idx]}"; idx=$((idx+1));;
      -h|--help) usage; exit 0;;
      *) printf 'Unknown option: %s\n' "$t" >&2; usage; exit 1;;
    esac
  done
  [[ -n "$cmd" ]] || { usage; exit 1; }
  validate_interval
  case "$cmd" in
    start)    start_service ;;
    stop)     stop_service ;;
    status)   status_service ;;
    run-once) run_once ;;
    run-loop) run_loop ;;
    *) usage; exit 1 ;;
  esac
}

parse_args_and_dispatch "$@"

