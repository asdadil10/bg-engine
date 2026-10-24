/*
 *  NerveCenter — NervePanel.qml
 *  Master 10/10 Standard Base Component for all NerveCenter HUD panels and plugins.
 *  
 *  Provides an effortless, intuitive standard for panel creation:
 *    • Built-in NerveFrame visual backdrop (cyber wireframe, glass blur, effects)
 *    • Standard HUD Titlebar with status LED and breadcrumb sublabel
 *    • Fixed docked coordinate clamping outside Edit Mode (prevents accidental drags)
 *    • Interactive Edit Mode: 8-point edge/corner resizing and grid snapping (16px)
 *    • Click elevation (brings active panel to top of z-stack during edit)
 *    • Automatic theme & context inheritance (accentColor, highlightColor, fonts)
 *    • Safe inset content area (contentMargins prevents clipping with corner brackets)
 *    • Power-saving lifecycle flag (isPanelActive)
 */
import QtQuick
import QtQuick.Layouts

Item {
    id: panelRoot

    // ═══════════════════════════════════════════════════════════
    //  1. IDENTIFICATION & METADATA
    // ═══════════════════════════════════════════════════════════
    property string panelId: "panel"
    property string title: ""
    property string subLabel: ""
    property string status: "nominal" // "nominal", "active", "warning", "critical", "offline"

    // Fixed docked states (no manual lock/unlock or collapse)
    readonly property bool isLocked: !panelRoot.editMode
    readonly property bool isStowed: false

    property bool showTitlebar: true
    property bool showCloseButton: false
    property int titlebarHeight: 24

    // Frame styling
    property bool showFrame: true
    property int contentMargins: showFrame ? 10 : 0

    // ── Dynamic Style & Theme Awareness (Tokens for child panels & plugins) ──
    readonly property int panelStyle: visualFrame.activePanelStyle // 0: Wireframe, 1: Glassmorphic, 2: Minimalist
    readonly property int cardRadius: panelStyle === 1 ? 6 : (panelStyle === 2 ? 4 : 1)
    readonly property int buttonRadius: panelStyle === 1 ? 4 : (panelStyle === 2 ? 3 : 1)
    readonly property int titlebarRadius: panelStyle === 1 ? 6 : (panelStyle === 2 ? 3 : 1)
    readonly property real hudBorderOpacity: panelStyle === 1 ? 0.35 : 0.22

    // ═══════════════════════════════════════════════════════════
    //  2. THEME & CONTEXT AUTO-INHERITANCE
    // ═══════════════════════════════════════════════════════════
    property color accentColor: {
        if (panelRoot.parent && panelRoot.parent.accentColor !== undefined) return panelRoot.parent.accentColor;
        if (typeof root !== "undefined" && root.accentColor !== undefined) return root.accentColor;
        return "#00f0ff";
    }
    property color highlightColor: {
        if (panelRoot.parent && panelRoot.parent.highlightColor !== undefined) return panelRoot.parent.highlightColor;
        if (typeof root !== "undefined" && root.highlightColor !== undefined) return root.highlightColor;
        return "#ff007f";
    }
    readonly property string fontFamily: {
        if (panelRoot.parent && panelRoot.parent.globalFontFamily !== undefined) return panelRoot.parent.globalFontFamily;
        if (typeof root !== "undefined" && root.globalFontFamily !== undefined) return root.globalFontFamily;
        return "monospace";
    }
    readonly property real fontScale: {
        if (panelRoot.parent && panelRoot.parent.globalFontScale !== undefined) return panelRoot.parent.globalFontScale;
        if (typeof root !== "undefined" && root.globalFontScale !== undefined) return root.globalFontScale;
        return 1.0;
    }

    // Helper for DPI/font scaling
    function px(n) { return Math.round(n * fontScale); }

    property bool editMode: {
        if (panelRoot.parent && panelRoot.parent.editMode !== undefined) return panelRoot.parent.editMode;
        if (typeof root !== "undefined" && root.editMode !== undefined) return root.editMode;
        return false;
    }

    property var layoutState: {
        if (panelRoot.parent && panelRoot.parent.layoutState !== undefined) return panelRoot.parent.layoutState;
        if (typeof root !== "undefined" && root.layoutState !== undefined) return root.layoutState;
        return ({});
    }

    // ═══════════════════════════════════════════════════════════
    //  3. SIZING CONSTRAINTS & GRID DEFAULTS
    // ═══════════════════════════════════════════════════════════
    property int minWidth: 160
    property int minHeight: showTitlebar ? (titlebarHeight + (contentMargins * 2) + 24) : 48
    property int maxWidth: 9999
    property int maxHeight: 9999

    property int defaultX: 0
    property int defaultY: 0
    property int defaultW: 300
    property int defaultH: 200
    property int gridSize: 16

    // ═══════════════════════════════════════════════════════════
    //  4. LIFECYCLE & SIGNALS
    // ═══════════════════════════════════════════════════════════
    readonly property bool isPanelActive: visible && opacity > 0
    signal requestSaveState()
    signal requestClose()

    // ═══════════════════════════════════════════════════════════
    //  5. GEOMETRY PERSISTENCE & POSITION BINDINGS
    // ═══════════════════════════════════════════════════════════
    readonly property bool isInteracting: (
        dragMa.pressed || titleDragMa.pressed ||
        rightResizeMa.pressed || leftResizeMa.pressed ||
        bottomResizeMa.pressed || topResizeMa.pressed ||
        brResizeMa.pressed || blResizeMa.pressed ||
        trResizeMa.pressed || tlResizeMa.pressed
    )

    Binding on x {
        value: {
            var val = (layoutState && layoutState[panelId] && layoutState[panelId].x !== undefined) ? layoutState[panelId].x : defaultX;
            return Math.round(val / gridSize) * gridSize;
        }
        when: !isInteracting
        restoreMode: Binding.RestoreBinding
    }

    Binding on y {
        value: {
            var val = (layoutState && layoutState[panelId] && layoutState[panelId].y !== undefined) ? layoutState[panelId].y : defaultY;
            return Math.round(val / gridSize) * gridSize;
        }
        when: !isInteracting
        restoreMode: Binding.RestoreBinding
    }

    Binding on width {
        value: {
            var val = (layoutState && layoutState[panelId] && layoutState[panelId].width !== undefined) ? layoutState[panelId].width : defaultW;
            return Math.max(minWidth, Math.min(maxWidth, Math.round(val / gridSize) * gridSize));
        }
        when: !isInteracting
        restoreMode: Binding.RestoreBinding
    }

    Binding on height {
        value: {
            var val = (layoutState && layoutState[panelId] && layoutState[panelId].height !== undefined) ? layoutState[panelId].height : defaultH;
            return Math.max(minHeight, Math.min(maxHeight, Math.round(val / gridSize) * gridSize));
        }
        when: !isInteracting
        restoreMode: Binding.RestoreBinding
    }

    function flushState() {
        if (!layoutState) return;
        if (!layoutState[panelId]) layoutState[panelId] = {};
        layoutState[panelId].x = panelRoot.x;
        layoutState[panelId].y = panelRoot.y;
        layoutState[panelId].width = panelRoot.width;
        layoutState[panelId].height = panelRoot.height;
        requestSaveState();
    }

    // Elevate panel to the top of the z-stack when interacted with
    function elevate() {
        if (panelRoot.parent && panelRoot.parent.children) {
            var maxZ = panelRoot.z;
            for (var i = 0; i < panelRoot.parent.children.length; i++) {
                var c = panelRoot.parent.children[i];
                if (c !== root && c.z !== undefined && c.z >= maxZ) {
                    maxZ = c.z;
                }
            }
            panelRoot.z = maxZ + 1;
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  6. CONTENT SLOTS
    // ═══════════════════════════════════════════════════════════
    default property alias content: innerContentSlot.data
    property list<Item> headerActions

    // ═══════════════════════════════════════════════════════════
    //  7. BUILT-IN NERVEFRAME BACKDROP
    // ═══════════════════════════════════════════════════════════
    NerveFrame {
        id: visualFrame
        anchors.fill: parent
        visible: panelRoot.showFrame
        accentColor: panelRoot.accentColor
        highlightColor: panelRoot.highlightColor
        z: 0
    }

    // Main Column: Titlebar + Safe Content Viewport
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: panelRoot.contentMargins
        spacing: 2
        z: 1

        // ── Standard HUD Titlebar ──
        Rectangle {
            id: titlebarArea
            Layout.fillWidth: true
            Layout.preferredHeight: panelRoot.titlebarHeight
            visible: panelRoot.showTitlebar
            radius: panelRoot.titlebarRadius
            color: Qt.rgba(panelRoot.accentColor.r, panelRoot.accentColor.g, panelRoot.accentColor.b, panelRoot.panelStyle === 1 ? 0.12 : 0.08)
            border.color: Qt.rgba(panelRoot.accentColor.r, panelRoot.accentColor.g, panelRoot.accentColor.b, panelRoot.hudBorderOpacity)
            border.width: 1

            // Drag handle via Titlebar (Active when in Edit Mode)
            MouseArea {
                id: titleDragMa
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                enabled: panelRoot.editMode
                cursorShape: pressed ? Qt.ClosedHandCursor : (panelRoot.editMode ? Qt.OpenHandCursor : Qt.ArrowCursor)

                property real startX
                property real startY
                property real startRootX
                property real startRootY

                onPressed: function(mouse) {
                    panelRoot.elevate();
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    startX = p.x; startY = p.y;
                    startRootX = panelRoot.x; startRootY = panelRoot.y;
                }
                onPositionChanged: function(mouse) {
                    if (pressed && panelRoot.parent) {
                        var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                        var newX = Math.round((startRootX + (p.x - startX)) / gridSize) * gridSize;
                        var newY = Math.round((startRootY + (p.y - startY)) / gridSize) * gridSize;
                        panelRoot.x = Math.max(0, Math.min(panelRoot.parent.width - panelRoot.width, newX));
                        panelRoot.y = Math.max(0, Math.min(panelRoot.parent.height - panelRoot.height, newY));
                    }
                }
                onReleased: panelRoot.flushState()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                // Status LED
                Rectangle {
                    Layout.preferredWidth: 6; Layout.preferredHeight: 6
                    radius: 3
                    color: {
                        switch (panelRoot.status) {
                            case "nominal": return panelRoot.accentColor;
                            case "active": return panelRoot.highlightColor;
                            case "warning": return Qt.rgba(1.0, 0.7, 0.0, 1.0);
                            case "critical": return "#ff2244";
                            default: return Qt.rgba(panelRoot.accentColor.r, panelRoot.accentColor.g, panelRoot.accentColor.b, 0.35);
                        }
                    }
                }

                // Title
                Text {
                    text: panelRoot.title.length > 0 ? panelRoot.title.toUpperCase() : panelRoot.panelId.toUpperCase()
                    color: panelRoot.accentColor
                    font.family: panelRoot.fontFamily
                    font.pixelSize: Math.round(10 * panelRoot.fontScale)
                    font.bold: true
                    font.letterSpacing: 1.2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // SubLabel Pill
                Text {
                    text: panelRoot.subLabel
                    visible: panelRoot.subLabel.length > 0 && panelRoot.width > 240
                    color: Qt.rgba(panelRoot.accentColor.r, panelRoot.accentColor.g, panelRoot.accentColor.b, 0.6)
                    font.family: panelRoot.fontFamily
                    font.pixelSize: Math.round(8 * panelRoot.fontScale)
                }

                // Custom Header Actions Slot
                RowLayout {
                    id: customActionsSlot
                    spacing: 4
                    data: panelRoot.headerActions
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 14; Layout.preferredHeight: 14
                    color: "transparent"
                    visible: panelRoot.showCloseButton
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: panelRoot.highlightColor
                        font.pixelSize: 9
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelRoot.requestClose()
                    }
                }
            }
        }

        // ── Inset Safe Content Viewport ──
        Item {
            id: innerContentSlot
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: true
            clip: true
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  8. EDIT MODE OVERLAY & INTERACTION HANDLERS
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: editOverlay
        anchors.fill: parent
        color: "transparent"
        border.color: panelRoot.editMode ? panelRoot.accentColor : "transparent"
        border.width: panelRoot.editMode ? 1.5 : 0
        z: 9999
        visible: panelRoot.editMode

        // Background Drag Handle (Edit Mode only)
        MouseArea {
            id: dragMa
            anchors.fill: parent
            anchors.margins: 12
            enabled: panelRoot.editMode
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real startX
            property real startY
            property real startRootX
            property real startRootY

            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startX = p.x; startY = p.y;
                startRootX = panelRoot.x; startRootY = panelRoot.y;
            }
            onPositionChanged: function(mouse) {
                if (pressed && panelRoot.parent) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    var newX = Math.round((startRootX + (p.x - startX)) / gridSize) * gridSize;
                    var newY = Math.round((startRootY + (p.y - startY)) / gridSize) * gridSize;
                    panelRoot.x = Math.max(0, Math.min(panelRoot.parent.width - panelRoot.width, newX));
                    panelRoot.y = Math.max(0, Math.min(panelRoot.parent.height - panelRoot.height, newY));
                }
            }
            onReleased: panelRoot.flushState()
        }

        // ── 8-POINT RESIZE HANDLERS ──

        // RIGHT edge
        MouseArea {
            id: rightResizeMa
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 12; anchors.bottomMargin: 12
            width: 8
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeHorCursor

            property real startX
            property real startRootW
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startX = p.x; startRootW = panelRoot.width;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    var targetW = startRootW + (p.x - startX);
                    panelRoot.width = Math.max(minWidth, Math.min(maxWidth, Math.round(targetW / gridSize) * gridSize));
                }
            }
            onReleased: panelRoot.flushState()
        }

        // LEFT edge
        MouseArea {
            id: leftResizeMa
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 12; anchors.bottomMargin: 12
            width: 8
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeHorCursor

            property real startX
            property real startRootX
            property real startRootW
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startX = p.x; startRootX = panelRoot.x; startRootW = panelRoot.width;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    var newX = Math.round((startRootX + (p.x - startX)) / gridSize) * gridSize;
                    var newW = startRootX + startRootW - newX;
                    if (newW >= minWidth && newW <= maxWidth && newX >= 0) {
                        panelRoot.x = newX;
                        panelRoot.width = newW;
                    }
                }
            }
            onReleased: panelRoot.flushState()
        }

        // BOTTOM edge
        MouseArea {
            id: bottomResizeMa
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12; anchors.rightMargin: 12
            height: 8
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeVerCursor

            property real startY
            property real startRootH
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startY = p.y; startRootH = panelRoot.height;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    var targetH = startRootH + (p.y - startY);
                    panelRoot.height = Math.max(minHeight, Math.min(maxHeight, Math.round(targetH / gridSize) * gridSize));
                }
            }
            onReleased: panelRoot.flushState()
        }

        // TOP edge
        MouseArea {
            id: topResizeMa
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12; anchors.rightMargin: 12
            height: 8
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeVerCursor

            property real startY
            property real startRootY
            property real startRootH
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startY = p.y; startRootY = panelRoot.y; startRootH = panelRoot.height;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    var newY = Math.round((startRootY + (p.y - startY)) / gridSize) * gridSize;
                    var newH = startRootY + startRootH - newY;
                    if (newH >= minHeight && newH <= maxHeight && newY >= 0) {
                        panelRoot.y = newY;
                        panelRoot.height = newH;
                    }
                }
            }
            onReleased: panelRoot.flushState()
        }

        // BOTTOM-RIGHT corner (Dual axis)
        MouseArea {
            id: brResizeMa
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 14; height: 14
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeFDiagCursor

            Rectangle { anchors.fill: parent; color: panelRoot.accentColor; opacity: 0.8 }

            property real startX
            property real startY
            property real startRootW
            property real startRootH
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startX = p.x; startY = p.y;
                startRootW = panelRoot.width; startRootH = panelRoot.height;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    panelRoot.width = Math.max(minWidth, Math.min(maxWidth, Math.round((startRootW + (p.x - startX)) / gridSize) * gridSize));
                    panelRoot.height = Math.max(minHeight, Math.min(maxHeight, Math.round((startRootH + (p.y - startY)) / gridSize) * gridSize));
                }
            }
            onReleased: panelRoot.flushState()
        }

        // BOTTOM-LEFT corner
        MouseArea {
            id: blResizeMa
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 14; height: 14
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeBDiagCursor

            Rectangle { anchors.fill: parent; color: panelRoot.accentColor; opacity: 0.8 }

            property real startX
            property real startY
            property real startRootX
            property real startRootW
            property real startRootH
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startX = p.x; startY = p.y;
                startRootX = panelRoot.x; startRootW = panelRoot.width; startRootH = panelRoot.height;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    var newX = Math.round((startRootX + (p.x - startX)) / gridSize) * gridSize;
                    var newW = startRootX + startRootW - newX;
                    if (newW >= minWidth && newW <= maxWidth && newX >= 0) {
                        panelRoot.x = newX;
                        panelRoot.width = newW;
                    }
                    panelRoot.height = Math.max(minHeight, Math.min(maxHeight, Math.round((startRootH + (p.y - startY)) / gridSize) * gridSize));
                }
            }
            onReleased: panelRoot.flushState()
        }

        // TOP-RIGHT corner
        MouseArea {
            id: trResizeMa
            anchors.top: parent.top
            anchors.right: parent.right
            width: 14; height: 14
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeBDiagCursor

            Rectangle { anchors.fill: parent; color: panelRoot.accentColor; opacity: 0.8 }

            property real startX
            property real startY
            property real startRootY
            property real startRootW
            property real startRootH
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startX = p.x; startY = p.y;
                startRootY = panelRoot.y; startRootW = panelRoot.width; startRootH = panelRoot.height;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    panelRoot.width = Math.max(minWidth, Math.min(maxWidth, Math.round((startRootW + (p.x - startX)) / gridSize) * gridSize));
                    var newY = Math.round((startRootY + (p.y - startY)) / gridSize) * gridSize;
                    var newH = startRootY + startRootH - newY;
                    if (newH >= minHeight && newH <= maxHeight && newY >= 0) {
                        panelRoot.y = newY;
                        panelRoot.height = newH;
                    }
                }
            }
            onReleased: panelRoot.flushState()
        }

        // TOP-LEFT corner
        MouseArea {
            id: tlResizeMa
            anchors.top: parent.top
            anchors.left: parent.left
            width: 14; height: 14
            enabled: panelRoot.editMode
            cursorShape: Qt.SizeFDiagCursor

            Rectangle { anchors.fill: parent; color: panelRoot.accentColor; opacity: 0.8 }

            property real startX
            property real startY
            property real startRootX
            property real startRootY
            property real startRootW
            property real startRootH
            onPressed: function(mouse) {
                panelRoot.elevate();
                var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                startX = p.x; startY = p.y;
                startRootX = panelRoot.x; startRootY = panelRoot.y;
                startRootW = panelRoot.width; startRootH = panelRoot.height;
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var p = mapToItem(panelRoot.parent, mouse.x, mouse.y);
                    var newX = Math.round((startRootX + (p.x - startX)) / gridSize) * gridSize;
                    var newW = startRootX + startRootW - newX;
                    if (newW >= minWidth && newW <= maxWidth && newX >= 0) {
                        panelRoot.x = newX;
                        panelRoot.width = newW;
                    }
                    var newY = Math.round((startRootY + (p.y - startY)) / gridSize) * gridSize;
                    var newH = startRootY + startRootH - newY;
                    if (newH >= minHeight && newH <= maxHeight && newY >= 0) {
                        panelRoot.y = newY;
                        panelRoot.height = newH;
                    }
                }
            }
            onReleased: panelRoot.flushState()
        }
    }
}
