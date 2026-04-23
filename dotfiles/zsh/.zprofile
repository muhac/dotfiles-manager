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

path_prepend_if_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
}

path_append_if_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$PATH:$dir" ;;
  esac
}

# Language/runtime paths (login shell only)
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
path_prepend_if_dir "$PYENV_ROOT/bin"
path_prepend_if_dir "$HOME/.jenv/bin"
path_prepend_if_dir "/opt/homebrew/opt/openjdk/bin"
path_prepend_if_dir "$HOME/.ghcup/bin"

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
path_prepend_if_dir "$BUN_INSTALL/bin"
# export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/bottles

# Added by Toolbox App
path_append_if_dir "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
path_append_if_dir "/usr/local/bin"

# Created by pipx
path_append_if_dir "$HOME/.local/bin"

unset -f path_prepend_if_dir
unset -f path_append_if_dir

export DOTFILES_ZPROFILE_LOADED=1
