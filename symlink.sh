#!/bin/bash

USERNAME=$(whoami)
echo "Hello, $USERNAME!"

echo -n "Operating System: "

if [[ "$(uname)" == "Darwin" ]]; then
    echo Mac OS

elif [[ "$(uname -s)" == Linux* ]]; then
    echo Linux

elif [[ "$(uname -s)" == MINGW* ]]; then
    echo Windows
    ## Symlinks on Windows require Developer Mode or admin privileges.
    ## Test by attempting to create a temporary symlink.
    _test_link=$(mktemp -u)
    if ! ln -sf "$0" "$_test_link" 2>/dev/null; then
        echo >&2 "Symlink creation failed. Please enable Developer Mode in Windows Settings"
        echo >&2 "(Settings -> Privacy & Security -> For developers -> Developer Mode)"
        echo >&2 "or re-run this script as Administrator."
        exit 1
    fi
    rm -f "$_test_link"

else
    echo Unknown
    exit 1
fi

## Check if the script is run from the correct directory
SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd)
echo "$SHELL_FOLDER"
cd "$SHELL_FOLDER/dotfiles" || exit 2

## Update the submodules
UPDATE_SUBMODULES="${UPDATE_SUBMODULES:-0}"
git submodule init
if [[ "$UPDATE_SUBMODULES" == "1" ]]; then
    echo "Updating submodules to remote tracking branches..."
    git submodule update --remote --recursive
else
    git submodule update --init --recursive
fi

## This is the config directory
mkdir -p "$HOME/.config"

## Clean up the old symlinks
find . -name '.DS_Store' -type f -delete
CLEAN_BROKEN_LINKS="${CLEAN_BROKEN_LINKS:-1}"
if [[ "$CLEAN_BROKEN_LINKS" == "1" ]]; then
    find -L "$HOME" -maxdepth 1 -type l -delete
    find -L "$HOME/.config" -maxdepth 1 -type l -delete
else
    echo "Skipping broken symlink cleanup (CLEAN_BROKEN_LINKS=$CLEAN_BROKEN_LINKS)"
fi

## Link a dotfiles package:
##   - .config items: link individual files (shared dir, never link the dir itself)
##   - other top-level items: link the whole file/dir, backing up real ones first
link_package() {
    local pkg="$1"
    local src_base="$(pwd)/$pkg"

    ## Top-level items (non-.config): one symlink per item
    while IFS= read -r src_item; do
        local name="${src_item#$src_base/}"

        ## .config is handled separately below
        [[ "$name" == ".config" ]] && continue

        ## Skip .gitconfig if the machine already has its own
        if [[ "$name" == ".gitconfig" && -f "$HOME/$name" && ! -L "$HOME/$name" ]]; then
            echo "  Skipping $name (local config exists)"
            continue
        fi

        local target="$HOME/$name"
        if [[ -e "$target" && ! -L "$target" ]]; then
            local ts backup_idx backup_path
            ts="$(date +%Y%m%d-%H%M%S)"
            backup_idx=0
            backup_path="${target}.bak.${ts}"
            while [[ -e "$backup_path" ]]; do
                backup_idx=$((backup_idx + 1))
                backup_path="${target}.bak.${ts}.${backup_idx}"
            done
            echo "  Backing up: $target -> $backup_path"
            mv "$target" "$backup_path"
        fi
        [[ -L "$target" ]] && rm -f "$target"
        ln -sf "$src_item" "$target"
        echo "  Linked: ~/$name"
    done < <(find "$src_base" -maxdepth 1 -mindepth 1 | sort)

    ## .config items: link individual files so multiple packages can share ~/.config
    if [[ -d "$src_base/.config" ]]; then
        while IFS= read -r src_file; do
            local rel="${src_file#$src_base/}"
            local target="$HOME/$rel"
            mkdir -p "$(dirname "$target")"
            [[ -L "$target" ]] && rm -f "$target"
            ln -sf "$src_file" "$target"
            echo "  Linked: ~/$rel"
        done < <(find "$src_base/.config" -name '.git' -prune -o -type f -print | sort)
    fi
}

## Stow the directories
for dir in */ ; do

    ## Skip unwanted directories
    if [[ ! "$USERNAME" =~ "muhan" && "${dir%/}" == "git" ]]; then
        echo "- Skipping $dir"
        continue
    fi

    echo "Processing $dir"
    link_package "${dir%/}"
done

echo Done!
echo "$(date)"
