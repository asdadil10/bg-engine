/*
 * EffectChain.qml  —  Ordered multi-pass effect chain
 *
 * Each active effect is rendered in activation order into a single texture
 * chain: stage N samples stage N-1's output instead of the original wallpaper.
 * Static Canvas/vector effects are captured into a texture and blended into
 * the chain, so they participate in the same order as shader effects.
 *
 * The chain is only used when chained mode is enabled, a wallpaper is ready,
 * and at least one shader effect is active. Otherwise NerveFrame falls back to
 * the independent ordered-overlay path.
 */

import QtQuick

Item {
    id: chain

    property var host: null
    property var model: []
    property var wallpaperItem: null
    property color accentColor: "#00f0ff"
    property color highlightColor: "#ff007f"

    readonly property int stageCount: model ? model.length : 0

    // Wallpaper crop under this panel. Kept as explicit state (rather than a
    // sourceRect binding) so a panel move reliably re-samples the new region.
    property rect cropRect: Qt.rect(0, 0, 0, 0)

    function stageAt(index) {
        return stageRepeater.itemAt(index)
    }

    function updateCropRect() {
        if (!wallpaperItem || !host) {
            cropRect = Qt.rect(0, 0, 0, 0)
            return
        }
        var absPos = host.mapToItem(wallpaperItem, 0, 0)
        cropRect = Qt.rect(absPos.x, absPos.y, host.width, host.height)
    }

    // Re-render the base sample and every stage in order. All sources are
    // live:false, so this is the only thing that makes the chain refresh.
    // Hidden chains do no work; becoming visible triggers a full refresh.
    function refreshChain() {
        updateCropRect()
        if (!visible) return
        baseSource.scheduleUpdate()
        for (var i = 0; i < stageRepeater.count; i++) {
            var stage = stageRepeater.itemAt(i)
            if (stage) stage.refresh()
        }
    }

    // The first stage samples the wallpaper crop under this panel.
    ShaderEffectSource {
        id: baseSource
        anchors.fill: parent
        sourceItem: chain.wallpaperItem
        sourceRect: chain.cropRect
        live: false
        // The wallpaper item is also the visible desktop background, so it must
        // not be hidden the way the intermediate stage sources are.
        hideSource: false
        visible: false
        format: ShaderEffectSource.RGBA8
    }

    Repeater {
        id: stageRepeater
        model: chain.model
        delegate: EffectChainStage {
            required property int index
            required property var modelData
            anchors.fill: parent
            host: chain.host
            effect: modelData
            inputTexture: index === 0
                          ? baseSource
                          : (stageRepeater.itemAt(index - 1)
                             ? stageRepeater.itemAt(index - 1).outputTexture
                             : null)
            isLast: index === chain.stageCount - 1
            accentColor: chain.accentColor
            highlightColor: chain.highlightColor
        }
    }

    Component.onCompleted: refreshChain()
    onModelChanged: refreshChain()
    onWidthChanged: refreshChain()
    onHeightChanged: refreshChain()
    onVisibleChanged: if (visible) refreshChain()

    Connections {
        target: chain.host
        ignoreUnknownSignals: true
        function onXChanged() { chain.refreshChain() }
        function onYChanged() { chain.refreshChain() }
        function onWidthChanged() { chain.refreshChain() }
        function onHeightChanged() { chain.refreshChain() }
        function onAccentColorChanged() { chain.refreshChain() }
        function onHighlightColorChanged() { chain.refreshChain() }
    }

    // The frame is laid out by its parent; moving the panel moves this item's
    // parent, not the frame itself.
    Connections {
        target: (chain.host && chain.host.parent) ? chain.host.parent : null
        ignoreUnknownSignals: true
        function onXChanged() { chain.refreshChain() }
        function onYChanged() { chain.refreshChain() }
        function onWidthChanged() { chain.refreshChain() }
        function onHeightChanged() { chain.refreshChain() }
    }

    Connections {
        target: (typeof root !== "undefined") ? root : null
        ignoreUnknownSignals: true
        function onBgImageChanged() { chain.refreshChain() }
        function onBgImageOpacityChanged() { chain.refreshChain() }
        function onActiveEffectsStackChanged() { chain.refreshChain() }
        function onEffectChainedChanged() { chain.refreshChain() }
    }

    Connections {
        target: chain.wallpaperItem
        ignoreUnknownSignals: true
        function onStatusChanged() { chain.refreshChain() }
    }
}
