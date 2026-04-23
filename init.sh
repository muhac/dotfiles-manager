#!/bin/bash
set -e

REPO_URL_PLACEHOLDER="__REPO""_URL__"
REPO_URL="${REPO_URL:-__REPO_URL__}"
BRANCH="${BRANCH:-main}"
CLONE_DIR="$HOME/.dotfiles"
AUTO_STASH_DIRTY="${AUTO_STASH_DIRTY:-0}"
FIX_ORIGIN_URL="${FIX_ORIGIN_URL:-0}"

normalize_repo_url() {
  local url="$1"
  url="${url%.git}"

  case "$url" in
    git@*:* )
      local host="${url%%:*}"
      local path="${url#*:}"
      host="${host#git@}"
      path="${path#/}"
      echo "https://${host}/${path}"
      return
      ;;
    ssh://git@* )
      url="${url#ssh://git@}"
      local host="${url%%/*}"
      local path="${url#*/}"
      path="${path#/}"
      echo "https://${host}/${path}"
      return
      ;;
    http://*|https://* )
      url="${url#http://}"
      url="${url#https://}"
      url="${url%/}"
      echo "https://${url}"
      return
      ;;
  esac

  echo "$url"
}

if [ -z "$REPO_URL" ] || [ "$REPO_URL" = "$REPO_URL_PLACEHOLDER" ]; then
  echo >&2 "Error: REPO_URL is not set."
  echo >&2 "Run this installer via the published curl/Pages URL so the repository URL is embedded,"
  echo >&2 "or run it locally with REPO_URL set explicitly, for example:"
  echo >&2 "  REPO_URL=https://github.com/<owner>/<repo>.git ./init.sh"
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo >&2 "git is required but not installed."; exit 1; }

if [ -d "$CLONE_DIR/.git" ]; then
  echo "Repo already exists at $CLONE_DIR, pulling latest..."
  CURRENT_ORIGIN_URL="$(git -C "$CLONE_DIR" remote get-url origin 2>/dev/null || true)"
  if [ -z "$CURRENT_ORIGIN_URL" ]; then
    echo >&2 "Error: origin remote is missing in $CLONE_DIR."
    echo >&2 "Please set it first, or remove $CLONE_DIR and rerun."
    exit 1
  fi

  if [ "$(normalize_repo_url "$CURRENT_ORIGIN_URL")" != "$(normalize_repo_url "$REPO_URL")" ]; then
    if [ "$FIX_ORIGIN_URL" = "1" ]; then
      echo "Origin URL mismatch detected, updating origin to $REPO_URL"
      git -C "$CLONE_DIR" remote set-url origin "$REPO_URL"
    else
      echo >&2 "Error: origin URL mismatch in $CLONE_DIR."
      echo >&2 "  Current: $CURRENT_ORIGIN_URL"
      echo >&2 "  Expected: $REPO_URL"
      echo >&2 "Set FIX_ORIGIN_URL=1 to auto-fix origin and continue."
      exit 1
    fi
  fi

  if [ -n "$(git -C "$CLONE_DIR" status --porcelain)" ]; then
    if [ "$AUTO_STASH_DIRTY" = "1" ]; then
      STASH_NAME="auto-stash-before-installer-$(date +%Y%m%d-%H%M%S)"
      echo "Local changes detected, stashing as '$STASH_NAME'..."
      git -C "$CLONE_DIR" stash push -u -m "$STASH_NAME" >/dev/null
    else
      echo >&2 "Error: local changes detected in $CLONE_DIR."
      echo >&2 "Commit/stash/discard them first, or set AUTO_STASH_DIRTY=1."
      exit 1
    fi
  fi

  git -C "$CLONE_DIR" fetch origin
  git -C "$CLONE_DIR" checkout -B "$BRANCH" "origin/$BRANCH"
  git -C "$CLONE_DIR" pull --recurse-submodules origin "$BRANCH"
elif [ -d "$CLONE_DIR" ]; then
  echo >&2 "Error: $CLONE_DIR already exists but is not a git repo. Please remove it first."
  exit 1
else
  echo "Cloning $REPO_URL (branch: $BRANCH) into $CLONE_DIR..."
  git clone --recurse-submodules --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR"
fi

echo "Running symlink.sh..."
bash "$CLONE_DIR/symlink.sh"
