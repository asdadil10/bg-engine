# NerveCenter — Cyberpunk Telemetry HUD for KDE Plasma 6

[![KDE Plasma 6](https://img.shields.io/badge/KDE-Plasma%206-31a8ff?logo=kde)](https://kde.org/plasma-desktop/)
[![Qt 6](https://img.shields.io/badge/Qt-6.6%2B-41cd52?logo=qt)](https://www.qt.io/)
[![CMake](https://img.shields.io/badge/Build-CMake%20%2F%20ECM-064f8c?logo=cmake)](https://cmake.org/)

**NerveCenter** is a high-performance, modular cyberpunk telemetry wallpaper engine for KDE Plasma 6. It turns your Linux desktop into an interactive, real-time command center equipped with native hardware sensors, network throughput graphs, media controls, audio spectrum visualizer, persistent scratchpad, application launcher, and an integrated native terminal.

---

## Features

- **Native Hardware Telemetry:** Directly bound to `org.kde.ksysguard.sensors` (zero process polling / fork overhead) for CPU, GPU, RAM, Disk, and CPU Temperatures.
- **Real-Time Network Monitor:** Live download/upload gauges with adaptive speed units (B/s, KB/s, MB/s) and a rolling traffic wave canvas.
- **Embedded Terminal:** Powered by custom `QMLTermWidget` (`libqmltermwidget.so`) with PTY allocation, ANSI colors, and configurable keyboard tables.
- **MPRIS2 Media HUD:** Real-time track information, playback controls, and procedural audio spectrum visualizer.
- **Draggable & Resizable HUD Panels:** Full floating layout manager with snap-to-grid, coordinate clamping, and session persistence.
- **In-Canvas Customization Engine:** Adjust accent colors, scanline/CRT shader effects, hologram glitch overlays, font scales, and background opacity on the fly.
- **Persistent Neural Link Scratchpad:** Instant two-way persistent notes synchronized between user settings and Plasma config.

---

## Codebase Navigation & Architecture

For AI coding agents and developers exploring the project structure, see **[`MINIMAP.md`](MINIMAP.md)** for:
- Exact line numbers and object pointers to all QML components.
- State management and two-tier storage architecture.
- Plasma 6 event flow and IPC bindings.

---

## Installation & Deployment

### Method 1: Using CMake (Recommended)

```bash
# Configure the build directory
cmake -B build

# Install into user wallpapers (~/.local/share/plasma/wallpapers/org.kde.nervecenter)
cmake --build build --target install_user

# Hot-reload package after making changes
cmake --build build --target reload
```

### Method 2: Direct Shell Script

```bash
chmod +x ./install.sh
./install.sh
```

---

## Activation in KDE Plasma 6

1. **Right-click** on your desktop &rarr; **Configure Desktop and Wallpaper...** (or `Ctrl + Shift + D`).
2. Set **Layout** to **"Desktop"** (disables the default folder view icon overlay so mouse clicks fall directly into NerveCenter).
3. Under **Wallpaper Type**, select **"NerveCenter"**.
4. Click **Apply**.

---

## Project Structure

```
├── CMakeLists.txt              # KDE Frameworks 6 / ECM build configuration
├── MINIMAP.md                  # Comprehensive AI agent & developer navigation map
├── README.md                   # Project overview and instructions
├── install.sh                  # Direct installer & service bridge cleanup
├── docs/                       # Architectural proposals and documentation
├── examples/                   # Configuration examples (nervecenter.conf.example)
└── nervecenter/                # Plasma 6 wallpaper package
    ├── metadata.json           # Package metadata and plugin declaration
    └── contents/
        ├── config/main.xml     # KConfigXT schema definitions
        └── ui/                 # QML components and native QMLTermWidget
```

---

## License

GPL-2.0-or-later.
