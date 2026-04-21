#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/symlink.sh" ]; then
  echo >&2 "Error: symlink.sh not found in $SCRIPT_DIR."
  echo >&2 "This script must be run from within the dotfiles repository."
  exit 1
fi

echo "Running symlink.sh from $SCRIPT_DIR..."
bash "$SCRIPT_DIR/symlink.sh"
