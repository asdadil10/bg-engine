/*
 *  NerveCenter — NetworkPanel.qml
 *  Native network telemetry with live download/upload graphs and connection telemetry.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

NervePanel {
    id: netPanel
    panelId: "rightNetworkPanel"
    title: "SUBNET // COGNITIVE_BRIDGE"
    subLabel: linkType

    minWidth: 200
    minHeight: 180

    Sensors.Sensor {
        id: rx
        sensorId: "network/all/download"
        updateRateLimit: netPanel.isPanelActive ? 1000 : 0
    }
    Sensors.Sensor {
        id: tx
        sensorId: "network/all/upload"
        updateRateLimit: netPanel.isPanelActive ? 1000 : 0
    }

    // ── Static info (every 10 s) ────────────────────────────
    readonly property string cmdIp:   "hostname -I 2>/dev/null | awk '{print $1}'"
    readonly property string cmdSsid: "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2-"
    readonly property string cmdType: "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep ':connected$' | head -1 | cut -d: -f1"

    P5Support.DataSource {
        id: netInfo
        engine: "executable"
        connectedSources: [netPanel.cmdIp, netPanel.cmdSsid, netPanel.cmdType]
        interval: netPanel.isPanelActive ? 10000 : 0
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            spacing: 12

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

        InfoRow { label: "IP.NODE"; value: netPanel.nv(netPanel.cmdIp); accentColor: netPanel.accentColor; fontFamily: netPanel.fontFamily; fontScale: netPanel.fontScale }
        InfoRow { label: "SUBNET";  value: netPanel.ssidText;           accentColor: netPanel.accentColor; fontFamily: netPanel.fontFamily; fontScale: netPanel.fontScale }
        InfoRow { label: "BRIDGE";  value: netPanel.linkType;           accentColor: netPanel.accentColor; fontFamily: netPanel.fontFamily; fontScale: netPanel.fontScale }
    }
}
