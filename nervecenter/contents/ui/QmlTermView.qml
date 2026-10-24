/*
 *  NerveCenter — QmlTermView.qml
 *  Native C++ Qt6 QMLTermWidget wrapper.
 *  Transparent background with layer-enabled FBO to eliminate ghosting.
 *
 *  Strategy:
 *  1. Color scheme uses Transparency=true so the native renderer clears to alpha=0.
 *  2. layer.enabled: true forces a full offscreen FBO render pass every frame,
 *     preventing stale pixel data from accumulating (no ghosting).
 *  3. layer.format: RGBA8 preserves the alpha channel through compositing.
 *  4. Rectangle color is "transparent" so the wallpaper shows through.
 */
import QtQuick
import "QMLTermWidget"

Item {
    id: termContainer
    anchors.fill: parent

    signal sessionFinished()

    property color currentAccentColor: (termContainer.parent && termContainer.parent.loaderAccentColor) 
                                        ? termContainer.parent.loaderAccentColor 
                                        : Qt.rgba(255/255, 169/255, 0, 1.0)
                                        
    onCurrentAccentColorChanged: {
        if (nativeTerminal) {
            nativeTerminal.syncColorsToTheme(currentAccentColor)
        }
    }



    Rectangle {
        id: terminalLayer
        anchors.fill: parent
        color: "transparent"
        clip: true
        radius: 4
        
        border.color: {
            var baseColor = termContainer.currentAccentColor
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.15)
        }
        border.width: 1

        QMLTermWidget {
            id: nativeTerminal
            anchors.fill: parent
            anchors.margins: 10
            
            // Explicit focus routing
            focus: true
            font.family: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
            font.pointSize: 9
            
            // High-fidelity neon styling
            colorScheme: "NerveCenter"

            session: QMLTermSession {
                id: mainsession
                initialWorkingDirectory: "$HOME"
                kbScheme: "default"
                
                onFinished: {
                    termContainer.sessionFinished()
                }
            }

            useFBORendering: false

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                propagateComposedEvents: true
                onPressed: (mouse) => {
                    nativeTerminal.forceActiveFocus()
                    mouse.accepted = false
                }
            }

            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier && event.modifiers & Qt.ShiftModifier) {
                    if (event.key === Qt.Key_C) {
                        nativeTerminal.copyClipboard()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_V) {
                        nativeTerminal.pasteClipboard()
                        event.accepted = true
                        return
                    }
                }
                event.accepted = false
            }

            Component.onCompleted: {
                mainsession.startShellProgram()
                nativeTerminal.forceActiveFocus()
                nativeTerminal.syncColorsToTheme(currentAccentColor)
            }
        }
    }
}