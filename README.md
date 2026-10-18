<div align="center">

# ⚡ Ikshvaku

**A lightweight Python environment manager for Linux, macOS & Windows**

Create, activate, and switch Python environments in milliseconds —
powered by [uv](https://docs.astral.sh/uv/), wired straight into your shell.

[![CI](https://github.com/ashish-jha-73/IkshvakuPEM/actions/workflows/ci.yml/badge.svg)](https://github.com/ashish-jha-73/IkshvakuPEM/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)](#-platform-support)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh%20%7C%20PowerShell%20%7C%20cmd-informational)](#-platform-support)

**[Install](#-installation) · [Quick start](#-quick-start) · [Commands](#-commands) · [How it works](#-how-it-works) · [FAQ](#-faq)**

</div>

---

## ✨ Why Ikshvaku

Most Python environment tools are either too heavy (Conda), too complex
(pyenv), or scattered across project directories.

**Ikshvaku takes a different position:**

| | |
|---|---|
| ⚡ **Fast** | Environments are created near-instantly by [uv](https://docs.astral.sh/uv/) — no waiting on `venv` |
| 🪶 **Tiny** | Envs are ~2–200× smaller than classic `venv`, thanks to uv's shared cache |
| 🏠 **Centralized** | Every environment lives in one place: `~/.Python-Env` — always findable, always completable |
| 🐚 **Shell-native** | Not another CLI you have to remember — a shell function with tab completion in bash, zsh, PowerShell and cmd |
| 🛡 **Self-healing** | `uv` is downloaded automatically if missing, on any platform |
| 🔗 **Project-aware** | `ikshvaku init` links a directory to an env; bare `activate` works from any subdirectory |
| 🤖 **Auto-pilot (opt-in)** | `auto on` switches environments as you `cd` |
| 🩺 **Observable** | `status` and `doctor` show state and diagnose problems |
| 🧹 **Self-cleaning** | `cleanup` finds and removes stale environments; `list --size` shows what disk each env costs |
| ⌨️ **Scriptable** | `run`, `export`, `clone` — use environments from scripts and CI without touching your shell |
| 📦 **Batteries included** | Every env ships with pip preinstalled and Python versions on demand: `ikshvaku create app 3.12` |

No background services. No magic. No lock-in.

---

## 🚀 Installation

### One-line install

**Linux / macOS / WSL / Git Bash:**

```bash
curl -LsSf https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main/install.sh | bash
```

<sub>`wget` users: `wget -qO- .../install.sh | bash`</sub>

**Windows (PowerShell or cmd):**

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main/install.ps1 | iex"
```

The installer detects your OS and shell, downloads `uv` if missing (internet
needed once), and wires up your shell automatically. Restart your shell
afterwards — or `source ~/.bashrc`, `source ~/.zshrc`, `. $PROFILE`.

### Manual install (from a clone)

```bash
git clone https://github.com/ashish-jha-73/IkshvakuPEM.git
cd IkshvakuPEM
bash install.sh          # Windows: .\install.ps1
```

### Uninstall

```bash
ikshvaku-uninstall       # ~\.ikshvaku\uninstall.ps1 on Windows
```

Removes all Ikshvaku files, shell integrations, symlinks and environments.
`uv` itself is left installed (other tools may use it).

---

## ⚡ Quick start

```console
$ ikshvaku create myenv
Using CPython 3.12.8 interpreter at: /usr/bin/python
Creating virtual environment at: ~/.Python-Env/myenv
Environment 'myenv' created

$ ikshvaku activate myenv
$ python --version
Python 3.12.8

$ pip install requests
Successfully installed requests-2.32.3

$ ikshvaku deactivate
```

Need a specific Python version? uv fetches it on demand:

```console
$ ikshvaku create app 3.12
Downloading cpython-3.12.15 (32.7 MiB)
Environment 'app' created
```

Working on a project? Link it — then activation is automatic:

```console
$ cd myproject
$ ikshvaku init
Environment 'myproject' created
Linked ~/myproject -> 'myproject'

$ cd ~/myproject/src/deep
$ ikshvaku activate        # no argument: finds the project's env
```

---

## 📖 Commands

| `ikshvaku init [env] [python-version]` | Link the current directory to an environment (creates it if needed, installs `requirements.txt` if present) and activate it |
| `ikshvaku link <env>` / `unlink` | Attach / detach this directory to an environment |
| `ikshvaku links` | Show every project → environment link |
| `ikshvaku activate [env]` | Activate — with no argument, uses this project's linked env (even from subdirectories) |
| `ikshvaku auto on\|off` | Opt-in: switch environments automatically as you `cd` |
| `ikshvaku create <env> [python-version]` | Create an environment (pip included; pin a Python version and uv fetches it) |
| `ikshvaku run <env> <cmd...>` | Run a command inside an environment without activating — exit codes propagate |
| `ikshvaku export <env>` | Print installed packages (redirect to `requirements.txt`) |
| `ikshvaku clone <src> <dst>` | Duplicate an environment, packages and all |
| `ikshvaku list` / `list --size` | List environments; `--size` adds disk usage and last-used |
| `ikshvaku cleanup [--days N] [--apply] [--cache]` | Report (or delete) environments unused for N days; `--cache` prunes uv's cache |
| `ikshvaku config [key [value]]` | Set `python_default`, `cleanup_days` |
| `ikshvaku status` | Active env, project link, Python version, package count, disk size |
| `ikshvaku doctor` | Health check: installation, uv, shell integration, broken links, cache size |
| `ikshvaku remove <env>` | Delete an environment |
| `ikshvaku --version` | Print the version |
| `ikshvaku-uninstall` | Remove Ikshvaku entirely |

All commands support **tab completion** for subcommands and environment names,
in every supported shell.

### Packages & pip

Every environment ships with **pip preinstalled** (seeded by uv), so the
classic workflow works out of the box — including `python -m pip`:

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

The install command runs in an isolated cycle — packages land in the target
environment, and whatever you have active in your current shell is never
disturbed.

---

## 🔗 Project linking

Ikshvaku remembers which environment belongs to which project:

```bash
cd myproject
ikshvaku init        # creates (if needed), links, activates
```

- `ikshvaku activate` with no argument uses the linked env — from the project
  root **or any subdirectory** (nearest parent wins, git-style)
- `ikshvaku auto on` switches environments automatically as you `cd` — opt-in,
  supported in bash (PROMPT_COMMAND), zsh (chpwd) and PowerShell (cd wrapper)
- Links live in plain text at `~/.ikshvaku/registry`
- `ikshvaku doctor` reports broken links, duplicated shell integrations and
  uv cache size; `ikshvaku status` shows where you are at a glance

---

## 🧹 Hygiene & scripting

Environments track when they were last used, so Ikshvaku can tell you what
your disk is doing — and clean it up safely:

```console
$ ikshvaku list --size
ENV                   SIZE  LAST USED
webapp                12 MB 2026-10-19
old-experiment       6.6 MB 2026-07-02

$ ikshvaku cleanup
ikshvaku cleanup — stale = unused for 90 days (linked projects and the active env are always kept)
  keep      webapp             linked to a project
  stale     old-experiment     last used 2026-07-02
Dry run: 1 environment(s) would be deleted. Re-run with --apply.

$ ikshvaku cleanup --apply --cache   # delete stale + prune uv's cache
```

Linked projects and the active environment are **always** kept.

Scripting and CI never need to touch your shell:

```bash
ikshvaku run webapp python manage.py test   # run inside an env, exit codes propagate
ikshvaku export webapp > requirements.txt   # freeze packages
ikshvaku clone webapp webapp-py313          # duplicate an environment
```

`ikshvaku init` in a project containing a `requirements.txt` creates the env,
installs its dependencies, links, and activates — one command from clone to
working. Defaults live in `ikshvaku config` (`python_default`, `cleanup_days`).

---

## ⚙️ How it works

Ikshvaku is a thin, transparent shell layer over [uv](https://docs.astral.sh/uv/).
There is no daemon and no database — just files and functions:

```
you ──▶ ikshvaku (shell function)
              │
              ├── uv venv --seed ~/.Python-Env/<name>     # create (with pip)
              ├── uv python install 3.12                  # version on demand
              ├── uv pip install --python <env> ...       # install (fast path)
              └── source <env>/{bin,Scripts}/activate     # activate
```

**What the installer places on your machine:**

```
~/.ikshvaku/            ikshvaku.sh · completion.sh (or .ps1/.cmd on Windows)
~/.Python-Env/          all your environments
~/.local/bin/           ikshvaku-uninstall (+ ikshvaku.cmd shim on Windows)
~/.bashrc | ~/.zshrc    a marked block sourcing the above
~/.cache/uv/            uv's shared package & interpreter cache
```

Removing the block from your rc file (or running `ikshvaku-uninstall`)
returns your shell to exactly how it was.

---

## 🖥 Platform support

| Platform | Status | Shell integration |
|---|---|---|
| Linux | ✅ Supported | bash (zsh supported too) |
| macOS | ✅ Supported | bash & zsh (default) |
| Windows — WSL | ✅ Supported | bash |
| Windows — Git Bash | ✅ Supported | bash |
| Windows — PowerShell 5 & 7 | ✅ Supported | function + tab completion |
| Windows — cmd | ✅ Supported | native activate/deactivate via shim |

The installer detects your OS and shell automatically and integrates with the
right rc file (`.bashrc` for bash, `.zshrc` for zsh — with a bash-completion
shim so tab-completion works there too). On Windows, `install.ps1` wires both
PowerShell and cmd.

---

## 📊 Performance

Measured on a real machine, not marketing:

| | Ikshvaku (uv) | Classic `python -m venv` |
|---|---|---|
| Environment size (empty) | **~60 KB** | ~13 MB |
| Environment size (with pip) | ~6 MB | ~13 MB |
| Create time | **< 1 s** | 1–3 s |
| Package install | **5–100× faster** (uv resolver + cache) | pip |
| Python version on demand | ✅ cached once, shared by all envs | ❌ |

Environments hardlink files from uv's shared cache (`~/.cache/uv`), so ten
environments with the same packages cost roughly the disk space of one.

---

## ⚖ Comparison

| Tool | Lightweight | System Python | Centralized envs | Shell-integrated | Python versions |
|---|---|---|---|---|---|
| **Ikshvaku** | ✅ | ✅ | ✅ | ✅ | ✅ via uv |
| virtualenv | ⚠️ | ✅ | ❌ | ❌ | ❌ |
| pyenv | ❌ | ❌ | ⚠️ | ⚠️ | ✅ |
| Conda | ❌ | ❌ | ✅ | ⚠️ | ✅ |

---

## ❓ FAQ

**Why `uv` instead of `venv`/`pip`?**
Speed and disk space. uv (written in Rust) creates environments in
milliseconds, hardlinks packages from a shared cache, and can download Python
versions on demand. Ikshvaku wraps it in a simple, centralized, shell-native
workflow.

**Where do my environments live?**
`~/.Python-Env/<name>` — always. One place, easy to back up, easy to clean.

**Do I still need `pip`?**
No — but it's there anyway. Every environment is seeded with pip, so both
`pip install ...` and `uv pip install ...` work inside an activated env.

**Why a central directory instead of a `.venv` in each project?**
Environments become first-class citizens: listed, tab-completed, and reusable
across projects. Activate any env anywhere with one command.

**Can I use a specific Python version?**
Yes: `ikshvaku create myapp 3.12`. uv downloads it once and shares it.

**Does it work in cmd?**
Yes — `activate`/`deactivate` run natively via the `ikshvaku.cmd` shim;
everything else delegates to PowerShell.

**Is auto-activation safe?**
It's opt-in (`ikshvaku auto on`) and predictable: on `cd`, Ikshvaku looks up
the nearest linked project and switches only between linked environments. It
never touches anything outside linked projects, and `ikshvaku auto off`
reverts it instantly.

**Does uninstalling remove uv?**
No — uv is a shared tool other projects may use. Remove it with
`uv self uninstall` if you want.

---

## 🗺 Roadmap

- [x] Non-interactive / scripting mode (`run`, `export`, `clone`)
- [x] Disk-space tooling (`list --size`, `cleanup`, cache pruning)
- [ ] Fish support
- [ ] Documentation site
- [ ] `ikshvaku upgrade` — self-update

---

## 🤝 Contributing

Contributions are welcome! The codebase is deliberately small — a few hundred
lines of Bash and PowerShell. CI smoke-tests every change on Ubuntu, macOS and
Windows (bash, zsh, PowerShell 5/7 and cmd), so breakage gets caught early.

1. Fork the repository
2. Create your branch: `git checkout -b my-feature`
3. Commit and push, then open a Pull Request

Found a bug? [Open an issue](https://github.com/ashish-jha-73/IkshvakuPEM/issues).

---

## ⭐ Support

If Ikshvaku made your workflow faster, please **star the repository** — it
helps others discover it.

Built on the shoulders of [**uv**](https://docs.astral.sh/uv/) by Astral —
the engine that makes all of this fast.

<div align="center">

**Ikshvaku** — named after King Ikshvaku, founder of the Suryavamsha dynasty.

</div>

---

## 📄 License

MIT — see [LICENSE](LICENSE).
