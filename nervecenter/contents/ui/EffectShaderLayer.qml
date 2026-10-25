/*
 * EffectShaderLayer.qml  —  Shared shader-backed backdrop overlay
 *
 * One instance per shader effect in NerveFrame's effect model. The wrapper
 * that owns this item is responsible for visibility and z-order; this item
 * only owns the wallpaper sample, the shader, and the refresh plumbing that
 * used to be copied into every effect block.
 *
 * Every effect samples the original wallpaper crop (not the previous effect's
 * output), so these layers alpha-composite in activation order rather than
 * forming a chained pipeline.
 */

import QtQuick

Item {
    id: layer

    // Frame that hosts this layer. Used for coordinate mapping only.
    property var host: null

    property string shaderFile: ""
    property int sourceMargins: 1
    property real effectOpacity: 1.0

    property vector4d p0: Qt.vector4d(0, 0, 0, 0)
    property vector4d p1: Qt.vector4d(0, 0, 0, 0)
    property vector4d p2: Qt.vector4d(0, 0, 0, 0)
    property vector4d p3: Qt.vector4d(0, 0, 0, 0)

    property color accentColor: "#00f0ff"
    property color highlightColor: "#ff007f"

    // "default": c0 = accent, c1 = highlight
    // "ascii":   translucent accent/highlight pair
    // "duotone": c0 = highlight, c1 = accent, c2 = void
    property string colorMode: "default"

    // Optional auxiliary texture (ASCII atlas or FLIR LUT). Shaders that do
    // not declare these uniforms ignore them.
    property var extraTexture: null

    anchors.fill: parent
    anchors.margins: sourceMargins
    clip: true

    readonly property color c0: {
        switch (colorMode) {
            case "ascii":   return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.65)
            case "duotone": return highlightColor
            default:        return accentColor
        }
    }

    readonly property color c1: {
        switch (colorMode) {
            case "ascii":   return Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, 0.95)
            case "duotone": return accentColor
            default:        return highlightColor
        }
    }

    readonly property color c2: {
        switch (colorMode) {
            case "duotone": return Qt.rgba(8 / 255, 9 / 255, 13 / 255, 1.0)
            default:        return Qt.rgba(0.04, 0.05, 0.08, 1.0)
        }
    }

    function refresh() {
        if (visible)
            sourceTexture.scheduleUpdate()
    }

    ShaderEffectSource {
        id: sourceTexture
        anchors.fill: parent
        sourceItem: (typeof root !== "undefined" && root.wallpaperImageItem)
                    ? root.wallpaperImageItem : null
        sourceRect: {
            if (typeof root === "undefined" || !root.wallpaperImageItem || !layer.host)
                return Qt.rect(0, 0, 0, 0)
            var absPos = layer.host.mapToItem(root.wallpaperImageItem, 0, 0)
            return Qt.rect(absPos.x, absPos.y, layer.host.width, layer.host.height)
        }
        live: false
        hideSource: false
        smooth: false
    }

    ShaderEffect {
        anchors.fill: parent
        supportsAtlasTextures: true

        property var source: sourceTexture
        property var u_lutTex: layer.extraTexture
        property var asciiAtlas: layer.extraTexture
        property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
        property vector4d p0: layer.p0
        property vector4d p1: layer.p1
        property vector4d p2: layer.p2
        property vector4d p3: layer.p3
        property color c0: layer.c0
        property color c1: layer.c1
        property color c2: layer.c2

        opacity: layer.effectOpacity
        fragmentShader: layer.shaderFile
    }

    onVisibleChanged: refresh()
    Component.onCompleted: refresh()

    Connections {
        target: layer.host
        ignoreUnknownSignals: true
        function onWidthChanged() { layer.refresh() }
        function onHeightChanged() { layer.refresh() }
        function onVisibleChanged() { layer.refresh() }
    }

    Connections {
        target: (layer.host && layer.host.parent) ? layer.host.parent : null
        ignoreUnknownSignals: true
        function onXChanged() { layer.refresh() }
        function onYChanged() { layer.refresh() }
        function onWidthChanged() { layer.refresh() }
        function onHeightChanged() { layer.refresh() }
    }

    Connections {
        target: (typeof root !== "undefined") ? root : null
        ignoreUnknownSignals: true
        function onBgImageChanged() { layer.refresh() }
        function onBgImageOpacityChanged() { layer.refresh() }
        function onActiveEffectsStackChanged() { layer.refresh() }
    }

    Connections {
        target: (typeof root !== "undefined" && root.wallpaperImageItem)
                ? root.wallpaperImageItem : null
        ignoreUnknownSignals: true
        function onStatusChanged() { layer.refresh() }
    }
}
