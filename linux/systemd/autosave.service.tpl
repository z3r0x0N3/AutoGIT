[Unit]
Description=AutoSave Directory Watcher

[Service]
Type=simple
ExecStart=__BIN_DIR__/autosave_dirwatch.sh run-loop
Restart=always
RestartSec=1
Environment=WATCH_FILE=__AUTOSAVE_WATCH_FILE__
Environment=CLONE_FILE=__AUTOSAVE_CLONE_FILE__
Environment=LOG_FILE=__AUTOSAVE_LOG_FILE__
Environment=PID_FILE=__AUTOSAVE_PID_FILE__
Environment=INTERVAL=__AUTOSAVE_INTERVAL__

[Install]
WantedBy=default.target
