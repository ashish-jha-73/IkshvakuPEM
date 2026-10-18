# Contributing to Ikshvaku

Thank you for your interest! Ikshvaku is deliberately small — a few hundred
lines of Bash and PowerShell — so reading the entire codebase takes minutes.

## Project layout

| File | Role |
|---|---|
| `ikshvaku.sh` | Core: shell function for bash/zsh/Git Bash (Linux, macOS, WSL) |
| `completion.sh` | Bash tab completion (zsh uses it via `bashcompinit`) |
| `ikshvaku.ps1` | Core: PowerShell function (also dispatched by the cmd shim) |
| `ikshvaku.cmd` | cmd shim — native `activate`/`deactivate`, delegates the rest |
| `install.sh` / `install.ps1` | Installers (work locally **and** via one-line remote install) |
| `uninstall.sh` / `uninstall.ps1` | Clean removal |
| `.github/workflows/ci.yml` | CI: lint + smoke tests on Ubuntu, macOS, Windows |

## Local development

```bash
git clone https://github.com/ashish-jha-73/IkshvakuPEM.git
cd IkshvakuPEM

# test in an isolated fake HOME — never pollutes your real one
export HOME=$(mktemp -d)
bash install.sh
```

### Checks to run before every push

```bash
bash -n *.sh                                            # syntax
shellcheck --severity=warning *.sh                      # lint (CI runs this)
pwsh -NoProfile -Command "..."                          # see CI's parse check for .ps1 files
```

CI runs the full smoke suite (create → install → activate → remove) on
Ubuntu, macOS and Windows — in bash, zsh, PowerShell 5/7 and cmd. Your change
must keep it green.

## Ground rules

- **Bash 3.2 compatible** — macOS ships bash 3.2: no associative arrays, no
  `mapfile`, no `${var,,}`.
- **PowerShell 5.1 compatible** — no ternary operator, no `??`.
- Quote every expansion; never expand unquoted variables in `rm -rf`.
- Handle both venv layouts: `bin/` (Unix) and `Scripts/` (Windows).
- Keep the one-line installers working: they must run when piped
  (`curl | bash` / `irm | iex`) with no files on disk.
- User-facing changes update `README.md` and `CHANGELOG.md`.

## Pull requests

1. Fork, then branch: `git checkout -b my-feature`
2. Make the change, run the checks above
3. Open a PR with a short description of *what* and *why*

Small, focused PRs get merged fastest.
