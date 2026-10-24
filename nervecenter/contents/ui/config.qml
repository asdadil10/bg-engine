/*
 *  NerveCenter — KDE Plasma 6 Wallpaper Plugin
 *  config.qml — Redesigned Modern Settings Panel
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kquickcontrols as KQuickControls
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    spacing: Kirigami.Units.largeSpacing

    // ─────────────────────────────────────────────────────────────────────────
    // Plasma KConfigXT Bindings (cfg_* aliases automatically synced to main.xml)
    // ─────────────────────────────────────────────────────────────────────────
    // Tab 1: Appearance & Theme
    property alias cfg_BackgroundColor:        bgColorButton.color
    property alias cfg_AccentColor:            accentColorButton.color
    property alias cfg_HighlightColor:         highlightColorButton.color
    property alias cfg_BackgroundImage:        bgImageField.text
    property alias cfg_BackgroundImageOpacity: bgImageOpacitySlider.value
    property alias cfg_BackgroundFillMode:     fillModeCombo.currentIndex
    property alias cfg_PanelStyle:             panelStyleCombo.currentIndex
    property alias cfg_EffectPrismBlur:        effectPrismBlurSwitch.checked
    property alias cfg_EffectHologram:         effectHologramSwitch.checked
    property alias cfg_EffectVignette:         effectVignetteSwitch.checked
    property alias cfg_EffectCircuit:          effectCircuitSwitch.checked
    property alias cfg_EffectScanlines:        effectScanlinesSwitch.checked
    property alias cfg_EffectAscii:            effectAsciiSwitch.checked
    property alias cfg_GridOpacity:            gridSlider.value
    property alias cfg_FontFamily:             fontFamilyCombo.currentText
    property alias cfg_FontScale:              fontScaleSlider.value

    // Tab 2: Panels & Layout
    property alias cfg_ShowMainTerminal:       showTerminalSwitch.checked
    property alias cfg_ShowLeftMediaPanel:     showMediaSwitch.checked
    property alias cfg_ShowLeftSensorPanel:    showSensorSwitch.checked
    property alias cfg_ShowRightNetworkPanel:  showNetworkSwitch.checked
    property alias cfg_ShowRightNotesPanel:    showNotesSwitch.checked
    property alias cfg_ShowRightControlsPanel: showControlsSwitch.checked
    property alias cfg_ShowLeftBookmarkBar:    showLauncherSwitch.checked
    property alias cfg_ShowTodoPanel:          showTodoSwitch.checked
    property alias cfg_ShowGitGridPanel:       showGitGridSwitch.checked
    property alias cfg_EditMode:               editModeSwitch.checked
    property alias cfg_HudOpacity:             hudOpacitySlider.value
    property alias cfg_PanelsLayoutJson:       panelsLayoutJsonField.text

    // Tab 3: App Launcher Dock
    property alias cfg_ShortcutIconPadding:    paddingSlider.value
    property alias cfg_ShortcutIconSize:       iconSizeSlider.value
    property alias cfg_ShortcutsJson:          shortcutsJsonField.text

    // Hidden trigger fields to notify Plasma of custom JSON edits
    QQC2.TextField {
        id: panelsLayoutJsonField
        visible: false
        text: "{}"
    }

    QQC2.TextField {
        id: shortcutsJsonField
        visible: false
        text: "[]"
        onTextChanged: {
            if (!root.syncingInternal) {
                root.reloadShortcutsModel()
            }
        }
    }

    // Shortcut management model & helpers
    property var shortcutsListModel: []
    property bool syncingInternal: false

    readonly property var defaultShortcutsList: [
        { name: "Dolphin",  cmd: "dolphin",                     icon: "system-file-manager" },
        { name: "Browser",  cmd: "xdg-open https://google.com", icon: "internet-web-browser" },
        { name: "Terminal", cmd: "konsole",                      icon: "utilities-terminal" },
        { name: "Settings", cmd: "systemsettings",               icon: "preferences-system" },
        { name: "Editor",   cmd: "antigravity-ide",              icon: "accessories-text-editor" },
        { name: "Monitor",  cmd: "plasma-systemmonitor",         icon: "utilities-system-monitor" }
    ]

    function reloadShortcutsModel() {
        var raw = shortcutsJsonField.text ? shortcutsJsonField.text.trim() : "";
        var parsed = [];
        if (raw && raw !== "[]" && raw !== "") {
            try {
                parsed = JSON.parse(raw);
            } catch (e) {
                parsed = [];
            }
        }
        if (!Array.isArray(parsed) || parsed.length === 0) {
            parsed = JSON.parse(JSON.stringify(defaultShortcutsList));
        }
        shortcutsListModel = parsed;
    }

    function saveShortcutsToConfig() {
        syncingInternal = true;
        shortcutsJsonField.text = JSON.stringify(shortcutsListModel);
        syncingInternal = false;
    }

    function addShortcut(name, cmd, icon) {
        var copy = [];
        for (var i = 0; i < shortcutsListModel.length; ++i) {
            copy.push(shortcutsListModel[i]);
        }
        copy.push({
            name: name,
            cmd: cmd,
            icon: icon
        });
        shortcutsListModel = copy;
        saveShortcutsToConfig();
    }

    function deleteShortcut(index) {
        if (index < 0 || index >= shortcutsListModel.length) return;
        var name = shortcutsListModel[index] ? shortcutsListModel[index].name : "Shortcut";
        var copy = [];
        for (var i = 0; i < shortcutsListModel.length; ++i) {
            if (i !== index) {
                copy.push(shortcutsListModel[i]);
            }
        }
        shortcutsListModel = copy;
        saveShortcutsToConfig();
        if (typeof shortcutActionStatusLabel !== "undefined") {
            shortcutActionStatusLabel.text = "✓ Removed \"" + name + "\". Click Apply to save.";
            shortcutActionStatusLabel.visible = true;
            shortcutStatusTimer.restart();
        }
    }

    function moveShortcut(fromIdx, toIdx) {
        if (fromIdx < 0 || fromIdx >= shortcutsListModel.length) return;
        if (toIdx < 0 || toIdx >= shortcutsListModel.length) return;
        var copy = [];
        for (var i = 0; i < shortcutsListModel.length; ++i) {
            copy.push(shortcutsListModel[i]);
        }
        var item = copy.splice(fromIdx, 1)[0];
        copy.splice(toIdx, 0, item);
        shortcutsListModel = copy;
        saveShortcutsToConfig();
    }

    function resetShortcutsToDefaults() {
        shortcutsListModel = JSON.parse(JSON.stringify(defaultShortcutsList));
        saveShortcutsToConfig();
        if (typeof shortcutActionStatusLabel !== "undefined") {
            shortcutActionStatusLabel.text = "✓ Reset to default shortcuts. Click Apply to save.";
            shortcutActionStatusLabel.visible = true;
            shortcutStatusTimer.restart();
        }
    }

    function addShortcutFromForm() {
        var name = newShortcutNameField.text.trim();
        var cmd = newShortcutCmdField.text.trim();
        var icon = newShortcutIconField.text.trim();
        if (!name || !cmd) return;
        if (!icon) {
            var firstWord = cmd.split(" ")[0].replace(/.*\//, "").toLowerCase();
            icon = firstWord || "application-x-executable";
        }

        addShortcut(name, cmd, icon);

        newShortcutNameField.text = "";
        newShortcutCmdField.text = "";
        newShortcutIconField.text = "";
        newShortcutNameField.forceActiveFocus();

        if (typeof shortcutActionStatusLabel !== "undefined") {
            shortcutActionStatusLabel.text = "✓ Added \"" + name + "\"! Click Apply to save.";
            shortcutActionStatusLabel.visible = true;
            shortcutStatusTimer.restart();
        }
    }

    Component.onCompleted: {
        reloadShortcutsModel();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Native File Chooser Dialog
    // ─────────────────────────────────────────────────────────────────────────
    FileDialog {
        id: imageFileDialog
        title: "Select Background Image"
        nameFilters: [
            "Image files (*.png *.jpg *.jpeg *.webp *.svg *.bmp)",
            "All files (*)"
        ]
        onAccepted: {
            var urlStr = imageFileDialog.selectedFile.toString()
            if (urlStr.indexOf("file://") === 0) {
                urlStr = urlStr.substring(7)
            }
            bgImageField.text = decodeURIComponent(urlStr)
        }
    }

    FileDialog {
        id: iconFileDialog
        title: "Select Shortcut Icon Image"
        nameFilters: [
            "Icon and image files (*.png *.svg *.xpm *.jpg *.jpeg *.webp)",
            "All files (*)"
        ]
        onAccepted: {
            var urlStr = iconFileDialog.selectedFile.toString()
            if (urlStr.indexOf("file://") === 0) {
                urlStr = urlStr.substring(7)
            }
            newShortcutIconField.text = decodeURIComponent(urlStr)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Tab Navigation Bar
    // ─────────────────────────────────────────────────────────────────────────
    QQC2.TabBar {
        id: navTabBar
        Layout.fillWidth: true
        currentIndex: 0

        QQC2.TabButton {
            text: "🎨 Wallpaper & Style"
            icon.name: "preferences-desktop-wallpaper"
        }
        QQC2.TabButton {
            text: "🪟 Panels & Layout"
            icon.name: "window-duplicate"
        }
        QQC2.TabButton {
            text: "🚀 App Launcher"
            icon.name: "favorites"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Tab Content Viewport
    // ─────────────────────────────────────────────────────────────────────────
    StackLayout {
        id: contentStack
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: navTabBar.currentIndex

        // ═════════════════════════════════════════════════════════════════════
        // TAB 1: 🎨 Wallpaper & Style
        // ═════════════════════════════════════════════════════════════════════
        Kirigami.FormLayout {
            id: tab1Layout

            // ── Background Image ──
            Kirigami.Separator {
                Kirigami.FormData.label: "Background Image"
                Kirigami.FormData.isSection: true
            }

            RowLayout {
                Kirigami.FormData.label: "Image Path:"
                Layout.fillWidth: true
                spacing: 6

                QQC2.TextField {
                    id: bgImageField
                    Layout.fillWidth: true
                    placeholderText: "No image selected (solid background color)"
                }

                QQC2.Button {
                    text: "Browse..."
                    icon.name: "document-open"
                    onClicked: imageFileDialog.open()
                }

                QQC2.Button {
                    text: "Clear"
                    icon.name: "edit-clear"
                    enabled: bgImageField.text !== ""
                    onClicked: bgImageField.text = ""
                }
            }

            // Thumbnail Preview (Visible only when an image path is present)
            Rectangle {
                Kirigami.FormData.label: "Preview:"
                visible: bgImageField.text !== ""
                Layout.preferredWidth: 260
                Layout.preferredHeight: 146
                color: bgColorButton.color
                radius: 4
                clip: true
                border.color: Qt.rgba(accentColorButton.color.r, accentColorButton.color.g, accentColorButton.color.b, 0.3)
                border.width: 1

                Image {
                    anchors.fill: parent
                    source: bgImageField.text !== "" ? bgImageField.text : ""
                    fillMode: {
                        if (fillModeCombo.currentIndex === 1) return Image.PreserveAspectFit
                        if (fillModeCombo.currentIndex === 2) return Image.Stretch
                        return Image.PreserveAspectCrop
                    }
                    smooth: true
                    asynchronous: true
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Image Visibility:"
                spacing: 8

                QQC2.Slider {
                    id: bgImageOpacitySlider
                    from: 0.0
                    to: 1.0
                    stepSize: 0.05
                    value: 0.15
                    Layout.preferredWidth: 220
                }
                QQC2.Label {
                    text: Math.round(bgImageOpacitySlider.value * 100) + "%"
                    Layout.preferredWidth: 40
                }
            }

            QQC2.ComboBox {
                id: fillModeCombo
                Kirigami.FormData.label: "Fill Mode:"
                Layout.preferredWidth: 260
                model: [
                    "Preserve Aspect Crop (Default)",
                    "Fit Screen with Borders",
                    "Stretch to Fill"
                ]
            }

            // ── Theme Palettes & Colors ──
            Kirigami.Separator {
                Kirigami.FormData.label: "Theme & Palette"
                Kirigami.FormData.isSection: true
            }

            QQC2.ComboBox {
                id: presetCombo
                Kirigami.FormData.label: "Preset Palette:"
                Layout.preferredWidth: 260
                textRole: "name"
                model: [
                    { name: "Cyberpunk Cyan (Default)", bg: "#08090d", accent: "#00f0ff", highlight: "#ff007f", grid: 0.0 },
                    { name: "Matrix Green",            bg: "#040b04", accent: "#33ff33", highlight: "#008800", grid: 0.0 },
                    { name: "Cobalt & Ice",             bg: "#050a12", accent: "#00a8ff", highlight: "#00e5ff", grid: 0.0 },
                    { name: "Classic Amber CRT",        bg: "#0a0600", accent: "#ffaa00", highlight: "#ff5500", grid: 0.0 },
                    { name: "Synthwave Sunset",         bg: "#120526", accent: "#ff007f", highlight: "#ffaa00", grid: 0.05 },
                    { name: "Ghost Chrome",             bg: "#000000", accent: "#ffffff", highlight: "#888888", grid: 0.0 }
                ]
                onActivated: {
                    var p = model[currentIndex]
                    bgColorButton.color = p.bg
                    accentColorButton.color = p.accent
                    highlightColorButton.color = p.highlight
                    gridSlider.value = p.grid
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Color Customization:"
                spacing: 16

                ColumnLayout {
                    spacing: 4
                    QQC2.Label { text: "Background"; font.pointSize: 8; opacity: 0.7 }
                    KQuickControls.ColorButton {
                        id: bgColorButton
                        showAlphaChannel: false
                        color: "#08090d"
                    }
                }

                ColumnLayout {
                    spacing: 4
                    QQC2.Label { text: "Accent"; font.pointSize: 8; opacity: 0.7 }
                    KQuickControls.ColorButton {
                        id: accentColorButton
                        showAlphaChannel: false
                        color: "#00f0ff"
                    }
                }

                ColumnLayout {
                    spacing: 4
                    QQC2.Label { text: "Highlight"; font.pointSize: 8; opacity: 0.7 }
                    KQuickControls.ColorButton {
                        id: highlightColorButton
                        showAlphaChannel: false
                        color: "#ff007f"
                    }
                }
            }

            // ── Backdrop & Style ──
            Kirigami.Separator {
                Kirigami.FormData.label: "Frame Style & Matrix Grid"
                Kirigami.FormData.isSection: true
            }

            QQC2.ComboBox {
                id: panelStyleCombo
                Kirigami.FormData.label: "Backdrop Style:"
                Layout.preferredWidth: 260
                model: [
                    "Cyber Wireframe (Default)",
                    "Glassmorphic Neon",
                    "Minimalist Flat",
                    "Tactical Chassis (Chamfered)",
                    "Stealth Void (0% Opacity)",
                    "Retro Phosphor CRT",
                    "Cyber Neumorphic"
                ]
            }

            Kirigami.Separator {
                Kirigami.FormData.label: "Overlays & Micro-Styles (Static 0% GPU)"
                Kirigami.FormData.isSection: true
            }

            QQC2.Switch {
                id: effectPrismBlurSwitch
                Kirigami.FormData.label: "Prism Glass Blur:"
                text: "Optical chromatic dispersion frosted glass blur"
                checked: false
            }

            QQC2.Switch {
                id: effectAsciiSwitch
                Kirigami.FormData.label: "ASCII Matrix Art:"
                text: "Contour-detecting 16-glyph ASCII matrix phosphor shader"
                checked: false
            }

            QQC2.Switch {
                id: effectHologramSwitch
                Kirigami.FormData.label: "Hologram Edges:"
                text: "Luminous neon gradient borders (top cyan, bottom magenta)"
                checked: false
            }

            QQC2.Switch {
                id: effectVignetteSwitch
                Kirigami.FormData.label: "Vignette Depth:"
                text: "Top and bottom dark radial gradients for visual contrast"
                checked: false
            }

            QQC2.Switch {
                id: effectCircuitSwitch
                Kirigami.FormData.label: "Circuit Board:"
                text: "Deterministic PCB traces, vias, and solder pad accents"
                checked: false
            }

            QQC2.Switch {
                id: effectScanlinesSwitch
                Kirigami.FormData.label: "CRT Interlace:"
                text: "Static 2px horizontal raster scanline texture overlay"
                checked: false
            }

            RowLayout {
                Kirigami.FormData.label: "Matrix Grid Opacity:"
                spacing: 8

                QQC2.Slider {
                    id: gridSlider
                    from: 0.0
                    to: 0.5
                    stepSize: 0.02
                    value: 0.0
                    Layout.preferredWidth: 220
                }
                QQC2.Label {
                    text: Math.round((gridSlider.value / 0.5) * 100) + "%"
                    Layout.preferredWidth: 40
                }
            }

            QQC2.ComboBox {
                id: fontFamilyCombo
                Kirigami.FormData.label: "Global Font:"
                Layout.preferredWidth: 260
                model: ["monospace", "Hack", "Fira Code", "JetBrains Mono", "Courier", "Sans Serif"]
            }

            RowLayout {
                Kirigami.FormData.label: "Font Scale:"
                spacing: 8

                QQC2.Slider {
                    id: fontScaleSlider
                    from: 0.7
                    to: 1.4
                    stepSize: 0.05
                    value: 1.0
                    Layout.preferredWidth: 220
                }
                QQC2.Label {
                    text: Math.round(fontScaleSlider.value * 100) + "%"
                    Layout.preferredWidth: 40
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // TAB 2: 🪟 Panels & Layout
        // ═════════════════════════════════════════════════════════════════════
        Kirigami.FormLayout {
            id: tab2Layout

            Kirigami.Separator {
                Kirigami.FormData.label: "Active HUD Panels"
                Kirigami.FormData.isSection: true
            }

            QQC2.Switch {
                id: showTerminalSwitch
                Kirigami.FormData.label: "Terminal Shell:"
                text: "Main Terminal Window (Native C++ GPU Console)"
                checked: true
            }

            QQC2.Switch {
                id: showMediaSwitch
                Kirigami.FormData.label: "Media Controller:"
                text: "Cyberpunk MPRIS Media Player & Audio Visualizer"
                checked: true
            }

            QQC2.Switch {
                id: showSensorSwitch
                Kirigami.FormData.label: "Hardware Telemetry:"
                text: "Live KSysGuard Sensors (CPU, GPU, RAM, Disk, Temperature)"
                checked: true
            }

            QQC2.Switch {
                id: showNetworkSwitch
                Kirigami.FormData.label: "Network Monitor:"
                text: "Real-time Download/Upload Bandwidth & Traffic Wave Graph"
                checked: true
            }

            QQC2.Switch {
                id: showNotesSwitch
                Kirigami.FormData.label: "Neural Scratchpad:"
                text: "Persistent Encrypted Notes Station"
                checked: true
            }

            QQC2.Switch {
                id: showControlsSwitch
                Kirigami.FormData.label: "Quick Deck Controls:"
                text: "Volume and Display Brightness Controller"
                checked: true
            }

            QQC2.Switch {
                id: showLauncherSwitch
                Kirigami.FormData.label: "App Launcher Dock:"
                text: "Quick Launch Application Dock Bar"
                checked: true
            }

            QQC2.Switch {
                id: showTodoSwitch
                Kirigami.FormData.label: "Task Directives:"
                text: "Cyberpunk Directives Todo Panel"
                checked: false
            }

            QQC2.Switch {
                id: showGitGridSwitch
                Kirigami.FormData.label: "Git Contribution Matrix:"
                text: "Git Activity Heatmap Grid and Repository Telemetry"
                checked: false
            }

            Kirigami.Separator {
                Kirigami.FormData.label: "Layout Positioning & Opacity"
                Kirigami.FormData.isSection: true
            }

            QQC2.Switch {
                id: editModeSwitch
                Kirigami.FormData.label: "Panel Placement:"
                text: "Unlock panels for free dragging and resizing on desktop"
                checked: false
            }

            RowLayout {
                Kirigami.FormData.label: "Reset Layout:"
                spacing: 8

                QQC2.Button {
                    text: "Reset All Panels to Default Positions"
                    icon.name: "edit-undo"
                    onClicked: {
                        panelsLayoutJsonField.text = "{}"
                        resetStatusLabel.visible = true
                    }
                }

                QQC2.Label {
                    id: resetStatusLabel
                    visible: false
                    text: "✓ Default layout queued! Click Apply to restore."
                    color: accentColorButton.color
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Master HUD Opacity:"
                spacing: 8

                QQC2.Slider {
                    id: hudOpacitySlider
                    from: 0.2
                    to: 1.0
                    stepSize: 0.05
                    value: 1.0
                    Layout.preferredWidth: 220
                }
                QQC2.Label {
                    text: Math.round(hudOpacitySlider.value * 100) + "%"
                    Layout.preferredWidth: 40
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // TAB 3: 🚀 App Launcher
        // ═════════════════════════════════════════════════════════════════════
        Kirigami.FormLayout {
            id: tab3Layout

            Kirigami.Separator {
                Kirigami.FormData.label: "Dock Appearance"
                Kirigami.FormData.isSection: true
            }

            RowLayout {
                Kirigami.FormData.label: "Icon Size:"
                spacing: 8

                QQC2.Slider {
                    id: iconSizeSlider
                    from: 24
                    to: 72
                    stepSize: 4
                    value: 48
                    Layout.preferredWidth: 220
                }
                QQC2.Label {
                    text: iconSizeSlider.value + " px"
                    Layout.preferredWidth: 40
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Icon Spacing:"
                spacing: 8

                QQC2.Slider {
                    id: paddingSlider
                    from: 6
                    to: 32
                    stepSize: 2
                    value: 16
                    Layout.preferredWidth: 220
                }
                QQC2.Label {
                    text: paddingSlider.value + " px"
                    Layout.preferredWidth: 40
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.label: "Configured Shortcuts"
                Kirigami.FormData.isSection: true
            }

            ColumnLayout {
                Kirigami.FormData.label: "Shortcuts (" + root.shortcutsListModel.length + "):"
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.shortcutsListModel

                    Rectangle {
                        id: shortcutCard
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 6
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
                        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            spacing: 10

                            // Icon preview box
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 4
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)
                                border.width: 1

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: {
                                        var ic = (shortcutCard.modelData && shortcutCard.modelData.icon) ? shortcutCard.modelData.icon : ""
                                        if (ic.indexOf("/") === 0) return "file://" + ic
                                        return ic || "application-x-executable"
                                    }
                                }
                            }

                            // Details (Name + Command + Icon name)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8
                                    QQC2.Label {
                                        text: (shortcutCard.modelData && shortcutCard.modelData.name) ? shortcutCard.modelData.name : "Unnamed"
                                        font.bold: true
                                        font.pointSize: 9
                                    }
                                    QQC2.Label {
                                        text: (shortcutCard.modelData && shortcutCard.modelData.icon) ? ("(" + shortcutCard.modelData.icon + ")") : ""
                                        font.pointSize: 8
                                        opacity: 0.5
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 160
                                    }
                                }

                                QQC2.Label {
                                    text: (shortcutCard.modelData && shortcutCard.modelData.cmd) ? shortcutCard.modelData.cmd : ""
                                    font.family: "monospace"
                                    font.pointSize: 8
                                    opacity: 0.75
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Reorder buttons (Move Up / Down)
                            QQC2.ToolButton {
                                icon.name: "go-up"
                                enabled: shortcutCard.index > 0
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: "Move Up"
                                onClicked: root.moveShortcut(shortcutCard.index, shortcutCard.index - 1)
                            }

                            QQC2.ToolButton {
                                icon.name: "go-down"
                                enabled: shortcutCard.index < root.shortcutsListModel.length - 1
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: "Move Down"
                                onClicked: root.moveShortcut(shortcutCard.index, shortcutCard.index + 1)
                            }

                            // Delete button
                            QQC2.Button {
                                icon.name: "edit-delete"
                                text: "Delete"
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: "Remove this shortcut"
                                onClicked: root.deleteShortcut(shortcutCard.index)
                            }
                        }
                    }
                }

                // Placeholder when list is empty
                Rectangle {
                    visible: root.shortcutsListModel.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    radius: 6
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    border.width: 1

                    QQC2.Label {
                        anchors.centerIn: parent
                        text: "No shortcuts configured. Add one below or click 'Reset to Defaults'."
                        opacity: 0.6
                        font.italic: true
                    }
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.label: "Add Shortcut"
                Kirigami.FormData.isSection: true
            }

            RowLayout {
                Kirigami.FormData.label: "Name:"
                Layout.fillWidth: true
                spacing: 8

                QQC2.TextField {
                    id: newShortcutNameField
                    Layout.fillWidth: true
                    placeholderText: "e.g. Firefox, Discord, Steam..."
                    onAccepted: {
                        if (newShortcutCmdField.text.trim() === "") {
                            newShortcutCmdField.forceActiveFocus()
                        } else {
                            root.addShortcutFromForm()
                        }
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Command:"
                Layout.fillWidth: true
                spacing: 8

                QQC2.TextField {
                    id: newShortcutCmdField
                    Layout.fillWidth: true
                    placeholderText: "e.g. firefox, /usr/bin/discord, code"
                    font.family: "monospace"
                    onAccepted: {
                        if (newShortcutIconField.text.trim() === "") {
                            newShortcutIconField.forceActiveFocus()
                        } else {
                            root.addShortcutFromForm()
                        }
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Icon:"
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 4
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    border.width: 1

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: {
                            var ic = newShortcutIconField.text.trim()
                            if (!ic) return "application-x-executable"
                            if (ic.indexOf("/") === 0) return "file://" + ic
                            return ic
                        }
                    }
                }

                QQC2.TextField {
                    id: newShortcutIconField
                    Layout.fillWidth: true
                    placeholderText: "e.g. firefox, discord, or /path/to/icon.png"
                    onAccepted: root.addShortcutFromForm()
                }

                QQC2.Button {
                    text: "Browse..."
                    icon.name: "document-open"
                    onClicked: iconFileDialog.open()
                }
            }

            RowLayout {
                Kirigami.FormData.label: " "
                spacing: 12

                QQC2.Button {
                    text: "Add Shortcut"
                    icon.name: "list-add"
                    enabled: newShortcutNameField.text.trim() !== "" && newShortcutCmdField.text.trim() !== ""
                    onClicked: root.addShortcutFromForm()
                }

                QQC2.Button {
                    text: "Reset to Defaults"
                    icon.name: "edit-undo"
                    onClicked: root.resetShortcutsToDefaults()
                }

                QQC2.Label {
                    id: shortcutActionStatusLabel
                    visible: false
                    text: ""
                    color: accentColorButton.color
                    font.bold: true

                    Timer {
                        id: shortcutStatusTimer
                        interval: 3500
                        onTriggered: shortcutActionStatusLabel.visible = false
                    }
                }
            }
        }
    }
}
