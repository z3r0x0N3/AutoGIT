#!/usr/bin/env python3
import os
import tkinter as tk
from tkinter import messagebox, filedialog, ttk

# --- CONFIG ---
AUTOGIT_DIR = os.path.expanduser("~/.autogit")
MAIN_FILE = os.path.join(AUTOGIT_DIR, "dirs_main.txt")
AUTOSAVE_FILE = os.path.join(AUTOGIT_DIR, "files_autosave.txt")

# --- COLORS ---
BG_COLOR = "#0D0221"
FG_COLOR = "#F0F0F0"
CYAN = "#00f0f0"
PURPLE = "#8f00f0"
TANGERINE = "#ff8000"
GRID_COLOR = "#2a0a4f"

# --- STYLES ---
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

def ensure_files():
    os.makedirs(AUTOGIT_DIR, exist_ok=True)
    for f in [MAIN_FILE, AUTOSAVE_FILE]:
        if not os.path.exists(f):
            with open(f, "w") as f:
                f.write(f"# AutoGit watch list\n")

def read_lines(file_path):
    lines = []
    with open(file_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            lines.append(line)
    return lines

def write_lines(file_path, lines):
    with open(file_path, "w") as f:
        f.write("# AutoGit watch list (managed by GUI)\n")
        for line in lines:
            f.write(f"{line}\n")

# --- Directory Functions ---
def add_dir():
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

def remove_selected_dir():
    selection = dir_listbox.curselection()
    if not selection:
        return
    idx = selection[0]
    dirs = read_lines(MAIN_FILE)
    removed = dirs.pop(idx)
    write_lines(MAIN_FILE, dirs)
    refresh_dir_list()
    messagebox.showinfo("AutoGit", f"Removed:\n{removed}")

def refresh_dir_list():
    dir_listbox.delete(0, tk.END)
    dirs = read_lines(MAIN_FILE)
    for d in dirs:
        dir_listbox.insert(tk.END, d)
    dir_status_var.set(f"Watching {len(dirs)} directories")

# --- Autosave Functions ---
def add_autosave_file():
    path = filedialog.askopenfilename(title="Select file to auto-save")
    if not path:
        return
    files = read_lines(AUTOSAVE_FILE)
    if path in files:
        messagebox.showinfo("AutoGit", "That file is already being watched.")
        return
    files.append(path)
    write_lines(AUTOSAVE_FILE, files)
    refresh_autosave_list()
    messagebox.showinfo("AutoGit", f"Added to autosave:\n{path}")

def remove_selected_autosave_file():
    selection = autosave_listbox.curselection()
    if not selection:
        return
    idx = selection[0]
    files = read_lines(AUTOSAVE_FILE)
    removed = files.pop(idx)
    write_lines(AUTOSAVE_FILE, files)
    refresh_autosave_list()
    messagebox.showinfo("AutoGit", f"Removed from autosave:\n{removed}")

def refresh_autosave_list():
    autosave_listbox.delete(0, tk.END)
    files = read_lines(AUTOSAVE_FILE)
    for f in files:
        autosave_listbox.insert(tk.END, f)
    autosave_status_var.set(f"Auto-saving {len(files)} files")

# --- System Functions ---
def open_file(path):
    os.system(f"xdg-open {path} >/dev/null 2>&1 &")

def start_daemon(script, name):
    os.system(f"nohup {script} start >/dev/null 2>&1 &")
    messagebox.showinfo("AutoGit", f"{name} daemon started.")

def stop_daemon(script, name):
    os.system(f"{script} stop >/dev/null 2>&1")
    messagebox.showinfo("AutoGit", f"{name} daemon stopped.")

def check_status(script, name):
    status = os.popen(f"{script} status").read().strip()
    messagebox.showinfo(f"{name} Status", status)

# --- GUI setup ---
ensure_files()
root = tk.Tk()
root.title("AutoGit Manager")
root.geometry("800x600")
root.resizable(False, False)
root.configure(bg=BG_COLOR)

# --- Main Frame ---
main_frame = tk.Frame(root, bg=BG_COLOR, padx=10, pady=10)
main_frame.pack(fill="both", expand=True)

# --- Directory Watcher Panel ---
dir_frame = tk.Frame(main_frame, bg=BG_COLOR, relief="sunken", borderwidth=1)
dir_frame.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")
main_frame.grid_columnconfigure(0, weight=1)
main_frame.grid_rowconfigure(0, weight=1)

tk.Label(dir_frame, text="Git Watcher", **LABEL_STYLE).pack(anchor="w", pady=5)
dir_listbox = tk.Listbox(dir_frame, height=15, **LISTBOX_STYLE)
dir_listbox.pack(fill="both", expand=True, pady=5)

dir_btn_frame = tk.Frame(dir_frame, bg=BG_COLOR)
dir_btn_frame.pack(fill="x", pady=5)

tk.Button(dir_btn_frame, text="➕", command=add_dir, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(dir_btn_frame, text="➖", command=remove_selected_dir, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(dir_btn_frame, text="🔄 Refresh", command=refresh_dir_list, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(dir_btn_frame, text="📄 Open", command=lambda: open_file(MAIN_FILE), **BTN_STYLE).pack(side="left", padx=5)

dir_status_var = tk.StringVar()
tk.Label(dir_frame, textvariable=dir_status_var, bg=BG_COLOR, fg=TANGERINE, font=("Consolas", 9)).pack(anchor="w")

# --- Autosave Panel ---
autosave_frame = tk.Frame(main_frame, bg=BG_COLOR, relief="sunken", borderwidth=1)
autosave_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")
main_frame.grid_columnconfigure(1, weight=1)

tk.Label(autosave_frame, text="File Auto-Saver", **LABEL_STYLE).pack(anchor="w", pady=5)
autosave_listbox = tk.Listbox(autosave_frame, height=15, **LISTBOX_STYLE)
autosave_listbox.pack(fill="both", expand=True, pady=5)

autosave_btn_frame = tk.Frame(autosave_frame, bg=BG_COLOR)
autosave_btn_frame.pack(fill="x", pady=5)

tk.Button(autosave_btn_frame, text="➕ Add File", command=add_autosave_file, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(autosave_btn_frame, text="➖ Remove", command=remove_selected_autosave_file, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(autosave_btn_frame, text="🔄 Refresh", command=refresh_autosave_list, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(autosave_btn_frame, text="📄 Open", command=lambda: open_file(AUTOSAVE_FILE), **BTN_STYLE).pack(side="left", padx=5)

autosave_status_var = tk.StringVar()
tk.Label(autosave_frame, textvariable=autosave_status_var, bg=BG_COLOR, fg=TANGERINE, font=("Consolas", 9)).pack(anchor="w")

# --- Daemon Control ---
daemon_frame = tk.Frame(main_frame, bg=BG_COLOR)
daemon_frame.grid(row=1, column=0, columnspan=2, pady=10)

tk.Button(daemon_frame, text="▶ Start Git Watcher", command=lambda: start_daemon("~/bin/autogit.sh", "AutoGit"), **BTN_STYLE).pack(side="left", padx=5)
tk.Button(daemon_frame, text="⏹ Stop Git Watcher", command=lambda: stop_daemon("~/bin/autogit.sh", "AutoGit"), **BTN_STYLE).pack(side="left", padx=5)
tk.Button(daemon_frame, text="📊 Git Status", command=lambda: check_status("~/bin/autogit.sh", "AutoGit"), **BTN_STYLE).pack(side="left", padx=5)

tk.Button(daemon_frame, text="▶ Start Auto-Saver", command=lambda: start_daemon("~/bin/autosave.sh", "AutoSaver"), **BTN_STYLE).pack(side="left", padx=5)
tk.Button(daemon_frame, text="⏹ Stop Auto-Saver", command=lambda: stop_daemon("~/bin/autosave.sh", "AutoSaver"), **BTN_STYLE).pack(side="left", padx=5)
tk.Button(daemon_frame, text="📊 Saver Status", command=lambda: check_status("~/bin/autosave.sh", "AutoSaver"), **BTN_STYLE).pack(side="left", padx=5)

# --- Initial Load ---
refresh_dir_list()
refresh_autosave_list()
root.mainloop()
