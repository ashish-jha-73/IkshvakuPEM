# Changelog

All notable changes to Ikshvaku are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Changed
- New installs write `# >>> IkshvakuPEM >>>` marker blocks to the shell rc
  file (previously `# >>> Ikshvaku >>>`). The uninstaller removes both the
  new and the legacy markers, and `ikshvaku doctor` recognizes either.

## [1.4.0] — 2026-10-19

Polish release: JSON output, first-class help, Jupyter integration, Fish
support, and a wave of hardening.

### Added
- **`--json` output** for `list`, `status` and `links` — scriptable, CI-ready.
- **`ikshvaku help <command>`** — detailed help for every command.
- **`ikshvaku prompt`** — a `'(env) '` prefix helper for custom PS1 prompts.
- **`ikshvaku jupyter <env>`** — registers an environment as a Jupyter kernel
  (installs `ipykernel` into the env automatically).
- **`init` reads `pyproject.toml`** — installs `[project]` dependencies when
  no `requirements.txt` is present.
- **`config <key> --unset`** and key validation.
- **Fish support** — full-featured `src/ikshvaku.fish`: core commands,
  auto-activation via PWD events, and fish tab completion.
- **Native zsh completion** (`src/completion.zsh`) — zsh users no longer need
  the bashcompinit shim.
- **`cleanup` hardening** — a concurrency lock prevents parallel runs, and
  environments with identical package sets are reported as duplicates.
- **Installer** now ships the fish script and native zsh completion, and
  integrates with `~/.config/fish/config.fish`.

## [1.3.0] — 2026-10-19Distribution release: Homebrew, GitHub Action, self-update, pinned installs.

### Added
- **`ikshvaku upgrade`** — re-runs the platform installer to move to the
  latest release (Homebrew users: `brew upgrade ikshvaku`).
- **Version-pinned installs** — `curl .../install.sh | bash -s -- v1.2.0` or
  set `IKSHVAKU_VERSION` before the PowerShell one-liner. Tags are validated;
  payloads come from the tag, not `main`.
- **Homebrew tap** — [`ashish-jha-73/homebrew-ikshvaku`](https://github.com/ashish-jha-73/homebrew-ikshvaku):
  `brew tap ashish-jha-73/ikshvaku https://github.com/ashish-jha-73/homebrew-ikshvaku`
  then `brew install ikshvaku`. `doctor` recognizes Homebrew installs.
- **`ikshvaku-action`** — [GitHub Action](https://github.com/ashish-jha-73/ikshvaku-action)
  for CI: installs Ikshvaku, creates and links an environment, and exposes its
  Python to later steps via `GITHUB_PATH`.
- **Offline release bundles** — every release ships a tarball
  (`ikshvaku-<version>.tar.gz`) for air-gapped or pinned installs; repository
  only directories are excluded from archives via `git export-ignore`.
- **Packaging starters** — AUR `PKGBUILD`, Scoop notes and packaging guides in
  `packaging/`.
- **Piped-install hardening** — `curl ... | bash` never uses the current
  directory as a payload source, even when run from inside a checkout.

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
