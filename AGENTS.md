# Repository Guidelines

## Project Structure & Module Organization
- `autogit.sh` is the core daemon: polls directories from `~/.autogit/dirs_main.txt`, computes checksums, commits, and pushes to GitHub. Keep logic here small and composable.
- `autogit_dirwatch.sh` and `autosave_dirwatch.sh` are user-facing wrappers that set defaults and forward to `autogit.sh`. `AutoGIT-install.sh` provisions `~/bin`, config files, and user services.
- `add_dir.py` provides the Tkinter GUI for editing watch lists; it writes `~/.autogit/dirs_main.txt` and `~/.autogit/autosave_dirs_main.txt`.
- `STATUS-LOGS/` and `tmp_demo_repo/` are for local smoke-testing and should remain free of secrets.

## Build, Test, and Development Commands
- Install fresh: `bash AutoGIT-install.sh` (prompts for GitHub user/token, installs scripts to `~/bin`, enables systemd user services).
- Ad-hoc loop without systemd: `./autogit_dirwatch.sh run-loop` or single pass via `./autogit_dirwatch.sh run-once`. Use `GIT_USER` or `WATCH_FILE` env vars to override defaults.
- AutoSave loop (no Git pushes): `./autosave_dirwatch.sh start`. Check status with `./autogit_dirwatch.sh status` or `systemctl --user status autogit.service`.
- GUI watch manager: `python add_dir.py` (requires Tk on the host).
- Logs live at `~/.autogit/auto_git.log`; tail during changes to confirm commits and pushes.

## Coding Style & Naming Conventions
- Bash: keep `set -Eeuo pipefail`, 2-space indents, `local` for function vars, and uppercase env defaults at the top. Prefer small helpers (`log`, `ensure_*`) and explicit exit codes.
- Python: follow PEP 8 with 4-space indents, type hints for new helpers, f-strings, and early returns. Keep GUI strings centralized and avoid hardcoding paths outside `~/.autogit`.
- Naming: snake_case for files/functions, SCREAMING_SNAKE_CASE for env/config, and imperative function names (e.g., `ensure_runtime_paths`).

## Testing Guidelines
- There is no formal test suite; smoke-test changes with `WATCH_FILE=/tmp/autogit-test.txt ./autogit.sh run-once` against a throwaway directory and verify `~/.autogit/dirs_clone.txt` updates.
- Prefer dry-runs before enabling systemd: run `./autogit_dirwatch.sh run-once` and inspect `auto_git.log` for HTTP/Git errors.
- For shell changes, run `shellcheck autogit.sh autogit_dirwatch.sh autosave_dirwatch.sh` when available. For GUI tweaks, launch `python add_dir.py` and ensure add/remove flows update the files.

## Commit & Pull Request Guidelines
- Use imperative, descriptive subjects (avoid “Auto backup ...”); e.g., `Clarify autogit interval validation`.
- Reference issues when applicable (`Refs #123`) and summarize behavior changes plus manual test commands in the body.
- PRs should note which scripts were exercised (e.g., `./autogit_dirwatch.sh run-once`, `systemctl --user status autogit.service`) and any config changes required for reviewers.

## Security & Configuration Tips
- Never commit personal tokens; they belong in `~/.AUTH/.GIT_token` with `chmod 600`. Confirm `.git-credentials` does not contain unintended usernames.
- Keep `.autogit/ignore_globs.txt` updated to exclude secrets/binaries from pushes. Avoid storing real client data in `tmp_demo_repo/`.
- If changing defaults, document required env vars (`GIT_USER`, `TOKEN_FILE`, `WATCH_FILE`) in README and verify backward compatibility with existing configs.
