#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/symlink.sh" ]; then
  echo >&2 "Error: symlink.sh not found in $SCRIPT_DIR."
  echo >&2 "This script must be run from within the dotfiles repository."
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
SUDO=""
[ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

apt_install() {
  # Usage: apt_install <pkg> [<pkg> ...]
  if command -v apt-get >/dev/null 2>&1; then
    ${SUDO} apt-get update -qq && ${SUDO} apt-get install -y "$@"
  elif command -v apt >/dev/null 2>&1; then
    ${SUDO} apt update -qq && ${SUDO} apt install -y "$@"
  else
    echo >&2 "Warning: apt not found, skipping install of: $*"
  fi
}

# ---------------------------------------------------------------------------
# Linux-only setup (Codespaces / remote)
# ---------------------------------------------------------------------------
SKIP_SYSTEM_SETUP="${SKIP_SYSTEM_SETUP:-0}"

if [ "$SKIP_SYSTEM_SETUP" = "1" ]; then
  echo "Skipping system setup (SKIP_SYSTEM_SETUP=$SKIP_SYSTEM_SETUP)"
elif [ "$(uname -s)" = "Linux" ]; then

  # -- zsh ------------------------------------------------------------------
  command -v zsh >/dev/null 2>&1 || { echo "Installing zsh..."; apt_install zsh; }

  if command -v zsh >/dev/null 2>&1; then
    ZSH_PATH="$(command -v zsh)"
    if ! grep -qF "$ZSH_PATH" /etc/shells 2>/dev/null; then
      if ! echo "$ZSH_PATH" | ${SUDO} tee -a /etc/shells >/dev/null; then
        echo >&2 "Warning: could not add $ZSH_PATH to /etc/shells."
      fi
    fi
    if [ "$SHELL" != "$ZSH_PATH" ]; then
      echo "Changing default shell to zsh..."
      if ! ${SUDO} chsh -s "$ZSH_PATH" "$(whoami)"; then
        echo >&2 "Warning: failed to change default shell; continuing."
      fi
    fi
  fi

  # -- starship -------------------------------------------------------------
  if ! command -v starship >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1; then
      echo "Installing starship..."
      if ! curl -fsSL https://starship.rs/install.sh | sh -s -- --yes; then
        echo >&2 "Warning: starship install failed; continuing."
      fi
    else
      echo >&2 "Warning: curl not found, skipping starship install."
    fi
  fi
  # init. starship for bash (Codespaces default shell)
  if [ -f "$HOME/.bashrc" ] && ! grep -qF "eval \"\$(starship init bash)\"" "$HOME/.bashrc"; then
    echo "Adding starship init to .bashrc..."
    echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
  fi

fi

# ---------------------------------------------------------------------------
echo "Running symlink.sh from $SCRIPT_DIR..."
bash "$SCRIPT_DIR/symlink.sh"
