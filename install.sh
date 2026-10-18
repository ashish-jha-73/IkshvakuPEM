#!/usr/bin/env bash
set -e

if [[ $EUID -eq 0 ]]; then
  printf "\033[0;31m❌ Do not run this installer as root\033[0m\n"
  exit 1
fi

# Where this script lives — and where its payload files are.
# When piped (curl ... | bash) there is no checkout on disk: fetch the
# payload from GitHub instead. IKSHVAKU_REPO_RAW overrides the source
# (useful for forks and tests).
SCRIPT_DIR="$(dirname "$0")"
if [ ! -f "$SCRIPT_DIR/ikshvaku.sh" ]; then
  RAW_BASE="${IKSHVAKU_REPO_RAW:-https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main}"
  PAYLOAD_DIR="$(mktemp -d)"
  trap 'rm -rf "$PAYLOAD_DIR"' EXIT
  printf ":: Remote install — downloading Ikshvaku files...\n"
  ikshvaku_fetch() {
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$RAW_BASE/$1" -o "$PAYLOAD_DIR/$1"
    elif command -v wget >/dev/null 2>&1; then
      wget -qO "$PAYLOAD_DIR/$1" "$RAW_BASE/$1"
    else
      printf "\033[0;31m❌ curl or wget is required to install Ikshvaku\033[0m\n"
      exit 1
    fi
  }
  for f in ikshvaku.sh completion.sh uninstall.sh; do
    ikshvaku_fetch "$f" || {
      printf "\033[0;31m❌ download failed — check your internet connection\033[0m\n"
      exit 1
    }
  done
  SCRIPT_DIR="$PAYLOAD_DIR"
fi

OS_NAME="$(uname -s)"                       # Linux / Darwin / MINGW*_NT-* (Git Bash) / ...
SHELL_NAME="$(basename "${SHELL:-bash}")"   # bash / zsh / ...

if [ "$SHELL_NAME" = "zsh" ]; then
  RC_FILE="$HOME/.zshrc"
else
  RC_FILE="$HOME/.bashrc"
fi

INSTALL_DIR="$HOME/.ikshvaku"
BIN_DIR="$HOME/.local/bin"
ENV_DIR="$HOME/.Python-Env"
UV_INSTALLER="https://astral.sh/uv/install.sh"
IKSHVAKU_VERSION="1.2.0"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

printf ":: Installing Ikshvaku %s...\n" "$IKSHVAKU_VERSION"
printf ":: Detected OS: %s | Shell: %s\n" "$OS_NAME" "$SHELL_NAME"

# uv lives in ~/.local/bin (or ~/.cargo/bin on older setups) — make sure it is reachable
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# --- uv: powers all environments. Downloaded automatically if missing. ---
if command -v uv >/dev/null 2>&1; then
  printf ":: uv found at $(command -v uv)\n"
else
  printf "${YELLOW}:: uv not found — downloading uv...${RESET}\n"
  if command -v curl >/dev/null 2>&1; then
    curl -LsSf "$UV_INSTALLER" | sh
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$UV_INSTALLER" | sh
  else
    printf "${RED}❌ curl or wget is required to download uv${RESET}\n"
    exit 1
  fi
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  if ! command -v uv >/dev/null 2>&1; then
    printf "${RED}❌ uv installation failed. Install it manually: https://docs.astral.sh/uv/${RESET}\n"
    exit 1
  fi
  printf "${GREEN}:: uv installed${RESET}\n"

  # The uv installer usually adds itself to your shell rc; this is a safety net
  # so ~/.local/bin stays on PATH in future sessions.
  if ! grep -q '.local/bin' "$RC_FILE" 2>/dev/null; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC_FILE"
  fi
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$ENV_DIR"
touch "$RC_FILE"

cp -f "$SCRIPT_DIR/ikshvaku.sh" "$SCRIPT_DIR/completion.sh" "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh

ln -sf "$INSTALL_DIR/uninstall.sh" "$BIN_DIR/ikshvaku-uninstall"

if ! grep -q "ikshvaku/ikshvaku.sh" "$RC_FILE"; then
  {
    printf '\n# >>> Ikshvaku >>>\n'
    if [ "$SHELL_NAME" = "zsh" ] && ! grep -q 'bashcompinit' "$RC_FILE" 2>/dev/null; then
      # zsh needs a shim to understand bash-style completion scripts
      printf 'autoload -U +X bashcompinit && bashcompinit\n'
    fi
    printf 'source ~/.ikshvaku/ikshvaku.sh\n'
    printf 'source ~/.ikshvaku/completion.sh\n'
    printf '# <<< Ikshvaku <<<\n'
  } >> "$RC_FILE"
fi


printf "${GREEN}:: Installed successfully${RESET}\n"
printf "${GREEN}:: Restart your shell or run: source %s${RESET}\n" "$RC_FILE"
printf "${GREEN}:: To support us, click here:${RESET}\n"
printf "${GREEN}:: https://github.com/ashish-jha-73/IkshvakuPEM${RESET}\n"
printf "${GREEN}:: Installation is complete. You may now safely delete the IkshvakuPEM directory.${RESET}\n"
printf "${GREEN}:: Ikshvaku is very lightweight, so you can safely ignore it when not in use.${RESET}\n"
printf "${GREEN}:: If you ever want to remove Ikshvaku, run: ikshvaku-uninstall${RESET}\n"
