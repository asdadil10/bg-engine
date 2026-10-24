/*
 *  NerveCenter — TerminalWidget.qml
 *  Native C++ GPU-accelerated Console with auto-session management.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts

NervePanel {
    id: termWidget
    panelId: "mainTerminal"
    title: "SYSTEM_CONSOLE // NATIVE_GPU_CORE"
    subLabel: "[NATIVE_SESSION]"

    minWidth: 260
    minHeight: 180
    focus: true

    // Header Actions: Reboot Button
    headerActions: [
        Rectangle {
            Layout.preferredWidth: 48; Layout.preferredHeight: 15
            radius: termWidget.buttonRadius
            color: rebootMa.containsMouse ? Qt.rgba(termWidget.highlightColor.r, termWidget.highlightColor.g, termWidget.highlightColor.b, 0.18) : "transparent"
            border.color: termWidget.highlightColor
            border.width: 1
            opacity: rebootMa.containsMouse ? 1.0 : 0.85
            Text {
                anchors.centerIn: parent
                text: "REBOOT"
                color: termWidget.highlightColor
                font.family: termWidget.fontFamily
                font.pixelSize: Math.round(7.5 * termWidget.fontScale)
                font.bold: true
            }
            MouseArea {
                id: rebootMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    termLoader.source = ""
                    reloadTimer.start()
                }
            }
        }
    ]

    // Automatic Native Session re-instantiator
    Timer {
        id: reloadTimer
        interval: 1000
        repeat: false
        onTriggered: {
            termLoader.source = "QmlTermView.qml"
        }
    }

    onActiveFocusChanged: {
        if (activeFocus && termLoader.item) {
            termLoader.item.forceActiveFocus()
        }
    }

    Item {
        id: outputContainer
        anchors.fill: parent

        Loader {
            id: termLoader
            anchors.fill: parent
            source: "QmlTermView.qml"
            focus: true
            
            property color loaderAccentColor: termWidget.accentColor

            Connections {
                target: termLoader.item
                ignoreUnknownSignals: true
                function onSessionFinished() {
                    termLoader.source = ""
                    reloadTimer.start()
                }
            }
        }
    }
}
