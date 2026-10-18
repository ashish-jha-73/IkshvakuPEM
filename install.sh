#!/usr/bin/env bash
set -e

if [[ $EUID -eq 0 ]]; then
  printf "\033[0;31m❌ Do not run this installer as root\033[0m\n"
  exit 1
fi

# Optional version pin: `curl .../install.sh | bash -s -- v1.2.0`
# installs the payload from that tag instead of main.
# Must run BEFORE the payload resolution below.
IK_TAG=""
if [ -n "$1" ]; then
  if ! echo "$1" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    printf "\033[0;31m❌ invalid version '%s' — expected e.g. 1.2.0 or v1.2.0\033[0m\n" "$1"
    exit 1
  fi
  IK_TAG="v$(printf '%s' "$1" | sed 's/^v//')"
fi

# Where this script lives — and where its payload files are.
# Payloads live in src/ in this repository. When piped (curl ... | bash) there
# is no checkout on disk — $0 is the shell's own name, so the current
# directory is never used as a payload source; fetch from GitHub instead.
# IKSHVAKU_REPO_RAW overrides the source (useful for forks and tests).
SCRIPT_DIR="$(dirname "$0")"
case "$(basename "$0")" in
    bash|sh|dash) SCRIPT_DIR="" ;;   # piped execution (curl ... | bash) — no local checkout
esac
PAYLOAD_DIR=""
if [ -f "$SCRIPT_DIR/src/ikshvaku.sh" ]; then
  PAYLOAD_DIR="$SCRIPT_DIR/src"        # repository checkout (this layout)
elif [ -f "$SCRIPT_DIR/ikshvaku.sh" ]; then
  PAYLOAD_DIR="$SCRIPT_DIR"            # legacy flat checkout
fi
if [ -z "$PAYLOAD_DIR" ]; then
  if [ -n "${IKSHVAKU_REPO_RAW:-}" ]; then
    RAW_BASE="$IKSHVAKU_REPO_RAW"
  elif [ -n "$IK_TAG" ]; then
    RAW_BASE="https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/$IK_TAG"
  else
    RAW_BASE="https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main"
  fi
  PAYLOAD_DIR="$(mktemp -d)"
  trap 'rm -rf "$PAYLOAD_DIR"' EXIT
  printf ":: Remote install — downloading Ikshvaku files...\n"
  ikshvaku_fetch() {
    # $1 = payload file name. Payloads live under src/ in current releases;
    # tags from before the reorganization had them flat at the root — try both.
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$RAW_BASE/src/$1" -o "$PAYLOAD_DIR/$1" \
        || curl -fsSL "$RAW_BASE/$1" -o "$PAYLOAD_DIR/$1"
    elif command -v wget >/dev/null 2>&1; then
      wget -qO "$PAYLOAD_DIR/$1" "$RAW_BASE/src/$1" \
        || wget -qO "$PAYLOAD_DIR/$1" "$RAW_BASE/$1"
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
  # optional files (new in 1.4; older tags don't have them)
  for f in completion.zsh ikshvaku.fish; do
    ikshvaku_fetch "$f" 2>/dev/null || rm -f "$PAYLOAD_DIR/$f"
  done
fi

OS_NAME="$(uname -s)"                       # Linux / Darwin / MINGW*_NT-* (Git Bash) / ...
SHELL_NAME="$(basename "${SHELL:-bash}")"   # bash / zsh / ...

case "$SHELL_NAME" in
  zsh)
    RC_FILE="$HOME/.zshrc"
    ;;
  fish)
    RC_FILE="$HOME/.config/fish/config.fish"
    mkdir -p "$HOME/.config/fish"
    ;;
  *)
    RC_FILE="$HOME/.bashrc"
    ;;
esac

INSTALL_DIR="$HOME/.ikshvaku"
BIN_DIR="$HOME/.local/bin"
ENV_DIR="$HOME/.Python-Env"
UV_INSTALLER="https://astral.sh/uv/install.sh"
IKSHVAKU_VERSION="1.4.0"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

printf ":: Installing Ikshvaku %s...\n" "$IKSHVAKU_VERSION"
if [ -n "$IK_TAG" ]; then
  printf ":: Version pinned — installing payload from %s\n" "$IK_TAG"
fi
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

cp -f "$PAYLOAD_DIR/ikshvaku.sh" "$PAYLOAD_DIR/completion.sh" "$PAYLOAD_DIR/uninstall.sh" "$INSTALL_DIR/"
for f in completion.zsh ikshvaku.fish; do
  [ -f "$PAYLOAD_DIR/$f" ] && cp -f "$PAYLOAD_DIR/$f" "$INSTALL_DIR/"
done
chmod +x "$INSTALL_DIR"/*.sh

ln -sf "$INSTALL_DIR/uninstall.sh" "$BIN_DIR/ikshvaku-uninstall"

if ! grep -q ">>> Ikshvaku >>>" "$RC_FILE"; then
  {
    printf '\n# >>> Ikshvaku >>>\n'
    if [ "$SHELL_NAME" = "fish" ]; then
      printf 'source ~/.ikshvaku/ikshvaku.fish\n'
    elif [ "$SHELL_NAME" = "zsh" ]; then
      printf 'if [ -f "$HOME/.ikshvaku/completion.zsh" ]; then\n'
      printf '  source "$HOME/.ikshvaku/completion.zsh"\n'
      printf 'elif [ -f "$HOME/.ikshvaku/completion.sh" ]; then\n'
      printf '  autoload -U +X bashcompinit && bashcompinit\n'
      printf '  source "$HOME/.ikshvaku/completion.sh"\n'
      printf 'fi\n'
      printf 'source ~/.ikshvaku/ikshvaku.sh\n'
    else
      printf 'source ~/.ikshvaku/ikshvaku.sh\n'
      printf 'source ~/.ikshvaku/completion.sh\n'
    fi
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
