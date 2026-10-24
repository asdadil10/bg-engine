/*
 *  NerveCenter — GaugeBlock.qml
 *  Custom segmented cyberpunk diagnostic gauge with full-width alignment and uniform geometry.
 */
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: gauge
    Layout.fillWidth: true
    spacing: 3

    property string label: "CPU"
    property real   value: 0
    property real   maxValue: 100
    property string suffix: "%"
    property color  accentColor: "#00f0ff"
    property color  highlightColor: "#ff007f"
    property string extraText: ""
    property real   warningThreshold: 0.85
    property string fontFamily: (typeof root !== "undefined" ? root.globalFontFamily : "monospace")
    property real   fontScale: (typeof root !== "undefined" ? root.globalFontScale : 1.0)
    property int    segmentRadius: 1

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: ":: " + label
            color: accentColor
            opacity: 0.85
            font.family: gauge.fontFamily
            font.pixelSize: Math.round(9.5 * gauge.fontScale)
            font.bold: true
            font.letterSpacing: 1
        }

        Item { Layout.fillWidth: true }

        Text {
            text: {
                var v = Math.min(value, maxValue)
                if (maxValue <= 100) return v.toFixed(1) + suffix
                return v.toFixed(0) + suffix
            }
            color: (warningThreshold > 0 && value > (maxValue * warningThreshold)) ? highlightColor : accentColor
            opacity: 0.95
            font.family: gauge.fontFamily
            font.pixelSize: Math.round(9.5 * gauge.fontScale)
            font.bold: true
        }
    }

    // Segmented bar — Spans 100% full width evenly with 24 sleek discrete segments
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 7
        Layout.maximumHeight: 7
        spacing: 2.5

        Repeater {
            model: 24 // 24 discrete cyberpunk segments across full width
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: gauge.segmentRadius
                border.width: 1
                border.color: {
                    var percent = ((index + 1) / 24) * maxValue
                    if (value >= percent)
                        return "transparent"
                    return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.20)
                }
                color: {
                    var percent = ((index + 1) / 24) * maxValue
                    if (value >= percent) {
                        return (warningThreshold > 0 && percent > (maxValue * warningThreshold)) ? highlightColor : accentColor
                    }
                    return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                }
                opacity: value >= (((index + 1) / 24) * maxValue) ? 0.95 : 0.45
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: extraText.length > 0
        text: "↳ " + extraText
        color: accentColor
        opacity: 0.50
        font.family: gauge.fontFamily
        font.pixelSize: Math.round(7.5 * gauge.fontScale)
        elide: Text.ElideRight
    }
}