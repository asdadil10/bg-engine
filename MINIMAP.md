# NerveCenter — Agent Minimap & Code Navigation Index

> **Target Audience:** AI Coding Assistants (LLMs) & Developers  
> **Plugin ID:** `org.kde.nervecenter`  
> **Platform:** KDE Plasma 6 (`WallpaperItem`), Qt 6 Quick / QML, KSysGuard Native Sensors, QMLTermWidget

---

## 1. Directory Structure & Quick Pointers

```
bgengine/
├── CMakeLists.txt                       # KF6/Plasma CMake build & packaging file
├── install.sh                           # Direct deployment & cleanup script
├── MINIMAP.md                           # This index file
├── README.md                            # Project overview & documentation
├── .gitignore                           # Git ignore rules (builds, pycache, etc.)
├── docs/
│   └── proposal.txt                     # Original architectural proposal
├── examples/
│   └── nervecenter.conf.example         # Sample preset & layout configuration
├── nervecenter/                         # KDE Plasma 6 Wallpaper Package root
│   ├── metadata.json                    # Plugin declaration & D-Bus service ID
│   └── contents/
│       ├── config/
│       │   └── main.xml                 # KConfigXT schema definition
│       ├── scripts/
│       │   ├── icon_db.json             # Icon name mapping database
│       │   └── icon_resolver.py         # Static icon resolver utility
│       └── ui/                          # QML presentation layer
│           ├── assets/                  # High-efficiency pre-rendered textures
│           │   ├── ascii_atlas.png      # 16-glyph Sobel contour runes & density ramp atlas
│           │   └── flir_ironbow_lut.png # 256x1 military thermal palette lookup texture
│           ├── shaders/                 # Hardware-accelerated graphics shaders (GLSL 100es/120/150)
│           │   ├── shader_registry.json # Shader metadata (documentation only; not loaded at runtime)
│           │   ├── blend.frag           # Alpha blend stage (only used by the unused compositor)
│           │   ├── prism_blur.frag      # Optical chromatic dispersion frosted glass blur
│           │   ├── ascii.frag           # Technical Sobel contour-detecting ASCII matrix
│           │   ├── lidar_sobel.frag     # Pre-filtered anti-aliased 3D wireframe extractor
│           │   ├── thermal_flir.frag    # FLIR Ironbow thermal reconnaissance shader
│           │   ├── duotone.frag         # 3-stop theme palette luminance remapping
│           │   ├── dither_frost.frag    # 8-tap Poisson dithered frosted acrylic blur
│           │   ├── dither_quantize.frag # Mandatory final ±1.0 LSB triangular dither pass
│           │   ├── streak_thresh.frag   # Anamorphic streak Pass 1: luma thresholding & LDR gain
│           │   ├── streak_blur.frag     # Anamorphic streak Pass 2: 17-tap bilinear paired blur
│           │   ├── streak_comp.frag     # Anamorphic streak Pass 3: additive optical composite
│           │   └── tiltshift.frag       # Center focus mask with specular highlight bokeh
│           ├── NerveCompositor.qml      # UNUSED reference multi-pass compositor (never instantiated)
│           ├── NerveShaderLayer.qml     # UNUSED reference shader wrapper (only used by the compositor)
│           ├── main.qml                 # WallpaperItem entry point & canvas engine
            ├── config.qml               # Plasma wallpaper settings dialog (3-tab GUI & shortcut manager)
            ├── NervePanel.qml           # Master HUD panel class (8-point resize, clamping, edit mode)
            ├── NervePanelBase.qml       # Compatibility alias -> NervePanel.qml
            ├── DraggablePanel.qml       # Compatibility alias -> NervePanel.qml
            ├── NerveFrame.qml           # Cyberpunk vector borders, corner brackets & scanlines
            ├── GaugeBlock.qml           # Reusable circular arc and horizontal sensor gauge
            ├── InfoRow.qml              # Key-value monospace telemetry item display
            ├── SensorPanel.qml          # Hardware metrics (CPU, GPU, RAM, Disk, Temp via KSysGuard)
            ├── NetworkPanel.qml         # Network throughput gauges & traffic graph
            ├── NetGraph.qml             # Real-time procedural wave graph canvas
            ├── MediaPanel.qml           # MPRIS2 player controller, metadata, cover art & EQ
            ├── ControlsPanel.qml        # Real-time HUD controls, volume/brightness & weather deck
            ├── CyberWeatherGlyph.qml    # Procedural cyberpunk vector weather icons
            ├── NotesPanel.qml           # Persistent encrypted scratchpad
            ├── TodoPanel.qml            # Cyberpunk Directives task tracker
            ├── GitGridPanel.qml         # 7x18 Git activity contribution heatmap matrix
            ├── BookmarkBar.qml          # Quick-launch app dock with live icon pack switcher
            ├── icon_scanner.py          # Background discovery of icons across installed themes
            ├── IconDatabase.js          # Static icon theme fallback lookup table
            ├── app_scanner.py           # Background XDG desktop entry indexer
            ├── TerminalWidget.qml       # High-level terminal panel container
            ├── QmlTermView.qml          # Low-level QMLTermWidget bridge
            └── QMLTermWidget/           # Native QML terminal C++ plugin
                ├── libqmltermwidget.so  # Custom-built binary (backed up in ~/.local/share)
                ├── qmldir               # QML module export declaration
                ├── QMLTermScrollbar.qml # Terminal scrollbar component
                ├── color-schemes/       # Terminal ANSI color schemes
                └── kb-layouts/          # Key translation tables (vt100, x11, linux)
```

---

## 2. Object Map & Line Index (Pointers to Large Objects)

### A. Root Wallpaper & Canvas Engine
- **File:** [`nervecenter/contents/ui/main.qml`](nervecenter/contents/ui/main.qml)
  - `WallpaperItem { id: root }` ([L15](nervecenter/contents/ui/main.qml#L15)): Wallpaper root object. Manages global reactive colors (`accentColor`, `highlightColor`, `bgColor`), font scales, HUD opacities, and Plasma configuration synchronization.
  - `Settings { id: layoutSettings }` ([L110-L138](nervecenter/contents/ui/main.qml#L110-L138)): Local persistent state store (`Qt.labs.settings`) for real-time panel dimensions, visibility, active themes, and edit mode.
  - `Canvas { id: canvas }` ([L250-L290](nervecenter/contents/ui/main.qml#L250-L290)): GPU-accelerated 2D background grid renderer.
  - `Top Control Bar` ([L365-L870](nervecenter/contents/ui/main.qml#L365-L870)): Centered Quote of the Day, mini desktop widgets, layout locks, theme switcher, and grid controls.
  - `Item { id: mainCanvas }` ([L1086-L1190](nervecenter/contents/ui/main.qml#L1086-L1190)): Parent viewport hosting all instantiated floating HUD panels:
    - `TerminalWidget` ([L1093](nervecenter/contents/ui/main.qml#L1093))
    - `MediaPanel` ([L1104](nervecenter/contents/ui/main.qml#L1104))
    - `SensorPanel` ([L1114](nervecenter/contents/ui/main.qml#L1114))
    - `BookmarkBar` ([L1124](nervecenter/contents/ui/main.qml#L1124))
    - `NotesPanel` ([L1137](nervecenter/contents/ui/main.qml#L1137))
    - `NetworkPanel` ([L1147](nervecenter/contents/ui/main.qml#L1147))
    - `ControlsPanel` ([L1158](nervecenter/contents/ui/main.qml#L1158))
    - `TodoPanel` ([L1167](nervecenter/contents/ui/main.qml#L1167))
    - `GitGridPanel` ([L1177](nervecenter/contents/ui/main.qml#L1177))

---

### B. Master HUD Panel & Frame System
- **File:** [`nervecenter/contents/ui/NervePanel.qml`](nervecenter/contents/ui/NervePanel.qml)
  - Master HUD panel component providing:
    - 8-point interactive border/corner resizing handles (N, S, E, W, NW, NE, SW, SE).
    - Viewport boundary clamping and coordinate persistence.
    - Titlebar with HUD identifier, status subLabel, and extensible header actions slot.
    - Movement and resizing gated strictly to `root.editMode`.
- **File:** [`nervecenter/contents/ui/NervePanelBase.qml`](nervecenter/contents/ui/NervePanelBase.qml) & [`DraggablePanel.qml`](nervecenter/contents/ui/DraggablePanel.qml)
  - Backward-compatibility aliases inheriting `NervePanel.qml`.
- **File:** [`nervecenter/contents/ui/NerveFrame.qml`](nervecenter/contents/ui/NerveFrame.qml)
  - Master procedural HUD framing engine supporting 7 Base Styles and 10 ordered backdrop overlays:
    - **7 Base Styles (`panelStyle`):**
      - `0: CYBER_WIREFRAME`: Classic cyberpunk HUD, corner brackets, crosshairs.
      - `1: GLASS_GLASSMORPHIC`: Frosted glass blur, dual-layer luminous rim.
      - `2: MINIMALIST_FLAT`: High-contrast dark terminal backdrop.
      - `3: TACTICAL_CHASSIS`: Militech $45^\circ$ chamfered corners, gunmetal fill, bolt rivets, hazard tag.
      - `4: STEALTH_VOID`: $0\%$ transparent floating backdrop, hairline corner crosshairs.
      - `5: RETRO_PHOSPHOR_CRT`: Vintage CRT cathode tint, phosphor glow inner bezel.
      - `6: CYBER_NEUMORPHIC`: Recessed milled-carbon look, specular highlight and deep ambient shadow.
    - **Ordered Backdrop Overlays (painted in activation order):**
      - Painted in the exact order enabled (`EffectsStackJson` & `activeEffectsStack`, shown as `[L1]`, `[L2]`, … in the HUD Style Menu). In the default **independent** mode each overlay samples the original wallpaper crop, so this is painter's-algorithm alpha blending — **not** a chained multi-pass pipeline.
      - `+ PRISM_FROST_BLUR`: Optical chromatic dispersion blur shader with multi-sample RGB separation (`live: false`).
      - `+ HOLOGRAM_EDGES`: Static cyan-top / magenta-bottom neon gradient borders.
      - `+ VIGNETTE_DEPTH`: Static multi-directional dark shadow gradient falls.
      - `+ CIRCUIT_BOARD`: Static deterministic PCB traces, vias, and solder pads.
      - `+ INTERLACE_SCANLINES`: Static $2\text{px}$ alternating dark CRT raster scanlines.
      - `+ TECHNICAL_ASCII_ART`: Sobel edge-contour detecting shader with directional runes, dual-color highlight grading, 16-level luminance quantization, and phosphor scanlines (`live: false`).
      - `+ LIDAR_SOBEL_CONTOUR`: Pre-filtered anti-aliased 3D wireframe edge extractor (`live: false`).
      - `+ THERMAL_FLIR_RECON`: FLIR Ironbow thermal palette (`live: false`).
      - `+ DUOTONE_ATMOSPHERE`: 3-stop theme palette luminance remapping (`live: false`).
      - `+ DITHER_FROST_ACRYLIC`: 8-tap Poisson dithered frosted acrylic blur (`live: false`).
      - *(Note: Halftone Dot Screen removed; legacy Hex Composite and Technical Graticule were removed earlier.)*
      - *(Cost note: `live: false` freezes the wallpaper sample, not the shader. Effects still draw when the panel repaints. Shader effects are hidden when no wallpaper image is ready, and effects covered by a nearly opaque `dither_frost` layer are skipped.)*
      - *(Chained mode: `EffectChained=true` switches to `EffectChain.qml` / `EffectChainStage.qml`. Each active stage reads the previous stage's RGBA16F texture; static Canvas/vector effects are captured and blended with `blend.frag`. It costs one render target per layer, disables occlusion culling, and falls back to independent overlays when no wallpaper or no shader effect is active. Toggle via the config dialog or `STYLE ▾` → `CHAIN SHADERS`.)*

---

### C. System Telemetry & Hardware Sensors
- **File:** [`nervecenter/contents/ui/SensorPanel.qml`](nervecenter/contents/ui/SensorPanel.qml)
  - Native KDE sensor bindings using `org.kde.ksysguard.sensors`:
    - `cpuSensor`: `"cpu/all/usage"`
    - `gpuSensor`: `"gpu/all/usage"`
    - `memSensor`: `"memory/physical/used"`
    - `diskSensor`: `"disk/all/used"`
    - `tempSensor`: `"cpu/all/averageTemperature"`
  - Employs zero external process spawning (`awk`, `sleep`, `free`, `df` are obsolete).
- **File:** [`nervecenter/contents/ui/NetworkPanel.qml`](nervecenter/contents/ui/NetworkPanel.qml)
  - Native network telemetry via `org.kde.ksysguard.sensors`:
    - `downSensor`: `"network/all/download"`
    - `upSensor`: `"network/all/upload"`
  - Adaptive unit formatting (`formatSpeed()`, B/s &rarr; KB/s &rarr; MB/s).
- **File:** [`nervecenter/contents/ui/NetGraph.qml`](nervecenter/contents/ui/NetGraph.qml)
  - Procedural Canvas wave history chart rendering live download/upload throughput.
- **File:** [`nervecenter/contents/ui/GaugeBlock.qml`](nervecenter/contents/ui/GaugeBlock.qml)
  - Reusable circular arc and horizontal meter component for telemetry gauges.
- **File:** [`nervecenter/contents/ui/InfoRow.qml`](nervecenter/contents/ui/InfoRow.qml)
  - Reusable key-value label/value row with monospace typography.

---

### D. Audio & Media Subsystem
- **File:** [`nervecenter/contents/ui/MediaPanel.qml`](nervecenter/contents/ui/MediaPanel.qml)
  - MPRIS2 media controller integration over D-Bus (`org.mpris.MediaPlayer2.*`).
  - Real-time track metadata (Artist, Title, Album art, playback position & duration).
  - Low-overhead GPU execution (continuous sine-wave visualizer removed to eliminate idle/playback GPU spikes).
  - EasyEffects Equalizer integration (`EQ ON` / `EQ OFF` via `easyeffects -b` and `--bypass-toggle`).

---

### E. Scratchpad, Directives & Developer Heatmap
- **File:** [`nervecenter/contents/ui/NotesPanel.qml`](nervecenter/contents/ui/NotesPanel.qml)
  - Persistent Neural Link scratchpad (`Qt.labs.settings` under category `"Notes"`).
- **File:** [`nervecenter/contents/ui/TodoPanel.qml`](nervecenter/contents/ui/TodoPanel.qml)
  - Cyberpunk Directives task tracker with completion badges, strikethrough state, directive input, and persistent JSON storage (`Qt.labs.settings` under category `"Directives"`).
- **File:** [`nervecenter/contents/ui/GitGridPanel.qml`](nervecenter/contents/ui/GitGridPanel.qml)
  - Git commit contribution heatmap matrix (7 rows × 18 weeks) scanning local repository activity via `git log`, with branch readout and latest commit telemetry.

---

### F. Application Shortcuts, Dock & Icon Scanner
- **File:** [`nervecenter/contents/ui/BookmarkBar.qml`](nervecenter/contents/ui/BookmarkBar.qml)
  - Quick-launch application dock with icon grid and search/filter.
  - In-header icon pack cycling (◂ / ▸) switching dynamically between installed system packs (Breeze, Tela, Fluent, Win11, etc.).
  - Tile backgrounds/borders removed with icons scaled cleanly to 100%.
  - Fully reactive model syncing dynamically with `root.shortcutModel`.
- **File:** [`nervecenter/contents/ui/icon_scanner.py`](nervecenter/contents/ui/icon_scanner.py)
  - Python utility inspecting `/usr/share/icons` and `~/.local/share/icons` to resolve requested icons across all installed packs.
- **File:** [`nervecenter/contents/ui/IconDatabase.js`](nervecenter/contents/ui/IconDatabase.js)
  - Static fallback icon map for instant rendering before background scan returns.
- **File:** [`nervecenter/contents/ui/app_scanner.py`](nervecenter/contents/ui/app_scanner.py)
  - Background XDG application entry crawler.

---

### G. In-HUD Controls, Clock & Weather Telemetry
- **File:** [`nervecenter/contents/ui/ControlsPanel.qml`](nervecenter/contents/ui/ControlsPanel.qml)
  - DECK_CONTROL mixing console:
    - Master volume output slider with wheel controls & large hitboxes.
    - Screen luminance brightness slider.
    - Night color toggle & power profile mode selector (Low, Normal, Ultra).
    - 3-day weather forecast telemetry from Open-Meteo with offline caching (`Settings` category `"DeckWeather"`).
    - High-visibility cybernetic clock & date readout.
- **File:** [`nervecenter/contents/ui/CyberWeatherGlyph.qml`](nervecenter/contents/ui/CyberWeatherGlyph.qml)
  - Procedural cyberpunk monochromatic vector glyphs rendering all standard WMO weather condition codes.

---

### H. Terminal Subsystem & Native Plugin
- **File:** [`nervecenter/contents/ui/TerminalWidget.qml`](nervecenter/contents/ui/TerminalWidget.qml)
  - High-level container wrapping the terminal inside `NervePanel`.
- **File:** [`nervecenter/contents/ui/QmlTermView.qml`](nervecenter/contents/ui/QmlTermView.qml)
  - Low-level bridge instantiating `QMLTermWidget` from `libqmltermwidget.so`.
  - Terminal session management, PTY allocation, color scheme mapping.
- **Directory:** [`nervecenter/contents/ui/QMLTermWidget/`](nervecenter/contents/ui/QMLTermWidget/)
  - Custom C++ QML plugin binary: `libqmltermwidget.so`.
  - **Permanent backup locations:** `~/.local/share/nervecenter_backup/libqmltermwidget.so` and `~/backup_libqmltermwidget/libqmltermwidget.so` (read-only `0444`).

---

### I. Configuration Schema & Plasma Settings Dialog
- **File:** [`nervecenter/metadata.json`](nervecenter/metadata.json)
  - Package declaration: `KPackage/Generic`, plugin ID `org.kde.nervecenter`, category `Wallpaper`.
- **File:** [`nervecenter/contents/config/main.xml`](nervecenter/contents/config/main.xml)
  - KConfigXT schema declaring configuration entries (`BackgroundColor`, `AccentColor`, `HighlightColor`, `GridOpacity`, `HudOpacity`, `ShortcutsJson`, `PanelsLayoutJson`, etc.).
- **File:** [`nervecenter/contents/ui/config.qml`](nervecenter/contents/ui/config.qml)
  - Plasma's native "Configure Desktop and Wallpaper" GUI dialog:
    - **Tab 1: 🎨 Wallpaper & Style:** Colors, background images, opacity, CRT presets, font customization.
    - **Tab 2: 🪟 Panels & Layout:** Panel visibility toggles, Edit Mode switch, reset layout button, master HUD opacity slider.
    - **Tab 3: 🚀 App Launcher:** Icon dimensions/padding, live shortcut list, Move Up/Down reordering, single-click deletion, Add Shortcut form with real-time icon preview and file chooser, and Reset to Defaults.

---

## 3. Data Flow & State Synchronization Architecture

```mermaid
flowchart TD
    subgraph Plasma_Host["KDE Plasma 6 Host"]
        KConfig["KConfigXT (main.xml)"]
        ConfigGUI["config.qml (Settings Dialog)"]
        Containment["Containment Layer (org.kde.desktopcontainment)"]
    end

    subgraph NerveCenter["NerveCenter WallpaperItem (main.qml)"]
        RootConfig["root.configuration (Reactive Bindings)"]
        LocalSettings["Settings (Qt.labs.settings - Layout & Directives)"]
        CanvasRenderer["GPU Canvas 2D (Grid & Scanlines)"]
        PanelsHost["NervePanel Layout Manager"]
    end

    subgraph Subsystems["Modular HUD Components"]
        Launcher["BookmarkBar (Launchpad Dock)"]
        IconScanner["icon_scanner.py (Packs & Resolvers)"]
        Sensors["SensorPanel & NetworkPanel"]
        Media["MediaPanel (MPRIS2)"]
        Terminal["TerminalWidget (libqmltermwidget.so)"]
    end

    subgraph Native_Bindings["System Telemetry & D-Bus"]
        KSysGuard["org.kde.ksysguard.sensors"]
        DBusMPRIS["org.mpris.MediaPlayer2"]
        PTY["Linux PTY Kernel Device"]
    end

    ConfigGUI <-->|Two-Way Sync (ShortcutsJson, Colors, Opacity)| KConfig
    KConfig <-->|Reactive Config Property Map| RootConfig
    RootConfig <-->|Runtime Overrides| LocalSettings
    LocalSettings --> PanelsHost
    PanelsHost --> CanvasRenderer

    PanelsHost --> Launcher
    Launcher <-->|Background Icon Search| IconScanner
    PanelsHost --> Sensors
    PanelsHost --> Media
    PanelsHost --> Terminal

    KSysGuard --> Sensors
    DBusMPRIS <--> Media
    PTY <--> Terminal
    Containment -->|Mouse Events (Desktop Mode)| NerveCenter
```

---

## 4. Common Agent Recipes

### Hot-reloading After Code Changes
When editing any QML or metadata file, reinstall or hot-reload without restarting Plasma:
```bash
# Direct rsync deployment to active Plasma wallpaper directory:
rsync -av --delete nervecenter/ ~/.local/share/plasma/wallpapers/org.kde.nervecenter/

# Quick plasmashell restart:
systemctl --user restart plasma-plasmashell.service
```

### Checking KSysGuard Available Sensor IDs
To verify available hardware telemetry keys on the user's system:
```bash
qdbus6 org.kde.ksysguard /Sensors org.kde.ksysguard.allSensors | grep -E "cpu|gpu|memory|network"
```

### Investigating QML Runtime Warnings / Errors
To stream live diagnostic logs from Plasma Shell:
```bash
journalctl --user -u plasma-plasmashell -f | grep -i nervecenter
```

### Validating QML Files
To run static syntax verification:
```bash
qmllint nervecenter/contents/ui/<filename>.qml
```
