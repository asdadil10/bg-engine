/*
 * NerveShaderLayer.qml  —  NerveCenter universal shader layer wrapper
 *
 * STATUS: NOT WIRED INTO THE SHIPPED WALLPAPER.
 *   Only `NerveCompositor.qml` (itself unused) would use this wrapper. The live
 *   wallpaper draws its own ShaderEffect blocks in `NerveFrame.qml` as ordered
 *   backdrop overlays; there is no chained pass between them.
 *
 * Every shader in the registry plugs into this component regardless of its
 * internal formula.  The standardized UBO (p0..p3, c0..c2, u_resolution,
 * u_texelSize) is wired from QML properties, so the compositor only needs to
 * change a handful of property values to reconfigure any layer.
 *
 * Usage:
 *   NerveShaderLayer {
 *       id: myLayer
 *       shaderSource: "shaders/lidar_sobel.frag.qsb"
 *       inputSource:  someShaderEffectSource
 *       p0: Qt.vector4d(1.5, 0.18, 1.0, 0.5)   // preBlur, threshold, thickness, bgDarken
 *       c0: root.accentColor
 *   }
 *   // myLayer.outputSource is a ShaderEffectSource with live:false
 *   // pointing at this ShaderEffect, ready to pipe into the next layer.
 */

import QtQuick

Item {
    id: layerWrapper
    anchors.fill: parent

    // ── Identity ────────────────────────────────────────────────────────────
    property string effectId:     ""
    property string shaderSource: ""           // path to .frag.qsb

    // ── Blend configuration (used by blend.frag, not this shader itself) ────
    property int  blendMode:    0              // 0:Normal 1:Add 2:Screen 3:Multiply 4:Overlay
    property real layerOpacity: 1.0

    // ── Standardized uniform slots ───────────────────────────────────────────
    property vector4d p0: Qt.vector4d(0, 0, 0, 0)
    property vector4d p1: Qt.vector4d(0, 0, 0, 0)
    property vector4d p2: Qt.vector4d(0, 0, 0, 0)
    property vector4d p3: Qt.vector4d(0, 0, 0, 0)

    // Colour convention (matches registry + shader comments):
    //   c0 = Primary Accent  (cyan, edge colour, dot colour …)
    //   c1 = Highlight       (magenta, contour colour …)
    //   c2 = Void / Shadow   (navy, background tint …)
    property color c0: Qt.rgba(0.0, 0.94, 1.0, 1.0)
    property color c1: Qt.rgba(1.0, 0.0,  0.5, 1.0)
    property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)

    // ── Input / Output ────────────────────────────────────────────────────────
    property var inputSource: null      // ShaderEffectSource or another layer's outputSource
    property var lutTexture:  null      // optional 256×1 LUT image (thermal, duotone)
    property var atlasTexture: null     // optional glyph atlas (ascii)

    // Expose output for ping-pong chaining
    readonly property alias outputSource: layerEffectSource

    // ── Core ShaderEffect ───────────────────────────────────────────────────
    ShaderEffect {
        id: layerEffect
        anchors.fill: parent
        supportsAtlasTextures: true
        visible: true

        // binding 1: wallpaper or previous layer
        property var source: layerWrapper.inputSource

        // binding 2: LUT texture OR ascii atlas (only one can occupy slot 2;
        //            ascii shader names it 'asciiAtlas', others name it 'u_lutTex'
        //            — both bind to location 2 so they are interchangeable here)
        property var u_lutTex:    layerWrapper.lutTexture
        property var asciiAtlas:  layerWrapper.atlasTexture

        // Standard UBO fields
        property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property vector2d u_texelSize:  Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))

        property vector4d p0: layerWrapper.p0
        property vector4d p1: layerWrapper.p1
        property vector4d p2: layerWrapper.p2
        property vector4d p3: layerWrapper.p3

        property color c0: layerWrapper.c0
        property color c1: layerWrapper.c1
        property color c2: layerWrapper.c2

        fragmentShader: layerWrapper.shaderSource
    }

    // ── Frozen output snapshot (live:false = zero idle GPU) ────────────────
    ShaderEffectSource {
        id: layerEffectSource
        anchors.fill: parent
        sourceItem: layerEffect
        live: false          // freeze: re-bake only on explicit scheduleUpdate()
        hideSource: true
    }
}
