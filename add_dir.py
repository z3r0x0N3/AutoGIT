import os
import tkinter as tk
from tkinter import messagebox, filedialog, ttk
import subprocess
from datetime import datetime

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
GREEN = "#00ff00"
RED = "#ff0000"

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
    update_status()

def stop_daemon(script, name):
    os.system(f"{script} stop >/dev/null 2>&1")
    messagebox.showinfo("AutoGit", f"{name} daemon stopped.")
    update_status()

def get_service_status(service_name):
    try:
        result = subprocess.run(["systemctl", "--user", "is-active", service_name], capture_output=True, text=True, check=True)
        if result.stdout.strip() == "active":
            status_result = subprocess.run(["systemctl", "--user", "status", service_name], capture_output=True, text=True)
            for line in status_result.stdout.splitlines():
                if "Active:" in line and "since" in line:
                    since = line.split("since")[1].strip()
                    dt_object = datetime.strptime(since.split(";")[0].strip(), "%a %Y-%m-%d %H:%M:%S %Z")
                    return "active", dt_object
            return "active", None
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "inactive", None
    return "inactive", None





def globalize(variable,alias):
    variable = []
    alias = []
    sub = subprocess 
    global variable
    global alias 
    global sub  
    print(sub)


def globals():
    globals = for variable and alias in globalize()
    print(globals)

def show_globals():
    print
    print(sub)





def format_uptime(start_time):
    if not start_time:
        return "N/A"
    now = datetime.now()
    delta = now - start_time
    seconds = delta.total_seconds()
    minutes = seconds // 60
    hours = minutes // 60
    days = hours // 24
    return f"{int(seconds % 60)}s:{int(minutes % 60)}m:{int(hours % 24)}h:{int(days)}d"

def update_status():
    # Git Watcher Status
    git_status, git_start_time = get_service_status("autogit.service")
    if git_status == "active":
        import subproccess as sub
        sub.run("echo 'AG-Directory-Manager-Online > > > [_TRUE_]")
        dir_frame.config(highlightbackground=GREEN, highlightthickness=2)
        git_status_label.config(text=f"AG-Directory-Manager > > > \n [!]-⚠️-[!]-⚠️-[!] -[!]-⚠️-[!]-⚠️[!] \n  [ ✅️-ONLINE-<< ⏳ >>-SINCE ] >>> <{format_uptime(git_start_time)}>")

    else:
        dir_frame.config(highlightbackground=RED, highlightthickness=2)
        git_status_label.config(text="AG-Directory-Manager > > > [ ⚠️-OFFLINE-⚠️ ]")


    # Auto-Saver Status
    saver_status, saver_start_time = get_service_status("autosave.service")
    if saver_status == "active":
       sub.run("echo 'AG-File-Service-Online > > > [_TRUE_]")
       autosave_frame.config(highlightbackground=GREEN, highlightthickness=2)
       saver_status_label.config(text=f"AG-File-service > > > [ ✅️-ONLINE-✅️ SINCE ] >>> {saver_start_time.strftime('%Y-%m-%d %H:%M:%S') if saver_start_time else 'N/A'}")
    else:
        sub.run("echo 'AG-File-Service-online > > > [_TRUE_]")
        autosave_frame.config(highlightbackground=RED, highlightthickness=2)
        saver_status_label.config(text="AG-File-service > > > [ ⚠️-OFFLINE-⚠️ ]")

    root.after(5000, update_status) # Update every 5 seconds

# --- GUI setup ---
ensure_files()
root = tk.Tk()
root.title("AutoGit Manager")
root.geometry("800x650")
root.resizable(False, False)
root.configure(bg=BG_COLOR)

# --- Main Frame ---
main_frame = tk.Frame(root, bg=BG_COLOR, padx=10, pady=10)
main_frame.pack(fill="both", expand=True)

# --- Directory Watcher Panel ---
dir_frame = tk.Frame(main_frame, bg=BG_COLOR)
dir_frame.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")
main_frame.grid_columnconfigure(0, weight=1)
main_frame.grid_rowconfigure(0, weight=1)

git_status_label = tk.Label(dir_frame, text="", bg=BG_COLOR, fg=GREEN, font=("Consolas", 10, "bold"))
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

# --- Autosave Panel ---
autosave_frame = tk.Frame(main_frame, bg=BG_COLOR)
autosave_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")
main_frame.grid_columnconfigure(1, weight=1)

saver_status_label = tk.Label(autosave_frame, text="", bg=BG_COLOR, fg=GREEN, font=("Consolas", 10, "bold"))
saver_status_label.pack(anchor="w")

tk.Label(autosave_frame, text="File Auto-Saver", **LABEL_STYLE).pack(anchor="w", pady=5)
autosave_listbox = tk.Listbox(autosave_frame, height=15, **LISTBOX_STYLE)
autosave_listbox.pack(fill="both", expand=True, pady=5)

autosave_btn_frame = tk.Frame(autosave_frame, bg=BG_COLOR)
autosave_btn_frame.pack(fill="x", pady=5)

tk.Button(autosave_btn_frame, text="➕ Add File", command=add_autosave_file, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(autosave_btn_frame, text="➖ Remove", command=remove_selected_autosave_file, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(autosave_btn_frame, text="⌕ Refresh", command=refresh_autosave_list, **BTN_STYLE).pack(side="left", padx=5)
tk.Button(autosave_btn_frame, text="Ὄ4 Open", command=lambda: open_file(AUTOSAVE_FILE), **BTN_STYLE).pack(side="left", padx=5)

autosave_status_var = tk.StringVar()
tk.Label(autosave_frame, textvariable=autosave_status_var, bg=BG_COLOR, fg=TANGERINE, font=("Consolas", 9)).pack(anchor="w")

# --- Daemon Control ---
daemon_frame = tk.Frame(main_frame, bg=BG_COLOR)
daemon_frame.grid(row=1, column=0, columnspan=2, pady=10)

tk.Button(daemon_frame, text="▶ Start Git Watcher", command=lambda: start_daemon("~/bin/autogit.sh", "AutoGit"), **BTN_STYLE).pack(side="left", padx=5)
tk.Button(daemon_frame, text="⏹ Stop Git Watcher", command=lambda: stop_daemon("~/bin/autogit.sh", "AutoGit"), **BTN_STYLE).pack(side="left", padx=5)

tk.Button(daemon_frame, text="▶ Start Auto-Saver", command=lambda: start_daemon("~/bin/autosave.sh", "AutoSaver"), **BTN_STYLE).pack(side="left", padx=5)
tk.Button(daemon_frame, text="⏹ Stop Auto-Saver", command=lambda: stop_daemon("~/bin/autosave.sh", "AutoSaver"), **BTN_STYLE).pack(side="left", padx=5)


# --- Initial Load ---
refresh_dir_list()
refresh_autosave_list()
update_status()
root.mainloop()
