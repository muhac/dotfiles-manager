#!/bin/bash

if [ "$(type stow)" != "stow not found" ]; then
    echo $(stow --version)

else
    echo "stow not found"

if [ "$(uname)" = "Darwin" ]; then
    echo Mac OS
    brew install stow

elif [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]; then
    echo Linux
    apt install stow -y

elif [ "$(expr substr $(uname -s) 1 10)" = "MINGW32_NT" ]; then
    echo Windows
fi

fi

if [ "$(type stow)" = "stow not found" ]; then
    exit 1
fi

SHELL_FOLDER=$(dirname $(readlink -f "$0"))
echo $SHELL_FOLDER
cd $SHELL_FOLDER
cd dotfiles

stow vim --target=`echo ~`
