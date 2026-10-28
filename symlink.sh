#!/bin/bash

SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd)
CONF_FILE="$SHELL_FOLDER/symlink.conf"

USERNAME=$(whoami)
echo "Hello, $USERNAME!"

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
echo -n "Operating System: "

if [[ "$(uname)" == "Darwin" ]]; then
    echo Mac OS

elif [[ "$(uname -s)" == Linux* ]]; then
    echo Linux

elif [[ "$(uname -s)" == MINGW* ]]; then
    echo Windows
    export MSYS=winsymlinks:nativestrict
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

# ---------------------------------------------------------------------------
# Submodule init/update
# ---------------------------------------------------------------------------
cd "$SHELL_FOLDER" || exit 2

UPDATE_SUBMODULES="${UPDATE_SUBMODULES:-0}"
git submodule init
if [[ "$UPDATE_SUBMODULES" == "1" ]]; then
    echo "Updating submodules to remote tracking branches..."
    git submodule update --remote --recursive
else
    git submodule update --init --recursive
fi

# ---------------------------------------------------------------------------
# Parse symlink.conf
# ---------------------------------------------------------------------------
if [[ ! -f "$CONF_FILE" ]]; then
    echo >&2 "Error: $CONF_FILE not found."
    exit 1
fi

SOURCES=()
TARGETS=()
ENTRY_FLAGS=()

expand_dest() {
    local path="$1"
    case "$path" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s\n' "$HOME/${path#"~/"}"
            ;;
        '$HOME')
            printf '%s\n' "$HOME"
            ;;
        '$HOME/'*)
            printf '%s\n' "$HOME/${path#"\$HOME/"}"
            ;;
        *)
            printf '%s\n' "$path"
            ;;
    esac
}

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line%$'\r'}"
    [[ -z "${line// /}" ]] && continue

    IFS=$'\t' read -ra fields <<< "$line"
    src="${fields[0]%$'\r'}"
    dest=""
    flags=""
    for f in "${fields[@]:1}"; do
        f="${f%$'\r'}"
        if [[ "$f" == flag:* ]]; then
            flags="${flags:+$flags,}${f#flag:}"
        else
            dest="$f"
        fi
    done
    dest_provided=1
    if [[ -z "$dest" ]]; then
        dest="$HOME/"
        dest_provided=0
    fi
    dest_is_root=0
    [[ "$dest" == */ ]] && dest_is_root=1
    dest="$(expand_dest "$dest")"
    if [[ "$dest_is_root" == "1" ]]; then
        dest="${dest%/}"
        [[ -z "$dest" ]] && dest="/"
    fi

    # Strip trailing / (convention only)
    src="${src%/}"

    # Glob expansion: pkg/* → all files in dotfiles/pkg/
    if [[ "$src" == *'/*' ]]; then
        glob_dir="${src%/*}"
        src_dir="$SHELL_FOLDER/dotfiles/$glob_dir"
        if [[ -d "$src_dir" ]]; then
            for item in "$src_dir"/*; do
                [[ -e "$item" ]] || continue
                [[ -d "$item" ]] && continue
                name="${item##*/}"
                rel="${item#$SHELL_FOLDER/dotfiles/}"
                rel="${rel#*/}"
                SOURCES+=("$item")
                TARGETS+=("$dest/$rel")
                ENTRY_FLAGS+=("$flags")
            done
            # Also match dotfiles (hidden files)
            for item in "$src_dir"/.*; do
                [[ -e "$item" ]] || continue
                name="${item##*/}"
                [[ "$name" == "." || "$name" == ".." ]] && continue
                [[ -d "$item" ]] && continue
                rel="${item#$SHELL_FOLDER/dotfiles/}"
                rel="${rel#*/}"
                SOURCES+=("$item")
                TARGETS+=("$dest/$rel")
                ENTRY_FLAGS+=("$flags")
            done
        fi
        continue
    fi

    source_path="$SHELL_FOLDER/dotfiles/$src"
    rel="${src#*/}"
    if [[ "$dest_is_root" == "1" || "$dest_provided" == "0" ]]; then
        target_path="$dest/$rel"
    else
        target_path="$dest"
    fi

    SOURCES+=("$source_path")
    TARGETS+=("$target_path")
    ENTRY_FLAGS+=("$flags")
done < "$CONF_FILE"

# ---------------------------------------------------------------------------
# Clean broken symlinks
# ---------------------------------------------------------------------------
CLEAN_BROKEN_LINKS="${CLEAN_BROKEN_LINKS:-1}"

if [[ "$CLEAN_BROKEN_LINKS" == "1" ]]; then
    cleanup_dirs="$HOME"
    for target in "${TARGETS[@]}"; do
        parent="$(dirname "$target")"
        case "$cleanup_dirs" in
            *"$parent"*) ;;
            *) cleanup_dirs="$cleanup_dirs"$'\n'"$parent" ;;
        esac
    done

    while IFS= read -r dir; do
        [[ -d "$dir" ]] || continue
        find -L "$dir" -maxdepth 1 -type l -exec rm -f {} +
        if [[ "$dir" != "$HOME" ]]; then
            find "$dir" -depth -mindepth 1 -type d -empty -exec rmdir {} + 2>/dev/null
        fi
    done <<< "$cleanup_dirs"
else
    echo "Skipping broken symlink cleanup (CLEAN_BROKEN_LINKS=$CLEAN_BROKEN_LINKS)"
fi

# ---------------------------------------------------------------------------
# Link entries
# ---------------------------------------------------------------------------
link_status=0
for i in "${!SOURCES[@]}"; do
    source_path="${SOURCES[$i]}"
    target_path="${TARGETS[$i]}"
    flags="${ENTRY_FLAGS[$i]}"
    rel="${target_path#$HOME/}"

    if [[ ! -e "$source_path" ]]; then
        echo "  Warning: source not found: $source_path"
        continue
    fi

    # A linked parent can make the target refer to the repository's source itself.
    if [[ "$target_path" -ef "$source_path" ]]; then
        echo "  Skipping: ~/$rel (already points to source)"
        continue
    fi

    # flag:skip-existing — skip if target is a real file/dir (not a symlink)
    if [[ ",$flags," == *",skip-existing,"* ]]; then
        if [[ -e "$target_path" && ! -L "$target_path" ]]; then
            echo "  Skipping: ~/$rel (exists)"
            continue
        fi
    fi

    if ! mkdir -p "$(dirname "$target_path")"; then
        echo >&2 "Error: failed to create parent directory for $target_path."
        link_status=1
        continue
    fi
    if [[ -d "$source_path" && -d "$target_path" && ! -L "$target_path" ]]; then
        echo "  Warning: ~/$rel is a real directory, cannot replace with symlink"
        continue
    fi

    if [[ -e "$target_path" && ! -L "$target_path" ]]; then
        ts="$(date +%Y%m%d-%H%M%S)"
        backup_idx=0
        backup_path="${target_path}.bak.${ts}"
        while [[ -e "$backup_path" || -L "$backup_path" ]]; do
            backup_idx=$((backup_idx + 1))
            backup_path="${target_path}.bak.${ts}.${backup_idx}"
        done
        echo "  Backing up: ~/$rel -> ${backup_path##*/}"
        if ! mv "$target_path" "$backup_path"; then
            echo >&2 "Error: failed to back up $target_path; refusing to replace it."
            link_status=1
            continue
        fi
    fi

    if [[ -L "$target_path" ]] && ! rm -f "$target_path"; then
        echo >&2 "Error: failed to remove existing link $target_path."
        link_status=1
        continue
    fi
    if ! ln -s "$source_path" "$target_path"; then
        echo >&2 "Error: failed to link $target_path to $source_path."
        link_status=1
        continue
    fi
    if [[ -d "$source_path" ]]; then
        echo "  Linked: ~/$rel/"
    else
        echo "  Linked: ~/$rel"
    fi
done

if [[ "$link_status" -eq 0 ]]; then
    echo Done!
else
    echo >&2 "Completed with errors."
fi
echo "$(date)"
exit "$link_status"
