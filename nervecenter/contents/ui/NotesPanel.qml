/*
 *  NerveCenter — NotesPanel.qml
 *  Highly polished secure neural log notepad with automatic sync state feedback.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore

NervePanel {
    id: notesRoot
    panelId: "rightNotesPanel"
    title: "NEURAL_STATION // LOG_EDITOR"
    subLabel: isSaving ? "[SYNCING...]" : (notesArea.activeFocus ? "[WRITING]" : "[SECURE]")
    status: isSaving ? "warning" : (notesArea.activeFocus ? "active" : "nominal")

    minWidth: 200
    minHeight: 160

    property bool isSaving: false

    Settings {
        id: notesSettings
        category: "Notes"
        property string text: "// NEURAL LINK LOGS //\n[SECURE RECORD] Enter custom logs here..."
    }

    function saveNotes() {
        notesSettings.text = notesArea.text
        if (typeof rootItem !== "undefined" && rootItem.configuration && rootItem.configuration.NotesText !== undefined) {
            rootItem.configuration.NotesText = notesArea.text
        }
        notesRoot.isSaving = true
        saveFeedbackTimer.restart()
    }

    Timer {
        id: saveFeedbackTimer
        interval: 1200
        onTriggered: notesRoot.isSaving = false
    }

    Timer {
        id: debounceTimer
        interval: 400
        repeat: false
        onTriggered: {
            notesRoot.saveNotes()
        }
    }

    // Direct click-to-focus background area
    MouseArea {
        anchors.fill: parent
        onClicked: {
            notesArea.forceActiveFocus()
            notesArea.cursorPosition = notesArea.text.length
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Scrollable text viewport with inset border
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.03)
            border.color: Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, notesRoot.hudBorderOpacity)
            border.width: 1
            radius: notesRoot.cardRadius

            QQC2.ScrollView {
                id: scrollFrame
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                QQC2.TextArea {
                    id: notesArea
                    width: scrollFrame.width
                    placeholderText: ":: ENTER SECURE NEURAL LOGS HERE..."
                    placeholderTextColor: Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.25)
                    color: Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.85)
                    selectionColor: Qt.rgba(notesRoot.highlightColor.r, notesRoot.highlightColor.g, notesRoot.highlightColor.b, 0.3)
                    selectedTextColor: "white"
                    font.family: notesRoot.fontFamily
                    font.pixelSize: Math.round(11 * notesRoot.fontScale)
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    background: null
                    padding: 0
                    topPadding: 0
                    bottomPadding: 0

                    text: notesSettings.text !== "" ? notesSettings.text : ""

                    Component.onCompleted: {
                        if ((!notesSettings.text || notesSettings.text === "") && typeof rootItem !== "undefined" && rootItem.configuration && rootItem.configuration.NotesText) {
                            notesSettings.text = rootItem.configuration.NotesText
                        }
                        notesArea.text = notesSettings.text
                    }

                    onTextChanged: {
                        if (activeFocus) {
                            debounceTimer.restart()
                        }
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus && debounceTimer.running) {
                            debounceTimer.stop()
                            notesRoot.saveNotes()
                        }
                    }

                    // Native shortcut captures
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            notesArea.focus = false
                            event.accepted = true
                        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_S) {
                            debounceTimer.stop()
                            notesRoot.saveNotes()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: notesRoot.accentColor; opacity: 0.08 }

        // HUD Status Footer
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: notesArea.activeFocus ? ">> ESC: SAVE & QUIT | CTRL+S: SYNC" : ">> CLICK TO WRITE LOGS"
                color: notesRoot.accentColor
                opacity: 0.4
                font.family: notesRoot.fontFamily
                font.pixelSize: Math.round(8 * notesRoot.fontScale)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "CHARS: " + notesArea.text.length
                color: notesRoot.accentColor; opacity: 0.4
                font.family: notesRoot.fontFamily
                font.pixelSize: Math.round(8 * notesRoot.fontScale)
            }
        }
    }
}
