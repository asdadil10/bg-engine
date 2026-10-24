/*
 * NerveCompositor.qml  —  NerveCenter Multi-Pass Ping-Pong Shader Compositor (v3)
 *
 * Architecture:
 *   - Two distinct blend effects (blendEffectA and blendEffectB) eliminating recursive FBO warnings.
 *   - Base source in RGBA8; intermediate ping-pong buffers in RGBA16F to prevent inter-pass banding.
 *   - Explicit textureSize matching bakeWidth/bakeHeight.
 *   - Live preview mode (live: true) for 60fps real-time Studio editing;
 *     drops back to live: false for 0.0% idle GPU footprint.
 *   - Layer configuration extracts real parameters (p0..p3, c0..c2) from layer definition.
 *   - Frame-barrier sequencing via window.frameSwapped for reliable offline grabs.
 */

import QtQuick

Item {
    id: compositor
    width: 1920
    height: 1080

    // Baking resolution
    property int bakeWidth:  1920
    property int bakeHeight: 1080

    // Configuration
    property var inputSourceItem: null
    property string wallpaperPath: ""
    property var activeStack: []       // Array of layer objects: { uid, type, mode, opacity, visible, p0, p1, p2, p3, c0, c1, c2 }
    property string targetCachePath: ""
    property bool isBaking: false
    property bool live: false          // Set to true while editing in Studio; false on desktop idle

    signal bakeFinished(string cachePath)
    signal bakeFailed(string reason)

    // Palette defaults
    property color defaultAccent:    "#00f0ff"
    property color defaultHighlight: "#ff007f"
    property color defaultVoid:      "#0a0c12"

    // Optional shared LUT textures
    Image {
        id: flirLutImage
        source: "assets/flir_ironbow_lut.png"
        visible: false
    }

    Image {
        id: asciiAtlasImage
        source: "assets/ascii_atlas.png"
        visible: false
    }

    // Dynamic 256x1 Duotone Gradient Canvas
    Canvas {
        id: duotoneLutCanvas
        width: 256
        height: 1
        visible: false
        onPaint: {
            var ctx = getContext("2d");
            var grad = ctx.createLinearGradient(0, 0, 256, 0);
            grad.addColorStop(0.0, compositor.defaultVoid);
            grad.addColorStop(0.5, compositor.defaultAccent);
            grad.addColorStop(1.0, compositor.defaultHighlight);
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, 256, 1);
        }
        Component.onCompleted: requestPaint()
    }

    // ── Input Wallpaper Capture (RGBA8) ───────────────────────────────────────
    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: compositor.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: false
    }

    ShaderEffectSource {
        id: baseSource
        anchors.fill: parent
        sourceItem: compositor.inputSourceItem ? compositor.inputSourceItem : wallpaperImage
        textureSize: Qt.size(compositor.bakeWidth, compositor.bakeHeight)
        format: ShaderEffectSource.RGBA8
        live: compositor.live
        hideSource: true
        visible: false
    }

    // ── Current Layer Effect Renderer ────────────────────────────────────────
    NerveShaderLayer {
        id: currentLayer
        anchors.fill: parent
        visible: false
    }

    // ── Two Dedicated Blend Effects (Avoids Recursive Warnings) ──────────────
    // blendEffectA: takes u_baseTex = (pass 0 ? baseSource : bufferB), outputs into bufferA
    ShaderEffect {
        id: blendEffectA
        anchors.fill: parent
        visible: false

        property var u_baseTex:  baseSource
        property var u_layerTex: currentLayer.outputSource

        property vector2d u_resolution: Qt.vector2d(compositor.bakeWidth, compositor.bakeHeight)
        property vector2d u_texelSize:  Qt.vector2d(1.0 / compositor.bakeWidth, 1.0 / compositor.bakeHeight)

        property vector4d p0: Qt.vector4d(0.0, 1.0, 0.0, 0.0) // mode, opacity
        property vector4d p1: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d p2: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d p3: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property color c0: compositor.defaultAccent
        property color c1: compositor.defaultHighlight
        property color c2: compositor.defaultVoid

        fragmentShader: "shaders/blend.frag.qsb"
    }

    // blendEffectB: takes u_baseTex = bufferA, outputs into bufferB
    ShaderEffect {
        id: blendEffectB
        anchors.fill: parent
        visible: false

        property var u_baseTex:  bufferA
        property var u_layerTex: currentLayer.outputSource

        property vector2d u_resolution: Qt.vector2d(compositor.bakeWidth, compositor.bakeHeight)
        property vector2d u_texelSize:  Qt.vector2d(1.0 / compositor.bakeWidth, 1.0 / compositor.bakeHeight)

        property vector4d p0: Qt.vector4d(0.0, 1.0, 0.0, 0.0) // mode, opacity
        property vector4d p1: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d p2: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d p3: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property color c0: compositor.defaultAccent
        property color c1: compositor.defaultHighlight
        property color c2: compositor.defaultVoid

        fragmentShader: "shaders/blend.frag.qsb"
    }

    // ── Ping-Pong Buffers (RGBA16F to prevent inter-pass banding) ───────────
    ShaderEffectSource {
        id: bufferA
        anchors.fill: parent
        sourceItem: blendEffectA
        textureSize: Qt.size(compositor.bakeWidth, compositor.bakeHeight)
        format: ShaderEffectSource.RGBA16F
        live: compositor.live
        hideSource: true
        visible: false
    }

    ShaderEffectSource {
        id: bufferB
        anchors.fill: parent
        sourceItem: blendEffectB
        textureSize: Qt.size(compositor.bakeWidth, compositor.bakeHeight)
        format: ShaderEffectSource.RGBA16F
        live: compositor.live
        hideSource: true
        visible: false
    }

    // ── Mandatory Final Triangular Dither Quantization Stage (RGBA8) ────────
    ShaderEffect {
        id: finalDitherEffect
        anchors.fill: parent
        visible: false

        property var source: bufferA

        property vector2d u_resolution: Qt.vector2d(compositor.bakeWidth, compositor.bakeHeight)
        property vector2d u_texelSize:  Qt.vector2d(1.0 / compositor.bakeWidth, 1.0 / compositor.bakeHeight)

        property vector4d p0: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d p1: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d p2: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d p3: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property color c0: "transparent"
        property color c1: "transparent"
        property color c2: "transparent"

        fragmentShader: "shaders/dither_quantize.frag.qsb"
    }

    ShaderEffectSource {
        id: finalOutputSource
        anchors.fill: parent
        sourceItem: finalDitherEffect
        textureSize: Qt.size(compositor.bakeWidth, compositor.bakeHeight)
        format: ShaderEffectSource.RGBA8
        live: compositor.live
        hideSource: false
        visible: true
    }

    // Expose final texture output item for UI display
    readonly property var outputItem: finalOutputSource

    // ── Bake Execution Controller ───────────────────────────────────────────
    property var stackSnapshot: []
    property int currentPassIndex: 0
    property bool writeToBufferA: true

    function afterNextFrame(callback) {
        var win = compositor.Window.window;
        if (win && win.frameSwapped) {
            var handler = function() {
                win.frameSwapped.disconnect(handler);
                callback();
            };
            win.frameSwapped.connect(handler);
        } else {
            // Fallback for headless environments without window
            frameTimer.callback = callback;
            frameTimer.restart();
        }
    }

    Timer {
        id: frameTimer
        interval: 16
        repeat: false
        property var callback: null
        onTriggered: {
            if (callback) callback();
        }
    }

    function startBake() {
        if (isBaking) return;

        // Snapshot stack so edits mid-bake don't corrupt it
        try {
            stackSnapshot = JSON.parse(JSON.stringify(activeStack));
        } catch (e) {
            stackSnapshot = [];
        }

        isBaking = true;
        currentPassIndex = 0;
        writeToBufferA = true;

        baseSource.scheduleUpdate();
        duotoneLutCanvas.requestPaint();

        afterNextFrame(function() {
            stepPass();
        });
    }

    function stepPass() {
        if (currentPassIndex >= stackSnapshot.length) {
            finishBake();
            return;
        }

        var layerDef = stackSnapshot[currentPassIndex];
        if (!layerDef || layerDef.visible === false) {
            // Skip disabled layer
            currentPassIndex++;
            stepPass();
            return;
        }

        var configured = configureLayer(layerDef);
        if (!configured) {
            // Unknown shader type -> skip pass safely
            currentPassIndex++;
            stepPass();
            return;
        }

        currentLayer.outputSource.scheduleUpdate();

        afterNextFrame(function() {
            var mode = (layerDef.mode !== undefined) ? layerDef.mode : 0.0;
            var opacity = (layerDef.opacity !== undefined) ? layerDef.opacity : 1.0;
            var p0_blend = Qt.vector4d(mode, opacity, 0.0, 0.0);

            if (writeToBufferA) {
                blendEffectA.u_baseTex = (currentPassIndex === 0) ? baseSource : bufferB;
                blendEffectA.u_layerTex = currentLayer.outputSource;
                blendEffectA.p0 = p0_blend;
                bufferA.scheduleUpdate();
            } else {
                blendEffectB.u_baseTex = bufferA;
                blendEffectB.u_layerTex = currentLayer.outputSource;
                blendEffectB.p0 = p0_blend;
                bufferB.scheduleUpdate();
            }

            writeToBufferA = !writeToBufferA;
            currentPassIndex++;

            afterNextFrame(function() {
                stepPass();
            });
        });
    }

    function finishBake() {
        var lastBuffer = (currentPassIndex === 0) ? baseSource : (!writeToBufferA ? bufferA : bufferB);
        finalDitherEffect.source = lastBuffer;
        finalOutputSource.scheduleUpdate();

        afterNextFrame(function() {
            if (targetCachePath !== "") {
                finalOutputSource.grabToImage(function(result) {
                    if (result.saveToFile(compositor.targetCachePath)) {
                        compositor.isBaking = false;
                        compositor.bakeFinished(compositor.targetCachePath);
                    } else {
                        compositor.isBaking = false;
                        compositor.bakeFailed("Failed to save bake to: " + compositor.targetCachePath);
                    }
                });
            } else {
                compositor.isBaking = false;
                compositor.bakeFinished("");
            }
        });
    }

    function configureLayer(def) {
        var type = def.type || def.id;
        if (!type) return false;

        currentLayer.effectId = type;
        currentLayer.lutTexture = null;
        currentLayer.atlasTexture = null;

        // Apply parameters directly from def, or use sensible defaults
        currentLayer.p0 = def.p0 ? def.p0 : Qt.vector4d(0, 0, 0, 0);
        currentLayer.p1 = def.p1 ? def.p1 : Qt.vector4d(0, 0, 0, 0);
        currentLayer.p2 = def.p2 ? def.p2 : Qt.vector4d(0, 0, 0, 0);
        currentLayer.p3 = def.p3 ? def.p3 : Qt.vector4d(0, 0, 0, 0);

        currentLayer.c0 = def.c0 ? def.c0 : compositor.defaultAccent;
        currentLayer.c1 = def.c1 ? def.c1 : compositor.defaultHighlight;
        currentLayer.c2 = def.c2 ? def.c2 : compositor.defaultVoid;

        if (type === "prism_blur") {
            currentLayer.shaderSource = "shaders/prism_blur.frag.qsb";
            if (!def.p0) currentLayer.p0 = Qt.vector4d(18.0, 4.5, 0.0, 0.0);
        } else if (type === "anamorphic_streak") {
            currentLayer.shaderSource = "shaders/streak_comp.frag.qsb";
            if (!def.p0) currentLayer.p0 = Qt.vector4d(0.82, 24.0, 2.5, 0.0);
        } else if (type === "dither_frost") {
            currentLayer.shaderSource = "shaders/dither_frost.frag.qsb";
            if (!def.p0) currentLayer.p0 = Qt.vector4d(8.0, 0.4, 0.0, 0.0);
        } else if (type === "duotone") {
            currentLayer.shaderSource = "shaders/duotone.frag.qsb";
            currentLayer.lutTexture = duotoneLutCanvas;
            if (!def.p0) currentLayer.p0 = Qt.vector4d(1.0, 0.0, 0.0, 0.0);
        } else if (type === "lidar_sobel") {
            currentLayer.shaderSource = "shaders/lidar_sobel.frag.qsb";
            if (!def.p0) currentLayer.p0 = Qt.vector4d(1.5, 0.18, 1.0, 0.5);
        } else if (type === "thermal_flir") {
            currentLayer.shaderSource = "shaders/thermal_flir.frag.qsb";
            currentLayer.lutTexture = flirLutImage;
            if (!def.p0) currentLayer.p0 = Qt.vector4d(1.0, 0.0, 0.0, 0.0);
        } else if (type === "halftone") {
            currentLayer.shaderSource = "shaders/halftone.frag.qsb";
            if (!def.p0) currentLayer.p0 = Qt.vector4d(8.0, 0.6, 0.0, 0.0);
        } else if (type === "ascii") {
            currentLayer.shaderSource = "shaders/ascii.frag.qsb";
            currentLayer.atlasTexture = asciiAtlasImage;
            if (!def.p0) currentLayer.p0 = Qt.vector4d(8.0, 12.0, 0.0, 0.0);
        } else if (type === "tiltshift") {
            currentLayer.shaderSource = "shaders/tiltshift.frag.qsb";
            if (!def.p0) currentLayer.p0 = Qt.vector4d(0.25, 0.6, 8.0, 1.5);
        } else {
            return false;
        }

        return true;
    }
}
