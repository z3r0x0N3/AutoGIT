# AutoGIT
Automated git updates


to setup just run the following after cloning the repo: bash AutoGIT-install.sh

Quick start

- Start AutoGit without systemd: `~/bin/autogit_dirwatch.sh start`
- Or with systemd: `systemctl --user enable --now autogit.service`
- Start AutoSave without systemd: `~/bin/autosave_dirwatch.sh start`
- Or with systemd: `systemctl --user enable --now autosave.service`

Watch files

- AutoGit watches `~/.autogit/dirs_main.txt` (pushes to GitHub)
- AutoSave watches `~/.autogit/autosave_dirs_main.txt` (no Git operations)
