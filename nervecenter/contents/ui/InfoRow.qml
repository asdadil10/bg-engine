/*
 *  NerveCenter — InfoRow.qml
 *  High-tech key-value display row.
 */
import QtQuick
import QtQuick.Layouts

RowLayout {
    Layout.fillWidth: true
    spacing: 8

    property string label: "IP"
    property string value: "127.0.0.1"
    property color  accentColor: "#00f0ff"
    property string fontFamily: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
    property real   fontScale: (typeof root !== "undefined" ? root.globalFontScale : 1.0)

    Text {
        text: "↳ " + label
        color: accentColor
        opacity: 0.5
        font.family: fontFamily
        font.pixelSize: Math.round(9 * fontScale)
        font.bold: true
        font.letterSpacing: 1
    }

    Item { Layout.fillWidth: true }

    Text {
        text: "[" + value + "]"
        color: accentColor
        opacity: 0.85
        font.family: fontFamily
        font.pixelSize: Math.round(9.5 * fontScale)
        font.bold: true
    }
}
