#!/bin/bash

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

mkdir -p ~/.config

SHELL_FOLDER=$(dirname "$(realpath "$0")")
echo "$SHELL_FOLDER"
cd "$SHELL_FOLDER/dotfiles" || exit 2

find . -name '.DS_Store' -type f -delete
find -L ~ -maxdepth 1 -type l -delete
find -L ~/.config -maxdepth 1 -type l -delete

for dir in */ ; do
    stow "${dir%/}" --target="$HOME" --restow
done

echo Done! "$(date)"
