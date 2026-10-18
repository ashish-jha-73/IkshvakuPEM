## What does this PR do?

<!-- A short description of the change and why it's needed. -->

## How was it tested?

- [ ] Linux / WSL
- [ ] macOS
- [ ] Windows (PowerShell / cmd / Git Bash)
- [ ] Fresh `curl | bash` one-line install still works
- [ ] Fresh `irm | iex` one-line install still works

## Checklist

- [ ] `bash -n *.sh` passes
- [ ] `shellcheck --severity=warning *.sh` passes
- [ ] Bash 3.2 compatible (macOS system bash)
- [ ] PowerShell 5.1 compatible (no ternary, no `??`)
- [ ] Both venv layouts handled (`bin/` and `Scripts/`)
- [ ] `README.md` / `CHANGELOG.md` updated if user-facing
