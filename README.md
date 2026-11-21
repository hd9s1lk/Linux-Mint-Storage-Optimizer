# Linux Mint Storage Optimizer (`Mint_Storage-opt.sh`)
A command-line (CLI) Bash Script for **Linux Mint** (and Ubuntu/Debian-based distributions) inspired by the clean, structured output of NixOS maintenance tools.

It performs essential storage cleanup tasks with an animated progress indicator, real-time command output preview, per-stage completion confirmation, and detailed error reporting if a step fails.

---

## Features

* **Live progress & output preview:** Displays recent lines produced by the running command alongside the animated `A Otimizar ***` indicator as well as it stops immediately if a step fails and prints the stage, command, exit code, and full error output.
* **Per-stage transparency:** Prints the stage name and command before running it, and confirms completion with `✔ Fase concluída` when it finishes cleanly.
* **Conservative cleanup:** Avoids wiping active temporary files in `/var/tmp`, focusing instead on orphaned packages, outdated APT cache files, user thumbnails, and old system logs.

---

## What It Cleans

Running `clean` executes 4 sequential stages:

| Stage | Command | Description |
| :--- | :--- | :--- |
| **1/4** | `sudo apt-get autoremove --purge -y` | Removes unneeded packages, dependencies, and old kernels, including orphaned configuration files. |
| **2/4** | `sudo apt-get autoclean -y` | Cleans outdated `.deb` archives in `/var/cache/apt/archives/` that are no longer available in repositories. |
| **3/4** | `find ~/.cache/thumbnails -type f -delete -print` | Deletes user thumbnail cache files and prints each removed file. |
| **4/4** | `sudo journalctl --vacuum-time=7d` | Vacuums `systemd-journald` logs older than 7 days while keeping the last week. |

---

## Requirements

* Linux Mint (or another Debian/Ubuntu-based distribution)
* `bash` (4.0+)
* `coreutils` (`stdbuf`, `mktemp`, `df`, `du`) and `awk` (installed by default on Linux Mint)
* `sudo` privileges

---

## Installation

1. **Clone the repository into your home directory:**
   ```bash
   git clone [https://github.com/](https://github.com/)<your-username>/Linux-Mint-Storage-Optimizer.git ~/Linux-Mint-Storage-Optimizer
   cd ~/Linux-Mint-Storage-Optimizer
   ```

2. **Make the script executable:**
   ```bash
   chmod +x Mint_Storage-opt.sh
   ```

3. **Create a global symlink** (optional, to run the script from any directory):
   ```bash
   sudo ln -sf ~/Linux-Mint-Storage-Optimizer/Mint_Storage-opt.sh /usr/local/bin/Mint_Storage-opt.sh
   ```

---

## Usage

### Check disk space and caches
Displays free space on the root partition (`/`) along with the size of the APT cache and thumbnails directory:
```bash
Mint_Storage-opt.sh check
```

### Run cleanup
Runs all 4 optimization stages with live progress:
```bash
Mint_Storage-opt.sh clean
```


MIT License

Copyright (c) 2026 <Henrique>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.