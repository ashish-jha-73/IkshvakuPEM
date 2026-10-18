# Changelog

All notable changes to Ikshvaku are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows [SemVer](https://semver.org/).

## [1.2.0] — 2026-10-19

Memory, hygiene, and scripting — environments now track their own lifecycle.

### Added
- **Usage tracking** — every environment records when it was last used
  (creation, activation, install, run). Plain-text state in
  `~/.ikshvaku/state/usage/`.
- **`ikshvaku list --size`** — per-environment disk usage and last-used date,
  plus totals for all envs and the uv cache.
- **`ikshvaku cleanup`** — finds environments unused for N days (default 90,
  configurable). Dry-run by default; `--apply` deletes; `--cache` prunes uv's
  cache. Linked projects and the active environment are always kept.
- **`ikshvaku run <env> <cmd...>`** — run any command inside an environment
  without touching the current shell; exit codes propagate for scripts and CI.
- **`ikshvaku export <env>`** — print installed packages (`> requirements.txt`).
- **`ikshvaku clone <src> <dst>`** — duplicate an environment on the same
  interpreter, packages included.
- **`init` bootstrap** — `ikshvaku init` in a directory with a
  `requirements.txt` installs its dependencies automatically.
- **`ikshvaku config`** — `python_default` (used by `create`/`init`) and
  `cleanup_days`; stored in `~/.ikshvaku/config`, shared across shells.

### Fixed
- Shell-integration helpers no longer abort under `set -e` when state files
  (config/registry/usage) are missing — "not found" is now a clean empty
  result everywhere.

## [1.1.0] — 2026-10-19

The release that makes Ikshvaku project-aware.

### Added
- **Project linking** — `ikshvaku init` links the current directory to an
  environment (creating it if needed) and activates it; `link`/`unlink`
  manage attachments; `links` lists them all. The registry is plain text at
  `~/.ikshvaku/registry`.
- **Bare `ikshvaku activate`** — no argument activates the linked env of the
  current directory, resolving the nearest parent (git-style).
- **Auto-activation** — `ikshvaku auto on`: environments switch automatically
  on `cd`. Opt-in; implemented via PROMPT_COMMAND (bash), `chpwd` (zsh) and a
  `Set-Location` wrapper (PowerShell).
- **`ikshvaku status`** — active env, project link, Python version, package
  count and disk size at a glance.
- **`ikshvaku doctor`** — health check: installation, uv, shell integration
  (with duplicate-block detection), broken registry links and uv cache size.
- **`ikshvaku --version`** — a version constant, finally.

## [1.0.0] — 2026-10-19

First major release: Ikshvaku is now a cross-platform, uv-powered environment
manager with a one-line installer and CI-verified support for every major
platform and shell.

### Added
- **uv under the hood** — environments are created by `uv venv --seed`, with
  real pip in every env and Python versions on demand
  (`ikshvaku create app 3.12` downloads and caches them).
- **Automatic uv bootstrap** — `uv` is downloaded at install time (and
  self-healed on first use) if missing: `curl`/`wget` on Unix, the official
  installer on Windows.
- **`ikshvaku install`** — install packages into any environment via an
  isolated *activate → install → deactivate* cycle; given only package names,
  it targets the active environment.
- **macOS support** — zsh integration with a bash-completion shim, BSD `sed`
  handling, no `realpath` dependency.
- **Windows support** — PowerShell 5 & 7 (function + tab completion), cmd
  (native activate/deactivate via `ikshvaku.cmd`), plus Git Bash and WSL.
- **One-line install** — `curl … install.sh | bash` on Unix,
  `irm … install.ps1 | iex` on Windows; both installers fetch their payload
  when run remotely.
- **CI** — GitHub Actions smoke-tests every change on Ubuntu, macOS and
  Windows across bash, zsh, PowerShell 5/7 and cmd, plus shellcheck lint.

### Changed
- Environments are now seeded with pip (~6 MB) for classic-workflow
  compatibility; unseeded uv environments are ~200× smaller than `venv`.
- Uninstall cleans its marker-delimited block from both `.bashrc` and
  `.zshrc`.
- Repository renamed to **IkshvakuPEM**; all scripts carry the executable bit
  in git.

### Fixed
- Installer works from any working directory, not only the repo root.
- Windows venv layout (`Scripts/` instead of `bin/`) is handled for
  `activate` and package installs.
