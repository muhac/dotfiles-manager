#!/bin/bash

USERNAME=$(whoami)
echo "Hello, $USERNAME!"

echo -n "Operating System: "

if [[ "$(uname)" == "Darwin" ]]; then
    echo Mac OS
    command -v brew >/dev/null 2>&1 || { echo >&2 "no brew!"; exit 1; }
    command -v stow >/dev/null 2>&1 || brew install stow

elif [[ "$(uname -s)" == Linux* ]]; then
    echo Linux
    command -v apt >/dev/null 2>&1 || { echo >&2 "no apt!"; exit 1; }
    command -v stow >/dev/null 2>&1 || apt install stow -y

elif [[ "$(uname -s)" == MINGW32_NT* ]]; then
    echo Windows
    echo Not supported
    exit 1

else
    echo Unknown
    exit 1
fi

stow --version

## Check if the script is run from the correct directory
SHELL_FOLDER=$(dirname "$(realpath "$0")")
echo "$SHELL_FOLDER"
cd "$SHELL_FOLDER/dotfiles" || exit 2

## Update the submodules
git submodule init
git submodule update --remote --recursive

## This is the config directory
mkdir -p "$HOME/.config"

## Clean up the old symlinks
find . -name '.DS_Store' -type f -delete
find -L "$HOME" -maxdepth 1 -type l -delete
find -L "$HOME/.config" -maxdepth 1 -type l -delete

## Stow the directories
for dir in */ ; do

    ## Skip unwanted directories
    if [[ ! "$USERNAME" =~ "muhan" && "${dir%/}" == "git" ]]; then
        echo "- Skipping $dir"
        continue
    fi

    echo "Processing $dir"
    stow "${dir%/}" --target="$HOME" --restow
done

echo Done!
echo "$(date)"
