/*
 *  NerveCenter — main.qml
 *  Main wallpaper canvas — highly optimized cyberpunk telemetry HUD.
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import QtQuick.Dialogs

WallpaperItem {
    id: root

    property color bgColor:          layoutSettings.themeBgColor !== "" ? layoutSettings.themeBgColor : root.configuration.BackgroundColor
    property color accentColor:      layoutSettings.themeAccentColor !== "" ? layoutSettings.themeAccentColor : root.configuration.AccentColor
    property color highlightColor:   layoutSettings.themeHighlightColor !== "" ? layoutSettings.themeHighlightColor : root.configuration.HighlightColor
    property real  gridOpacity:      layoutSettings.gridOpacity !== -1 ? layoutSettings.gridOpacity : root.configuration.GridOpacity
    readonly property string bgImage:         layoutSettings.bgImageOverride !== "" ? layoutSettings.bgImageOverride : root.configuration.BackgroundImage
    property real   bgImageOpacity:  layoutSettings.bgImageOpacity !== -1 ? layoutSettings.bgImageOpacity : root.configuration.BackgroundImageOpacity
    property real   hudOpacity:      layoutSettings.hudOpacity !== -1 ? layoutSettings.hudOpacity : root.configuration.HudOpacity
    readonly property int    shortcutIconPadding: root.configuration.ShortcutIconPadding || 16
    readonly property int    shortcutIconSize: root.configuration.ShortcutIconSize || 48
    readonly property string shortcutsJson:   root.configuration.ShortcutsJson || "[]"
    property bool editMode: layoutSettings.editMode
    // layoutSettings.editMode is initialized from config in Component.onCompleted below
    property var wallpaperImageItem: bgImageItem
    property var wallpaperCanvas: canvas
    readonly property string globalFontFamily: layoutSettings.fontFamilyOverride !== "" ? layoutSettings.fontFamilyOverride : (root.configuration.FontFamily || "monospace")
    readonly property real   globalFontScale:  layoutSettings.fontScaleOverride !== -1 ? layoutSettings.fontScaleOverride : (root.configuration.FontScale || 1.0)

    property var layoutState: {
        try {
            return JSON.parse(layoutSettings.panelsLayoutJson || "{}")
        } catch (e) {
            return {}
        }
    }

    function saveLayoutState() {
        layoutSettings.panelsLayoutJson = JSON.stringify(layoutState)
        // Also sync to configuration so it persists via Plasma's Apply button
        if (root.configuration.PanelsLayoutJson !== undefined) {
            root.configuration.PanelsLayoutJson = layoutSettings.panelsLayoutJson
        }
    }

    // Dynamic Chronological Stacking Order for Micro-Style Effects
    property var activeEffectsStack: []

    function isEffectActive(key) {
        return activeEffectsStack.indexOf(key) >= 0;
    }

    function getEffectLayer(key) {
        var idx = activeEffectsStack.indexOf(key);
        return idx >= 0 ? (idx + 1) : 0;
    }

    function toggleEffect(key) {
        var copy = [];
        var found = false;
        for (var i = 0; i < activeEffectsStack.length; i++) {
            if (activeEffectsStack[i] === key) {
                found = true;
            } else {
                copy.push(activeEffectsStack[i]);
            }
        }
        if (!found) {
            copy.push(key);
        }
        activeEffectsStack = copy;
        syncEffectsToConfig();
    }

    function syncEffectFromConfig(key, active) {
        var copy = [];
        var found = false;
        for (var i = 0; i < activeEffectsStack.length; i++) {
            if (activeEffectsStack[i] === key) {
                if (active) copy.push(key);
                found = true;
            } else {
                copy.push(activeEffectsStack[i]);
            }
        }
        if (active && !found) {
            copy.push(key);
        }
        activeEffectsStack = copy;
    }

    function syncEffectsToConfig() {
        layoutSettings.effectHologram = isEffectActive("hologram");
        layoutSettings.effectVignette = isEffectActive("vignette");
        layoutSettings.effectCircuit = isEffectActive("circuit");
        layoutSettings.effectPrismBlur = isEffectActive("prism_blur");
        layoutSettings.effectScanlines = isEffectActive("scanlines");
        layoutSettings.effectAscii = isEffectActive("ascii");
        layoutSettings.effectLidarSobel = isEffectActive("lidar_sobel");
        layoutSettings.effectThermalFlir = isEffectActive("thermal_flir");
        layoutSettings.effectHalftone = isEffectActive("halftone");
        layoutSettings.effectDuotone = isEffectActive("duotone");
        layoutSettings.effectDitherFrost = isEffectActive("dither_frost");
        layoutSettings.effectsStackJson = JSON.stringify(activeEffectsStack);

        if (root.configuration.EffectsStackJson !== undefined) {
            root.configuration.EffectsStackJson = layoutSettings.effectsStackJson;
        }
    }

    Settings {
        id: panelsVisibilitySettings
        category: "PanelsVisibility"
        property bool showMainTerminal: true
        property bool showLeftMediaPanel: true
        property bool showLeftSensorPanel: true
        property bool showLeftBookmarkBar: true
        property bool showRightNotesPanel: true
        property bool showRightNetworkPanel: true
        property bool showRightControlsPanel: true
        property bool showTodoPanel: false
        property bool showGitGridPanel: false
        property bool hasSavedState: false
    }

    function setPanelVisible(panelKey, isVisible) {
        if (panelKey === "MainTerminal") layoutSettings.showMainTerminal = isVisible
        else if (panelKey === "LeftMediaPanel") layoutSettings.showLeftMediaPanel = isVisible
        else if (panelKey === "LeftSensorPanel") layoutSettings.showLeftSensorPanel = isVisible
        else if (panelKey === "LeftBookmarkBar") layoutSettings.showLeftBookmarkBar = isVisible
        else if (panelKey === "RightNotesPanel") layoutSettings.showRightNotesPanel = isVisible
        else if (panelKey === "RightNetworkPanel") layoutSettings.showRightNetworkPanel = isVisible
        else if (panelKey === "RightControlsPanel") layoutSettings.showRightControlsPanel = isVisible
        else if (panelKey === "TodoPanel") layoutSettings.showTodoPanel = isVisible
        else if (panelKey === "GitGridPanel") layoutSettings.showGitGridPanel = isVisible

        if (panelKey === "MainTerminal") panelsVisibilitySettings.showMainTerminal = isVisible
        else if (panelKey === "LeftMediaPanel") panelsVisibilitySettings.showLeftMediaPanel = isVisible
        else if (panelKey === "LeftSensorPanel") panelsVisibilitySettings.showLeftSensorPanel = isVisible
        else if (panelKey === "LeftBookmarkBar") panelsVisibilitySettings.showLeftBookmarkBar = isVisible
        else if (panelKey === "RightNotesPanel") panelsVisibilitySettings.showRightNotesPanel = isVisible
        else if (panelKey === "RightNetworkPanel") panelsVisibilitySettings.showRightNetworkPanel = isVisible
        else if (panelKey === "RightControlsPanel") panelsVisibilitySettings.showRightControlsPanel = isVisible
        else if (panelKey === "TodoPanel") panelsVisibilitySettings.showTodoPanel = isVisible
        else if (panelKey === "GitGridPanel") panelsVisibilitySettings.showGitGridPanel = isVisible
        panelsVisibilitySettings.hasSavedState = true

        var cfgKey = "Show" + panelKey
        if (root.configuration && root.configuration[cfgKey] !== undefined) {
            root.configuration[cfgKey] = isVisible
        }
    }

    function togglePanel(panelKey) {
        var current = false
        if (panelKey === "MainTerminal") current = layoutSettings.showMainTerminal
        else if (panelKey === "LeftMediaPanel") current = layoutSettings.showLeftMediaPanel
        else if (panelKey === "LeftSensorPanel") current = layoutSettings.showLeftSensorPanel
        else if (panelKey === "LeftBookmarkBar") current = layoutSettings.showLeftBookmarkBar
        else if (panelKey === "RightNotesPanel") current = layoutSettings.showRightNotesPanel
        else if (panelKey === "RightNetworkPanel") current = layoutSettings.showRightNetworkPanel
        else if (panelKey === "RightControlsPanel") current = layoutSettings.showRightControlsPanel
        else if (panelKey === "TodoPanel") current = layoutSettings.showTodoPanel
        else if (panelKey === "GitGridPanel") current = layoutSettings.showGitGridPanel

        setPanelVisible(panelKey, !current)
    }

    Settings {
        id: layoutSettings
        category: "Layout"
        property real leftWidth: -1
        property real rightWidth: -1
        property real leftSensorHeight: -1
        property real leftBookmarkHeight: -1
        property real rightNotesHeight: -1
        property real rightNetworkHeight: -1
        property real rightControlsHeight: -1
        property string panelsLayoutJson: "{}"
        property bool editMode: false

        // Dynamic in-canvas control settings
        property string themeBgColor: ""
        property string themeAccentColor: ""
        property string themeHighlightColor: ""
        property real gridOpacity: -1
        property real bgImageOpacity: -1
        property real hudOpacity: -1
        property string bgImageOverride: ""
        property int panelStyle: 0
        property string fontFamilyOverride: ""
        property real fontScaleOverride: -1

        // Stackable effect overlays
        property bool effectHologram: false
        property bool effectVignette: false
        property bool effectCircuit: false
        property bool effectPrismBlur: false
        property bool effectScanlines: false
        property bool effectAscii: false
        property bool effectLidarSobel: false
        property bool effectThermalFlir: false
        property bool effectHalftone: false
        property bool effectDuotone: false
        property bool effectDitherFrost: false
        property string effectsStackJson: "[]"
        
        // Panel Toggles
        property bool showMainTerminal: true
        property bool showLeftMediaPanel: true
        property bool showLeftSensorPanel: true
        property bool showLeftBookmarkBar: true
        property bool showRightNotesPanel: true
        property bool showRightNetworkPanel: true
        property bool showRightControlsPanel: true
        property bool showTodoPanel: false
        property bool showGitGridPanel: false
    }

    // Sync external wallpaper configuration changes
    Connections {
        target: root.configuration
        ignoreUnknownSignals: true
        function onValueChanged(key, value) {
            if (key === "EditMode") {
                layoutSettings.editMode = value
            }
            if (key === "PanelsLayoutJson") {
                try { layoutSettings.panelsLayoutJson = value } catch(e) {}
            }
            if (key === "BackgroundColor") { layoutSettings.themeBgColor = "" }
            if (key === "AccentColor") { layoutSettings.themeAccentColor = "" }
            if (key === "HighlightColor") { layoutSettings.themeHighlightColor = "" }
            if (key === "GridOpacity") { layoutSettings.gridOpacity = -1 }
            if (key === "BackgroundImageOpacity") { layoutSettings.bgImageOpacity = -1 }
            if (key === "HudOpacity") { layoutSettings.hudOpacity = -1 }
            if (key === "BackgroundImage") { layoutSettings.bgImageOverride = "" }
            if (key === "PanelStyle") { layoutSettings.panelStyle = value }
            if (key === "EffectHologram") { layoutSettings.effectHologram = value; root.syncEffectFromConfig("hologram", value) }
            if (key === "EffectVignette") { layoutSettings.effectVignette = value; root.syncEffectFromConfig("vignette", value) }
            if (key === "EffectCircuit") { layoutSettings.effectCircuit = value; root.syncEffectFromConfig("circuit", value) }
            if (key === "EffectPrismBlur") { layoutSettings.effectPrismBlur = value; root.syncEffectFromConfig("prism_blur", value) }
            if (key === "EffectScanlines") { layoutSettings.effectScanlines = value; root.syncEffectFromConfig("scanlines", value) }
            if (key === "EffectAscii") { layoutSettings.effectAscii = value; root.syncEffectFromConfig("ascii", value) }
            if (key === "EffectLidarSobel") { layoutSettings.effectLidarSobel = value; root.syncEffectFromConfig("lidar_sobel", value) }
            if (key === "EffectThermalFlir") { layoutSettings.effectThermalFlir = value; root.syncEffectFromConfig("thermal_flir", value) }
            if (key === "EffectHalftone") { layoutSettings.effectHalftone = value; root.syncEffectFromConfig("halftone", value) }
            if (key === "EffectDuotone") { layoutSettings.effectDuotone = value; root.syncEffectFromConfig("duotone", value) }
            if (key === "EffectDitherFrost") { layoutSettings.effectDitherFrost = value; root.syncEffectFromConfig("dither_frost", value) }
            if (key === "EffectsStackJson") {
                try {
                    var s = JSON.parse(value || "[]");
                    if (Array.isArray(s)) root.activeEffectsStack = s;
                } catch(e) {}
            }
            if (key === "FontFamily") { layoutSettings.fontFamilyOverride = "" }
            if (key === "FontScale") { layoutSettings.fontScaleOverride = -1 }
            if (key === "ShowMainTerminal") { layoutSettings.showMainTerminal = value; panelsVisibilitySettings.showMainTerminal = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowLeftMediaPanel") { layoutSettings.showLeftMediaPanel = value; panelsVisibilitySettings.showLeftMediaPanel = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowLeftSensorPanel") { layoutSettings.showLeftSensorPanel = value; panelsVisibilitySettings.showLeftSensorPanel = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowLeftBookmarkBar") { layoutSettings.showLeftBookmarkBar = value; panelsVisibilitySettings.showLeftBookmarkBar = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowRightNotesPanel") { layoutSettings.showRightNotesPanel = value; panelsVisibilitySettings.showRightNotesPanel = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowRightNetworkPanel") { layoutSettings.showRightNetworkPanel = value; panelsVisibilitySettings.showRightNetworkPanel = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowRightControlsPanel") { layoutSettings.showRightControlsPanel = value; panelsVisibilitySettings.showRightControlsPanel = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowTodoPanel") { layoutSettings.showTodoPanel = value; panelsVisibilitySettings.showTodoPanel = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShowGitGridPanel") { layoutSettings.showGitGridPanel = value; panelsVisibilitySettings.showGitGridPanel = value; panelsVisibilitySettings.hasSavedState = true }
            if (key === "ShortcutsJson") { root.shortcutModel = loadShortcuts(value || "[]") }
        }
    }

    function loadShortcuts(jsonStr) {
        try {
            var arr = JSON.parse(jsonStr)
            if (!Array.isArray(arr)) arr = []
            return arr
        } catch (e) {
            return []
        }
    }

    property var shortcutModel: loadShortcuts(shortcutsJson)

    onShortcutsJsonChanged: {
        shortcutModel = loadShortcuts(shortcutsJson)
    }

    Component.onCompleted: {
        if (layoutSettings.leftWidth <= 0)
            layoutSettings.leftWidth = 350
        if (layoutSettings.rightWidth <= 0)
            layoutSettings.rightWidth = 350
        if (layoutSettings.leftSensorHeight <= 0)
            layoutSettings.leftSensorHeight = 0.55
        if (layoutSettings.leftBookmarkHeight <= 0)
            layoutSettings.leftBookmarkHeight = 0.35
        if (layoutSettings.rightNotesHeight <= 0)
            layoutSettings.rightNotesHeight = 0.45
        if (layoutSettings.rightNetworkHeight <= 0)
            layoutSettings.rightNetworkHeight = 220
        if (layoutSettings.rightControlsHeight <= 0)
            layoutSettings.rightControlsHeight = 180

        // Initialize persistent EditMode from config
        layoutSettings.editMode = root.configuration.EditMode
        // Sync panels layout from config if not already set
        if (layoutSettings.panelsLayoutJson === "{}" || layoutSettings.panelsLayoutJson === "") {
            layoutSettings.panelsLayoutJson = root.configuration.PanelsLayoutJson || "{}"
        }

        // Initialize panel visibility from persistent settings or configuration
        if (panelsVisibilitySettings.hasSavedState) {
            layoutSettings.showMainTerminal = panelsVisibilitySettings.showMainTerminal
            layoutSettings.showLeftMediaPanel = panelsVisibilitySettings.showLeftMediaPanel
            layoutSettings.showLeftSensorPanel = panelsVisibilitySettings.showLeftSensorPanel
            layoutSettings.showLeftBookmarkBar = panelsVisibilitySettings.showLeftBookmarkBar
            layoutSettings.showRightNotesPanel = panelsVisibilitySettings.showRightNotesPanel
            layoutSettings.showRightNetworkPanel = panelsVisibilitySettings.showRightNetworkPanel
            layoutSettings.showRightControlsPanel = panelsVisibilitySettings.showRightControlsPanel
            layoutSettings.showTodoPanel = panelsVisibilitySettings.showTodoPanel
            layoutSettings.showGitGridPanel = panelsVisibilitySettings.showGitGridPanel
        } else {
            if (root.configuration.ShowMainTerminal !== undefined) layoutSettings.showMainTerminal = root.configuration.ShowMainTerminal
            if (root.configuration.ShowLeftMediaPanel !== undefined) layoutSettings.showLeftMediaPanel = root.configuration.ShowLeftMediaPanel
            if (root.configuration.ShowLeftSensorPanel !== undefined) layoutSettings.showLeftSensorPanel = root.configuration.ShowLeftSensorPanel
            if (root.configuration.ShowLeftBookmarkBar !== undefined) layoutSettings.showLeftBookmarkBar = root.configuration.ShowLeftBookmarkBar
            if (root.configuration.ShowRightNotesPanel !== undefined) layoutSettings.showRightNotesPanel = root.configuration.ShowRightNotesPanel
            if (root.configuration.ShowRightNetworkPanel !== undefined) layoutSettings.showRightNetworkPanel = root.configuration.ShowRightNetworkPanel
            if (root.configuration.ShowRightControlsPanel !== undefined) layoutSettings.showRightControlsPanel = root.configuration.ShowRightControlsPanel
            if (root.configuration.ShowTodoPanel !== undefined) layoutSettings.showTodoPanel = root.configuration.ShowTodoPanel
            if (root.configuration.ShowGitGridPanel !== undefined) layoutSettings.showGitGridPanel = root.configuration.ShowGitGridPanel
            panelsVisibilitySettings.hasSavedState = true
        }

        // Initialize active effects stacking order
        var savedStack = [];
        try {
            var raw = (root.configuration && root.configuration.EffectsStackJson) ? root.configuration.EffectsStackJson : layoutSettings.effectsStackJson;
            savedStack = JSON.parse(raw || "[]");
        } catch(e) {}
        if (Array.isArray(savedStack) && savedStack.length > 0) {
            root.activeEffectsStack = savedStack;
        } else {
            var init = [];
            if (layoutSettings.effectPrismBlur) init.push("prism_blur");
            if (layoutSettings.effectHologram) init.push("hologram");
            if (layoutSettings.effectVignette) init.push("vignette");
            if (layoutSettings.effectCircuit) init.push("circuit");
            if (layoutSettings.effectScanlines) init.push("scanlines");
            if (layoutSettings.effectAscii) init.push("ascii");
            if (layoutSettings.effectLidarSobel) init.push("lidar_sobel");
            if (layoutSettings.effectThermalFlir) init.push("thermal_flir");
            if (layoutSettings.effectHalftone) init.push("halftone");
            if (layoutSettings.effectDuotone) init.push("duotone");
            if (layoutSettings.effectDitherFrost) init.push("dither_frost");
            root.activeEffectsStack = init;
        }
    }

    Rectangle {
        id: canvas
        anchors.fill: parent
        // Base solid color — shows when no image is set, also tints image
        color: bgColor

        // Layer 1: Background image at full quality (no opacity loss)
        Image {
            id: bgImageItem
            anchors.fill: parent
            source: root.bgImage !== "" ? root.bgImage : ""
            visible: root.bgImage !== ""
            fillMode: {
                var m = (typeof root.configuration !== "undefined" && root.configuration.BackgroundFillMode !== undefined) ? root.configuration.BackgroundFillMode : 0
                if (m === 1) return Image.PreserveAspectFit
                if (m === 2) return Image.Stretch
                return Image.PreserveAspectCrop
            }
            asynchronous: true
            smooth: true
            // No opacity here — image renders at full fidelity
        }

        // Layer 2: Dim overlay — blends image into the bg color
        // bgImageOpacity here controls how "frosted/dark" the overlay is.
        // 0 = full image visible, 1 = fully covered by bgColor
        Rectangle {
            anchors.fill: parent
            visible: bgImageItem.visible && bgImageItem.status === Image.Ready
            color: bgColor
            opacity: 1.0 - root.bgImageOpacity  // invert: high opacity = show image, low = hide
        }

        // Layer 2.5: Tech Digital Matrix Grid Overlay (always active when gridOpacity > 0)
        Canvas {
            id: backgroundGrid
            anchors.fill: parent
            visible: root.gridOpacity > 0.0
            opacity: root.gridOpacity
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onAccentColorChanged() { backgroundGrid.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = root.accentColor
                ctx.globalAlpha = 0.1
                ctx.lineWidth = 1
                ctx.beginPath()
                for (var x = 0; x <= width; x += 48) {
                    ctx.moveTo(x + 0.5, 0)
                    ctx.lineTo(x + 0.5, height)
                }
                for (var y = 0; y <= height; y += 48) {
                    ctx.moveTo(0, y + 0.5)
                    ctx.lineTo(width, y + 0.5)
                }
                ctx.stroke()
            }
        }

        // Edit Mode Grid Overlay (16px cells)
        Canvas {
            id: editGrid
            anchors.fill: parent
            visible: root.editMode
            opacity: 0.15
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onAccentColorChanged() { editGrid.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = root.accentColor
                ctx.lineWidth = 1
                ctx.beginPath()
                for (var x = 0; x <= width; x += 16) {
                    ctx.moveTo(x + 0.5, 0)
                    ctx.lineTo(x + 0.5, height)
                }
                for (var y = 0; y <= height; y += 16) {
                    ctx.moveTo(0, y + 0.5)
                    ctx.lineTo(width, y + 0.5)
                }
                ctx.stroke()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0
            opacity: root.hudOpacity

            // ── TOP CONTROL BAR ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                Layout.minimumHeight: 22
                Layout.maximumHeight: 22
                clip: true
                color: Qt.rgba(8/255, 9/255, 13/255, 0.65)
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                border.width: 1

                // Subtle tactical corner ticks
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top
                    width: 6; height: 1.5; color: root.highlightColor
                }
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top
                    width: 1.5; height: 6; color: root.highlightColor
                }
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top
                    width: 6; height: 1.5; color: root.highlightColor
                }
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top
                    width: 1.5; height: 6; color: root.highlightColor
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 12
                    
                    Text {
                        text: ":: NERVE_CENTER // SYS_CONTROL"
                        color: root.accentColor
                        font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                        font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                        font.bold: true
                        font.letterSpacing: 2
                        opacity: 0.8
                    }

                    // ── CENTERED QUOTE OF THE DAY (Programmers & Philosophers) ──
                    Item {
                        id: quoteContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        readonly property var quoteList: [
                            { q: "Simplicity is prerequisite for reliability.", a: "Edsger W. Dijkstra" },
                            { q: "The best way to predict the future is to invent it.", a: "Alan Kay" },
                            { q: "Talk is cheap. Show me the code.", a: "Linus Torvalds" },
                            { q: "Premature optimization is the root of all evil.", a: "Donald Knuth" },
                            { q: "Waste no more time arguing what a good man should be. Be one.", a: "Marcus Aurelius" },
                            { q: "He who has a why to live can bear almost any how.", a: "Friedrich Nietzsche" },
                            { q: "We can only see a short distance, but plenty needs to be done.", a: "Alan Turing" },
                            { q: "Controlling complexity is the essence of computer programming.", a: "Brian W. Kernighan" },
                            { q: "Difficulties strengthen the mind, as labor does the body.", a: "Seneca" },
                            { q: "The most dangerous phrase is, 'We've always done it this way.'", a: "Grace Hopper" },
                            { q: "A journey of a thousand miles begins with a single step.", a: "Lao Tzu" },
                            { q: "That brain of mine is something more than merely mortal.", a: "Ada Lovelace" },
                            { q: "First say to yourself what you would be; then do what you must.", a: "Epictetus" },
                            { q: "There are only two kinds of languages: those people complain about and those nobody uses.", a: "Bjarne Stroustrup" },
                            { q: "Any sufficiently advanced technology is indistinguishable from magic.", a: "Arthur C. Clarke" },
                            { q: "The unexamined life is not worth living.", a: "Socrates" },
                            { q: "Programs must be written for people to read, and only incidentally for machines to execute.", a: "Harold Abelson" },
                            { q: "Make it work, make it right, make it fast.", a: "Kent Beck" },
                            { q: "Knowing others is intelligence; knowing yourself is true wisdom.", a: "Lao Tzu" },
                            { q: "Good judgment comes from experience, experience from bad judgment.", a: "Fred Brooks" }
                        ]

                        Settings {
                            id: quoteSettings
                            category: "QuoteOfDay"
                            property int quoteIndex: 0
                            property string lastDate: ""
                        }

                        function checkDailyQuote() {
                            var todayStr = Qt.formatDate(new Date(), "yyyy-MM-dd");
                            if (quoteSettings.lastDate !== todayStr) {
                                quoteSettings.lastDate = todayStr;
                                quoteSettings.quoteIndex = (quoteSettings.quoteIndex + 1) % quoteContainer.quoteList.length;
                            }
                        }

                        function rollNextQuote() {
                            var next = (quoteSettings.quoteIndex + 1 + Math.floor(Math.random() * (quoteContainer.quoteList.length - 1))) % quoteContainer.quoteList.length;
                            quoteSettings.quoteIndex = next;
                            quoteSettings.lastDate = Qt.formatDate(new Date(), "yyyy-MM-dd");
                        }

                        Component.onCompleted: checkDailyQuote()

                        Timer {
                            interval: 60000 // 1-minute tick to detect midnight date rollover
                            running: true
                            repeat: true
                            onTriggered: quoteContainer.checkDailyQuote()
                        }

                        Text {
                            id: quoteText
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 16, implicitWidth)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: {
                                var item = quoteContainer.quoteList[quoteSettings.quoteIndex % quoteContainer.quoteList.length];
                                return "“" + item.q + "” — " + item.a;
                            }
                            color: quoteMa.containsMouse ? root.highlightColor : root.accentColor
                            font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                            font.pixelSize: Math.round(9 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                            font.italic: true
                            opacity: quoteMa.containsMouse ? 1.0 : 0.72

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: quoteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: quoteContainer.rollNextQuote()
                        }
                    }

                    // Radio Toggles
                    RowLayout {
                        spacing: 24

                        // Dropdown: WIDGETS
                        Item {
                            Layout.fillHeight: true
                            Layout.preferredWidth: widgetsRow.implicitWidth

                            RowLayout {
                                id: widgetsRow
                                anchors.fill: parent
                                spacing: 8
                                Text {
                                    text: "WIDGETS ▾"
                                    color: widgetsMenu.visible ? root.highlightColor : root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: widgetsMenu.visible ? 1.0 : 0.8
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetsMenu.open()
                            }

                            Menu {
                                id: widgetsMenu
                                y: parent.height + 4
                                background: Rectangle {
                                    color: Qt.rgba(8/255, 9/255, 13/255, 0.95)
                                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                                }

                                component MiniWidget: MenuItem {
                                    id: miniItem
                                    property var targetPanel
                                    property string labelText
                                    
                                    contentItem: RowLayout {
                                        spacing: 12
                                        Rectangle {
                                            width: 48; height: 32
                                            color: "transparent"
                                            border.color: miniItem.highlighted ? root.highlightColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                                            ShaderEffectSource {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                sourceItem: miniItem.targetPanel ? miniItem.targetPanel : null
                                                live: widgetsMenu.visible && miniItem.targetPanel && miniItem.targetPanel.visible
                                            }
                                        }
                                        Text {
                                            text: miniItem.labelText
                                            color: (miniItem.targetPanel && miniItem.targetPanel.visible) ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                                            font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                            font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: (miniItem.targetPanel && miniItem.targetPanel.visible) ? "[ON]" : "[OFF]"
                                            color: (miniItem.targetPanel && miniItem.targetPanel.visible) ? root.highlightColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                                            font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                            font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                        }
                                    }
                                    background: Rectangle {
                                        color: miniItem.highlighted ? Qt.rgba(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, 0.1) : "transparent"
                                    }
                                    onTriggered: {
                                        if (miniItem.labelText === "Main Terminal") root.togglePanel("MainTerminal")
                                        else if (miniItem.labelText === "Media Panel") root.togglePanel("LeftMediaPanel")
                                        else if (miniItem.labelText === "Sensor Panel") root.togglePanel("LeftSensorPanel")
                                        else if (miniItem.labelText === "Bookmark Bar") root.togglePanel("LeftBookmarkBar")
                                        else if (miniItem.labelText === "Notes Panel") root.togglePanel("RightNotesPanel")
                                        else if (miniItem.labelText === "Network Panel") root.togglePanel("RightNetworkPanel")
                                        else if (miniItem.labelText === "Controls Panel") root.togglePanel("RightControlsPanel")
                                        else if (miniItem.labelText === "Todo Panel") root.togglePanel("TodoPanel")
                                        else if (miniItem.labelText === "Git Grid") root.togglePanel("GitGridPanel")
                                    }
                                }

                                MiniWidget { labelText: "Main Terminal"; targetPanel: mainTerminal }
                                MiniWidget { labelText: "Media Panel"; targetPanel: leftMediaPanel }
                                MiniWidget { labelText: "Sensor Panel"; targetPanel: leftSensorPanel }
                                MiniWidget { labelText: "Bookmark Bar"; targetPanel: leftBookmarkBar }
                                MiniWidget { labelText: "Notes Panel"; targetPanel: rightNotesPanel }
                                MiniWidget { labelText: "Network Panel"; targetPanel: rightNetworkPanel }
                                MiniWidget { labelText: "Controls Panel"; targetPanel: rightControlsPanel }
                                MiniWidget { labelText: "Todo Panel"; targetPanel: todoPanel }
                                MiniWidget { labelText: "Git Grid"; targetPanel: gitGridPanel }

                                
                                MenuSeparator {
                                    contentItem: Rectangle {
                                        implicitHeight: 1
                                        color: root.accentColor
                                        opacity: 0.2
                                    }
                                }
                                MenuItem {
                                    contentItem: Text {
                                        text: "Install New (.qml)..."
                                        color: parent.highlighted ? root.highlightColor : root.accentColor
                                        font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                        font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                        font.bold: true
                                        opacity: parent.highlighted ? 1.0 : 0.8
                                    }
                                    background: Rectangle {
                                        color: parent.highlighted ? Qt.rgba(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, 0.1) : "transparent"
                                    }
                                    onTriggered: {
                                        console.log("Install new widget requested")
                                    }
                                }
                            }
                        }

                        // Dropdown: BACKDROP STYLE
                        Item {
                            Layout.fillHeight: true
                            Layout.preferredWidth: styleRow.implicitWidth

                            RowLayout {
                                id: styleRow
                                anchors.fill: parent
                                spacing: 8
                                Text {
                                    text: "STYLE ▾"
                                    color: styleMenu.visible ? root.highlightColor : root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: styleMenu.visible ? 1.0 : 0.8
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: styleMenu.open()
                            }

                            Menu {
                                id: styleMenu
                                y: parent.height + 4
                                background: Rectangle {
                                    color: Qt.rgba(8/255, 9/255, 13/255, 0.95)
                                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                                }

                                // Base style items (single-select)
                                component StyleItem: MenuItem {
                                    id: si
                                    property string styleName
                                    property int styleIndex
                                    
                                    contentItem: RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: layoutSettings.panelStyle === si.styleIndex ? root.highlightColor : "transparent"
                                            border.color: layoutSettings.panelStyle === si.styleIndex ? root.highlightColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                                            border.width: 1
                                        }
                                        Text {
                                            text: si.styleName
                                            color: si.highlighted ? root.highlightColor : (layoutSettings.panelStyle === si.styleIndex ? root.highlightColor : root.accentColor)
                                            font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                            font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                            font.bold: true
                                        }
                                    }
                                    background: Rectangle {
                                        color: si.highlighted ? Qt.rgba(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, 0.1) : "transparent"
                                    }
                                    onTriggered: {
                                        layoutSettings.panelStyle = si.styleIndex;
                                    }
                                }

                                // Effect toggle items (multi-select, dynamically stacked in activation order)
                                component EffectItem: MenuItem {
                                    id: ei
                                    property string effectName
                                    property string effectKey
                                    readonly property bool effectActive: root.isEffectActive(effectKey)
                                    readonly property int layerNum: root.getEffectLayer(effectKey)
                                    
                                    contentItem: RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            width: 8; height: 8; radius: 1
                                            color: ei.effectActive ? root.highlightColor : "transparent"
                                            border.color: ei.effectActive ? root.highlightColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                                            border.width: 1
                                        }
                                        Text {
                                            text: ei.effectName
                                            color: ei.highlighted ? root.highlightColor : (ei.effectActive ? root.highlightColor : root.accentColor)
                                            font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                            font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                            font.bold: true
                                        }
                                        Text {
                                            text: ei.effectActive ? ("[L" + ei.layerNum + "]") : "[OFF]"
                                            color: ei.effectActive ? root.highlightColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                                            font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                            font.pixelSize: Math.round(9 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                        }
                                    }
                                    background: Rectangle {
                                        color: ei.highlighted ? Qt.rgba(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, 0.1) : "transparent"
                                    }
                                    onTriggered: root.toggleEffect(ei.effectKey)
                                }

                                // ── Base Styles ──
                                StyleItem { styleName: "CYBER_WIREFRAME"; styleIndex: 0 }
                                StyleItem { styleName: "GLASS_GLASSMORPHIC"; styleIndex: 1 }
                                StyleItem { styleName: "MINIMALIST_FLAT"; styleIndex: 2 }
                                StyleItem { styleName: "TACTICAL_CHASSIS"; styleIndex: 3 }
                                StyleItem { styleName: "STEALTH_VOID"; styleIndex: 4 }
                                StyleItem { styleName: "RETRO_PHOSPHOR_CRT"; styleIndex: 5 }
                                StyleItem { styleName: "CYBER_NEUMORPHIC"; styleIndex: 6 }

                                MenuSeparator {
                                    contentItem: Rectangle {
                                        implicitHeight: 1
                                        color: root.accentColor
                                        opacity: 0.15
                                    }
                                }

                                // ── Stackable Effects (Dynamic Layer Stacking / 0% GPU) ──
                                EffectItem {
                                    effectName: "+ PRISM_FROST_BLUR"
                                    effectKey: "prism_blur"
                                }
                                EffectItem {
                                    effectName: "+ ASCII_MATRIX_ART"
                                    effectKey: "ascii"
                                }
                                EffectItem {
                                    effectName: "+ HOLOGRAM_EDGES"
                                    effectKey: "hologram"
                                }
                                EffectItem {
                                    effectName: "+ VIGNETTE_DEPTH"
                                    effectKey: "vignette"
                                }
                                EffectItem {
                                    effectName: "+ CIRCUIT_BOARD"
                                    effectKey: "circuit"
                                }
                                EffectItem {
                                    effectName: "+ INTERLACE_SCANLINES"
                                    effectKey: "scanlines"
                                }
                                EffectItem {
                                    effectName: "+ LIDAR_SOBEL_CONTOUR"
                                    effectKey: "lidar_sobel"
                                }
                                EffectItem {
                                    effectName: "+ THERMAL_FLIR_RECON"
                                    effectKey: "thermal_flir"
                                }
                                EffectItem {
                                    effectName: "+ HALFTONE_DOT_SCREEN"
                                    effectKey: "halftone"
                                }
                                EffectItem {
                                    effectName: "+ DUOTONE_ATMOSPHERE"
                                    effectKey: "duotone"
                                }
                                EffectItem {
                                    effectName: "+ DITHER_FROST_ACRYLIC"
                                    effectKey: "dither_frost"
                                }
                            }
                        }

                        // Dropdown: THEME
                        Item {
                            Layout.fillHeight: true
                            Layout.preferredWidth: themeRow.implicitWidth

                            RowLayout {
                                id: themeRow
                                anchors.fill: parent
                                spacing: 8
                                Text {
                                    text: "THEME ▾"
                                    color: themeMenu.visible ? root.highlightColor : root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: themeMenu.visible ? 1.0 : 0.8
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: themeMenu.open()
                            }

                            Menu {
                                id: themeMenu
                                y: parent.height + 4
                                background: Rectangle {
                                    color: Qt.rgba(8/255, 9/255, 13/255, 0.95)
                                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                                }

                                component ThemeItem: MenuItem {
                                    id: ti
                                    property string themeName
                                    property color accentVal
                                    property color highlightVal
                                    property color bgVal: "#08090d"
                                    
                                    contentItem: Text {
                                        text: ti.themeName
                                        color: ti.highlighted ? root.highlightColor : root.accentColor
                                        font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                        font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                        font.bold: true
                                    }
                                    background: Rectangle {
                                        color: ti.highlighted ? Qt.rgba(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, 0.1) : "transparent"
                                    }
                                    onTriggered: {
                                        layoutSettings.themeAccentColor = ti.accentVal.toString()
                                        layoutSettings.themeHighlightColor = ti.highlightVal.toString()
                                        layoutSettings.themeBgColor = ti.bgVal.toString()
                                    }
                                }

                                ThemeItem { themeName: "CYBERPUNK NEON"; accentVal: "#00f0ff"; highlightVal: "#ff007f"; bgVal: "#08090d" }
                                ThemeItem { themeName: "MATRIX ACTIVE"; accentVal: "#33ff33"; highlightVal: "#00aa00"; bgVal: "#040b04" }
                                ThemeItem { themeName: "ICE COBALT"; accentVal: "#0088ff"; highlightVal: "#00f0ff"; bgVal: "#050a12" }
                                ThemeItem { themeName: "CLASSIC AMBER"; accentVal: "#ff8800"; highlightVal: "#ffaa00"; bgVal: "#0a0600" }
                                ThemeItem { themeName: "GHOST WHITE"; accentVal: "#ffffff"; highlightVal: "#888888"; bgVal: "#000000" }
                                ThemeItem { themeName: "SYNTHWAVE SUNSET"; accentVal: "#ff007f"; highlightVal: "#ffaa00"; bgVal: "#120526" }
                                ThemeItem { themeName: "TOXIC CHEMICAL"; accentVal: "#00ffaa"; highlightVal: "#c0ff00"; bgVal: "#040d0a" }
                                ThemeItem { themeName: "ROYAL CHROMIUM"; accentVal: "#8a2be2"; highlightVal: "#00ffff"; bgVal: "#0b001a" }
                            }
                        }

                        // Dropdown: OPACITY
                        Item {
                            Layout.fillHeight: true
                            Layout.preferredWidth: opacityRow.implicitWidth

                            RowLayout {
                                id: opacityRow
                                anchors.fill: parent
                                spacing: 8
                                Text {
                                    text: "HUD_OPACITY: " + Math.round(root.hudOpacity * 100) + "% ▾"
                                    color: opacityMenu.visible ? root.highlightColor : root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: opacityMenu.visible ? 1.0 : 0.8
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: opacityMenu.open()
                            }

                            Menu {
                                id: opacityMenu
                                y: parent.height + 4
                                background: Rectangle {
                                    color: Qt.rgba(8/255, 9/255, 13/255, 0.95)
                                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                                }

                                component OpacityItem: MenuItem {
                                    id: oi
                                    property real opacityVal
                                    
                                    contentItem: Text {
                                        text: Math.round(oi.opacityVal * 100) + "%"
                                        color: oi.highlighted ? root.highlightColor : root.accentColor
                                        font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                        font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                        font.bold: true
                                    }
                                    background: Rectangle {
                                        color: oi.highlighted ? Qt.rgba(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, 0.1) : "transparent"
                                    }
                                    onTriggered: {
                                        layoutSettings.hudOpacity = oi.opacityVal
                                    }
                                }

                                OpacityItem { opacityVal: 1.0 }
                                OpacityItem { opacityVal: 0.85 }
                                OpacityItem { opacityVal: 0.7 }
                                OpacityItem { opacityVal: 0.5 }
                                OpacityItem { opacityVal: 0.3 }
                            }
                        }

                        // Toggle: BG_DIM
                        MouseArea {
                            Layout.fillHeight: true
                            Layout.preferredWidth: dimRow.implicitWidth
                            cursorShape: Qt.PointingHandCursor
                            onClicked: layoutSettings.bgImageOpacity = (root.bgImageOpacity > 0.0 ? 0.0 : 0.85)

                            RowLayout {
                                id: dimRow
                                anchors.fill: parent
                                spacing: 8
                                Text {
                                    text: "BG_DIM"
                                    color: root.bgImageOpacity > 0.0 ? root.highlightColor : root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: root.bgImageOpacity > 0.0 ? 1.0 : 0.5
                                }
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: root.bgImageOpacity > 0.0 ? root.highlightColor : "transparent"
                                    border.color: root.bgImageOpacity > 0.0 ? root.highlightColor : root.accentColor
                                    border.width: 1
                                }
                            }
                        }

                        // Trigger: BG_IMAGE picker dialogue
                        Item {
                            Layout.fillHeight: true
                            Layout.preferredWidth: bgImageRow.implicitWidth

                            RowLayout {
                                id: bgImageRow
                                anchors.fill: parent
                                spacing: 8
                                Text {
                                    text: "BG_IMAGE"
                                    color: root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: 0.8
                                }
                                Text {
                                    text: "[SELECT]"
                                    color: root.highlightColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(9 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: bgFileDialog.open()
                                    }
                                }
                                Text {
                                    text: "[RESET]"
                                    color: root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(9 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    visible: layoutSettings.bgImageOverride !== ""
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: layoutSettings.bgImageOverride = ""
                                    }
                                }
                            }
                        }

                        // Toggle: EDIT_MODE
                        MouseArea {
                            Layout.fillHeight: true
                            Layout.preferredWidth: editRow.implicitWidth
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                layoutSettings.editMode = !layoutSettings.editMode
                                root.configuration.EditMode = layoutSettings.editMode
                            }
                            
                            RowLayout {
                                id: editRow
                                anchors.fill: parent
                                spacing: 8
                                Text {
                                    text: "EDIT_LAYOUT"
                                    color: root.editMode ? root.highlightColor : root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: root.editMode ? 1.0 : 0.5
                                }
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: root.editMode ? root.highlightColor : "transparent"
                                    border.color: root.editMode ? root.highlightColor : root.accentColor
                                    border.width: 1
                                }
                            }
                        }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.topMargin: 3
                            Layout.bottomMargin: 3
                            width: 1
                            color: root.accentColor
                            opacity: 0.2
                        }

                        // Trigger: SAVE_CONFIG — syncs all layoutSettings to root.configuration
                        MouseArea {
                            id: saveMa
                            Layout.fillHeight: true
                            Layout.preferredWidth: saveRow.implicitWidth
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            
                            property bool isHovered: containsMouse

                            onClicked: {
                                // Theme colors
                                if (layoutSettings.themeAccentColor !== "")
                                    root.configuration.AccentColor = layoutSettings.themeAccentColor
                                if (layoutSettings.themeHighlightColor !== "")
                                    root.configuration.HighlightColor = layoutSettings.themeHighlightColor
                                if (layoutSettings.themeBgColor !== "")
                                    root.configuration.BackgroundColor = layoutSettings.themeBgColor

                                // Opacity / visual settings
                                if (layoutSettings.gridOpacity !== -1)
                                    root.configuration.GridOpacity = layoutSettings.gridOpacity
                                if (layoutSettings.bgImageOpacity !== -1)
                                    root.configuration.BackgroundImageOpacity = layoutSettings.bgImageOpacity
                                if (layoutSettings.hudOpacity !== -1)
                                    root.configuration.HudOpacity = layoutSettings.hudOpacity

                                // Background image
                                if (layoutSettings.bgImageOverride !== "")
                                    root.configuration.BackgroundImage = layoutSettings.bgImageOverride

                                // Panel style
                                root.configuration.PanelStyle = layoutSettings.panelStyle

                                // Font overrides
                                if (layoutSettings.fontFamilyOverride !== "")
                                    root.configuration.FontFamily = layoutSettings.fontFamilyOverride
                                if (layoutSettings.fontScaleOverride !== -1)
                                    root.configuration.FontScale = layoutSettings.fontScaleOverride

                                // Edit mode
                                root.configuration.EditMode = layoutSettings.editMode

                                // Panel layout positions and visibilities
                                root.configuration.PanelsLayoutJson = layoutSettings.panelsLayoutJson
                                root.configuration.ShowMainTerminal = layoutSettings.showMainTerminal
                                root.configuration.ShowLeftMediaPanel = layoutSettings.showLeftMediaPanel
                                root.configuration.ShowLeftSensorPanel = layoutSettings.showLeftSensorPanel
                                root.configuration.ShowLeftBookmarkBar = layoutSettings.showLeftBookmarkBar
                                root.configuration.ShowRightNotesPanel = layoutSettings.showRightNotesPanel
                                root.configuration.ShowRightNetworkPanel = layoutSettings.showRightNetworkPanel
                                root.configuration.ShowRightControlsPanel = layoutSettings.showRightControlsPanel
                                root.configuration.ShowTodoPanel = layoutSettings.showTodoPanel
                                root.configuration.ShowGitGridPanel = layoutSettings.showGitGridPanel

                                panelsVisibilitySettings.showMainTerminal = layoutSettings.showMainTerminal
                                panelsVisibilitySettings.showLeftMediaPanel = layoutSettings.showLeftMediaPanel
                                panelsVisibilitySettings.showLeftSensorPanel = layoutSettings.showLeftSensorPanel
                                panelsVisibilitySettings.showLeftBookmarkBar = layoutSettings.showLeftBookmarkBar
                                panelsVisibilitySettings.showRightNotesPanel = layoutSettings.showRightNotesPanel
                                panelsVisibilitySettings.showRightNetworkPanel = layoutSettings.showRightNetworkPanel
                                panelsVisibilitySettings.showRightControlsPanel = layoutSettings.showRightControlsPanel
                                panelsVisibilitySettings.showTodoPanel = layoutSettings.showTodoPanel
                                panelsVisibilitySettings.showGitGridPanel = layoutSettings.showGitGridPanel
                                panelsVisibilitySettings.hasSavedState = true

                                // Flash confirmation
                                saveConfirmText.text = "✓ SAVED"
                                saveConfirmText.color = "#50fa7b"
                                saveRestoreTimer.start()
                            }

                            Timer {
                                id: saveRestoreTimer
                                interval: 1500
                                onTriggered: {
                                    saveConfirmText.text = "SAVE_CONFIG"
                                    saveConfirmText.color = saveMa.isHovered ? root.highlightColor : root.accentColor
                                }
                            }

                            RowLayout {
                                id: saveRow
                                anchors.fill: parent
                                spacing: 4
                                Text {
                                    id: saveConfirmText
                                    text: "SAVE_CONFIG"
                                    color: saveMa.isHovered ? root.highlightColor : root.accentColor
                                    font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
                                    font.pixelSize: Math.round(10 * (typeof root !== "undefined" ? root.globalFontScale : 1.0))
                                    font.bold: true
                                    opacity: saveMa.isHovered ? 1.0 : 0.6

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                            }
                        }
                    }
                }

            // ── 3-COLUMN COGNITIVE HUD -> FREE-FORM LAYOUT ──
            Item {
                id: mainCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ═══ CENTER Terminal ═════════════════════════
                TerminalWidget {
                    id: mainTerminal
                    visible: layoutSettings.showMainTerminal
                    defaultX: parent.width / 2 - Math.max(400, parent.width * 0.4) / 2
                    defaultY: 0
                    defaultW: Math.max(400, parent.width * 0.4)
                    defaultH: parent.height
                    onRequestSaveState: root.saveLayoutState()
                }

                // ═══ HUD PANELS ══════════════════════════════
                MediaPanel {
                    id: leftMediaPanel
                    visible: layoutSettings.showLeftMediaPanel
                    defaultX: 0
                    defaultY: 0
                    defaultW: Math.max(200, parent.width * 0.28)
                    defaultH: 120
                    onRequestSaveState: root.saveLayoutState()
                }

                SensorPanel {
                    id: leftSensorPanel
                    visible: layoutSettings.showLeftSensorPanel
                    defaultX: 0
                    defaultY: 120 + 8
                    defaultW: Math.max(200, parent.width * 0.28)
                    defaultH: parent.height * 0.55 - (120 + 8)
                    onRequestSaveState: root.saveLayoutState()
                }

                BookmarkBar {
                    id: leftBookmarkBar
                    visible: layoutSettings.showLeftBookmarkBar
                    defaultX: 0
                    defaultY: parent.height * 0.55 + 8
                    defaultW: Math.max(200, parent.width * 0.28)
                    defaultH: parent.height * 0.45 - 8
                    shortcutModel: root.shortcutModel
                    shortcutIconPadding: root.shortcutIconPadding
                    iconSize: root.shortcutIconSize
                    onRequestSaveState: root.saveLayoutState()
                }

                NotesPanel {
                    id: rightNotesPanel
                    visible: layoutSettings.showRightNotesPanel
                    defaultX: parent.width - Math.max(200, parent.width * 0.28)
                    defaultY: 0
                    defaultW: Math.max(200, parent.width * 0.28)
                    defaultH: parent.height * 0.45
                    onRequestSaveState: root.saveLayoutState()
                }

                NetworkPanel {
                    id: rightNetworkPanel
                    visible: layoutSettings.showRightNetworkPanel
                    defaultX: parent.width - Math.max(200, parent.width * 0.28)
                    defaultY: parent.height * 0.45 + 8
                    defaultW: Math.max(200, parent.width * 0.28)
                    defaultH: 220
                    onRequestSaveState: root.saveLayoutState()
                }

                ControlsPanel {
                    id: rightControlsPanel
                    visible: layoutSettings.showRightControlsPanel
                    defaultX: parent.width - Math.max(200, parent.width * 0.28)
                    defaultY: parent.height * 0.45 + 8 + 220 + 8
                    defaultW: Math.max(200, parent.width * 0.28)
                    defaultH: parent.height - (parent.height * 0.45 + 8 + 220 + 8)
                    onRequestSaveState: root.saveLayoutState()
                }

                TodoPanel {
                    id: todoPanel
                    visible: layoutSettings.showTodoPanel
                    defaultX: parent.width * 0.28 + 12
                    defaultY: parent.height * 0.62
                    defaultW: Math.max(220, parent.width * 0.21)
                    defaultH: parent.height * 0.38 - 8
                    onRequestSaveState: root.saveLayoutState()
                }

                GitGridPanel {
                    id: gitGridPanel
                    visible: layoutSettings.showGitGridPanel
                    defaultX: parent.width * 0.50 + 12
                    defaultY: parent.height * 0.62
                    defaultW: Math.max(250, parent.width * 0.21)
                    defaultH: parent.height * 0.38 - 8
                    onRequestSaveState: root.saveLayoutState()
                }

            }
        }
    }

    FileDialog {
        id: bgFileDialog
        title: "Select Cybernetic Backdrop"
        nameFilters: ["Image files (*.jpg *.png *.jpeg *.webp *.svg)"]
        onAccepted: {
            var path = selectedFile.toString();
            layoutSettings.bgImageOverride = path;
        }
    }
}
