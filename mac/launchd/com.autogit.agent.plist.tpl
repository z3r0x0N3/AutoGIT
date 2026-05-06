<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.autogit.agent</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>__BIN_DIR__/autogit.sh</string>
    <string>run-loop</string>
  </array>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>

  <key>EnvironmentVariables</key>
  <dict>
    <key>WATCH_FILE</key><string>__WATCH_FILE__</string>
    <key>CLONE_FILE</key><string>__CLONE_FILE__</string>
    <key>LOG_FILE</key><string>__LOG_FILE__</string>
    <key>PID_FILE</key><string>__PID_FILE__</string>
    <key>IGNORE_FILE</key><string>__IGNORE_FILE__</string>
    <key>INTERVAL</key><string>__INTERVAL__</string>
    <key>BRANCH</key><string>__BRANCH__</string>
    <key>REMOTE_NAME</key><string>__REMOTE_NAME__</string>
    <key>PRESERVE_EXISTING_REMOTE</key><string>__PRESERVE_EXISTING_REMOTE__</string>
    <key>REPO_VISIBILITY</key><string>__REPO_VISIBILITY__</string>
    <key>GIT_USER</key><string>__GIT_USER__</string>
    <key>TOKEN_FILE</key><string>__TOKEN_FILE__</string>
    <key>API_URL</key><string>__API_URL__</string>
  </dict>

  <key>StandardOutPath</key>
  <string>__AUTOGIT_STDOUT__</string>
  <key>StandardErrorPath</key>
  <string>__AUTOGIT_STDERR__</string>
</dict>
</plist>
