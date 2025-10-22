#!/usr/bin/env python3
import os
import tkinter as tk
from tkinter import messagebox, filedialog, ttk

AUTOGIT_DIR = os.path.expanduser("~/.autogit")
MAIN_FILE = os.path.join(AUTOGIT_DIR, "dirs_main.txt")

def ensure_files():
    os.makedirs(AUTOGIT_DIR, exist_ok=True)
    if not os.path.exists(MAIN_FILE):
        with open(MAIN_FILE, "w") as f:
            f.write("# AutoGit watch list\n")

def read_dirs():
    dirs = []
    with open(MAIN_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if " - [" in line:
                dirpath = line.split(" - [")[0].strip()
                dirs.append(dirpath)
            else:
                dirs.append(line)
    return dirs

def write_dirs(dirs):
    with open(MAIN_FILE, "w") as f:
        f.write("# AutoGit watch list (managed by GUI)\n")
        for d in dirs:
            f.write(f"{d} - [0000000000000000]\n")

def add_dir():
    path = filedialog.askdirectory(title="Select directory to watch")
    if not path:
        return
    dirs = read_dirs()
    if path in dirs:
        messagebox.showinfo("AutoGit", "That directory is already being watched.")
        return
    dirs.append(path)
    write_dirs(dirs)
    refresh_list()
    messagebox.showinfo("AutoGit", f"Added:\n{path}")

def remove_selected():
    selection = listbox.curselection()
    if not selection:
        return
    idx = selection[0]
    dirs = read_dirs()
    removed = dirs.pop(idx)
    write_dirs(dirs)
    refresh_list()
    messagebox.showinfo("AutoGit", f"Removed:\n{removed}")

def refresh_list():
    listbox.delete(0, tk.END)
    dirs = read_dirs()
    for d in dirs:
        listbox.insert(tk.END, d)
    status_var.set(f"Watching {len(dirs)} directories")

def open_file():
    os.system(f"xdg-open {MAIN_FILE} >/dev/null 2>&1 &")

def start_autogit():
    os.system("nohup ~/bin/autogit.sh start >/dev/null 2>&1 &")
    messagebox.showinfo("AutoGit", "AutoGit daemon started.")

def stop_autogit():
    os.system("~/bin/autogit.sh stop >/dev/null 2>&1")
    messagebox.showinfo("AutoGit", "AutoGit daemon stopped.")

def check_status():
    status = os.popen("~/bin/autogit.sh status").read().strip()
    messagebox.showinfo("AutoGit Status", status)

# --- GUI setup ---
ensure_files()
root = tk.Tk()
root.title("AutoGit Directory Manager")
root.geometry("600x400")
root.resizable(False, False)

frame = ttk.Frame(root, padding=10)
frame.pack(fill="both", expand=True)

ttk.Label(frame, text="Watched Directories:", font=("Segoe UI", 11, "bold")).pack(anchor="w")

listbox = tk.Listbox(frame, height=12, selectmode=tk.SINGLE, font=("Consolas", 10))
listbox.pack(fill="both", expand=True, pady=5)

btn_frame = ttk.Frame(frame)
btn_frame.pack(fill="x", pady=5)

ttk.Button(btn_frame, text="➕ Add Dir", command=add_dir).pack(side="left", padx=5)
ttk.Button(btn_frame, text="➖ Remove", command=remove_selected).pack(side="left", padx=5)
ttk.Button(btn_frame, text="🔄 Refresh", command=refresh_list).pack(side="left", padx=5)
ttk.Button(btn_frame, text="📄 Open File", command=open_file).pack(side="left", padx=5)

ttk.Separator(frame, orient="horizontal").pack(fill="x", pady=5)

daemon_frame = ttk.Frame(frame)
daemon_frame.pack(fill="x", pady=5)
ttk.Button(daemon_frame, text="▶ Start AutoGit", command=start_autogit).pack(side="left", padx=5)
ttk.Button(daemon_frame, text="⏹ Stop", command=stop_autogit).pack(side="left", padx=5)
ttk.Button(daemon_frame, text="📊 Status", command=check_status).pack(side="left", padx=5)

status_var = tk.StringVar()
status_bar = ttk.Label(root, textvariable=status_var, relief="sunken", anchor="w")
status_bar.pack(fill="x", side="bottom")

refresh_list()
root.mainloop()

