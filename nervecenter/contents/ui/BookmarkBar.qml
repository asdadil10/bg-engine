/*
 *  NerveCenter — BookmarkBar.qml
 *  Launchpad: quick app grid with independent icon pack selection.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import QtCore
import "IconDatabase.js" as IconDB

NervePanel {
    id: bookmarkRoot
    panelId: "leftBookmarkBar"
    title: "LAUNCHPAD // SHORTCUTS"
    subLabel: (shortcutModel && shortcutModel.length ? shortcutModel.length : defaultShortcuts.length) + " APPS"

    minWidth: 160
    minHeight: 120

    property int shortcutIconPadding: 16
    property int iconSize: 48

    property var shortcutModel: []
    property var defaultShortcuts: [
        { name: "Dolphin",  cmd: "dolphin",                      icon: "system-file-manager" },
        { name: "Browser",  cmd: "xdg-open https://google.com",  icon: "internet-web-browser" },
        { name: "Terminal", cmd: "konsole",                       icon: "utilities-terminal" },
        { name: "Settings", cmd: "systemsettings",                icon: "preferences-system" },
        { name: "Editor",   cmd: "kate",                          icon: "accessories-text-editor" },
        { name: "Monitor",  cmd: "plasma-systemmonitor",          icon: "utilities-system-monitor" }
    ]

    // ── Persistent Icon Pack Selection ──
    Settings {
        id: launchpadSettings
        category: "Launchpad"
        property string selectedIconPack: "System Default"
    }

    property string selectedIconPack: launchpadSettings.selectedIconPack || "System Default"

    // ── Dynamic icon pack discovery (icon_scanner.py) ──
    property var iconMap: ({})          // pack -> { iconName: "file:///..." }
    property var scannedPacks: []       // packs actually installed on this system
    property bool scanDone: false
    property string scanCmd: ""

    readonly property var fallbackPacks: [
        "System Default", "Tela", "Tela-circle", "Fluent", "Win11-black",
        "kora", "Deepin2022-Dark", "breeze", "Adwaita"
    ]
    readonly property var availableIconPacks:
        (scanDone && scannedPacks.length > 0) ? ["System Default"].concat(scannedPacks) : fallbackPacks

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    function collectIconNames() {
        var src = (shortcutModel && shortcutModel.length > 0) ? shortcutModel : defaultShortcuts;
        var seen = {}, out = [];
        for (var i = 0; i < src.length; ++i) {
            var n = src[i] ? src[i].icon : "";
            if (n && n.charAt(0) !== "/" && !seen[n]) { seen[n] = true; out.push(n); }
        }
        return out;
    }

    function runScan() {
        var names = collectIconNames();
        if (names.length === 0) return;
        var script = decodeURIComponent(Qt.resolvedUrl("icon_scanner.py").toString().replace(/^file:\/\//, ""));
        var cmd = "python3 " + shq(script) + " " + names.map(shq).join(" ");
        if (scanCmd !== "") scanner.disconnectSource(scanCmd);
        scanCmd = cmd;
        scanner.connectSource(cmd);
    }

    function applyScan(text) {
        try {
            var parsed = JSON.parse(text);
            iconMap = parsed.map || {};
            scannedPacks = parsed.packs || [];
            scanDone = true;
            if (selectedIconPack !== "System Default" && scannedPacks.indexOf(selectedIconPack) < 0)
                selectedIconPack = "System Default";
            updateModel();
        } catch (e) {
            console.log("icon_scanner: could not parse output:", e, text);
        }
    }

    function resolveIconFor(pack, name) {
        if (!name) return "";
        if (name.charAt(0) === "/") return "file://" + name;
        if (pack === "System Default") return name;
        var m = iconMap[pack];
        if (m && m[name]) return m[name];
        if (!scanDone) return IconDB.resolveIcon(pack, name);   // static fallback until scan returns
        return name;                                            // not in this pack -> system theme
    }

    function selectPack(packName) {
        selectedIconPack = packName;
        launchpadSettings.selectedIconPack = packName;
        updateModel();
    }

    function cycleNextPack() {
        var idx = availableIconPacks.indexOf(selectedIconPack);
        if (idx === -1) idx = 0;
        var nextIdx = (idx + 1) % availableIconPacks.length;
        selectPack(availableIconPacks[nextIdx]);
    }

    function cyclePrevPack() {
        var idx = availableIconPacks.indexOf(selectedIconPack);
        if (idx === -1) idx = 0;
        var prevIdx = (idx - 1 + availableIconPacks.length) % availableIconPacks.length;
        selectPack(availableIconPacks[prevIdx]);
    }

    Component.onCompleted: { updateModel(); runScan(); }
    onShortcutModelChanged: { updateModel(); runScan(); }

    function updateModel() {
        var src = (shortcutModel && shortcutModel.length > 0) ? shortcutModel : defaultShortcuts;
        var arr = [];
        for (var i = 0; i < src.length; ++i) {
            arr.push(src[i]);
        }
        if (shortcutList) {
            shortcutList.model = null;
            shortcutList.model = arr;
        }
    }

    P5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: function(s) { disconnectSource(s); }
    }

    P5Support.DataSource {
        id: scanner
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source);
            bookmarkRoot.applyScan(data["stdout"]);
        }
    }

    // ── Header Actions: High-Reliability Independent Icon Pack Switcher ──
    headerActions: [
        // Prev button
        Rectangle {
            id: prevBtn
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            radius: bookmarkRoot.buttonRadius
            color: prevMa.containsMouse ? Qt.rgba(bookmarkRoot.highlightColor.r, bookmarkRoot.highlightColor.g, bookmarkRoot.highlightColor.b, 0.25)
                                        : Qt.rgba(bookmarkRoot.accentColor.r, bookmarkRoot.accentColor.g, bookmarkRoot.accentColor.b, 0.10)
            border.color: prevMa.containsMouse ? bookmarkRoot.highlightColor
                                               : Qt.rgba(bookmarkRoot.accentColor.r, bookmarkRoot.accentColor.g, bookmarkRoot.accentColor.b, bookmarkRoot.hudBorderOpacity)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "◂"
                color: prevMa.containsMouse ? bookmarkRoot.highlightColor : bookmarkRoot.accentColor
                font.pixelSize: 9
                font.bold: true
            }

            MouseArea {
                id: prevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bookmarkRoot.cyclePrevPack()
            }
        },

        // Pack Name Pill (Clicking switches to next pack, right-click/wheel cycles)
        Rectangle {
            id: packPill
            Layout.preferredHeight: 16
            Layout.preferredWidth: packLabel.implicitWidth + 14
            radius: bookmarkRoot.buttonRadius
            color: packMa.containsMouse ? Qt.rgba(bookmarkRoot.highlightColor.r, bookmarkRoot.highlightColor.g, bookmarkRoot.highlightColor.b, 0.25)
                                        : Qt.rgba(bookmarkRoot.accentColor.r, bookmarkRoot.accentColor.g, bookmarkRoot.accentColor.b, 0.10)
            border.color: packMa.containsMouse ? bookmarkRoot.highlightColor
                                               : Qt.rgba(bookmarkRoot.accentColor.r, bookmarkRoot.accentColor.g, bookmarkRoot.accentColor.b, bookmarkRoot.hudBorderOpacity)
            border.width: 1

            Text {
                id: packLabel
                anchors.centerIn: parent
                text: "PACK: " + (bookmarkRoot.selectedIconPack === "System Default" ? "SYSTEM" : bookmarkRoot.selectedIconPack.toUpperCase())
                color: packMa.containsMouse ? bookmarkRoot.highlightColor : bookmarkRoot.accentColor
                font.family: bookmarkRoot.fontFamily
                font.pixelSize: Math.round(7.5 * bookmarkRoot.fontScale)
                font.bold: true
            }

            MouseArea {
                id: packMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) bookmarkRoot.cyclePrevPack();
                    else bookmarkRoot.cycleNextPack();
                }
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0) bookmarkRoot.cyclePrevPack();
                    else bookmarkRoot.cycleNextPack();
                }
            }
        },

        // Next button
        Rectangle {
            id: nextBtn
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            radius: bookmarkRoot.buttonRadius
            color: nextMa.containsMouse ? Qt.rgba(bookmarkRoot.highlightColor.r, bookmarkRoot.highlightColor.g, bookmarkRoot.highlightColor.b, 0.25)
                                        : Qt.rgba(bookmarkRoot.accentColor.r, bookmarkRoot.accentColor.g, bookmarkRoot.accentColor.b, 0.10)
            border.color: nextMa.containsMouse ? bookmarkRoot.highlightColor
                                               : Qt.rgba(bookmarkRoot.accentColor.r, bookmarkRoot.accentColor.g, bookmarkRoot.accentColor.b, bookmarkRoot.hudBorderOpacity)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "▸"
                color: nextMa.containsMouse ? bookmarkRoot.highlightColor : bookmarkRoot.accentColor
                font.pixelSize: 9
                font.bold: true
            }

            MouseArea {
                id: nextMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bookmarkRoot.cycleNextPack()
            }
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Shortcut grid (Icons scaled 100%, without tile background or borders)
        GridView {
            id: shortcutList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: []
            property int minCellWidth: bookmarkRoot.iconSize + (bookmarkRoot.shortcutIconPadding * 2)
            property int columnsCount: Math.max(1, Math.floor(width / minCellWidth))
            cellWidth: Math.floor(width / columnsCount)
            cellHeight: cellWidth
            clip: true

            delegate: Item {
                id: btn
                required property var modelData
                required property int index
                width: shortcutList.cellWidth
                height: shortcutList.cellHeight

                readonly property string resolved: bookmarkRoot.resolveIconFor(
                    bookmarkRoot.selectedIconPack, btn.modelData ? btn.modelData.icon : "")
                readonly property bool isFile: resolved.indexOf("file://") === 0

                Component {
                    id: fileIconComp
                    Image {
                        source: btn.resolved
                        sourceSize: Qt.size(bookmarkRoot.iconSize * 2, bookmarkRoot.iconSize * 2)
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        smooth: true
                    }
                }
                Component {
                    id: themeIconComp
                    Kirigami.Icon { source: btn.resolved }
                }

                Loader {
                    id: iconLoader
                    anchors.centerIn: parent
                    width: bookmarkRoot.iconSize
                    height: bookmarkRoot.iconSize
                    sourceComponent: btn.isFile ? fileIconComp : themeIconComp
                    opacity: ma.pressed ? 0.65 : (ma.containsMouse ? 1.0 : 0.88)
                    scale: ma.pressed ? 0.92 : (ma.containsMouse ? 1.10 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    // Rebuild the icon item whenever the pack changes
                    Connections {
                        target: bookmarkRoot
                        function onSelectedIconPackChanged() {
                            iconLoader.sourceComponent = null
                            iconLoader.sourceComponent = Qt.binding(function() {
                                return btn.isFile ? fileIconComp : themeIconComp
                            })
                        }
                    }
                }

                // Interactive trigger covering entire cell
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (btn.modelData && btn.modelData.cmd)
                            launcher.connectSource(btn.modelData.cmd + " >/dev/null 2>&1 &");
                    }
                }
            }
        }
    }
}
