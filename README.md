# Dotfiles Manager

Symlinks are declared in [`symlink.conf`](symlink.conf) — one entry per line.
Files are linked individually; directories are linked as a whole.
Existing real files are backed up with a timestamp suffix before linking.

## Install

### Option 1: Remote install (GitHub Pages)

```bash
curl -fsSL https://muhac.github.io/dotfiles-manager/install.sh | bash
```

This downloads the published installer, clones the repo to `~/.dotfiles`, and creates symlinks.
It also applies repo-managed Codex config fields into `~/.codex/config.toml` with
[`dot-sync`](https://github.com/muhac/dot-sync). The installer installs the [`dot-sync`](https://github.com/muhac/dot-sync) nightly release into a temporary
directory and removes it when the installer exits.

Supported parameters for Option 1 (set before `bash`):

- `BRANCH` (default: `main`): branch used by installer clone/update.
- `AUTO_STASH_DIRTY=1`: auto-stash local changes in `~/.dotfiles` before update.
- `FIX_ORIGIN_URL=1`: auto-fix `origin` URL when it differs from expected repository URL.
- `CLEAN_BROKEN_LINKS=0`: skip broken symlink cleanup in `symlink.sh`.
- `UPDATE_SUBMODULES=1`: fast-forward submodules to remote tracking branches (default keeps pinned SHAs).
- `RUN_DOT_SYNC=0`: skip applying managed app config with [`dot-sync`](https://github.com/muhac/dot-sync).
- `DOT_SYNC_INSTALL_URL`: override the [`dot-sync`](https://github.com/muhac/dot-sync) installer URL.

Example:

```bash
curl -fsSL https://muhac.github.io/dotfiles-manager/install.sh | BRANCH=main AUTO_STASH_DIRTY=1 FIX_ORIGIN_URL=1 bash
```

### Option 2: Run from a local clone

```bash
bash install.sh
```

`install.sh` runs Linux workspace setup (zsh/starship) when needed, then calls `symlink.sh`.

## Script entrypoints

- `init.sh`: template source for the published installer (used by the deploy workflow).
- `install.sh`: repository entrypoint for local/dev setup.
- `symlink.sh`: reads `symlink.conf` and links dotfiles into `$HOME`.
- `symlink.conf`: declarative config — see comments in file for format.
- `.sync.yaml`: [`dot-sync`](https://github.com/muhac/dot-sync) config for selected app-owned config fields, such as Codex config.

## Related Projects

- [`dot-sync`](https://github.com/muhac/dot-sync): sync selected fields between structured config files without owning the whole file.

## Useful environment variables

- `BRANCH` (default: `main`): branch used by `init.sh` clone/update flow.
- `AUTO_STASH_DIRTY=1`: auto-stash local changes in `~/.dotfiles` before update.
- `FIX_ORIGIN_URL=1`: auto-fix `origin` URL mismatch in `~/.dotfiles`.
- `SKIP_SYSTEM_SETUP=1`: skip Linux system setup in `install.sh` (Option 2).
- `CLEAN_BROKEN_LINKS=0`: skip broken symlink cleanup in `symlink.sh`.
- `UPDATE_SUBMODULES=1`: fast-forward submodules to their remote tracking branches in `symlink.sh`. Defaults to pinned SHAs for reproducibility.
- `RUN_DOT_SYNC=0`: skip applying managed app config in the remote installer.
- `DOT_SYNC_INSTALL_URL`: override the [`dot-sync`](https://github.com/muhac/dot-sync) installer URL.
