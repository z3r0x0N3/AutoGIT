# AutoGIT

Automated git updates and autosave directory monitoring.

## Linux architecture

The project now includes a Linux-structured layout while preserving root compatibility:

- `linux/core/autogit.sh`
- `linux/wrappers/autogit_dirwatch.sh`
- `linux/wrappers/autosave_dirwatch.sh`
- `linux/install/AutoGIT-install-linux.sh`
- `linux/systemd/*.service.tpl`
- `linux/profiles/gnosis/*`

`AutoGIT-install.sh` at repo root is the compatibility entrypoint and forwards to the Linux installer.

## Installation

Default profile:

```bash
bash AutoGIT-install.sh
```

GNOSIS profile:

```bash
bash AutoGIT-install.sh --profile gnosis
```

Skip auto-start:

```bash
bash AutoGIT-install.sh --profile gnosis --no-start
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
- Remote behavior can be overridden with:
  - `REMOTE_NAME=origin|<name>`
  - `PRESERVE_EXISTING_REMOTE=0|1`
  - `REPO_VISIBILITY=public|private`

## Credentials

- Token path: `~/.AUTH/.GIT_token` (repo scope token, `chmod 600`)
- Git credentials file: `~/.git-credentials`
