# AutoGIT

Automated git updates and autosave directory monitoring.

## Platform architecture

The project now includes platform-separated installer trees in root:

- `linux/core/autogit.sh`
- `linux/wrappers/autogit_dirwatch.sh`
- `linux/wrappers/autosave_dirwatch.sh`
- `linux/install/AutoGIT-install-linux.sh`
- `linux/systemd/*.service.tpl`
- `linux/profiles/gnosis/*`
- `mac/install/AutoGIT-install-mac.sh`
- `mac/launchd/*.plist.tpl`
- `mac/profiles/gnosis/*`
- `windows/install/AutoGIT-install-windows.ps1`
- `windows/tasks/*`
- `windows/profiles/gnosis/*`

`AutoGIT-install.sh` at repo root is the compatibility entrypoint and forwards to the Linux installer.

## Installation

Linux (default):

```bash
bash AutoGIT-install.sh
```

Linux GNOSIS profile:

```bash
bash AutoGIT-install.sh --profile gnosis
```

Linux skip auto-start:

```bash
bash AutoGIT-install.sh --profile gnosis --no-start
```

macOS GNOSIS profile:

```bash
bash mac/install/AutoGIT-install-mac.sh --profile gnosis
```

Windows GNOSIS profile (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\install\AutoGIT-install-windows.ps1 -Profile gnosis
```

## Quick start

- Start AutoGit without systemd: `~/bin/autogit_dirwatch.sh start`
- Start AutoSave without systemd: `~/bin/autosave_dirwatch.sh start`
- Start both with systemd:
  - `systemctl --user enable --now autogit.service`
  - `systemctl --user enable --now autosave.service`

## Watch files

- AutoGit: `~/.autogit/dirs_main.txt` (commits + pushes)
- AutoSave: `~/.autogit/autosave_dirs_main.txt` (local hash snapshots only)

## GNOSIS compatibility notes

- `autogit.sh` supports tagged entries like `/path/to/repo::tag`.
- Existing remotes are preserved by default (`PRESERVE_EXISTING_REMOTE=1`) to avoid rewriting GNOSIS repo remotes.
- All installers create a canonical `autogit` executable in the user bin directory.
- All installers write a discovery manifest at `~/.autogit/gnosis_autogit.env` so GNOSIS can resolve executable and watch-file paths.
- Remote behavior can be overridden with:
  - `REMOTE_NAME=origin|<name>`
  - `PRESERVE_EXISTING_REMOTE=0|1`
  - `REPO_VISIBILITY=public|private`

## Credentials

- Token path: `~/.AUTH/.GIT_token` (repo scope token, `chmod 600`)
- Git credentials file: `~/.git-credentials`
