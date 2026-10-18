# Changelog

All notable changes to Ikshvaku are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/); versioning follows [SemVer](https://semver.org/).

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
