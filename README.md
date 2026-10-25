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

## Rendering model

NerveCenter supports two rendering modes. **Independent overlays** is the
default; **chained pipeline** is opt-in via the `EffectChained` config switch
or `STYLE ▾` → `CHAIN SHADERS`.

### Independent overlays (default)

- A **base style** (0–6) paints the panel fill, radius, border, and its
  decorations. Base-style decorations are pinned above the overlays.
- **10 micro-effects** (prism blur, hologram, vignette, circuit, scanlines,
  ASCII, LiDAR Sobel, thermal FLIR, duotone, dither frost) are painted in the
  order you enable them. `EffectsStackJson` stores that order, and
  `z = index + 5` is the paint order shown as `[L1]`, `[L2]`, … in the menu.
- Every effect samples the **original wallpaper crop**. Effect N does not read
  effect N−1's output, so this is painter's-algorithm alpha blending, not a
  multi-pass render chain. An opaque overlay simply covers the one below it.
- `live: false` freezes each effect's `ShaderEffectSource` texture, so idle
  repaints do not re-render the source item. It does **not** make the shader
  free: the `ShaderEffect` still runs whenever the panel repaints (clocks,
  graphs, and other live widgets cause repaints). Treat the effect stack as a
  small per-repaint GPU cost, not a true zero-GPU path.
- Nearly opaque layers can hide the effects below them. When a layer marked
  `occludesBelow` sits above another effect, the covered effect is skipped
  instead of running a full-panel pass it cannot visibly contribute to.

### Chained pipeline (`EffectChained = true`)

- Active effects are rendered in activation order into **one texture chain**.
  Stage N samples stage N−1's output, so each shader sees the previous result
  rather than the original wallpaper.
- Shader stages run their fragment shader against the previous texture.
  Static Canvas/vector stages (hologram, vignette, circuit, scanlines) are
  captured into a texture and blended into the chain with `blend.frag`, so they
  participate in the same order as shader effects.
- Translucent layers (duotone at 0.65, dither frost at 0.85) are blended over
  the accumulated texture at their opacity before the next stage reads it.
- `EffectChain.qml` / `EffectChainStage.qml` implement the live chain.
  Intermediates are RGBA16F to limit inter-pass banding. The cost is one
  render target per active layer (up to 10), so it is heavier than independent
  mode; occlusion culling is disabled because every layer feeds the next.
- If no wallpaper image is ready, or no shader effect is active, the wallpaper
  falls back to independent overlays (shader effects hidden, static overlays
  still drawn).
- `NerveCompositor.qml` and `NerveShaderLayer.qml` remain **unused reference
  implementations**; the live chain is the declarative `EffectChain`
  implementation. `shader_registry.json` is documentation only and is not
  loaded at runtime.

---

## Persistence model

- **KConfig is authoritative.** Base style (`PanelStyle`) and the effect stack
  (`EffectsStackJson` plus every `Effect*` boolean) live in the wallpaper's
  per-containment group in
  `~/.config/plasma-org.kde.plasma.desktop-appletsrc`. Both the in-canvas menu
  and the Plasma config dialog write there, and `root.configuration.writeConfig()`
  flushes the group to disk.
- **Local settings are migration-only.** Older releases mirrored style and
  effects into `~/.config/kde.org/plasmashell.conf` through `QtCore.Settings`.
  A one-time migration guarded by the KConfig `StyleMigrated` flag reads those
  mirrors, normalizes the result into KConfig, and never reads them again.
- **Stack and booleans stay in sync.** Every write normalizes `EffectsStackJson`
  and the `Effect*` booleans together; unknown or duplicate keys (including the
  removed `halftone`) are dropped on load.
- **Legacy key cleanup.** `scripts/cleanup-legacy-settings.py` removes obsolete
  local keys as text (preserving the rest of the shared file) and runs from
  `install.sh`.

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
