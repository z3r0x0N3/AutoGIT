# AutoGIT
Automated git updates


to setup just run the following after cloning the repo: bash AutoGIT-install.sh

Quick start

- Start AutoGit without systemd: `~/bin/autogit_dirwatch.sh start`
- If your GitHub username differs from the default in `autogit.sh`, set it explicitly when using the wrapper, e.g.: `GIT_USER="<your-github-username>" ~/bin/autogit_dirwatch.sh start`
- Or with systemd: `systemctl --user enable --now autogit.service`
- Start AutoSave without systemd: `~/bin/autosave_dirwatch.sh start`
- Or with systemd: `systemctl --user enable --now autosave.service`

Watch files

- AutoGit watches `~/.autogit/dirs_main.txt` (pushes to GitHub)
- AutoSave watches `~/.autogit/autosave_dirs_main.txt` (no Git operations)

Notes

- AutoGit reads a GitHub token from `~/.AUTH/.GIT_token`. Ensure it contains a valid Personal Access Token with repo scope.
- Credentials are stored in `~/.git-credentials`. If you previously ran an older wrapper that defaulted `GIT_USER` to your local username, you may need to remove any `github.com/_localuser_/...` entries from that file.

