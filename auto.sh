### == AUTO GITHUB BACKUP (DETERMINISTIC INT WATCHER) ==
MAIN_FILE="$HOME/.auto_backup_dirs"
CLONE_FILE="$HOME/.auto_backup_clone"
BRANCH="main"
INTERVAL=5  # seconds
LOG_FILE="$HOME/.auto_backup.log"

auto_git_backup_int() {
    mkdir -p "$(dirname "$MAIN_FILE")"

    if [ ! -f "$MAIN_FILE" ]; then
        echo "[AutoBackup] Directory list not found: $MAIN_FILE"
        return
    fi

    echo "[AutoBackup] Deterministic integer watcher started..."
    echo "[AutoBackup] Monitoring directories listed in $MAIN_FILE"

    while true; do
        > "$CLONE_FILE"  # truncate clone each cycle

        # Generate new integers for each directory
        while IFS= read -r LINE || [ -n "$LINE" ]; do
            [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue

            DIR_PATH=$(echo "$LINE" | sed -E 's/\s*-.*$//')  # extract path only
            [ ! -d "$DIR_PATH" ] && continue

            # Create checksum of structure only (names + sizes + mtimes)
            SUM=$(find "$DIR_PATH" -type f -not -path "*/.git/*" \
                -printf "%p %s %T@\n" 2>/dev/null | sha256sum | base64 | tr -dc '0-9' | head -c 16)

            echo "$DIR_PATH - [$SUM]" >> "$CLONE_FILE"
        done < "$MAIN_FILE"

        # Compare and act
        while IFS= read -r NEW_LINE || [ -n "$NEW_LINE" ]; do
            NEW_DIR=$(echo "$NEW_LINE" | sed -E 's/\s*-.*$//')
            NEW_INT=$(echo "$NEW_LINE" | grep -oE '\[[0-9]{16}\]' | tr -d '[]')

            OLD_LINE=$(grep -F "$NEW_DIR" "$MAIN_FILE" 2>/dev/null)
            OLD_INT=$(echo "$OLD_LINE" | grep -oE '\[[0-9]{16}\]' | tr -d '[]')

            if [ "$NEW_INT" != "$OLD_INT" ]; then
                # Update the integer in the main file
                sed -i "s|$OLD_INT|$NEW_INT|" "$MAIN_FILE"

                # Git sync if repo
                if [ -d "$NEW_DIR/.git" ]; then
                    (
                        cd "$NEW_DIR" || exit
                        git add -A
                        git commit -m "Auto backup (int change): $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null 2>&1
                        git push origin "$BRANCH" >/dev/null 2>&1
                        echo "[AutoBackup] Synced $NEW_DIR at $(date '+%H:%M:%S')" | tee -a "$LOG_FILE"
                    )
                fi
            fi
        done < "$CLONE_FILE"

        sleep "$INTERVAL"
    done
}

# Launch in background if not already running
if ! pgrep -f "auto_git_backup_int" >/dev/null; then
    nohup bash -c "source ~/.bashrc; auto_git_backup_int" >/dev/null 2>&1 &
fi
### == END AUTO GITHUB BACKUP ==

