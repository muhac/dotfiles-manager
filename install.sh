#!/bin/bash
set -e

REPO_URL="${REPO_URL:-__REPO_URL__}"
BRANCH="${BRANCH:-main}"
CLONE_DIR="$HOME/.dotfiles"

command -v git >/dev/null 2>&1 || { echo >&2 "git is required but not installed."; exit 1; }

if [ -d "$CLONE_DIR/.git" ]; then
  echo "Repo already exists at $CLONE_DIR, pulling latest..."
  git -C "$CLONE_DIR" fetch origin
  git -C "$CLONE_DIR" checkout "$BRANCH"
  git -C "$CLONE_DIR" pull --recurse-submodules
elif [ -d "$CLONE_DIR" ]; then
  echo >&2 "Error: $CLONE_DIR already exists but is not a git repo. Please remove it first."
  exit 1
else
  echo "Cloning $REPO_URL (branch: $BRANCH) into $CLONE_DIR..."
  git clone --recurse-submodules --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR"
fi

echo "Running symlink.sh..."
bash "$CLONE_DIR/symlink.sh"
