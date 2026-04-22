# Dotfiles Manager

- `.config` files are linked file-by-file.
- Other top-level package entries are linked as whole files/directories.
- Existing real files/dirs are backed up with a timestamp suffix before linking.

## Install

### Option 1: Remote install (GitHub Pages)

```bash
curl -fsSL https://muhac.github.io/dotfiles-manager/install.sh | bash
```

This downloads the published installer, clones the repo to `~/.dotfiles`, and creates symlinks.

### Option 2: Run from a local clone

```bash
bash install.sh
```

`install.sh` runs Linux workspace setup (zsh/starship) when needed, then calls `symlink.sh`.

## Script entrypoints

- `init.sh`: template source for the published installer (used by the deploy workflow).
- `install.sh`: repository entrypoint for local/dev setup.
- `symlink.sh`: links dotfiles into `$HOME`.

## Useful environment variables

- `BRANCH` (default: `main`): branch used by `init.sh` clone/update flow.
- `SKIP_SYSTEM_SETUP=1`: skip Linux system setup in `install.sh`.
- `CLEAN_BROKEN_LINKS=0`: skip broken symlink cleanup in `symlink.sh`.
