#!/usr/bin/env python3
# AutoGit Manager GUI
#
# This GUI allows the user to manage AutoGit directory watches and an
# AutoSave (directory) watcher.  It exposes two panels: one for Git
# directory watches and one for AutoSave directory watches.  Each panel
# allows adding and removing directories from its respective watch list
# and shows the current count of watched entries.  The daemon control
# buttons start and stop the associated background scripts.

import os
import tkinter as tk
from tkinter import messagebox, filedialog, ttk
import subprocess
from datetime import datetime

# --- CONFIGURATION -----------------------------------------------------------
AUTOGIT_DIR = os.path.expanduser("~/.autogit")
# Path to the Git watcher directory list.  Each entry is a directory,
# optionally followed by a 16-digit hash.
MAIN_FILE = os.path.join(AUTOGIT_DIR, "dirs_main.txt")
# Path to the AutoSave directory list.  Each entry is a directory
# optionally followed by a 16-digit hash.  The autosave_dirwatch.sh
# script monitors this file for directory changes.
AUTOSAVE_FILE = os.path.join(AUTOGIT_DIR, "autosave_dirs_main.txt")

# --- COLOUR PALETTE ----------------------------------------------------------
BG_COLOR = "#0D0221"
FG_COLOR = "#F0F0F0"
CYAN = "#00f0f0"
PURPLE = "#8f00f0"
TANGERINE = "#ff8000"
GRID_COLOR = "#2a0a4f"
GREEN = "#00ff00"
RED = "#ff0000"

# --- STYLES ------------------------------------------------------------------
STYLE = {
    "background": BG_COLOR,
    "foreground": FG_COLOR,
    "font": ("Consolas", 11),
}

BTN_STYLE = {
    "background": PURPLE,
    "foreground": FG_COLOR,
    "font": ("Consolas", 11, "bold"),
    "activebackground": TANGERINE,
    "activeforeground": BG_COLOR,
    "relief": "flat",
    "border": 0,
}

LISTBOX_STYLE = {
    "background": "#100a20",
    "foreground": CYAN,
    "font": ("Consolas", 10),
    "selectbackground": TANGERINE,
    "selectforeground": BG_COLOR,
    "border": 0,
    "highlightthickness": 0,
}

LABEL_STYLE = {
    "background": BG_COLOR,
    "foreground": PURPLE,
    "font": ("Consolas", 12, "bold"),
}

# --- HELPERS -----------------------------------------------------------------
def ensure_files() -> None:
    """Ensure that configuration directory and watch files exist."""
    os.makedirs(AUTOGIT_DIR, exist_ok=True)
    for f in [MAIN_FILE, AUTOSAVE_FILE]:
        if not os.path.exists(f):
            with open(f, "w", encoding="utf-8") as fh:
                fh.write("# AutoGit watch list\n")

def read_lines(file_path: str) -> list[str]:
    """Return non-empty, non-comment lines from file."""
    lines: list[str] = []
    with open(file_path, "r", encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            lines.append(line)
    return lines

def write_lines(file_path: str, lines: list[str]) -> None:
    """Write header and list of lines to file."""
    with open(file_path, "w", encoding="utf-8") as fh:
        fh.write("# AutoGit watch list (managed by GUI)\n")
        for line in lines:
            fh.write(f"{line}\n")

def sanitize_autosave_entries(entries: list[str]) -> list[str]:
    """Ensure AutoSave entries are plain directories (strip any ::tags)."""
    sanitized: list[str] = []
    for e in entries:
        base = e.split("::")[0]
        if base and base not in sanitized:
            sanitized.append(base)
    return sanitized

# --- Directory Watcher (Git) Functions --------------------------------------
def add_dir() -> None:
    """Prompt user for a directory and add it to Git watch list."""
    path = filedialog.askdirectory(title="Select directory to watch")
    if not path:
        return
    dirs = read_lines(MAIN_FILE)
    if path in dirs:
        messagebox.showinfo("AutoGit", "That directory is already being watched.")
        return
    dirs.append(path)
    write_lines(MAIN_FILE, dirs)
    refresh_dir_list()
    messagebox.showinfo("AutoGit", f"Added:\n{path}")

def remove_selected_dir() -> None:
    """Remove the selected directory from Git watch list."""
    selection = dir_listbox.curselection()
    if not selection:
        return
    idx = selection[0]
    dirs = read_lines(MAIN_FILE)
    removed = dirs.pop(idx)
    write_lines(MAIN_FILE, dirs)
    refresh_dir_list()
    messagebox.showinfo("AutoGit", f"Removed:\n{removed}")

def refresh_dir_list() -> None:
    """Refresh the display of Git watch list."""
    dir_listbox.delete(0, tk.END)
    dirs = read_lines(MAIN_FILE)
    for d in dirs:
        dir_listbox.insert(tk.END, d)
    dir_status_var.set(f"Watching {len(dirs)} directories")

# --- AutoSave Directory Functions -------------------------------------------
def add_autosave_dir() -> None:
    """Prompt user for a directory and add it to AutoSave watch list."""
    path = filedialog.askdirectory(title="Select directory to auto-save")
    if not path:
        return
    entries = sanitize_autosave_entries(read_lines(AUTOSAVE_FILE))
    if path in entries:
        messagebox.showinfo("AutoGit", "That directory is already in the AutoSave list.")
        return

    entries.append(path)
    write_lines(AUTOSAVE_FILE, entries)
    refresh_autosave_list()
    messagebox.showinfo("AutoGit", f"Added to AutoSave:\n{path}")

def remove_selected_autosave_dir() -> None:
    """Remove the selected directory from AutoSave watch list."""
    selection = autosave_listbox.curselection()
    if not selection:
        return
    idx = selection[0]
    entries = sanitize_autosave_entries(read_lines(AUTOSAVE_FILE))
    removed = entries.pop(idx)
    write_lines(AUTOSAVE_FILE, entries)
    refresh_autosave_list()
    messagebox.showinfo("AutoGit", f"Removed from AutoSave:\n{removed}")

def refresh_autosave_list() -> None:
    """Refresh the display of AutoSave watch list."""
    autosave_listbox.delete(0, tk.END)
    raw_entries = read_lines(AUTOSAVE_FILE)
    entries = sanitize_autosave_entries(raw_entries)
    # If file contained tags, write back sanitized entries to keep it clean
    if entries != raw_entries:
        write_lines(AUTOSAVE_FILE, entries)
    for e in entries:
        autosave_listbox.insert(tk.END, e)
    autosave_status_var.set(f"Auto-saving {len(entries)} directories")

# --- System Functions --------------------------------------------------------
def open_file(path: str) -> None:
    """Open a file using the system handler."""
    os.system(f"xdg-open {path} >/dev/null 2>&1 &")

def start_daemon(script: str, name: str) -> None:
    """Start a background service using the given script."""
    os.system(f"nohup {script} start >/dev/null 2>&1 &")
    messagebox.showinfo("AutoGit", f"{name} daemon started.")
    update_status()

def stop_daemon(script: str, name: str) -> None:
    """Stop a background service using the given script."""
    os.system(f"{script} stop >/dev/null 2>&1")
    messagebox.showinfo("AutoGit", f"{name} daemon stopped.")
    update_status()

def get_service_status(service_name: str) -> tuple[str, datetime | None]:
    """Query systemd for the status of a user service."""
    try:
        result = subprocess.run([
            "systemctl", "--user", "is-active", service_name
        ], capture_output=True, text=True, check=True)
        if result.stdout.strip() == "active":
            status_result = subprocess.run([
                "systemctl", "--user", "status", service_name
            ], capture_output=True, text=True)
            for line in status_result.stdout.splitlines():
                if "Active:" in line and "since" in line:
                    since = line.split("since")[1].strip()
                    try:
                        dt_object = datetime.strptime(
                            since.split(";")[0].strip(),
                            "%a %Y-%m-%d %H:%M:%S %Z"
                        )
                    except ValueError:
                        dt_object = None
                    return "active", dt_object
            return "active", None
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "inactive", None
    return "inactive", None

# --- Status Update -----------------------------------------------------------
def format_uptime(start_time: datetime | None) -> str:
    if not start_time:
        return "N/A"
    now = datetime.now()
    delta = now - start_time
    seconds = delta.total_seconds()
    minutes = seconds // 60
    hours = minutes // 60
    days = hours // 24
    return f"{int(seconds % 60)}s:{int(minutes % 60)}m:{int(hours % 24)}h:{int(days)}d"

def update_status() -> None:
    """Poll daemon statuses and update the GUI labels."""
    # Git watcher service
    git_status, git_start_time = get_service_status("autogit.service")
    if git_status == "active":
        dir_frame.config(highlightbackground=GREEN, highlightthickness=2)
        git_status_label.config(
            text=f"AG-Directory-Manager >>> [✅ ONLINE ⏳ SINCE] <{format_uptime(git_start_time)}>"
        )
    else:
        dir_frame.config(highlightbackground=RED, highlightthickness=2)
        git_status_label.config(
            text="AG-Directory-Manager [ ⚠️ OFFLINE ⚠️ ]"
        )

    # AutoSave directory watcher service (assumes autosave.service for backwards compat)
    saver_status, saver_start_time = get_service_status("autosave.service")
    if saver_status == "active":
        autosave_frame.config(highlightbackground=GREEN, highlightthickness=2)
        saver_status_label.config(
            text=f"AutoSave Watcher >>> [✅ ONLINE SINCE] >>> "
                 f"{saver_start_time.strftime('%Y-%m-%d %H:%M:%S') if saver_start_time else 'N/A'}"
        )
    else:
        autosave_frame.config(highlightbackground=RED, highlightthickness=2)
        saver_status_label.config(
            text="AutoSave Watcher [ ⚠️ OFFLINE ⚠️ ]"
        )
    # schedule next update
    root.after(5000, update_status)

# --- GUI Construction -------------------------------------------------------
def build_gui() -> None:
    """Construct the GUI layout."""
    ensure_files()
    global root, dir_frame, dir_listbox, dir_status_var
    global autosave_frame, autosave_listbox, autosave_status_var
    global git_status_label, saver_status_label

    root.title("AutoGit Manager")
    root.geometry("800x650")
    root.resizable(False, False)
    root.configure(bg=BG_COLOR)

    # Main container
    main_frame = tk.Frame(root, bg=BG_COLOR, padx=10, pady=10)
    main_frame.pack(fill="both", expand=True)

    # Git Watcher Panel
    dir_frame = tk.Frame(main_frame, bg=BG_COLOR)
    dir_frame.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")
    main_frame.grid_columnconfigure(0, weight=1)
    main_frame.grid_rowconfigure(0, weight=1)

    git_status_label = tk.Label(
        dir_frame, text="", bg=BG_COLOR, fg=GREEN, font=("Consolas", 10, "bold")
    )
    git_status_label.pack(anchor="w")

    tk.Label(dir_frame, text="Git Watcher", **LABEL_STYLE).pack(anchor="w", pady=5)
    dir_listbox = tk.Listbox(dir_frame, height=15, **LISTBOX_STYLE)
    dir_listbox.pack(fill="both", expand=True, pady=5)

    dir_btn_frame = tk.Frame(dir_frame, bg=BG_COLOR)
    dir_btn_frame.pack(fill="x", pady=5)
    tk.Button(dir_btn_frame, text="➕ Add Dir", command=add_dir, **BTN_STYLE).pack(side="left", padx=5)
    tk.Button(dir_btn_frame, text="➖ Remove", command=remove_selected_dir, **BTN_STYLE).pack(side="left", padx=5)
    tk.Button(dir_btn_frame, text="⌕ Refresh", command=refresh_dir_list, **BTN_STYLE).pack(side="left", padx=5)
    tk.Button(dir_btn_frame, text="Ὄ4 Open", command=lambda: open_file(MAIN_FILE), **BTN_STYLE).pack(side="left", padx=5)

    dir_status_var = tk.StringVar()
    tk.Label(dir_frame, textvariable=dir_status_var, bg=BG_COLOR, fg=TANGERINE, font=("Consolas", 9)).pack(anchor="w")

    # AutoSave Directory Watcher Panel
    autosave_frame = tk.Frame(main_frame, bg=BG_COLOR)
    autosave_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")
    main_frame.grid_columnconfigure(1, weight=1)

    saver_status_label = tk.Label(
        autosave_frame, text="", bg=BG_COLOR, fg=GREEN, font=("Consolas", 10, "bold")
    )
    saver_status_label.pack(anchor="w")

    tk.Label(autosave_frame, text="AutoSave Directories", **LABEL_STYLE).pack(anchor="w", pady=5)

    autosave_listbox = tk.Listbox(autosave_frame, height=15, **LISTBOX_STYLE)
    autosave_listbox.pack(fill="both", expand=True, pady=5)

    autosave_btn_frame = tk.Frame(autosave_frame, bg=BG_COLOR)
    autosave_btn_frame.pack(fill="x", pady=5)
    tk.Button(autosave_btn_frame, text="➕ Add Dir", command=add_autosave_dir, **BTN_STYLE).pack(side="left", padx=5)
    tk.Button(autosave_btn_frame, text="➖ Remove", command=remove_selected_autosave_dir, **BTN_STYLE).pack(side="left", padx=5)
    tk.Button(autosave_btn_frame, text="⌕ Refresh", command=refresh_autosave_list, **BTN_STYLE).pack(side="left", padx=5)
    tk.Button(autosave_btn_frame, text="Ὄ4 Open", command=lambda: open_file(AUTOSAVE_FILE), **BTN_STYLE).pack(side="left", padx=5)

    autosave_status_var = tk.StringVar()
    tk.Label(autosave_frame, textvariable=autosave_status_var, bg=BG_COLOR, fg=TANGERINE, font=("Consolas", 9)).pack(anchor="w")

    # Daemon control
    daemon_frame = tk.Frame(main_frame, bg=BG_COLOR)
    daemon_frame.grid(row=1, column=0, columnspan=2, pady=10)
    tk.Button(
        daemon_frame, text="▶ Start Git Watcher",
        command=lambda: start_daemon("~/bin/autogit.sh", "AutoGit"),
        **BTN_STYLE
    ).pack(side="left", padx=5)
    tk.Button(
        daemon_frame, text="⏹ Stop Git Watcher",
        command=lambda: stop_daemon("~/bin/autogit.sh", "AutoGit"),
        **BTN_STYLE
    ).pack(side="left", padx=5)
    tk.Button(
        daemon_frame, text="▶ Start AutoSave",
        command=lambda: start_daemon("~/bin/autosave_dirwatch.sh", "AutoSave"),
        **BTN_STYLE
    ).pack(side="left", padx=5)
    tk.Button(
        daemon_frame, text="⏹ Stop AutoSave",
        command=lambda: stop_daemon("~/bin/autosave_dirwatch.sh", "AutoSave"),
        **BTN_STYLE
    ).pack(side="left", padx=5)

    # Initialize lists and status
    refresh_dir_list()
    refresh_autosave_list()
    update_status()

# Only build the GUI if this script is the main entry point.  This
# prevents global execution when the module is imported.
if __name__ == "__main__":
    root = tk.Tk()
    build_gui()
    root.mainloop()
