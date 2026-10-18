#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/.ikshvaku"
BIN_DIR="$HOME/.local/bin"
SELF_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

printf ":: Uninstalling Ikshvaku...\n"

# Portable in-place edit: GNU sed uses `sed -i`, BSD sed (macOS) uses `sed -i ''`
ikshvaku_sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$1" "$2"     # GNU/Linux/Git Bash
  else
    sed -i '' "$1" "$2"  # BSD/macOS
  fi
}

for RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$RC_FILE" ]; then
    # Remove the marker-delimited block written by recent installers
    ikshvaku_sed_inplace '/^# >>> Ikshvaku >>>$/,/^# <<< Ikshvaku <<<$/d' "$RC_FILE"
    # Legacy (pre-marker) lines, for installs from older versions
    ikshvaku_sed_inplace '/ikshvaku\/ikshvaku\.sh/d' "$RC_FILE"
    ikshvaku_sed_inplace '/ikshvaku\/completion\.sh/d' "$RC_FILE"
  fi
done

rm -rf "$INSTALL_DIR"
rm -rf "$HOME/.Python-Env"
rm -f "$BIN_DIR/ikshvaku-uninstall"

printf "${GREEN}:: Files removed${RESET}\n"

rm -f "$SELF_PATH"

printf "${GREEN}:: Uninstalled successfully${RESET}\n"
printf "${GREEN}:: Restart your shell to apply changes${RESET}\n"
printf "${GREEN}:: uv was left installed (other tools may use it). Remove with: uv self uninstall${RESET}\n"
printf "${GREEN}:: To report any problem, raise an issue at:${RESET}\n"
printf "${GREEN}:: https://github.com/ashish-jha-73/IkshvakuPEM${RESET}\n"
