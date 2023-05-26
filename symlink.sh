#!/bin/bash

if [ "$(uname)" = "Darwin" ]; then
    echo Mac OS
    brew install stow

elif [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]; then
    echo Linux
    apt install stow -y

elif [ "$(expr substr $(uname -s) 1 10)" = "MINGW32_NT" ]; then
    echo Windows
fi

echo $(stow --version)

mkdir -p ~/.config

SHELL_FOLDER=$(dirname $(readlink -f "$0"))
echo $SHELL_FOLDER
cd $SHELL_FOLDER
cd dotfiles

find . -name '.DS_Store' -type f -delete
find ~ -maxdepth 1 -type l -exec test ! -e {} \; -delete
find ~/.config -maxdepth 1 -type l -exec test ! -e {} \; -delete

stow zsh --target=`echo ~` --restow
stow vim --target=`echo ~` --restow

