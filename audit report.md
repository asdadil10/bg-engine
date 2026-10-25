# NerveCenter — Styles & Persistence Audit

**Date:** 2026-10-25  
**Scope:** `NerveFrame.qml`, `main.qml`, `config.qml`, `config/main.xml`, `NerveCompositor.qml`, `NerveShaderLayer.qml`, `shader_registry.json`  
**Live config inspected:** `~/.config/kde.org/plasmashell.conf`, `~/.config/plasma-org.kde.plasma.desktop-appletsrc`

---

## Verdict

- **Layering is real, but shallow.** At audit time the micro-effects were ordered by one array and assigned `z = index + 5`; they alpha-composite in activation order. They are **not a render chain** — each effect samples the original wallpaper independently. Base styles are outside the stack and pinned above it. The only true ping-pong compositor in the repo (`NerveCompositor.qml`) is **never instantiated**. C1 resolved this by documenting the shipped model as ordered backdrop overlays and relabelling the compositor as unused reference code. C2 replaced the hand-written blocks with one `effectModel` (shader effects share `EffectShaderLayer.qml`; static effects load from `Component`s), and C4 skips shader layers hidden beneath `dither_frost`.
- **Persistence is split-brain.** Base style is effectively local-settings-authoritative; the effect stack is KConfig-authoritative. The two stores already disagree on this machine, so a reboot can produce a hybrid state that was never selected.

> **Status (2026-10-25):** the P0 persistence findings below are fixed and verified. KConfig is now the single source of truth for both base style and the effect stack, after a one-time migration guarded by `StyleMigrated`. Sections 1–3 describe the **pre-fix** code and are kept as the audit record; §5 tracks each fix and its verification. The halftone effect was subsequently removed end-to-end (schema, both UIs, runtime, registry, shaders, tests), leaving **10** shipped effects; legacy `"halftone"` entries in saved stacks are filtered out on load. The C category is also complete: one ordered effect model drives all overlays, the stack is capped at 10, `dither_frost` culls covered shader layers, and shader/blur layers wait for a ready wallpaper. E6 (layer order) and E7 (CPU/GPU) are verified; E4 (multi-monitor) is deferred.

---

## 1. Intended model

| Axis | Selection | Storage key | Applied by |
|---|---|---|---|
| **Base style** | Single-select, `0–6` | `panelStyle` | `NerveFrame.qml:12`, `44–78` |
| **Micro-effects** | Multi-select, 11 effects at audit time (10 after halftone removal) | `activeEffectsStack` + `effectsStackJson` | `main.qml:52`, `NerveFrame.qml:28–41` |

Base styles change the root `Rectangle` fill, radius, and border, plus hardcoded decoration layers:

- `0 CYBER_WIREFRAME` — corner brackets / crosshairs
- `1 GLASS_GLASSMORPHIC` — blur + glass rims
- `2 MINIMALIST_FLAT` — flat fill
- `3 TACTICAL_CHASSIS` — chamfers, rivets, hazard tag
- `4 STEALTH_VOID` — transparent fill, hairline crosshairs
- `5 RETRO_PHOSPHOR_CRT` — cathode rim
- `6 CYBER_NEUMORPHIC` — bevel highlights/shadows

Micro-effects are toggled from the in-canvas `STYLE ▾` menu. `toggleEffect()` removes then appends the key (`main.qml:63–78`), so the most recently enabled effect goes last. `getEffectZ()` returns `index + 5` (`NerveFrame.qml:28–34`), which is the entire layering mechanism.

Runtime visibility is driven almost entirely by `activeEffectsStack`:

```js
function isEffectVisible(key, fallbackBool) {
    if (typeof root !== "undefined" && root.activeEffectsStack) {
        return root.activeEffectsStack.indexOf(key) >= 0;
    }
    return fallbackBool;
}
```

Because `root.activeEffectsStack` is always defined, the `show*` booleans in `NerveFrame.qml:15–25` are effectively dead in the wallpaper path. They only matter if `NerveFrame` is used outside a `root` context.

---

## 2. Are the styles truly layered?

### 2.1 Actual z-order

| Element | z | Notes |
|---|---:|---|
| Root fill / border | parent | base style background |
| Prism/FastBlur container | `1` or `idx+5` | style 1 always shows FastBlur; prism moves it into the stack |
| Hologram | `idx+5` | overlay |
| Vignette | `idx+5` | overlay |
| Circuit canvas | `idx+5` | overlay |
| Circuit edge markers | `idx+6` | collides with next effect's z |
| Scanlines | `idx+5` | overlay |
| ASCII | `idx+5` | overlay |
| LiDAR Sobel | `idx+5` | overlay |
| Thermal FLIR | `idx+5` | translucent overlay |
| Halftone | `idx+5` | overlay |
| Duotone | `idx+5` | mostly opaque |
| Dither Frost | `idx+5` | mostly opaque |
| Base style 3–6 decorations | `9998` | always above effects |
| Base style 0–1 decorations | `9999` | always above effects |
| Panel content (`NervePanel.qml:198–202`) | `1` outside | above the entire frame |

The ordering **is real among the micro-effects**, but it is not global. Base-style chamfers, glass rims, rivets, and wireframe corners always render above every micro-effect. Because `NerveFrame` is at `z: 0` while panel content is at `z: 1` (`NervePanel.qml:188–202`), the effects are **backdrop treatments only** — they never overlay panel text or controls.

### 2.2 Why it is not a compositor chain

Every shader effect creates its own `ShaderEffectSource` with:

```qml
sourceItem: root.wallpaperImageItem
```

Examples: `NerveFrame.qml:793–805`, `883–895`, `953–965`, `1024–1036`, `1094–1106`, `1165–1177`.

Effect N does **not** read effect N−1's output. It reads the original wallpaper crop. The visual result is painter's-algorithm alpha blending, not a multi-pass pipeline.

Concrete consequences:

- Enabling `duotone` then `ascii` does **not** produce ASCII over a duotone-graded image; the ASCII shader samples the ungraded wallpaper.
- Enabling `duotone` then `dither_frost` means dither frost (alpha 1.0, QML opacity 0.85) largely hides duotone.
- `prism_blur` is alpha 0.92, `duotone` and `dither_frost` are alpha 1.0 — they are effectively opaque plates, not blend layers.
- ASCII, LiDAR, thermal, and halftone are transparent overlays, so they behave more like the "stack" description.

The true multi-pass implementation exists in `NerveCompositor.qml` — RGBA16F ping-pong buffers, `blendEffectA`/`blendEffectB`, final dither (`NerveCompositor.qml:100–201`, `236–329`) — but **no file instantiates it**. `NerveShaderLayer.qml` is only used by that unused compositor. `shader_registry.json` is not loaded by any code; it is documentation only.

### 2.3 Other layering defects

- **Circuit marker z collision:** `getEffectZ("circuit") + 1` equals the next effect's z. Tie-breaking then depends on declaration order.
- **No layer cap:** `shader_registry.json:3` declares `"max_layers": 8`, but the menu exposes 11 effects and the z math has no cap.
- **Registry drift:** the registry lists `anamorphic_streak` with a nonexistent `anamorphic_streak.frag.qsb` (`shader_registry.json:24–40`), and lists `tiltshift` (`124–138`), neither of which is exposed in the wallpaper UI. The actual streak passes are `streak_thresh/blur/comp`.
- **Occlusion culling absent:** all active effects remain `visible: true`; stacking five opaque effects runs five full-panel shader passes while only the top one is visible.
- **Theme repaint gaps:** the style-0 and style-3 `Canvas` decorations read `highlightColor`/`accentColor` in `onPaint`, but only repaint on width/height changes (`NerveFrame.qml:309–310`, `629–630`). Changing theme colors can leave stale canvas colors until a resize. The circuit canvas handles this correctly via `onTraceColorChanged` (`569`).
- **"Zero idle GPU" is overstated.** `live: false` freezes the `ShaderEffectSource` texture, but the `ShaderEffect` itself is still drawn whenever the scene repaints. Panels with clocks/graphs cause repaints, so the fragment shader can still run each frame.
- **Missing background image:** `blurContainer` requires `root.wallpaperImageItem.status === Image.Ready` (`NerveFrame.qml:90–92`). Without a background image, Glassmorphic has no blur, and shader effects that sample the wallpaper have nothing meaningful to render.

---

## 3. Persistence and storage

### 3.1 The two stores

| Store | Location | Scope | Written by |
|---|---|---|---|
| **Local QSettings** (`QtCore.Settings`) | `~/.config/kde.org/plasmashell.conf` | **Global per plasmashell user**, not per containment/screen | `main.qml` `Settings { category: "Layout" }` and `"PanelsVisibility"` |
| **KConfig** | `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, group `[Containments][N][Wallpaper][org.kde.nervecenter][General]` | **Per containment** | Plasma config dialog (`config.qml` `cfg_*` aliases) and `root.configuration.*` writes |

The schema is `nervecenter/contents/config/main.xml`. It defines all 11 `Effect*` booleans plus `EffectsStackJson` (`main.xml:37–88`).

### 3.2 Write paths

**In-canvas `STYLE ▾` menu:**

- Base style: `layoutSettings.panelStyle = si.styleIndex` only (`main.qml:782`). KConfig `PanelStyle` is **not** written until `SAVE_CONFIG` (`main.qml:1166`).
- Effects: `toggleEffect()` → `syncEffectsToConfig()` writes:
  - local `layoutSettings.effect*` booleans
  - local `layoutSettings.effectsStackJson`
  - KConfig `EffectsStackJson` immediately (`main.qml:97–114`)
  - **not** KConfig `Effect*` booleans.

**Plasma config dialog (`config.qml`):**

- Exposes only 6 of 11 effects: prism, hologram, vignette, circuit, scanlines, ASCII (`config.qml:30–35`, switches `441–481`).
- Does **not** expose LiDAR, thermal, halftone, duotone, dither frost, or `EffectsStackJson`.
- On Apply, writes those 6 KConfig booleans. `main.qml:244–254` handles them via `syncEffectFromConfig()`, which updates the in-memory stack but **does not serialize it** back to local or KConfig.
- `cfg_PanelStyle` writes KConfig `PanelStyle`; `onValueChanged` copies it into local `panelStyle` (`main.qml:243`).

**`SAVE_CONFIG` button (`main.qml:1134–1204`):**

- Writes KConfig `PanelStyle`, colors, opacities, layout, visibility, edit mode.
- Does **not** write KConfig `Effect*` booleans or `EffectsStackJson`.
- Therefore it cannot persist effect changes made in the config dialog.

### 3.3 Read precedence at startup

`Component.onCompleted` (`main.qml:339–361`):

1. Read KConfig `EffectsStackJson`.
2. If it parses to a non-empty array → use it.
3. Otherwise rebuild from local `layoutSettings.effect*` booleans in a hardcoded order.

Consequences:

- **Local `effectsStackJson` is never used** in practice, because KConfig always returns at least `"[]"` (truthy) from the schema default. The local stack JSON is write-only.
- **KConfig wins for effects, local wins for base style.** `panelStyle` is a plain `property int panelStyle: 0` (`main.qml:195`) and is **never initialized from `root.configuration.PanelStyle`**. KConfig only reaches it through a runtime `valueChanged` signal. If local settings are reset, KConfig's style is ignored.

### 3.4 Concrete divergence on this machine

`~/.config/kde.org/plasmashell.conf`:

```ini
[Layout]
panelStyle=3
effectsStackJson=["lidar_sobel"]
effectLidarSobel=true
effectHologram=false
hudOpacity=1
```

`~/.config/plasma-org.kde.plasma.desktop-appletsrc`:

```ini
[Containments][223][Wallpaper][org.kde.nervecenter][General]
PanelStyle=1
EffectsStackJson=["prism_blur","lidar_sobel"]
EffectHologram=true
EffectPrismBlur=true
# no EffectLidarSobel entry
HudOpacity=0.7
```

Interpretation:

- **Base style:** local says Tactical (3), KConfig says Glass (1). Startup uses local 3; KConfig 1 is ignored. Opening the Plasma config dialog and clicking Apply will load 1 and overwrite local to 1.
- **Effect stack:** KConfig says `["prism_blur","lidar_sobel"]`; local says `["lidar_sobel"]`. Startup uses KConfig, so the stack after restart is prism + LiDAR, not LiDAR only.
- **Boolean/stack contradiction:** KConfig has `EffectHologram=true` but hologram is absent from `EffectsStackJson`, so hologram will not render. The per-effect booleans and the stack JSON are already out of sync.
- **Opacity:** local `hudOpacity=1` shadows KConfig `HudOpacity=0.7`, so the KConfig value is ignored.
- **Legacy keys:** local still contains `effectGraticule`, `effectHex`, `showRightAIPanel`, and `[Presets]` — stale schema from earlier versions. `install.sh` does not touch config, so these survive reinstalls. (`[QuoteOfDay]` is current, not legacy.)

### 3.5 What survives a reboot

| Setting | Effective startup source | Survives? |
|---|---|---|
| Base style | local `panelStyle` only | Yes via local; KConfig ignored; lost if local reset; clobbered by config Apply |
| Effect stack | KConfig `EffectsStackJson` if non-empty, else local booleans | Yes, but can revert to a stale KConfig stack |
| Config-dialog effect changes | Not serialized to stack | **Lost** when KConfig stack is non-empty |
| Config-dialog effect order | Hardcoded fallback order | **Lost**; not activation order |
| 5 newer effects | Stack JSON only | Survives only while stack JSON is correct; config UI cannot control them |
| Colors | local override if set, else KConfig | Yes |
| Opacity | local if `!= -1`, else KConfig | Yes; local can shadow KConfig indefinitely |
| Panel layout | local `panelsLayoutJson` if non-empty, else KConfig | Yes; KConfig changes ignored once local is populated |
| Visibility | `PanelsVisibility` local if `hasSavedState`, else KConfig | Yes; triple-stored |
| Shortcuts | KConfig only | Yes |

---

## 4. Findings by severity

| Severity | Finding |
|---|---|
| **High** | Dual source of truth for effects. KConfig stack overrides local at startup, but config-dialog changes never update the stack → settings lost on reboot. |
| **High** | `panelStyle` has no explicit KConfig initialization. KConfig `PanelStyle` is ignored at startup and can clobber the in-canvas selection when the config dialog is applied. |
| **High** | Config dialog exposes only 6/11 effects and no `EffectsStackJson`. KConfig booleans and stack JSON can contradict each other. |
| **High** | Local `Layout` settings are global per plasmashell user, while KConfig is per containment. Multi-monitor/multi-activity setups share style/effects locally but diverge per containment in KConfig. |
| **Medium** | `syncEffectFromConfig()` updates memory but does not serialize the stack; `syncEffectsToConfig()` writes KConfig stack but not KConfig booleans. Asymmetric write paths. |
| **Medium** | `SAVE_CONFIG` flushes `PanelStyle` but not effect stack/booleans, so it cannot rescue config-dialog effect changes. |
| **Medium** | Effects are independent wallpaper samples, not a chain; opaque effects occlude lower layers and waste passes. |
| **Medium** | `NerveCompositor.qml`, `NerveShaderLayer.qml`, and `shader_registry.json` are unused by the live wallpaper; the "multi-pass compositor" claim is not true for the shipped path. |
| **Medium** | Base-style decorations are pinned at z 9998/9999, so "exact activation order" only applies to micro-effects, never to the base style. |
| **Low** | Circuit marker z collides with the next effect's z. |
| **Low** | Style-0/3 Canvas decorations don't repaint on theme color changes. |
| **Low** | `max_layers: 8` vs 11 selectable effects; registry lists two unwired shaders and a nonexistent filename. |
| **Low** | Local `effectsStackJson` is write-only; `show*` booleans are shadowed by `activeEffectsStack`. |
| **Low** | "0.0% idle GPU" is not guaranteed; `live:false` only freezes texture updates. |
| **Low** | Effects/blur degrade silently when no background image is configured. |

---

## 5. Fix checklist

### A. Persistence correctness (P0)

- [x] **A1. Make KConfig the single source of truth for base style.** `main.qml` now exposes `readonly property int panelStyle` bound to `root.configuration.PanelStyle`; `setPanelStyle()` writes KConfig directly. Acceptance: deleting local settings restores the KConfig style.
- [x] **A2. Make effect persistence write-through.** `syncEffectFromConfig()` now updates the in-memory stack and calls `syncEffectsToConfig()`, which writes `EffectsStackJson` **and** every current `Effect*` boolean (10 after halftone removal) under a re-entrancy guard. Acceptance: a config-dialog effect toggle updates the stack immediately.
- [x] **A3. Persist every effect from the config dialog.** Added `cfg_EffectLidarSobel`, `cfg_EffectThermalFlir`, `cfg_EffectDuotone`, `cfg_EffectDitherFrost`, and `cfg_EffectsStackJson` in `config.qml`, plus the missing switches. (`cfg_EffectHalftone` existed briefly and was removed with the effect.) Acceptance: every effect can be toggled from Plasma settings and survives a restart.
- [x] **A4. Remove the KConfig-stack-over-local precedence ambiguity.** KConfig is authoritative after a one-time migration. Local style/effect mirrors are read only by the migration and are never used at runtime. Acceptance: mixed in-canvas + config-dialog edits no longer revert.
- [x] **A5. Stop local overrides shadowing KConfig indefinitely.** Style and effect reads now come from `root.panelStyle` / `root.configuration.Effect*`; the local `Settings` mirrors are migration-only. Acceptance: KConfig changes are reflected even when local values are non-default.
- [x] **A6. Scope local Settings per containment, or eliminate local style/effect storage.** Local style/effect storage is now legacy-only and ignored after the per-containment KConfig `StyleMigrated` flag is set; KConfig provides per-containment isolation. Acceptance: two containments/screens can hold different styles without cross-talk.
- [x] **A7. Make `SAVE_CONFIG` flush effect state consistently.** The handler re-asserts `setPanelStyle(root.panelStyle)` and calls `syncEffectsToConfig()`, so `PanelStyle`, all `Effect*` booleans, and `EffectsStackJson` are flushed together. Acceptance: `SAVE_CONFIG` alone fully persists the current style and effect stack.

### B. Schema and config UI consistency

- [x] **B1. Add the missing effect aliases to `config.qml`.** All 10 current `cfg_Effect*` aliases exist (halftone's alias was removed with the effect).
- [x] **B2. Add `cfg_EffectsStackJson` or replace the 10 switches with one ordered list editor.** A hidden `effectsStackJsonField` is bound to `cfg_EffectsStackJson`; toggling a switch preserves activation order (new effects append, disabled effects are removed). Unknown/duplicate keys — including legacy `"halftone"` — are filtered on load.
- [x] **B3. Remove redundant per-effect booleans if the stack JSON is the source of truth**, or write both consistently. Both are written together by `syncEffectsToConfig()`, so `EffectHologram=true` can no longer coexist with a stack that excludes `hologram`.
- [x] **B4. Migrate and remove legacy local keys** (`effectHex`, `effectGraticule`, `showRightAIPanel`, `[Presets]`, `[QuoteOfDay]`). Acceptance: local settings contain only the current schema. *(`[QuoteOfDay]` is current, not legacy — `main.qml` reads it for the daily quote. The three orphaned `[Layout]` keys and the `[Presets]` group were removed by `scripts/cleanup-legacy-settings.py`, which edits the shared file as text instead of re-serializing it through KConfig tools. The script runs from `install.sh` and is idempotent. The `panelStyle`/`effect*`/`effectsStackJson` mirrors are deliberately retained: the one-time migration still reads them for users upgrading from older versions.)*
- [x] **B5. Update `main.xml` labels/defaults** if the schema changes, and keep `config.qml` aliases in lockstep. The schema and aliases are in lockstep at 10 effects plus `EffectsStackJson`; `EffectHalftone` was removed from both.

> **Implementation note:** On first run after this patch, `main.qml` runs a one-time migration guarded by the per-containment KConfig `StyleMigrated` flag (`config/main.xml`). It preserves the previously effective state (local base style + KConfig effect stack), writes the normalized result to KConfig, then ignores the local mirrors. This is the only point where local style/effect values are read.

### C. Layering and architecture

- [x] **C1. Decide the layering model.** Resolved with the low-risk option: the shipped model is documented as **ordered backdrop overlays** (`README.md` → "Rendering model", `MINIMAP.md`), and `NerveCompositor.qml` / `NerveShaderLayer.qml` are explicitly marked unused reference code. Each effect samples the original wallpaper crop and alpha-composites in activation order; there is no chained pass. Acceptance: docs and code agree on whether effects are chained. *(Verified: no QML file instantiates the compositor; docs and source headers now say so.)*
- [x] **C2. Replace hardcoded effect blocks with one ordered effect model** (`Repeater`/`Loader`) so z-order, visibility, and parameters come from a single list. Acceptance: adding an effect requires one model entry, not a new hand-written block. *(`NerveFrame.qml` now declares one `effectModel` array; `shaderEffectModel` drives a `Repeater` of the shared `EffectShaderLayer.qml`, and `staticEffectModel` drives a `Repeater` of `Loader`s over four `Component`s. Adding an effect is one model entry plus its shader/component.)*
- [x] **C3. Enforce a layer cap or update the registry.** Align `shader_registry.json` `max_layers` with the 10 exposed effects. Acceptance: the UI cannot exceed the declared cap. *(`maxEffectLayers: 10` in `main.qml`; `sanitizeEffectStack()`, `toggleEffect()`, and `syncEffectFromConfig()` clamp to it. Registry `max_layers` is now 10.)*
- [x] **C4. Add occlusion culling or skip fully covered opaque layers.** Acceptance: enabling `dither_frost` above `duotone` does not run both full-panel passes. *(`dither_frost` is marked `occludesBelow: true`. Lower shader layers report `effectLayerVisible() === false`; cheap static Canvas/vector overlays stay visible. Live: `["duotone","dither_frost"]` rendered only the frost, and `["dither_frost","duotone"]` rendered duotone above it.)*
- [x] **C5. Fix the circuit marker z collision** (`NerveFrame.qml:576`). Use a unique sub-layer offset or fold markers into the circuit item. *(Markers moved inside the circuit effect `Component` with relative `z: 1`, so no global `z+1` collision remains.)*
- [x] **C6. Fix Canvas repaint on theme color changes** for style 0 and style 3 (`NerveFrame.qml:309–310`, `629–630`). Acceptance: changing accent/highlight updates decorations immediately. *(Style-0 canvas repaints on `frame.highlightColor`; style-3 chassis repaints on `frame.accentColor` and `root.bgColor`. Live static-stack screenshot confirmed the amber theme is applied to both.)*
- [x] **C7. Clarify or measure the "zero GPU" claim.** `live:false` freezes textures but does not eliminate shader draws on repaint. Acceptance: docs state the real cost, or idle cost is measured and documented. *(README "Rendering model" now states `live: false` freezes the wallpaper sample but the shader still runs on panel repaint; MINIMAP carries the same cost note.)*
- [x] **C8. Fix shader registry drift.** Correct the `anamorphic_streak` filename and either expose or remove `tiltshift`. Acceptance: every registry entry points to a real, reachable shader. *(`anamorphic_streak.file` corrected to `streak_comp.frag.qsb` and marked `"status": "reference"`; the unexposed `tiltshift` entry and both shader files were removed. Registry parses and every non-canvas entry resolves to a file on disk.)*
- [x] **C9. Handle missing background images gracefully.** Disable or fall back for blur/shader effects when `wallpaperImageItem.status !== Image.Ready`. Acceptance: Glassmorphic and shader effects do not render blank panels without a wallpaper image. *(`backgroundReady` gates every `needsBackground` layer, and the style-1 `FastBlur` fallback. Headless test flips the wallpaper item to `Image.Null` and asserts shader layers hide while static overlays remain.)*

### D. Documentation

- [x] **D1. Update `MINIMAP.md` and `README.md`** to reflect the actual code: 10 effects (halftone removed), no `tools/` directory, unused `NerveCompositor`, real persistence model. *(MINIMAP now omits the nonexistent `tools/` tree, marks the compositor and shader wrapper as unused, and lists the 10 overlays. README gained "Rendering model" and "Persistence model" sections.)*
- [x] **D2. Add a persistence architecture note** documenting both stores, their scopes, write paths, and startup precedence. *(Added `README.md` → "Persistence model": KConfig authoritative, per-containment scope, `writeConfig()` flush, `StyleMigrated` one-time migration, local mirrors migration-only.)*

### E. Verification

- [x] **E1. Reboot test:** set style and effects in-canvas, restart `plasma-plasmashell`, verify the exact style/stack returns. *(Verified with two full `plasma-plasmashell` service restarts; the migrated state survived on disk and in the live config.)*
- [x] **E2. Config-dialog round-trip:** toggle each of the 10 effects in Plasma settings, Apply, restart, verify all survive. *(Dialog logic covered by `tests/tst_config_effects.qml`: all 10 real switches are clicked, activation order is preserved, Apply→reopen round-trips, legacy `halftone` is dropped, and malformed JSON normalizes. Live KConfig round-trip of the effect booleans plus a scrambled-order stack survived a full shell restart.)*
- [x] **E3. Mixed-path test:** in-canvas toggle → config dialog Apply → restart; verify no reversion or lost effect. *(Simulated in-canvas write `["prism_blur","lidar_sobel","vignette"]`, then dialog Apply `["prism_blur","vignette","duotone"]`; after a full restart the live and on-disk state were exactly the dialog value — LiDAR stayed off, Duotone stayed on, no reversion.)*
- [ ] **E4. Multi-monitor/activity test:** set different styles per containment; verify isolation. *(Deferred per user request; this machine exposes a single active NerveCenter containment.)*
- [x] **E5. Local-reset test:** move/delete `~/.config/kde.org/plasmashell.conf`; verify KConfig style/effects restore. *(Moved the file aside and restarted: style 3 and `["prism_blur","lidar_sobel"]` were restored from KConfig alone. The original file was then restored intact.)*
- [x] **E6. Layer-order test:** enable the same effects in different orders; verify z-order, occlusion, and no marker collisions. *(Live checks on an empty desktop: `["circuit","vignette","hologram","scanlines"]` rendered all four with no marker collision; `["duotone"]` alone graded the wallpaper; `["duotone","dither_frost"]` showed frost over duotone while `["dither_frost","duotone"]` showed duotone over frost, confirming activation-order painting and C4 occlusion. Headless `tst_nerveframe.qml` asserts z follows stack position.)*
- [x] **E7. Performance check:** measure CPU/GPU with 1, 5, and 10 effects active; update the "0% GPU" wording accordingly. *(Measured on the reference AMD Vega APU with the wallpaper visible on an empty desktop and the session kept awake. Method: `plasmashell` CPU from `/proc/<pid>/stat` deltas and system GPU busy from `/sys/class/drm/card1/device/gpu_busy_percent`, 20 s per stack, 0.25 s samples. Results — **0 effects:** 1.2–1.4% GPU avg, p90 3–4%, max 6%; **1 effect (`prism_blur`):** 2.2% avg, p90 4%, max 8%; **3 effects (baseline):** 2.0–2.2% avg, p90 4%, max 11%; **5 effects (1 shader + 4 static):** 2.7% avg, p90 7%, max 13%; **10 effects (6 shader + 4 static, `dither_frost` first so nothing is culled):** 4.6% avg, p90 7%, max 18%. Plasmashell CPU stayed ~2–5% and is dominated by unrelated work, so it is not a reliable per-effect signal. One baseline run read 20% GPU; two immediate repeats read 2.0% and 2.2%, so that sample was discarded as external GPU activity. Idle averages are low because the wallpaper only repaints when something changes, and the counter drops to 0% when the session locks — the cost is repaint-bound, not a continuous shader loop. README/MINIMAP now describe this instead of claiming zero GPU.)*

> **Static verification (2026-10-25):** `qmllint 6.11.2` parses `main.qml`, `config.qml`, and `NerveFrame.qml` with exit code `0` (warnings only, all pre-existing).
>
> **Config-dialog tests (2026-10-25):** `QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_config_effects.qml` → **12 passed, 0 failed**. The tests instantiate the real `config.qml`, drive the 10 `QQC2.Switch` controls through `checked` + `clicked`, and assert the KConfigXT `cfg_*` values against `EffectsStackJson`.
>
> **C2–C9 refactor verification (2026-10-25):** `qmllint` reports 0 errors on `NerveFrame.qml`, `EffectShaderLayer.qml`, and `main.qml`. A temporary headless `tst_nerveframe.qml` suite instantiates the real `NerveFrame` and asserts: the model covers all 10 effects (6 shader + 4 static), z-order follows activation position, `backgroundReady` gates shader layers, `dither_frost` culls lower shader layers while static overlays stay visible, and inactive effects hide — **8 passed, 0 failed**. Live stack tests on an empty desktop verified static-only, duotone-only, duotone-under-frost, and frost-under-duotone rendering with no QML errors in the journal. The user's baseline (`PanelStyle=3`, `StyleMigrated=true`, `["prism_blur","hologram","scanlines"]`, matching booleans) was restored and re-verified after the tests.
>
> **Halftone removal + C1 (2026-10-25):** halftone was removed from `main.xml`, both QML UIs, the runtime frame, the shader registry, the compositor branch, and the shader files. `sanitizeEffectStack()` and the config-dialog filter drop legacy `"halftone"` keys on load. Live verification: injected `["prism_blur","halftone","hologram","scanlines"]` into the running KConfig and restarted the shell; the live and on-disk stack both came back as `["prism_blur","hologram","scanlines"]` with no QML errors. The orphaned `EffectHalftone` key was also removed from the live config. `NerveCompositor.qml` / `NerveShaderLayer.qml` are now labelled unused, and README/MINIMAP describe ordered backdrop overlays.
>
> **Live migration verification (2026-10-25):** before the patch, local `PanelStyle=3` and KConfig `PanelStyle=1`; KConfig stack was `["prism_blur","lidar_sobel"]` with `EffectHologram=true`. After the first reload, the live KConfig became `PanelStyle=3`, `StyleMigrated=true`, stack `["prism_blur","lidar_sobel"]`, `EffectHologram=false`, `EffectPrismBlur=true`, `EffectLidarSobel=true`. `root.configuration.writeConfig()` flushed the same values to `plasma-org.kde.plasma.desktop-appletsrc`. A second full shell restart returned the identical state, confirming the migration is one-time and stable.
>
> **Repair verification (2026-10-25):** with the shell stopped, `EffectHologram=true` was injected while `EffectsStackJson` excluded `hologram`. On the next start the boolean was normalized to `false` and dropped from disk, so the stack and the booleans cannot disagree.
>
> **Local-settings cleanup (2026-10-25):** `scripts/cleanup-legacy-settings.py` removed `effectHex`, `effectGraticule`, `showRightAIPanel`, and the `[Presets]` group. A byte-level diff showed no other changes; the keys did not reappear after a full shell restart; every current group (`[DeckWeather]`, `[GitGrid]`, `[QuoteOfDay]`, …) was untouched. A backup is kept as `plasmashell.conf.nervecenter-bak`.

---

## 6. Suggested implementation order

1. **A1–A4, A7** — fix persistence and config-dialog loss first.
2. **B1–B3** — align schema and UI; remove contradictory state.
3. **A5–A6** — clean up precedence and scoping.
4. **C1–C4** — decide and refactor the layering model.
5. **C5–C9, B4–B5, D1–D2** — polish, cleanup, docs.
6. **E1–E7** — verify each fix.

---

## 7. Notes

- `install.sh` removes/reinstalls the package but never touches `~/.config/kde.org/plasmashell.conf` or the appletsrc group. Stale state therefore survives reinstall and must be migrated explicitly.
- The `Settings` component uses `~/.config/kde.org/plasmashell.conf` on this machine. That file is shared by all plasmashell components using the same `QtCore.Settings` application identity, so the `Layout` category is not isolated to NerveCenter.
- No code was changed during the initial audit pass. Fixes were then implemented in `dfc2337` (persistence), `558ce4f` (B4 cleanup), `87a379f` (C1 + halftone removal), `c7a634d` (C2–C9), and `8a2fc83` (E7 measurements). E4 remains deferred.
