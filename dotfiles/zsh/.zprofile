# Set PATH, MANPATH, etc., for Homebrew.
__brew_bin=""
__brew_bins=(
  "/opt/homebrew/bin/brew"
  "/usr/local/bin/brew"
  "$HOME/.linuxbrew/bin/brew"
  "/home/linuxbrew/.linuxbrew/bin/brew"
)

for __brew_candidate in "${__brew_bins[@]}"; do
  if [ -x "$__brew_candidate" ]; then
    __brew_bin="$__brew_candidate"
    break
  fi
done

if [ -n "$__brew_bin" ]; then
  eval "$("$__brew_bin" shellenv)"
fi

unset __brew_bin
unset __brew_bins
unset __brew_candidate
# export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/bottles

# Added by Toolbox App
export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
export PATH="$PATH:/usr/local/bin"

# Created by pipx
export PATH="$PATH:$HOME/.local/bin"
