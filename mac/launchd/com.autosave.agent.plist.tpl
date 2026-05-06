<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.autosave.agent</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>__BIN_DIR__/autosave_dirwatch.sh</string>
    <string>run-loop</string>
  </array>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>

  <key>EnvironmentVariables</key>
  <dict>
    <key>WATCH_FILE</key><string>__AUTOSAVE_WATCH_FILE__</string>
    <key>CLONE_FILE</key><string>__AUTOSAVE_CLONE_FILE__</string>
    <key>LOG_FILE</key><string>__AUTOSAVE_LOG_FILE__</string>
    <key>PID_FILE</key><string>__AUTOSAVE_PID_FILE__</string>
    <key>INTERVAL</key><string>__AUTOSAVE_INTERVAL__</string>
  </dict>

  <key>StandardOutPath</key>
  <string>__AUTOSAVE_STDOUT__</string>
  <key>StandardErrorPath</key>
  <string>__AUTOSAVE_STDERR__</string>
</dict>
</plist>
