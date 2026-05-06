[Unit]
Description=AutoGit Backup Daemon
After=network-online.target

[Service]
Type=simple
ExecStart=__BIN_DIR__/autogit.sh run-loop
Restart=always
RestartSec=5
Environment=WATCH_FILE=__WATCH_FILE__
Environment=CLONE_FILE=__CLONE_FILE__
Environment=LOG_FILE=__LOG_FILE__
Environment=PID_FILE=__PID_FILE__
Environment=IGNORE_FILE=__IGNORE_FILE__
Environment=INTERVAL=__INTERVAL__
Environment=BRANCH=__BRANCH__
Environment=REMOTE_NAME=__REMOTE_NAME__
Environment=PRESERVE_EXISTING_REMOTE=__PRESERVE_EXISTING_REMOTE__
Environment=REPO_VISIBILITY=__REPO_VISIBILITY__
Environment=GIT_USER=__GIT_USER__
Environment=TOKEN_FILE=__TOKEN_FILE__
Environment=API_URL=__API_URL__

[Install]
WantedBy=default.target
