# DUX Apps Suite for DankMaterialShell (DMS)

[![Quickshell](https://img.shields.io/badge/Quickshell-Qt6-blue.svg)](https://quickshell.outfoxxed.me/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A unified suite of **Material 3 Expressive** desktop apps for **DankMaterialShell (DMS)** and **Quickshell** — featuring synchronized themes, foreground layers, translucent blur, and customizable segmented/floating sidebars.

---

## 🌟 Features

- 🎨 **Unified Material 3 Expressive UI**: Synchronized theme mode, accent color, translucent windows, foreground layers, and motion settings across all apps.
- 🧩 **Customizable Segmented Sidebar**: Choose between **Icons only**, **Below icons**, or **Next to icons** label placement, vertical centering, and an auto-hiding **Floating sidebar** with a configurable delay slider and edge reveal pill.
- 🎮 **DUX Game Hub (`dgamehub`)**: Standalone launcher & hub for Steam, Epic, Ubisoft, EA, Prime, and Bottles with platform filtering, metadata enrichment, and controller support.
- 💱 **Currency & Unit Converter (`dcalc`)**: Dedicated **Currency** sidebar tab with live exchange rates alongside scientific calculator and unit conversion.
- 🖼️ **DUX Galary & Video (`dview`, `dplay`)**: Unified 2-column Filter & Sort popup, Quick Access pinned albums, group-by-date, and floating search bar with backdrop blur.

---

## 📦 Apps

| App | Command | Description |
|---|---|---|
| [DUX Galary](./dankview/) | `dview` | Image viewer & gallery with albums, favorites, Quick Access, and EXIF info |
| [DUX Video Player](./dankvideo/) | `dplay` | Hardware-accelerated video library & player with albums, playlists, and group-by-date |
| [DUX Calculator](./dankcalc/) | `dcalc` | Scientific calculator, unit converter, and live currency converter |
| [DUX Clock](./dankclock/) | `dclock` | Clock, world clock, alarm, timer, Pomodoro, and stopwatch |
| [DUX Game Hub](./duxgamehub/) | `dgamehub` | Unified Linux game launcher & fullscreen hub for Steam, Epic, Ubisoft, EA, Prime, and Bottles |
| [Duzzle](./duzzle/) | `duzzle` | Puzzle and arcade games |

---

## 🛠️ Installation

### Quick Install via `curl`

Run the interactive installer directly:

```bash
curl -fsSL https://raw.githubusercontent.com/JD-Danklinux/dankapps/main/install.sh | bash
```

### Non-Interactive Install (CLI Flags)

Pass `--all` or `--apps` (or app names directly) to install without any prompts:

```bash
# Install all apps
curl -fsSL https://raw.githubusercontent.com/JD-Danklinux/dankapps/main/install.sh | bash -s -- --all

# Install specific apps (e.g. Game Hub, Gallery, and Calculator)
curl -fsSL https://raw.githubusercontent.com/JD-Danklinux/dankapps/main/install.sh | bash -s -- --apps gamehub,view,calc

# System-wide install (requires sudo)
curl -fsSL https://raw.githubusercontent.com/JD-Danklinux/dankapps/main/install.sh | bash -s -- --system --apps clock,video
```

Available app names for `--apps`: `clock`, `calc`, `video`, `view` (or `gallery`), `duzzle`, `gamehub`.

### From Source

```bash
git clone --recursive https://github.com/JD-Danklinux/dankapps.git
cd dankapps
./install.sh --all
```

---

## 📖 Usage

```bash
dview photo.jpg    # DUX Galary
dplay video.mp4    # DUX Video Player
dcalc              # DUX Calculator & Currency Converter
dclock             # DUX Clock
dgamehub           # DUX Game Hub
duzzle             # Duzzle
```

---

## 📄 License

Distributed under the MIT License. See [LICENSE](./LICENSE) for details.
