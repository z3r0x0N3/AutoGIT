# AutoGIT Deep Analysis Report (2025-11-13)

This report summarizes a recursive inspection of the repository rooted at the current working directory. It catalogs imports, environment variables, services/endpoints, and configuration, and provides a dependency graph and prioritized recommendations.

## Summary
- Small project with one Python GUI (`add_dir.py`) and several Bash daemons (`autogit.sh`, `autogit_dirwatch.sh`, `autosave_dirwatch.sh`) plus an installer (`AutoGIT-install.sh`) and a legacy helper (`auto.sh`).
- Primary function: watch configured directories, compute a deterministic 16‑digit change signal, and commit/push (AutoGit) or just track (AutoSave).
- User‑level systemd services are used for long‑running operation. GitHub API is used to auto‑create public repos when needed.

## Security Assessment
- Token handling
  - `autogit.sh` writes credentials to `~/.git-credentials` (plaintext token in URL). High risk if the machine is compromised or the file is synced/backed up. Consider SSH or a secure credential helper.
  - Token is read from `~/.AUTH/.GIT_token` and permissions are set by installer to 600 (good). Ensure this remains restricted.
- Public repo creation by default
  - `ensure_remote_repo_exists_public` creates public GitHub repos by default. Risk of inadvertent data exposure. Make private the default or configurable.
- Shell execution from GUI
  - `add_dir.py` uses `os.system` with static paths for `xdg-open` and daemon scripts. While inputs are controlled, swapping to `subprocess.run([...])` avoids shell interpolation risks.
- Service permissions
  - Services run as user (`systemd --user`) which appropriately limits privileges. No `sudo` usage detected in runtime scripts.
- Logging
  - Logs do not include secrets but ensure log rotation and safe permissions for `~/.autogit/*.log`.

## Performance Assessment
- Polling vs events
  - `autosave_dirwatch.sh` default `INTERVAL=.2` seconds triggers frequent `find`+hash over directories. This can be CPU/IO heavy at scale. Prefer inotify (`inotifywait`) or increase interval.
  - `autogit.sh` default `INTERVAL=5` seconds is more conservative but still scales linearly with monitored content size.
- Hashing strategy
  - Change signal uses file size and mtime aggregated, hashed, then digits extracted. Efficient and adequate for change detection but not collision‑resistant; acceptable for this use.
- Git operations
  - For changed dirs: local commit and optional push with a best‑effort `pull --rebase`. Reasonable; consider batching for many repos.

## UI/UX Assessment
- Tkinter GUI is straightforward and responsive with a 5s status poll. Accessibility is minimal (keyboard focus, screen reader) but acceptable for a small tool. Colors are high‑contrast; buttons consistent.
- The GUI assumes scripts in `~/bin/`. Consider detecting local script paths as `autogit_dirwatch.sh` does.

## Configuration Findings
- Installer creates user services: `autogit.service` and `autosave.service` with `Restart=always` and sensible defaults. `autogit.service` depends on `network-online.target`.
- Watch lists and logs stored under `~/.autogit/`. Token under `~/.AUTH/.GIT_token`.
- `GIT_USER` default in `autogit.sh` is a hardcoded username (`z3r0x0N3`). Users must override or edit; wrapper script optionally forwards `GIT_USER`.

## Discovered Imports, Env Vars, Endpoints
- Python imports (add_dir.py): `os`, `tkinter` (tk, ttk, messagebox, filedialog), `subprocess`, `datetime`.
- Shell environment variables
  - autogit.sh: WATCH_FILE, CLONE_FILE, LOG_FILE, PID_FILE, IGNORE_FILE, INTERVAL, BRANCH, GIT_USER, TOKEN_FILE, API_URL, GITHUB_HOST
  - autogit_dirwatch.sh: WATCH_FILE, CLONE_FILE, LOG_FILE, PID_FILE, IGNORE_FILE, INTERVAL, BRANCH, GIT_USER (optional), TOKEN_FILE, API_URL, AUTOGIT_BIN
  - autosave_dirwatch.sh: WATCH_FILE, CLONE_FILE, LOG_FILE, PID_FILE, INTERVAL
  - auto.sh: MAIN_FILE, CLONE_FILE, BRANCH, INTERVAL, LOG_FILE
- Services/commands: `systemctl --user` (autogit.service, autosave.service), `git`, `curl` (GitHub API)
- Network endpoints: `https://api.github.com`, `github.com`

## Notable Files and Status
- Present: `add_dir.py`, `autogit.sh`, `autogit_dirwatch.sh`, `autosave_dirwatch.sh`, `AutoGIT-install.sh`, `auto.sh`, `README.md`
- Not found (requested for logging): `c2.py`, any `indeh.html`, `bot.py` at repo root

## Recommendations (Priority)
1) Secrets and Credentials
   - Avoid storing tokens in `~/.git-credentials`. Prefer SSH remotes or a secure credential helper (e.g., `git credential-manager`, `gh auth login`) and remove the plaintext token entry.
   - Keep `~/.AUTH/.GIT_token` mode 600 and outside of VCS (already OK).
2) Default Privacy
   - Default new repos to PRIVATE; add `PUBLIC=true` flag or config to opt in.
3) Efficiency
   - Use inotify (`inotifywait`) for change detection where available; otherwise increase `INTERVAL` for `autosave_dirwatch.sh`.
4) Robustness
   - Replace `os.system(...)` in `add_dir.py` with `subprocess.run([...], check=False)` to avoid shell interpretation and improve error handling.
   - Make `GIT_USER` mandatory or validate it at startup; remove hardcoded default from `autogit.sh` to prevent accidental pushes to the wrong account.
5) UX polish
   - Auto‑detect `autogit.sh` and `autosave_dirwatch.sh` paths in the GUI like the wrapper does; surface daemon errors in‑app.

## Dependency Graph
- See `STATUS-LOGS/dependency-graph.dot` for a Graphviz representation.

## Paths captured for follow‑up
- add_dir.py
- autogit.sh
- autogit_dirwatch.sh
- autosave_dirwatch.sh
- AutoGIT-install.sh
- auto.sh
- README.md
- Missing: c2.py, indeh.html, bot.py (not present)
