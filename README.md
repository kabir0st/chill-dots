<h1 align="center">
  <br>
  Chill Dots
  <br>
</h1>

<h4 align="center">A complete rice with automatic wallpaper-based theming — for Arch Linux (Hyprland/Omarchy) and PikaOS (niri).</h4>

<p align="center">
  <a href="#screenshots">Screenshots</a> •
  <a href="#features">Features</a> •
  <a href="#whats-included">What's Included</a> •
  <a href="#installation">Installation</a> •
  <a href="#modules">Modules</a> •
  <a href="#auto-theming">Auto Theming</a> •
  <a href="#pikaos-notes">PikaOS Notes</a> •
  <a href="#keybindings">Keybindings</a>
</p>

---

## Screenshots

<p align="center">
  <img src="screenshots/chill_1.jpg" width="49%">
  <img src="screenshots/chill_3.png" width="49%">
</p>
<p align="center">
  <img src="screenshots/chill_2.jpg" width="49%">
  <img src="screenshots/chill_5.jpg" width="49%">
</p>
<p align="center">
  <img src="screenshots/chill_4.jpg" width="80%">
</p>

> Every screenshot above uses the **same config** — the only difference is the wallpaper. Colors are generated automatically.

---

## Features

- **Auto-theming** — [wallust](https://codeberg.org/explosion-mental/wallust) extracts a 16-color palette from your wallpaper and applies it across the desktop in real-time: terminal, prompt, bar, notifications, and window borders (Hyprland *and* niri)
- **Wallpaper rotation** — systemd timer swaps wallpapers every 20 minutes with smooth transitions ([awww](https://github.com/jbg/awww) on Arch, [swww](https://github.com/LGFae/swww) on PikaOS), re-theming everything automatically
- **106 curated wallpapers** included out of the box
- **Two OSes, one repo** — the installer detects Arch or PikaOS and asks you to confirm, maps package names per distro, and adapts configs per compositor
- **Pick what you install** — arrow-key installer (no dependencies — no gum, no whiptail) with presets, a component checklist, and a preview of exactly which packages get installed and which of your files get replaced
- **Undo any run** — every run journals what it changed (files replaced *and* created, units enabled, plugins cloned, shell changed), so `./install.sh --rollback` puts it all back. Files you already had are never touched
- **Live terminal recolor** — kitty windows change colors in place on every wallpaper change (config reload via SIGUSR1)
- **Weather in your bar** — live weather module in [Waybar](https://github.com/Alexays/Waybar) (Arch default)

---

## What's Included

| Component | Tool | Arch | PikaOS |
|-----------|------|------|--------|
| Window Manager | [Hyprland](https://hyprland.org/) (via [Omarchy](https://omarchy.dev/)) / [niri](https://github.com/niri-wm/niri) | Hyprland | niri (kept as-is, themed via includes) |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) (+ Ghostty, Alacritty optional) | ✓ | ✓ |
| Shell | [Oh My Zsh](https://ohmyz.sh/) + [Starship](https://starship.rs/) | ✓ | ✓ |
| Auto-theming | [wallust](https://codeberg.org/explosion-mental/wallust) | ✓ | ✓ |
| Wallpaper | awww / swww + [Waypaper](https://github.com/anufrievroman/waypaper) | ✓ | ✓ (waypaper via pipx) |
| Status Bar | [Waybar](https://github.com/Alexays/Waybar) | ✓ | optional — pikabar stays |
| App Launcher | [Walker](https://github.com/abenz1267/walker) + Elephant | ✓ | optional — pikabar stays |
| Notifications | [Mako](https://github.com/emersion/mako) | ✓ | optional — pikabar stays |
| OSD | [SwayOSD](https://github.com/ErikReider/SwayOSD) | ✓ | optional |
| Lock / Idle | [Hyprlock](https://github.com/hyprwm/hyprlock) + [Hypridle](https://github.com/hyprwm/hypridle) | ✓ | optional — pikabar-lock stays |
| Sound | [EasyEffects](https://github.com/wwmm/easyeffects) EQ + Dolby convolver presets, PipeWire tweaks | optional | ✓ |

<details>
<summary><strong>Full Arch package list (official + AUR)</strong></summary>

Official packages are listed in `pkglist-official.txt` and AUR packages in `pkglist-aur.txt` (installed by the `extras-arch` module). Key categories:

- **Dev tools** — neovim, git, docker, lazygit, lazydocker, nodejs, python, rust, ruby, mise, pnpm, uv
- **Browsers** — chromium, brave (AUR), cursor (AUR)
- **Media** — obs-studio, kdenlive, mpv, ffmpeg, imagemagick
- **Apps** — obsidian, signal-desktop, spotify, libreoffice
- **CLI utilities** — btop, eza, bat, fzf, ripgrep, fd, tldr, jq, tmux, zoxide, wget
- **Fonts** — JetBrains Mono Nerd Font, Noto (CJK + Emoji)

</details>

---

## Installation

### Arch Linux

Prerequisites: Arch with **[Omarchy](https://omarchy.dev/)** installed first.

```bash
git clone https://github.com/kabir0st/chill-dots.git
cd chill-dots
chmod +x install.sh
./install.sh
```

### PikaOS (niri)

```bash
git clone https://github.com/kabir0st/chill-dots.git
cd chill-dots
chmod +x install.sh
./install.sh
```

The installer walks you through it:

1. **Which system?** — Arch or PikaOS, with the detected one preselected (`--os arch|pika` skips the prompt)
2. **What do you want?** — *Recommended* (the OS default set), *Everything*, *Custom* (component checklist), or *Configs only* (no packages)
3. Shows which packages will be installed and which existing files will be replaced, then asks to proceed
4. Backs up every replaced file to `~/.config-backup-<timestamp>/` — on every run
5. Installs packages (pacman/yay on Arch, apt on PikaOS) — asking for your sudo password once, up front — then deploys configs and enables services
6. Generates the initial wallust color scheme
7. Records everything it changed, so the whole run can be undone

The menus are plain bash — nothing to install first. `↑↓` move, `space` toggles, `a`/`n`/`d` select all/none/defaults, `enter` confirms, `q` cancels. Terminals that can't do arrow keys get a numbered prompt instead.

Useful flags:

```bash
./install.sh --list-modules                          # see what's available on this OS
./install.sh --dry-run                               # print planned changes, write nothing
./install.sh --non-interactive --profile pika-default  # scripted install with defaults
./install.sh --modules terminal-kitty,shell-zsh      # install exactly these
./install.sh --skip-packages                         # configs only
./install.sh --all                                   # every module available on this OS
```

After installation, **log out and back in** (or reboot).

### Undoing a run

Every run that changes anything writes a run directory — `~/.config-backup-<id>/` — holding a pristine copy of each file it replaced and a journal of everything else it did: files and directories created, wallpapers added, systemd units enabled, plugin repos cloned, your previous login shell. That journal is what makes a real undo possible:

```bash
./install.sh --list-runs        # what each run changed, newest first
./install.sh --rollback         # undo the most recent run (asks first)
./install.sh --rollback 20260809-143210   # undo a specific run
./install.sh --rollback --yes   # no confirmation prompt
```

If a run finishes with errors it offers to roll itself back on the spot.

Rollback is deliberately narrow: it only touches paths the journal says *that run* created or replaced, so your own files are never collateral — a wallpaper you already had is never removed, and a directory is only deleted while it is empty. It also **never uninstalls packages**; it lists them and leaves the decision to you.

---

## Modules

Run `./install.sh --list-modules` for the live list. Defaults per OS:

| Module | Arch | PikaOS | Notes |
|--------|------|--------|-------|
| compositor-hyprland | on | — | Hyprland configs + Omarchy hooks |
| compositor-niri | — | on | wallust border colors + wallpaper keybinds via `config.kdl` includes; your config is never rewritten, only two `include` lines are appended (validated with `niri validate`, rolled back on failure) |
| theming-wallust | on | on | color engine + templates + `chill-wallpaper` |
| wallpapers | on | on | copies to `~/Pictures/Wallpapers` |
| wallpaper-rotation | on | on | 20-min systemd timer; on PikaOS also disables pikabar's own rotation |
| wallpaper-picker | on | on | waypaper (AUR on Arch, pipx on PikaOS) |
| terminal-kitty | on | on | full look + live wallust colors; downloads JetBrainsMono Nerd Font on PikaOS |
| terminal-ghostty / terminal-alacritty | on | off | omarchy imports handled per OS |
| shell-zsh | on | on | Oh My Zsh + plugins; sets zsh as default shell |
| prompt-starship | on | on | wallpaper-driven prompt palette |
| bar-waybar | on | off | on PikaOS pikabar keeps the bar unless you switch |
| launcher-walker | on | off | walker + elephant (PikaOS repos have both) |
| notif-mako | on | off | **PikaOS:** conflicts with pikabar's notification service — see notes |
| osd-swayosd | on | off | |
| lock-idle | on | off | **PikaOS:** deploys a niri-adapted hypridle that keeps `pikabar-lock` |
| audio-easyeffects | off | on | EasyEffects EQ + Dolby convolver presets, PipeWire no-suspend rule |
| tools-cli | on | off | btop, tmux, lazygit, fastfetch, gum |
| editor-nvim | on | off | LazyVim setup |
| extras-arch | on | — | the full Arch package lists |

---

## Auto Theming

```
┌─────────────┐     ┌─────────┐     ┌──────────────────────┐
│  Wallpaper   │────▶│ wallust │────▶│  Template Engine      │
│  (any image) │     │ kmeans  │     │  7 config templates   │
└─────────────┘     └─────────┘     └──────────┬───────────┘
                                               │
                    ┌──────────────────────────┐│
                    │  Live-updated configs:    ││
                    │  ├─ Hyprland (borders)    │◀
                    │  ├─ niri (borders)        │
                    │  ├─ Waybar (panel)        │
                    │  ├─ Kitty (terminal)      │
                    │  ├─ Ghostty (terminal)    │
                    │  ├─ Mako (notifications)  │
                    │  └─ Starship (prompt)     │
                    └──────────────────────────┘
```

**wallust** extracts a 16-color dark palette from the current wallpaper (k-means, `labmixed` color space, contrast-checked). `~/.local/bin/chill-wallpaper` drives the whole pipeline and reloads every app:

- **kitty** — `SIGUSR1` config reload recolors all open windows in place
- **niri** — watches the included `wallust-colors.kdl` and live-reloads on its own
- **Hyprland** — colors sourced by `looknfeel.conf`
- **waybar** — `SIGUSR2` reload; `style.css` is wired to the wallust palette
- **mako** — `makoctl reload`; config includes the wallust colors
- **starship** — palette spliced between markers in `starship.toml` (idempotent, bounded)

### Trigger methods

| Trigger | What happens |
|---------|-------------|
| **Automatic** (every 20 min) | systemd timer → `chill-wallpaper random` |
| **Manual random** | `Super + Shift + R` |
| **Manual pick** | `Super + Shift + W` opens Waypaper |
| **Login** | `chill-wallpaper restore` re-applies the last wallpaper |
| **Omarchy theme change** (Arch) | the `theme-set` hook re-runs the theming pipeline |

Templates live in `configs/wallust/templates/` — edit these to change how colors map to each app.

---

## PikaOS Notes

The PikaOS default profile deliberately **keeps pikabar** (bar, launcher `Mod+D`, lock screen, notifications, tray). What changes:

- **Wallpaper rotation** — chill-dots' timer takes over; the installer sets `randomWallpaper: false` in `~/.config/pikabar/Settings.json` (backed up first). pikabar's own wallpaper-derived theme (`useWallpaperTheme`) is left on — check whether it follows externally-set swww wallpapers on your build; if not, its accent colors stay static while kitty/niri/starship follow the wallpaper.
- **Keybinds** — `Mod+Shift+R` (random wallpaper) and `Mod+Shift+W` (picker) are added via an included `chill-bindings.kdl`. `Mod+Shift+R` replaces niri's default `switch-preset-window-height`; delete the include line in `config.kdl` to undo.
- **mako** — if you select it anyway, don't autostart it while pikabar runs: both claim `org.freedesktop.Notifications` on D-Bus.
- **Fonts** — JetBrainsMono Nerd Font has no Debian package; the installer downloads it from the nerd-fonts release into `~/.local/share/fonts`.
- **waypaper** — installed via `pipx install --system-site-packages waypaper`; make sure `~/.local/bin` is on your PATH (the shipped `.zshrc` does this).
- **bat/fd** — Debian names them `batcat`/`fdfind`; the shipped `.zshrc` aliases them automatically.
- **Packages go through `apt`, not `pikman`** — despite the name, `pikman` is PikaOS's *container* package manager (it has `init`/`enter`/`run` subcommands). `pikman install zsh` installs into a managed container, not onto the host, and fails outright when no container exists.
- **Sound** — the `audio-easyeffects` module ships the EasyEffects profile (equalizer, Dolby convolver impulse responses, limiter, autogain, multiband compressor, bass enhancer), plus a WirePlumber rule that stops the analog speakers from suspending between sounds. EasyEffects is the **Flatpak** build here, so its config lives in `~/.var/app/com.github.wwmm.easyeffects/`, not `~/.config/easyeffects`; the module targets whichever layout your install uses. The bundled autoload rule is bound to this laptop's output sink — on other hardware the presets are still installed, you just pick one manually in the GUI.

Troubleshooting:

- *Nerd font glyphs missing* → `fc-list | grep JetBrainsMono` — if empty, re-run the terminal-kitty module or download `JetBrainsMono.zip` from [nerd-fonts releases](https://github.com/ryanoasis/nerd-fonts/releases) into `~/.local/share/fonts` and run `fc-cache -f`
- *`chsh` didn't stick* → run `chsh -s $(command -v zsh)` manually (needs your password)
- *Wallpaper timer inactive* → `systemctl --user enable --now wallpaper-rotate.timer`
- *Packages all failed* → check `~/.config-backup-<id>/packages.log`; the installer keeps the package manager's real output instead of discarding it
- *Want the whole thing gone* → `./install.sh --rollback`

---

## Keybindings

| Key | Arch (Hyprland) | PikaOS (niri) |
|-----|------------------|----------------|
| `Super + Enter` | Kitty | Kitty (pika default) |
| `Super + Shift + R` | Random wallpaper | Random wallpaper |
| `Super + Shift + W` | Wallpaper picker | Wallpaper picker |
| `Super + Alt + Enter` | Tmux session | — |
| `Super + Shift + S` | Screenshot (satty) | niri native (`Print`) |
| `Super + V` | Clipboard (CopyQ) | — |
| `Super + D` | — | pikabar launcher |

Full Arch bindings: `configs/hypr/bindings.conf`. PikaOS additions: `configs/niri/chill-bindings.kdl`.

---

## Structure

```
chill-dots/
├── install.sh              # Interactive multi-OS installer
├── lib/                    # deploy/backup/dry-run, OS dispatch, module registry, arrow-key TUI
├── os/                     # arch.sh (pacman/yay), pika.sh (apt, pipx, nerd font)
├── modules/                # one file per selectable component
├── profiles/               # arch-default.txt, pika-default.txt
├── bin/chill-wallpaper     # compositor-neutral wallpaper + theming driver
├── pkglist-official.txt    # Arch packages (extras-arch module)
├── pkglist-aur.txt         # AUR packages
├── configs/
│   ├── hypr/               # Hyprland (+ hypridle.pika.conf variant)
│   ├── niri/               # wallust color stub + wallpaper keybind include
│   ├── wallust/            # theming engine + 7 color templates
│   ├── waybar/             # bar config + wallust-wired stylesheet + weather
│   ├── kitty/              # terminal config + per-OS theme include
│   ├── ghostty/ alacritty/ # alt terminals
│   ├── mako/ walker/ swayosd/ waypaper/
│   ├── easyeffects/        # EQ/convolver presets + impulse responses (PikaOS)
│   ├── wireplumber/        # speaker no-suspend rule
│   ├── starship/           # prompt (wallust palette between markers)
│   ├── fastfetch/          # + config.pika.jsonc (no omarchy commands)
│   └── omarchy/            # theme hooks (Arch only)
├── shell/.zshrc            # single zsh config, guards for both distros
├── systemd/                # wallpaper rotation timer + services
└── wallpapers/             # 106 curated wallpapers
```

---

<p align="center">
  Built on <a href="https://hyprland.org/">Hyprland</a> + <a href="https://omarchy.dev/">Omarchy</a> on Arch, <a href="https://github.com/niri-wm/niri">niri</a> + pikabar on PikaOS, themed by <a href="https://codeberg.org/explosion-mental/wallust">wallust</a>
</p>
