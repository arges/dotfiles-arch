# dotfiles

Personal dotfiles for a [Hyprland](https://hyprland.org/) desktop, managed with
[GNU Stow](https://www.gnu.org/software/stow/).

Currently targets **Arch Linux**. Cross-distro support for **Ubuntu + Hyprland**
is a planned goal — see [Cross-distro notes](#cross-distro-notes).

## What's here

| Package  | Path                        | Description                                  |
| -------- | --------------------------- | -------------------------------------------- |
| `git`    | `~/.gitconfig`              | Git config (uses `gh` as credential helper)  |
| `hypr`   | `~/.config/hypr/`           | Hyprland, hypridle, hyprlock, hyprpaper      |
| `kitty`  | `~/.config/kitty/`          | Kitty terminal                               |
| `nvim`   | `~/.config/nvim/`           | Neovim                                       |
| `waybar` | `~/.config/waybar/`         | Waybar status bar                            |

## Layout

Each top-level directory is a Stow *package*. Its contents mirror the paths they
install to under `$HOME`, so `waybar/.config/waybar/style.css` is symlinked to
`~/.config/waybar/style.css`.

## Install

```sh
git clone https://github.com/<you>/dotfiles-arch ~/src/dotfiles-arch
cd ~/src/dotfiles-arch

# Install everything
stow */

# ...or a single package
stow waybar
```

Re-run `stow <package>` after adding new files. Use `stow -D <package>` to
remove symlinks and `stow -R <package>` to restow.

### Dependencies (Arch)

```sh
sudo pacman -S stow hyprland hypridle hyprlock hyprpaper waybar kitty neovim \
  ttf-jetbrains-mono-nerd noto-fonts-emoji github-cli
```

## Machine-local overrides

Secrets and per-machine settings are kept out of the repo (see `.gitignore`):

- `~/.gitconfig.local` — sourced by `git/.gitconfig` via `[include]`; put a
  work email, signing key, or other host-specific git settings here.
- `hypr/.config/hypr/hyprpaper.conf` — ignored because wallpaper paths are
  machine-specific.

## Cross-distro notes

The configs themselves are largely distro-agnostic, but package names and a few
paths differ. Known Ubuntu differences to sort out when adding support:

- Package names differ (`apt` vs `pacman`), and Hyprland is not yet packaged in
  older Ubuntu releases — may need a PPA or a source build.
- The `gh` credential-helper path in `git/.gitconfig`
  (`/usr/bin/gh auth git-credential`) is hardcoded and may vary by distro.
- Nerd Font / emoji font package names differ.

The intent is to gate anything distro-specific so a single checkout works on
both Arch and Ubuntu.
