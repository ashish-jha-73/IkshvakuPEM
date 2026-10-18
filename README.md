# Ikshvaku — Python Environment Manager

[![CI](https://github.com/ashish-jha-73/IkshvakuPEM/actions/workflows/ci.yml/badge.svg)](https://github.com/ashish-jha-73/IkshvakuPEM/actions/workflows/ci.yml)

**Ikshvaku** is a lightweight Python virtual environment manager for Linux, macOS, and Windows.  
It provides a minimal, zero-bloat alternative to tools like `virtualenv`, `pyenv`, and Conda — powered by [uv](https://docs.astral.sh/uv/).

Designed for developers who prefer **simplicity, transparency, and control**.

---

## Why Ikshvaku?

Most Python environment tools are either:
- Too heavy (Conda),
- Too complex (pyenv),
- Or scattered across project directories.

**Ikshvaku solves this by:**
- Using [uv](https://docs.astral.sh/uv/) — near-instant environments, tiny disk footprint
- Downloading `uv` automatically if it is not installed
- Centralizing environments in one location
- Integrating cleanly with Bash
- Staying completely lightweight and transparent

No background services. No magic. No lock-in.

---

## Features

- Create, activate, deactivate Python virtual environments (via `uv`)
- Install packages into any environment, active or not: `ikshvaku install <env> <pkg>`
- pip preinstalled in every environment (seeded by uv at creation)
- Pin a Python version per environment: `ikshvaku create myenv 3.12` (uv fetches it if needed)
- `uv` is downloaded automatically on first use — no manual setup
- List and remove environments
- Centralized environment storage: `~/.Python-Env`
- Bash tab-completion for commands and environment names
- Clean shell prompt integration
- Pure Bash (Linux/macOS) and pure PowerShell (Windows) — very lightweight
- Cross-platform: Linux, macOS, and Windows (WSL, Git Bash, PowerShell, cmd)
- No internet needed after first setup (uv and Python versions are cached)

---

## Quick Demo

```bash
ikshvaku create myenv
ikshvaku activate myenv
python --version
pip install requests        # pip comes preinstalled (seeded by uv)
ikshvaku deactivate
```

---

## Usage

```bash
ikshvaku list
ikshvaku create <env_name> [python-version]
ikshvaku activate <env_name>
ikshvaku deactivate
ikshvaku install <env_name> <package...>
ikshvaku remove <env_name>
```

---

## Packages & pip

Every environment ships with **pip preinstalled** (seeded by `uv` at creation),
so the classic workflow works out of the box — including `python -m pip`:

```bash
ikshvaku activate myenv
pip install requests
python -m pip list
```

You can also install without activating:

```bash
ikshvaku install myenv requests
# or, while an env is active:
ikshvaku install requests
```

The install command runs in an isolated *activate → install → deactivate*
cycle inside a subshell — packages land in the target environment, and
whatever you have active in your current shell is never disturbed.

---

## Installation

### One-line install

**Linux / macOS / WSL / Git Bash:**

```bash
curl -LsSf https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main/install.sh | bash
```

`wget` users: `wget -qO- https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main/install.sh | bash`

**Windows (PowerShell or cmd):**

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main/install.ps1 | iex"
```

The installer detects your OS and shell, downloads `uv` if missing, and wires
up your shell automatically. Restart your shell afterwards (or `source ~/.bashrc`,
`source ~/.zshrc`, or `. $PROFILE`).

### Manual install (from a clone)

### 1. Clone the repository
```bash
git clone https://github.com/ashish-jha-73/IkshvakuPEM.git
```

### 2. Enter the repository
```bash
cd IkshvakuPEM
```

### 3. Run installer
```bash
bash install.sh
```

If `uv` is not already on your system, the installer downloads it for you
(requires `curl` or `wget`, once only).

### 4. Reload shell
```bash
source ~/.bashrc   # zsh users: source ~/.zshrc
```

Installation is complete.  
You may now safely remove the `IkshvakuPEM` directory.

### Windows (PowerShell & cmd)

The one-line install above covers Windows too. From a cloned repository you
can instead run:

```powershell
.\install.ps1
```

- **PowerShell 5.1 and 7** — full `ikshvaku` function with tab completion,
  wired into your `$PROFILE`
- **cmd** — works through the `ikshvaku.cmd` shim: `activate`/`deactivate`
  run natively in cmd, everything else delegates to PowerShell
- **uv** is downloaded automatically if missing (internet needed once)

WSL and Git Bash users: follow the Linux steps above with `bash install.sh`.

---

## Uninstall

Ikshvaku installs a clean uninstall command:

```bash
ikshvaku-uninstall
```

This removes:
- All Ikshvaku files
- Shell integrations
- Installed symlinks

Your system remains untouched otherwise.

---

## Requirements

- `curl` or `wget` — only needed the first time, to download `uv`

---

## Platform Support

| Platform                  | Status     |
|---------------------------|------------|
| Linux (bash)              | ✅ Supported |
| macOS (bash & zsh)        | ✅ Supported |
| Windows — WSL             | ✅ Supported |
| Windows — Git Bash        | ✅ Supported |
| Windows — PowerShell 5 & 7 | ✅ Supported |
| Windows — cmd             | ✅ Supported (via shim) |

The installer detects your OS and shell automatically and integrates with the
right rc file (`.bashrc` for bash, `.zshrc` for zsh — with a bash-completion
shim so tab-completion works there too). On Windows, `install.ps1` wires both
PowerShell (function + tab completion) and cmd (via the `ikshvaku.cmd` shim).

---

## Comparison

| Tool        | Lightweight | Uses system Python | Centralized envs | Bash-first |
|-------------|------------|--------------------|------------------|-----------|
| Ikshvaku    | ✅         | ✅                 | ✅               | ✅        |
| virtualenv  | ⚠️         | ✅                 | ❌               | ⚠️        |
| pyenv       | ❌         | ❌                 | ⚠️               | ❌        |
| Conda       | ❌         | ❌                 | ✅               | ❌        |

---

## Who is this for?

- Linux users who prefer Bash workflows
- Developers who dislike Conda bloat
- Students learning Python environments
- Arch Linux users who value simplicity
- Anyone who wants full transparency

---

## Philosophy

Ikshvaku follows the Unix philosophy:

> Do one thing. Do it well. Stay out of the way.

It does not manage Python versions directly — `uv` does that when you ask for one.  
Ikshvaku simply manages Python environments — cleanly.

---

## Roadmap

- Fish support
- Documentation site
- Non-interactive mode
- Further disk-space optimization (uv already dedupes via a shared cache)

---

## Contributing

Contributions are welcome.  
If you find a bug or have an idea, please open an issue.

---

## Support

If Ikshvaku helped you, please ⭐ star the repository.  
It helps others discover the project.

To report issues or suggest improvements:  
https://github.com/ashish-jha-73/IkshvakuPEM

---

## License

MIT
