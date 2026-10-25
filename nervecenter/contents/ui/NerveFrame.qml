/*
 *  NerveCenter — NerveFrame.qml
 *  Custom cyberpunk HUD frame with high-tech corner brackets and glassmorphic backdrop styling.
 */
import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: frame
    
    // KConfig is the single source of truth for the base style and effect flags.
    readonly property int activePanelStyle: (typeof root !== "undefined" && root.panelStyle !== undefined)
                                             ? root.panelStyle : 0

    function configEffectEnabled(configKey) {
        return (typeof root !== "undefined" && root.configuration
                && root.configuration[configKey] === true)
    }

    // Stackable effect flags (fallback only; visibility is driven by activeEffectsStack)
    readonly property bool showPrismBlur:   frame.configEffectEnabled("EffectPrismBlur")
    readonly property bool showHologram:    frame.configEffectEnabled("EffectHologram")
    readonly property bool showVignette:    frame.configEffectEnabled("EffectVignette")
    readonly property bool showCircuit:     frame.configEffectEnabled("EffectCircuit")
    readonly property bool showScanlines:   frame.configEffectEnabled("EffectScanlines")
    readonly property bool showAscii:       frame.configEffectEnabled("EffectAscii")
    readonly property bool showLidarSobel:  frame.configEffectEnabled("EffectLidarSobel")
    readonly property bool showThermalFlir: frame.configEffectEnabled("EffectThermalFlir")
    readonly property bool showHalftone:    frame.configEffectEnabled("EffectHalftone")
    readonly property bool showDuotone:     frame.configEffectEnabled("EffectDuotone")
    readonly property bool showDitherFrost: frame.configEffectEnabled("EffectDitherFrost")

    // Dynamic chronological stacking order helpers (stacked in the exact order user turns them on)
    function getEffectZ(key, fallbackZ) {
        if (typeof root !== "undefined" && root.activeEffectsStack) {
            var idx = root.activeEffectsStack.indexOf(key);
            if (idx >= 0) return idx + 5;
        }
        return fallbackZ;
    }

    function isEffectVisible(key, fallbackBool) {
        if (typeof root !== "undefined" && root.activeEffectsStack) {
            return root.activeEffectsStack.indexOf(key) >= 0;
        }
        return fallbackBool;
    }

    // Dynamic styling based on selected Panel Backdrop Style (base styles 0-6)
    radius: {
        switch (activePanelStyle) {
            case 0: return 3;   // Cyber wireframe
            case 1: return 10;  // Glass
            case 2: return 6;   // Minimalist
            case 3: return 0;   // Tactical (chamfered polygon)
            case 4: return 2;   // Stealth void
            case 5: return 8;   // Retro CRT
            case 6: return 6;   // Cyber Neumorphic
            default: return 3;
        }
    }

    color: {
        switch (activePanelStyle) {
            case 0: return Qt.rgba(8/255, 9/255, 13/255, 0.55);
            case 1: return Qt.rgba(10/255, 12/255, 18/255, 0.35);
            case 2: return Qt.rgba(12/255, 13/255, 18/255, 0.82);
            case 3: return Qt.rgba(11/255, 13/255, 18/255, 0.88); // Tactical gunmetal
            case 4: return "transparent";                          // Stealth void
            case 5: return Qt.rgba(4/255, 8/255, 5/255, 0.90);     // Retro CRT cathode
            case 6: return Qt.rgba(10/255, 11/255, 15/255, 0.92);  // Milled carbon matte
            default: return Qt.rgba(8/255, 9/255, 13/255, 0.55);
        }
    }

    border.color: {
        switch (activePanelStyle) {
            case 0: return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18);
            case 3: return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.40);
            case 4: return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22);
            case 5: return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35);
            default: return "transparent";
        }
    }

    border.width: 1

    property color accentColor: "#00f0ff"
    property color highlightColor: "#ff007f"
    property string subLabel: ""

    // ── Backdrop blur (Style 1 or when prism_blur is active) ──
    Item {
        id: blurContainer
        anchors.fill: parent
        visible: (frame.activePanelStyle === 1 || frame.isEffectVisible("prism_blur", frame.showPrismBlur)) &&
                 typeof root !== "undefined" && root.wallpaperImageItem && root.wallpaperImageItem.status === Image.Ready
        clip: true
        z: frame.getEffectZ("prism_blur", 1)

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: frame.width
                height: frame.height
                radius: frame.radius
            }
        }

        ShaderEffectSource {
            id: blurSource
            anchors.fill: parent
            sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            sourceRect: {
                if (typeof root === "undefined" || !root.wallpaperImageItem) return Qt.rect(0,0,0,0);
                var absPos = frame.mapToItem(root.wallpaperImageItem, 0, 0);
                return Qt.rect(absPos.x, absPos.y, frame.width, frame.height);
            }
            live: false
        }

        // Standard blur when in Style 1 without prism effect
        FastBlur {
            anchors.fill: parent
            source: blurSource
            radius: 48
            visible: !frame.isEffectVisible("prism_blur", frame.showPrismBlur)
        }

        // Chromatic dispersion optical prism blur when prism_blur is active
        ShaderEffect {
            id: prismBlurEffect
            anchors.fill: parent
            visible: frame.isEffectVisible("prism_blur", frame.showPrismBlur)
            supportsAtlasTextures: true

            property var source: blurSource
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(18.0, 4.5, 0.0, 0.0) // blurRadius, dispersion
            property vector4d p1: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
            property vector4d p2: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
            property vector4d p3: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
            property color c0: frame.accentColor
            property color c1: frame.highlightColor
            property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)

            fragmentShader: "shaders/prism_blur.frag.qsb"
        }

        // Refresh blur on coordinate or stack changes
        Connections {
            target: frame
            function onWidthChanged() { blurSource.scheduleUpdate(); }
            function onHeightChanged() { blurSource.scheduleUpdate(); }
            function onVisibleChanged() { if (frame.visible) blurSource.scheduleUpdate(); }
        }
        Connections {
            target: frame.parent ? frame.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { blurSource.scheduleUpdate(); }
            function onYChanged() { blurSource.scheduleUpdate(); }
            function onWidthChanged() { blurSource.scheduleUpdate(); }
            function onHeightChanged() { blurSource.scheduleUpdate(); }
        }
        Connections {
            target: (frame.parent && frame.parent.parent) ? frame.parent.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { blurSource.scheduleUpdate(); }
            function onYChanged() { blurSource.scheduleUpdate(); }
            function onWidthChanged() { blurSource.scheduleUpdate(); }
            function onHeightChanged() { blurSource.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined") ? root : null
            ignoreUnknownSignals: true
            function onBgImageChanged() { blurSource.scheduleUpdate(); }
            function onBgImageOpacityChanged() { blurSource.scheduleUpdate(); }
            function onBgColorChanged() { blurSource.scheduleUpdate(); }
            function onActiveEffectsStackChanged() { blurSource.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            ignoreUnknownSignals: true
            function onStatusChanged() { blurSource.scheduleUpdate(); }
        }
        Component.onCompleted: { blurSource.scheduleUpdate(); }
    }

    // ═══════════════════════════════════════════════════════════
    //  GLASS BORDER — fully contained within widget bounds
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 9999
        clip: true  // keep everything inside

        // ── Outer glass rim with subtle accent tint (Style 1) ──
        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.color: activePanelStyle === 1
                          ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
                          : (activePanelStyle === 2 ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.20) : "transparent")
            border.width: 2
            visible: activePanelStyle >= 1
        }

        // ── Inner glass highlight ring (Style 1) ──
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: frame.radius - 3
            color: "transparent"
            border.color: activePanelStyle === 1
                          ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
                          : "transparent"
            border.width: 1
            visible: activePanelStyle === 1
        }

        // ── Glass depth shadow (inside the panel) ──
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: frame.radius - 5
            color: "transparent"
            border.color: activePanelStyle === 1
                          ? Qt.rgba(0/255, 0/255, 0/255, 0.12)
                          : "transparent"
            border.width: 1
            visible: activePanelStyle === 1
        }
    }

    // ── Minimal accent overlays (Style 0 only) ────────────────
    Item {
        anchors.fill: parent
        z: 9999
        visible: activePanelStyle === 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            height: 1
            color: accentColor
            opacity: 0.08
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            height: 1
            color: accentColor
            opacity: 0.08
        }
    }

    // ── Cybernetic corners (Style 0: Cyberpunk Wireframe) ──
    Canvas {
        anchors.fill: parent
        visible: frame.activePanelStyle === 0
        z: 9999
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, 0.6)
            ctx.lineWidth = 1.5

            var len = 16
            ctx.beginPath()
            ctx.moveTo(0, len)
            ctx.lineTo(0, 0)
            ctx.lineTo(len, 0)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(width - len, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, len)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(0, height - len)
            ctx.lineTo(0, height)
            ctx.lineTo(len, height)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(width - len, height)
            ctx.lineTo(width, height)
            ctx.lineTo(width, height - len)
            ctx.stroke()

            ctx.strokeStyle = Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, 0.2)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(len, 0)
            ctx.lineTo(len + 6, 0)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(width - len - 6, 0)
            ctx.lineTo(width - len, 0)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(len, height)
            ctx.lineTo(len + 6, height)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(width - len - 6, height)
            ctx.lineTo(width - len, height)
            ctx.stroke()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // ── Side crosshairs (Style 0 only) ──
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3; height: 1
        color: highlightColor; opacity: 0.6
        visible: frame.activePanelStyle === 0
        z: 9999
    }
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 3; height: 1
        color: highlightColor; opacity: 0.6
        visible: frame.activePanelStyle === 0
        z: 9999
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: HOLOGRAM EDGES (Static Neon Gradient Borders)
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: frame.isEffectVisible("hologram", frame.showHologram)
        clip: true
        z: frame.getEffectZ("hologram", 2)


        // ── Top edge neon line ──
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.5) }
                GradientStop { position: 0.7; color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.5) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Bottom edge neon line ──
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, 0.35) }
                GradientStop { position: 0.7; color: Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Left edge accent ──
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25) }
                GradientStop { position: 0.8; color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Right edge accent ──
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25) }
                GradientStop { position: 0.8; color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: VIGNETTE DEPTH (Static Dark Shadow Gradients)
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: frame.isEffectVisible("vignette", frame.showVignette)
        clip: true
        z: frame.getEffectZ("vignette", 3)

        // ── Top vignette ──
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height * 0.35
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Bottom vignette ──
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.35
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
            }
        }

        // ── Left vignette ──
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.25
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.50) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Right vignette ──
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.25
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.50) }
            }
        }

        // ── Subtle outer border glow ──
        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
            border.width: 1
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, frame.radius - 2)
            color: "transparent"
            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.06)
            border.width: 1
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: CIRCUIT BOARD  (GPU-light: Canvas drawn once)
    // ═══════════════════════════════════════════════════════════
    Canvas {
        id: circuitCanvas
        anchors.fill: parent
        visible: frame.isEffectVisible("circuit", frame.showCircuit)
        z: frame.getEffectZ("circuit", 4)

        property color traceColor: accentColor

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width < 10 || height < 10) return;

            // Fixed seed — pattern is position-independent and consistent
            var seed = 314159;
            function rng() {
                seed = (seed * 1103515245 + 12345) & 0x7fffffff;
                return (seed % 10000) / 10000.0;
            }

            var gridStep = 16;
            // Use a large virtual grid so every panel samples from the same pattern field
            var virtualCols = 60;
            var virtualRows = 60;
            var cols = Math.floor(width / gridStep);
            var rows = Math.floor(height / gridStep);

            // Fixed trace count — same visual density regardless of panel size
            var traceCount = 35;

            // Draw traces
            ctx.strokeStyle = Qt.rgba(traceColor.r, traceColor.g, traceColor.b, 0.10);
            ctx.lineWidth = 1;

            for (var i = 0; i < traceCount; i++) {
                var sx = Math.floor(rng() * virtualCols) * gridStep;
                var sy = Math.floor(rng() * virtualRows) * gridStep;
                var segments = 2 + Math.floor(rng() * 4);
                var horizontal = rng() > 0.5;

                // Skip traces entirely outside visible area
                if (sx > width + gridStep * 4 && sy > height + gridStep * 4) continue;

                ctx.beginPath();
                ctx.moveTo(sx, sy);

                for (var s = 0; s < segments; s++) {
                    var len = (1 + Math.floor(rng() * 4)) * gridStep;
                    if (horizontal) {
                        sx += (rng() > 0.5 ? len : -len);
                    } else {
                        sy += (rng() > 0.5 ? len : -len);
                    }
                    ctx.lineTo(sx, sy);
                    horizontal = !horizontal;
                }
                ctx.stroke();
            }

            // Fixed pad count
            ctx.fillStyle = Qt.rgba(traceColor.r, traceColor.g, traceColor.b, 0.15);
            var padCount = 25;
            for (var p = 0; p < padCount; p++) {
                var px = Math.floor(rng() * virtualCols) * gridStep;
                var py = Math.floor(rng() * virtualRows) * gridStep;
                if (px <= width && py <= height) {
                    ctx.beginPath();
                    ctx.arc(px, py, 2.5, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }

            // Fixed via count
            ctx.strokeStyle = Qt.rgba(traceColor.r, traceColor.g, traceColor.b, 0.12);
            ctx.lineWidth = 1;
            var viaCount = 15;
            for (var v = 0; v < viaCount; v++) {
                var vx = Math.floor(rng() * virtualCols) * gridStep;
                var vy = Math.floor(rng() * virtualRows) * gridStep;
                if (vx <= width && vy <= height) {
                    ctx.beginPath();
                    ctx.arc(vx, vy, 4, 0, 2 * Math.PI);
                    ctx.stroke();
                }
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onTraceColorChanged: requestPaint()
    }

    // ── Circuit board edge markers ──
    Item {
        anchors.fill: parent
        visible: frame.isEffectVisible("circuit", frame.showCircuit)
        z: frame.getEffectZ("circuit", 4) + 1

        // Top-left corner bracket
        Rectangle { x: 0; y: 0; width: 12; height: 1; color: accentColor; opacity: 0.3 }
        Rectangle { x: 0; y: 0; width: 1; height: 12; color: accentColor; opacity: 0.3 }

        // Top-right corner bracket
        Rectangle { x: parent.width - 12; y: 0; width: 12; height: 1; color: accentColor; opacity: 0.3 }
        Rectangle { x: parent.width - 1; y: 0; width: 1; height: 12; color: accentColor; opacity: 0.3 }

        // Bottom-left corner bracket
        Rectangle { x: 0; y: parent.height - 1; width: 12; height: 1; color: accentColor; opacity: 0.3 }
        Rectangle { x: 0; y: parent.height - 12; width: 1; height: 12; color: accentColor; opacity: 0.3 }

        // Bottom-right corner bracket
        Rectangle { x: parent.width - 12; y: parent.height - 1; width: 12; height: 1; color: accentColor; opacity: 0.3 }
        Rectangle { x: parent.width - 1; y: parent.height - 12; width: 1; height: 12; color: accentColor; opacity: 0.3 }
    }

    // ═══════════════════════════════════════════════════════════
    //  BASE STYLE 3 — TACTICAL CHASSIS (Chamfers, Rivets & Hazard)
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: frame.activePanelStyle === 3
        z: 9998

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var c = 10;
                ctx.fillStyle = (typeof root !== "undefined") ? root.bgColor : "#08090d";
                // Top-left
                ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(c, 0); ctx.lineTo(0, c); ctx.closePath(); ctx.fill();
                // Top-right
                ctx.beginPath(); ctx.moveTo(width, 0); ctx.lineTo(width - c, 0); ctx.lineTo(width, c); ctx.closePath(); ctx.fill();
                // Bottom-left
                ctx.beginPath(); ctx.moveTo(0, height); ctx.lineTo(c, height); ctx.lineTo(0, height - c); ctx.closePath(); ctx.fill();
                // Bottom-right
                ctx.beginPath(); ctx.moveTo(width, height); ctx.lineTo(width - c, height); ctx.lineTo(width, height - c); ctx.closePath(); ctx.fill();

                // Angled chamfer border lines
                ctx.strokeStyle = frame.accentColor;
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(c, 0); ctx.lineTo(0, c);
                ctx.moveTo(width - c, 0); ctx.lineTo(width, c);
                ctx.moveTo(c, height); ctx.lineTo(0, height - c);
                ctx.moveTo(width - c, height); ctx.lineTo(width, height - c);
                ctx.stroke();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // Corner Bolt Rivets
        Repeater {
            model: [
                { x: 12, y: 5 }, { x: parent.width - 18, y: 5 },
                { x: 12, y: parent.height - 11 }, { x: parent.width - 18, y: parent.height - 11 }
            ]
            Rectangle {
                required property var modelData
                x: modelData.x; y: modelData.y
                width: 5; height: 5; radius: 2.5
                color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.20)
                border.color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.50)
                border.width: 1
            }
        }

        // Top-right hazard accent tag
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.top: parent.top
            width: 32; height: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: frame.highlightColor }
                GradientStop { position: 0.5; color: frame.accentColor }
                GradientStop { position: 1.0; color: frame.highlightColor }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  BASE STYLE 4 — STEALTH VOID (Hairline Corner Crosshairs)
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: frame.activePanelStyle === 4
        z: 9998

        // Top-left crosshair
        Rectangle { x: 4; y: 4; width: 8; height: 1; color: frame.accentColor; opacity: 0.4 }
        Rectangle { x: 4; y: 4; width: 1; height: 8; color: frame.accentColor; opacity: 0.4 }

        // Top-right crosshair
        Rectangle { x: parent.width - 12; y: 4; width: 8; height: 1; color: frame.accentColor; opacity: 0.4 }
        Rectangle { x: parent.width - 5; y: 4; width: 1; height: 8; color: frame.accentColor; opacity: 0.4 }

        // Bottom-left crosshair
        Rectangle { x: 4; y: parent.height - 5; width: 8; height: 1; color: frame.accentColor; opacity: 0.4 }
        Rectangle { x: 4; y: parent.height - 12; width: 1; height: 8; color: frame.accentColor; opacity: 0.4 }

        // Bottom-right crosshair
        Rectangle { x: parent.width - 12; y: parent.height - 5; width: 8; height: 1; color: frame.accentColor; opacity: 0.4 }
        Rectangle { x: parent.width - 5; y: parent.height - 12; width: 1; height: 8; color: frame.accentColor; opacity: 0.4 }
    }

    // ═══════════════════════════════════════════════════════════
    //  BASE STYLE 5 — RETRO PHOSPHOR CRT (Cathode Glow Rim)
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: frame.activePanelStyle === 5
        z: 9998

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 6
            color: "transparent"
            border.color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.16)
            border.width: 1
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  BASE STYLE 6 — CYBER NEUMORPHIC (Milled Cavity Bevels)
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: frame.activePanelStyle === 6
        z: 9998

        // Top & Left Specular Highlight
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.28)
            radius: frame.radius
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.28)
            radius: frame.radius
        }

        // Bottom & Right Deep Ambient Drop Shadow
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Qt.rgba(0, 0, 0, 0.75)
            radius: frame.radius
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: Qt.rgba(0, 0, 0, 0.75)
            radius: frame.radius
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: INTERLACE SCANLINES (Static CRT Raster)
    // ═══════════════════════════════════════════════════════════
    Canvas {
        id: scanlinesCanvas
        anchors.fill: parent
        visible: frame.isEffectVisible("scanlines", frame.showScanlines)
        z: frame.getEffectZ("scanlines", 5)

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width < 4 || height < 4) return;
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.24);
            for (var y = 0; y < height; y += 3) {
                ctx.fillRect(0, y, width, 1);
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // Hidden atlas image referenced as texture by the ASCII shader
    Image {
        id: asciiAtlasImage
        source: "assets/ascii_atlas.png"
        visible: false
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: ASCII MATRIX SHADER (Zero-GPU: live: false)
    // ═══════════════════════════════════════════════════════════
    Item {
        id: asciiContainer
        anchors.fill: parent
        anchors.margins: 1
        visible: frame.isEffectVisible("ascii", frame.showAscii)
        clip: true
        z: frame.getEffectZ("ascii", 6)

        ShaderEffectSource {
            id: asciiSourceTexture
            anchors.fill: parent
            sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            sourceRect: {
                if (typeof root === "undefined" || !root.wallpaperImageItem) return Qt.rect(0, 0, 0, 0);
                var absPos = frame.mapToItem(root.wallpaperImageItem, 0, 0);
                return Qt.rect(absPos.x, absPos.y, frame.width, frame.height);
            }
            live: false
            hideSource: false
            smooth: false
        }

        ShaderEffect {
            id: asciiShaderEffect
            anchors.fill: parent
            supportsAtlasTextures: true

            property var source: asciiSourceTexture
            property var asciiAtlas: asciiAtlasImage
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(8.0, 12.0, 0.0, 0.0) // char width, char height
            property vector4d p1: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
            property vector4d p2: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
            property vector4d p3: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
            property color c0: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.65)
            property color c1: Qt.rgba(frame.highlightColor.r, frame.highlightColor.g, frame.highlightColor.b, 0.95)
            property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)

            fragmentShader: "shaders/ascii.frag.qsb"
        }

        onVisibleChanged: {
            if (visible) {
                asciiSourceTexture.scheduleUpdate();
            }
        }

        Connections {
            target: frame
            function onWidthChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
            function onVisibleChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: frame.parent ? frame.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
            function onYChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
            function onWidthChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined") ? root : null
            ignoreUnknownSignals: true
            function onBgImageChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
            function onActiveEffectsStackChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            ignoreUnknownSignals: true
            function onStatusChanged() { if (asciiContainer.visible) asciiSourceTexture.scheduleUpdate(); }
        }
        Component.onCompleted: {
            if (asciiContainer.visible) {
                asciiSourceTexture.scheduleUpdate();
            }
        }
    }

    // 256x1 Ironbow texture LUT for FLIR
    Image {
        id: flirLutImage
        source: "assets/flir_ironbow_lut.png"
        visible: false
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: LIDAR SOBEL WIREFRAME CONTOURS
    // ═══════════════════════════════════════════════════════════
    Item {
        id: lidarContainer
        anchors.fill: parent
        anchors.margins: 1
        visible: frame.isEffectVisible("lidar_sobel", frame.showLidarSobel)
        clip: true
        z: frame.getEffectZ("lidar_sobel", 7)

        ShaderEffectSource {
            id: lidarSourceTexture
            anchors.fill: parent
            sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            sourceRect: {
                if (typeof root === "undefined" || !root.wallpaperImageItem) return Qt.rect(0, 0, 0, 0);
                var absPos = frame.mapToItem(root.wallpaperImageItem, 0, 0);
                return Qt.rect(absPos.x, absPos.y, frame.width, frame.height);
            }
            live: false
            hideSource: false
            smooth: false
        }

        ShaderEffect {
            anchors.fill: parent
            supportsAtlasTextures: true
            property var source: lidarSourceTexture
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(1.5, 0.18, 1.0, 0.5) // preBlur, threshold, thickness, bgDarken
            property vector4d p1: Qt.vector4d(0, 0, 0, 0)
            property vector4d p2: Qt.vector4d(0, 0, 0, 0)
            property vector4d p3: Qt.vector4d(0, 0, 0, 0)
            property color c0: frame.accentColor
            property color c1: frame.highlightColor
            property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)
            fragmentShader: "shaders/lidar_sobel.frag.qsb"
        }

        onVisibleChanged: { if (visible) lidarSourceTexture.scheduleUpdate(); }
        Connections {
            target: frame
            function onWidthChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
            function onVisibleChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: frame.parent ? frame.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
            function onYChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
            function onWidthChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined") ? root : null
            ignoreUnknownSignals: true
            function onActiveEffectsStackChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
            function onBgImageChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            ignoreUnknownSignals: true
            function onStatusChanged() { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
        }
        Component.onCompleted: { if (lidarContainer.visible) lidarSourceTexture.scheduleUpdate(); }
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: THERMAL FLIR RECONNAISSANCE
    // ═══════════════════════════════════════════════════════════
    Item {
        id: flirContainer
        anchors.fill: parent
        anchors.margins: 1
        visible: frame.isEffectVisible("thermal_flir", frame.showThermalFlir)
        clip: true
        z: frame.getEffectZ("thermal_flir", 8)

        ShaderEffectSource {
            id: flirSourceTexture
            anchors.fill: parent
            sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            sourceRect: {
                if (typeof root === "undefined" || !root.wallpaperImageItem) return Qt.rect(0, 0, 0, 0);
                var absPos = frame.mapToItem(root.wallpaperImageItem, 0, 0);
                return Qt.rect(absPos.x, absPos.y, frame.width, frame.height);
            }
            live: false
            hideSource: false
            smooth: false
        }

        ShaderEffect {
            anchors.fill: parent
            supportsAtlasTextures: true
            property var source: flirSourceTexture
            property var u_lutTex: flirLutImage
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(1.0, 0.0, 0, 0) // gain, invert
            property vector4d p1: Qt.vector4d(0, 0, 0, 0)
            property vector4d p2: Qt.vector4d(0, 0, 0, 0)
            property vector4d p3: Qt.vector4d(0, 0, 0, 0)
            property color c0: frame.accentColor
            property color c1: frame.highlightColor
            property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)
            fragmentShader: "shaders/thermal_flir.frag.qsb"
        }

        onVisibleChanged: { if (visible) flirSourceTexture.scheduleUpdate(); }
        Connections {
            target: frame
            function onWidthChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
            function onVisibleChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: frame.parent ? frame.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
            function onYChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
            function onWidthChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined") ? root : null
            ignoreUnknownSignals: true
            function onActiveEffectsStackChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
            function onBgImageChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            ignoreUnknownSignals: true
            function onStatusChanged() { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
        }
        Component.onCompleted: { if (flirContainer.visible) flirSourceTexture.scheduleUpdate(); }
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: HALFTONE DOT SCREEN
    // ═══════════════════════════════════════════════════════════
    Item {
        id: halftoneContainer
        anchors.fill: parent
        anchors.margins: 1
        visible: frame.isEffectVisible("halftone", frame.showHalftone)
        clip: true
        z: frame.getEffectZ("halftone", 9)

        ShaderEffectSource {
            id: halftoneSourceTexture
            anchors.fill: parent
            sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            sourceRect: {
                if (typeof root === "undefined" || !root.wallpaperImageItem) return Qt.rect(0, 0, 0, 0);
                var absPos = frame.mapToItem(root.wallpaperImageItem, 0, 0);
                return Qt.rect(absPos.x, absPos.y, frame.width, frame.height);
            }
            live: false
            hideSource: false
            smooth: false
        }

        ShaderEffect {
            anchors.fill: parent
            supportsAtlasTextures: true
            property var source: halftoneSourceTexture
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(8.0, 0.6, 0, 0) // cellSize, bgDarken
            property vector4d p1: Qt.vector4d(0, 0, 0, 0)
            property vector4d p2: Qt.vector4d(0, 0, 0, 0)
            property vector4d p3: Qt.vector4d(0, 0, 0, 0)
            property color c0: frame.accentColor
            property color c1: frame.highlightColor
            property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)
            fragmentShader: "shaders/halftone.frag.qsb"
        }

        onVisibleChanged: { if (visible) halftoneSourceTexture.scheduleUpdate(); }
        Connections {
            target: frame
            function onWidthChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
            function onVisibleChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: frame.parent ? frame.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
            function onYChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
            function onWidthChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined") ? root : null
            ignoreUnknownSignals: true
            function onActiveEffectsStackChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
            function onBgImageChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            ignoreUnknownSignals: true
            function onStatusChanged() { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
        }
        Component.onCompleted: { if (halftoneContainer.visible) halftoneSourceTexture.scheduleUpdate(); }
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: DUOTONE ATMOSPHERE
    // ═══════════════════════════════════════════════════════════
    Item {
        id: duotoneContainer
        anchors.fill: parent
        anchors.margins: 1
        visible: frame.isEffectVisible("duotone", frame.showDuotone)
        clip: true
        z: frame.getEffectZ("duotone", 10)

        ShaderEffectSource {
            id: duotoneSourceTexture
            anchors.fill: parent
            sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            sourceRect: {
                if (typeof root === "undefined" || !root.wallpaperImageItem) return Qt.rect(0, 0, 0, 0);
                var absPos = frame.mapToItem(root.wallpaperImageItem, 0, 0);
                return Qt.rect(absPos.x, absPos.y, frame.width, frame.height);
            }
            live: false
            hideSource: false
            smooth: false
        }

        ShaderEffect {
            anchors.fill: parent
            supportsAtlasTextures: true
            property var source: duotoneSourceTexture
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(1.0, 0, 0, 0)
            property vector4d p1: Qt.vector4d(0, 0, 0, 0)
            property vector4d p2: Qt.vector4d(0, 0, 0, 0)
            property vector4d p3: Qt.vector4d(0, 0, 0, 0)
            property color c0: frame.highlightColor
            property color c1: frame.accentColor
            property color c2: Qt.rgba(8/255, 9/255, 13/255, 1.0)
            opacity: 0.65
            fragmentShader: "shaders/duotone.frag.qsb"
        }

        onVisibleChanged: { if (visible) duotoneSourceTexture.scheduleUpdate(); }
        Connections {
            target: frame
            function onWidthChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
            function onVisibleChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: frame.parent ? frame.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
            function onYChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
            function onWidthChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined") ? root : null
            ignoreUnknownSignals: true
            function onActiveEffectsStackChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
            function onBgImageChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            ignoreUnknownSignals: true
            function onStatusChanged() { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
        }
        Component.onCompleted: { if (duotoneContainer.visible) duotoneSourceTexture.scheduleUpdate(); }
    }

    // ═══════════════════════════════════════════════════════════
    //  MICRO-STYLE: SANDBLASTED DITHER FROST
    // ═══════════════════════════════════════════════════════════
    Item {
        id: ditherContainer
        anchors.fill: parent
        anchors.margins: 1
        visible: frame.isEffectVisible("dither_frost", frame.showDitherFrost)
        clip: true
        z: frame.getEffectZ("dither_frost", 11)

        ShaderEffectSource {
            id: ditherSourceTexture
            anchors.fill: parent
            sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            sourceRect: {
                if (typeof root === "undefined" || !root.wallpaperImageItem) return Qt.rect(0, 0, 0, 0);
                var absPos = frame.mapToItem(root.wallpaperImageItem, 0, 0);
                return Qt.rect(absPos.x, absPos.y, frame.width, frame.height);
            }
            live: false
            hideSource: false
            smooth: false
        }

        ShaderEffect {
            anchors.fill: parent
            supportsAtlasTextures: true
            property var source: ditherSourceTexture
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(8.0, 0.4, 0, 0)
            property vector4d p1: Qt.vector4d(0, 0, 0, 0)
            property vector4d p2: Qt.vector4d(0, 0, 0, 0)
            property vector4d p3: Qt.vector4d(0, 0, 0, 0)
            property color c0: frame.accentColor
            property color c1: frame.highlightColor
            property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)
            opacity: 0.85
            fragmentShader: "shaders/dither_frost.frag.qsb"
        }

        onVisibleChanged: { if (visible) ditherSourceTexture.scheduleUpdate(); }
        Connections {
            target: frame
            function onWidthChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
            function onVisibleChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: frame.parent ? frame.parent : null
            ignoreUnknownSignals: true
            function onXChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
            function onYChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
            function onWidthChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
            function onHeightChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined") ? root : null
            ignoreUnknownSignals: true
            function onActiveEffectsStackChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
            function onBgImageChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
        }
        Connections {
            target: (typeof root !== "undefined" && root.wallpaperImageItem) ? root.wallpaperImageItem : null
            ignoreUnknownSignals: true
            function onStatusChanged() { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
        }
        Component.onCompleted: { if (ditherContainer.visible) ditherSourceTexture.scheduleUpdate(); }
    }
}