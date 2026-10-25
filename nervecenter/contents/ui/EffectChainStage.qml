/*
 * EffectChainStage.qml  —  One link in the chained effect pipeline
 *
 * A stage either runs a shader against `inputTexture` or captures a static
 * Canvas/vector component. When the layer is translucent (or static), its
 * output is blended over the input with blend.frag; the result becomes the
 * next stage's input. The last stage's output texture is displayed.
 */

import QtQuick

Item {
    id: stage

    property var host: null
    property var effect: null
    property var inputTexture: null
    property bool isLast: false
    property color accentColor: "#00f0ff"
    property color highlightColor: "#ff007f"

    readonly property bool isStatic: effect !== null && effect !== undefined
                                     && effect.component !== undefined
    readonly property real layerOpacity: (effect && effect.opacity !== undefined)
                                         ? effect.opacity : 1.0
    readonly property bool needsBlend: isStatic || layerOpacity < 0.999

    // The texture this stage exposes to the next stage.
    readonly property var outputTexture: needsBlend ? blendOutput : shaderOutput
    // The raw layer output before the opacity blend.
    readonly property var layerOutput: isStatic ? staticOutput : shaderOutput

    readonly property color c0: {
        var mode = (effect && effect.colorMode !== undefined) ? effect.colorMode : "default"
        switch (mode) {
            case "ascii":   return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.65)
            case "duotone": return highlightColor
            default:        return accentColor
        }
    }

    readonly property color c1: {
        var mode = (effect && effect.colorMode !== undefined) ? effect.colorMode : "default"
        switch (mode) {
            case "ascii":   return Qt.rgba(highlightColor.r, highlightColor.g, highlightColor.b, 0.95)
            case "duotone": return accentColor
            default:        return highlightColor
        }
    }

    readonly property color c2: {
        var mode = (effect && effect.colorMode !== undefined) ? effect.colorMode : "default"
        switch (mode) {
            case "duotone": return Qt.rgba(8 / 255, 9 / 255, 13 / 255, 1.0)
            default:        return Qt.rgba(0.04, 0.05, 0.08, 1.0)
        }
    }

    function refresh() {
        if (shaderOutput) shaderOutput.scheduleUpdate()
        if (staticOutput) staticOutput.scheduleUpdate()
        if (blendOutput) blendOutput.scheduleUpdate()
        if (isStatic) staticRefreshTimer.restart()
    }

    // ── Shader stage ────────────────────────────────────────────────────────
    Loader {
        id: shaderLoader
        anchors.fill: parent
        active: !stage.isStatic
        sourceComponent: shaderComponent
    }

    Component {
        id: shaderComponent
        ShaderEffect {
            anchors.fill: parent
            supportsAtlasTextures: true

            property var source: stage.inputTexture
            property var u_lutTex: (stage.effect && stage.effect.extraTexture !== undefined)
                                   ? stage.effect.extraTexture : null
            property var asciiAtlas: (stage.effect && stage.effect.extraTexture !== undefined)
                                     ? stage.effect.extraTexture : null
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: (stage.effect && stage.effect.p0) ? stage.effect.p0 : Qt.vector4d(0, 0, 0, 0)
            property vector4d p1: Qt.vector4d(0, 0, 0, 0)
            property vector4d p2: Qt.vector4d(0, 0, 0, 0)
            property vector4d p3: Qt.vector4d(0, 0, 0, 0)
            property color c0: stage.c0
            property color c1: stage.c1
            property color c2: stage.c2

            fragmentShader: (stage.effect && stage.effect.shader) ? stage.effect.shader : ""
        }
    }

    ShaderEffectSource {
        id: shaderOutput
        anchors.fill: parent
        sourceItem: shaderLoader.item
        live: false
        hideSource: true
        visible: stage.isLast && !stage.needsBlend
        format: ShaderEffectSource.RGBA16F
    }

    // ── Static Canvas/vector stage ──────────────────────────────────────────
    Loader {
        id: staticLoader
        anchors.fill: parent
        active: stage.isStatic
        sourceComponent: stage.isStatic ? stage.effect.component : null
        onLoaded: {
            stage.connectCanvases(item)
            stage.refresh()
        }
    }

    ShaderEffectSource {
        id: staticOutput
        anchors.fill: parent
        sourceItem: staticLoader.item
        live: false
        hideSource: true
        visible: false
        format: ShaderEffectSource.RGBA16F
    }

    Timer {
        id: staticRefreshTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (staticOutput) staticOutput.scheduleUpdate()
        }
    }

    function connectCanvases(item) {
        if (!item) return
        try {
            if (item.painted !== undefined && item.painted !== null)
                item.painted.connect(stage.refresh)
        } catch (e) {
            // Not a Canvas; ignore.
        }
        for (var i = 0; i < item.children.length; i++)
            connectCanvases(item.children[i])
    }

    // ── Opacity / static composite ──────────────────────────────────────────
    Loader {
        id: blendLoader
        anchors.fill: parent
        active: stage.needsBlend
        sourceComponent: blendComponent
    }

    Component {
        id: blendComponent
        ShaderEffect {
            anchors.fill: parent

            property var u_baseTex: stage.inputTexture
            property var u_layerTex: stage.layerOutput
            property vector2d u_resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
            property vector2d u_texelSize: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property vector4d p0: Qt.vector4d(0.0, stage.layerOpacity, 0.0, 0.0)
            property vector4d p1: Qt.vector4d(0, 0, 0, 0)
            property vector4d p2: Qt.vector4d(0, 0, 0, 0)
            property vector4d p3: Qt.vector4d(0, 0, 0, 0)
            property color c0: stage.accentColor
            property color c1: stage.highlightColor
            property color c2: Qt.rgba(0.04, 0.05, 0.08, 1.0)

            fragmentShader: "shaders/blend.frag.qsb"
        }
    }

    ShaderEffectSource {
        id: blendOutput
        anchors.fill: parent
        sourceItem: blendLoader.item
        live: false
        hideSource: true
        visible: stage.isLast && stage.needsBlend
        format: ShaderEffectSource.RGBA16F
    }

    Component.onCompleted: refresh()
    onEffectChanged: refresh()
    onInputTextureChanged: refresh()
    onWidthChanged: refresh()
    onHeightChanged: refresh()
    onAccentColorChanged: refresh()
    onHighlightColorChanged: refresh()

    Connections {
        target: (typeof root !== "undefined") ? root : null
        ignoreUnknownSignals: true
        function onBgColorChanged() { stage.refresh() }
    }
}
