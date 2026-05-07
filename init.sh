#!/bin/bash
set -e

REPO_URL_PLACEHOLDER="__REPO""_URL__"
DOTCTL_BASE_URL_PLACEHOLDER="__DOTCTL""_BASE_URL__"
REPO_URL="${REPO_URL:-__REPO_URL__}"
DOTCTL_BASE_URL="${DOTCTL_BASE_URL:-__DOTCTL_BASE_URL__}"
BRANCH="${BRANCH:-main}"
CLONE_DIR="$HOME/.dotfiles"
AUTO_STASH_DIRTY="${AUTO_STASH_DIRTY:-0}"
FIX_ORIGIN_URL="${FIX_ORIGIN_URL:-0}"
RUN_DOTCTL="${RUN_DOTCTL:-1}"
DOWNLOAD_DOTCTL="${DOWNLOAD_DOTCTL:-1}"
DOTCTL_TMP_DIR=""

cleanup_dotctl() {
  if [ -n "$DOTCTL_TMP_DIR" ] && [ -d "$DOTCTL_TMP_DIR" ]; then
    rm -rf "$DOTCTL_TMP_DIR"
  fi
}
trap cleanup_dotctl EXIT

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

dotctl_asset_name() {
  local os
  local arch
  local exe=""

  case "$(uname -s)" in
    Darwin)
      os="macos"
      ;;
    Linux)
      os="linux"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      os="windows"
      exe=".exe"
      ;;
    *)
      return 1
      ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)
      arch="x64"
      ;;
    arm64|aarch64)
      arch="arm64"
      ;;
    *)
      return 1
      ;;
  esac

  echo "dotctl-${os}-${arch}${exe}"
}

download_dotctl() {
  if [ "$DOWNLOAD_DOTCTL" != "1" ]; then
    echo "Skipping dotctl download (DOWNLOAD_DOTCTL=$DOWNLOAD_DOTCTL)"
    return 1
  fi

  if [ -z "$DOTCTL_BASE_URL" ] || [ "$DOTCTL_BASE_URL" = "$DOTCTL_BASE_URL_PLACEHOLDER" ]; then
    echo >&2 "Warning: DOTCTL_BASE_URL is not set, skipping dotctl download."
    return 1
  fi

  command -v curl >/dev/null 2>&1 || {
    echo >&2 "Warning: curl is required to download dotctl, skipping."
    return 1
  }

  local asset
  if ! asset="$(dotctl_asset_name)"; then
    echo >&2 "Warning: unsupported OS/architecture for prebuilt dotctl: $(uname -s)/$(uname -m)"
    return 1
  fi

  local tmp_parent="${TMPDIR:-/tmp}"
  tmp_parent="${tmp_parent%/}"
  if ! DOTCTL_TMP_DIR="$(mktemp -d "$tmp_parent/dotctl.XXXXXX")"; then
    echo >&2 "Warning: failed to create temporary directory for dotctl."
    return 1
  fi

  local bin="$DOTCTL_TMP_DIR/dotctl"
  if [ "${asset%.exe}" != "$asset" ]; then
    bin="$DOTCTL_TMP_DIR/dotctl.exe"
  fi

  echo "Downloading dotctl from $DOTCTL_BASE_URL/bin/$asset..."
  if ! curl -fsSL "$DOTCTL_BASE_URL/bin/$asset" -o "$bin"; then
    echo >&2 "Warning: failed to download dotctl."
    return 1
  fi
  if ! chmod +x "$bin"; then
    echo >&2 "Warning: failed to make dotctl executable."
    return 1
  fi
  DOTCTL_BIN="$bin"
}

run_dotctl() {
  if [ "$RUN_DOTCTL" != "1" ]; then
    echo "Skipping dotctl sync (RUN_DOTCTL=$RUN_DOTCTL)"
    return
  fi

  local dotctl_bin
  dotctl_bin="$(command -v dotctl 2>/dev/null || true)"

  if [ -z "$dotctl_bin" ]; then
    if download_dotctl; then
      dotctl_bin="$DOTCTL_BIN"
    fi
  fi

  if [ -z "$dotctl_bin" ]; then
    echo >&2 "Warning: dotctl is not available, skipping Codex config sync."
    return
  fi

  echo "Syncing Codex config with dotctl..."
  (cd "$CLONE_DIR" && "$dotctl_bin" push codex --backup)
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

run_dotctl
