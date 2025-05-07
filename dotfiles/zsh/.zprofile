# Set PATH, MANPATH, etc., for Homebrew.
if [ -e /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -e /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
# export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/bottles

# Added by Toolbox App
export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"export PATH="$PATH:/usr/local/bin"

# Created by pipx
export PATH="$PATH:$HOME/.local/bin"
