# Packaging Ikshvaku

This directory contains everything needed to distribute Ikshvaku through
native package managers.

## Homebrew (macOS / Linux)

The tap lives at [`ashish-jha-73/homebrew-ikshvaku`](https://github.com/ashish-jha-73/homebrew-ikshvaku)
and contains `Formula/ikshvaku.rb`, which installs the payload from the
release tarball and prints the exact lines to add to your shell rc.

```bash
brew tap ashish-jha-73/ikshvaku https://github.com/ashish-jha-73/homebrew-ikshvaku
brew install ikshvaku
```

To bump the formula for a new release: update `version`, `url` and `sha256`
(`sha256sum` of the release tarball) in the tap's formula and push.

## Arch Linux (AUR)

`PKGBUILD` in this directory is ready for an AUR submission:

1. Create an AUR account and add an SSH key at aur.archlinux.org
2. `git clone aur@aur.archlinux.org:ikshvaku.git` (creates the package base)
3. Copy `PKGBUILD` in, update `pkgver`/`sha256sums` for the release
4. `makepkg --printsrcdata > .SRCINFO && git add -A && git commit && git push`
5. Users install with: `paru -S ikshvaku`

Note: `uv` is available in the Arch `extra` repository and is listed as a
dependency.

## Scoop (Windows)

A bucket repository (`scoop-ikshvaku`) with a JSON manifest mirroring the
Homebrew tap is the natural next step. Scoop can install the payload files
and print the PowerShell profile line — the manifest in this directory is a
starting point.

## Windows winget

Publishing to winget requires a PR to `microsoft/winget-pkgs` with a YAML
manifest per release. Deferred until there is demand — the one-liner covers
Windows today.
