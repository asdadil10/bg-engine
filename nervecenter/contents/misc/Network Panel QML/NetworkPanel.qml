/*
 *  NerveCenter — NetworkPanel.qml  (slimmed: graphs live in NetGraph.qml)
 */
import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

Item {
    id: netPanel
    property color accentColor: "#00f0ff"
    property color highlightColor: "#ff007f"

    readonly property string fontFamily: (typeof root !== "undefined") ? root.globalFontFamily : "monospace"
    readonly property real   fontScale:  (typeof root !== "undefined") ? root.globalFontScale  : 1.0
    function px(n) { return Math.round(n * fontScale) }

    Sensors.Sensor { id: rx; sensorId: "network/all/download"; updateRateLimit: 1000 }
    Sensors.Sensor { id: tx; sensorId: "network/all/upload";   updateRateLimit: 1000 }

    // ── Static info (every 10 s) ────────────────────────────
    readonly property string cmdIp:   "hostname -I 2>/dev/null | awk '{print $1}'"
    readonly property string cmdSsid: "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2-"
    // ':connected$' so "disconnected" lines are not matched
    readonly property string cmdType: "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep ':connected$' | head -1 | cut -d: -f1"

    P5Support.DataSource {
        id: netInfo
        engine: "executable"
        connectedSources: [netPanel.cmdIp, netPanel.cmdSsid, netPanel.cmdType]
        interval: 10000
    }
    function nv(cmd) {
        var d = netInfo.data[cmd]
        var s = (d && d["stdout"]) ? d["stdout"].trim() : ""
        return s.length ? s : "—"
    }
    readonly property string linkType: nv(cmdType).toUpperCase()
    readonly property string ssidText: {
        var s = nv(cmdSsid)
        return (s === "—" && linkType === "ETHERNET") ? "WIRED" : s
    }

    NerveFrame {
        anchors.fill: parent
        accentColor: netPanel.accentColor
        highlightColor: netPanel.highlightColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            z: 2        // keep content above NerveFrame's hologram/vignette/circuit layers (z: 1)

            RowLayout {
                spacing: 6
                Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3
                            color: netPanel.highlightColor; opacity: 0.6 }
                Text {
                    text: "SUBNET // COGNITIVE_BRIDGE"
                    color: netPanel.accentColor; opacity: 0.8
                    font.family: netPanel.fontFamily; font.pixelSize: netPanel.px(9)
                    font.bold: true; font.letterSpacing: 2
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: netPanel.accentColor; opacity: 0.15 }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 90
                spacing: 16

                NetGraph {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                    title: "DOWNLOAD"
                    lineColor: netPanel.accentColor
                    rate: Number(rx.value) || 0
                    fontFamily: netPanel.fontFamily; fontScale: netPanel.fontScale
                }
                NetGraph {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                    title: "UPLOAD"
                    lineColor: netPanel.highlightColor
                    rate: Number(tx.value) || 0
                    fontFamily: netPanel.fontFamily; fontScale: netPanel.fontScale
                }
            }

            InfoRow { label: "IP.NODE"; value: netPanel.nv(netPanel.cmdIp); accentColor: netPanel.accentColor }
            InfoRow { label: "SUBNET";  value: netPanel.ssidText;           accentColor: netPanel.accentColor }
            InfoRow { label: "BRIDGE";  value: netPanel.linkType;           accentColor: netPanel.accentColor }
        }
    }
}
