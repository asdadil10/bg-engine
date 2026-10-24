/*
 *  NerveCenter — SensorPanel.qml
 *  Native KDE KSysGuard telemetry readout stack with battery % and GPU compute load.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

NervePanel {
    id: sensorRoot
    panelId: "leftSensorPanel"
    title: "SYS_TELEMETRY // MATRIX"
    subLabel: getStaticInfo("hostname 2>/dev/null || echo localhost").toUpperCase()

    minWidth: 200
    minHeight: 220

    // ── Native KDE KSysGuard Sensors ─────────────────────────
    Sensors.Sensor {
        id: cpuSensor
        sensorId: "cpu/all/usage"
        updateRateLimit: sensorRoot.isPanelActive ? 1000 : 0
    }

    Sensors.Sensor {
        id: gpuSensor
        sensorId: "gpu/all/usage"
        updateRateLimit: sensorRoot.isPanelActive ? 1000 : 0
    }

    Sensors.Sensor {
        id: memUsedSensor
        sensorId: "memory/physical/used"
        updateRateLimit: sensorRoot.isPanelActive ? 1000 : 0
    }

    Sensors.Sensor {
        id: memTotalSensor
        sensorId: "memory/physical/total"
        updateRateLimit: sensorRoot.isPanelActive ? 1000 : 0
    }

    Sensors.Sensor {
        id: diskUsedSensor
        sensorId: "disk/all/used"
        updateRateLimit: sensorRoot.isPanelActive ? 3000 : 0
    }

    Sensors.Sensor {
        id: diskTotalSensor
        sensorId: "disk/all/total"
        updateRateLimit: sensorRoot.isPanelActive ? 3000 : 0
    }

    Sensors.Sensor {
        id: tempSensor
        sensorId: "cpu/all/averageTemperature"
        updateRateLimit: sensorRoot.isPanelActive ? 1000 : 0
    }

    property var batInfo: ({ status: "N/A", percent: 0, timeLeft: "STATIONARY", isCharging: false })

    // Passive battery reader
    P5Support.DataSource {
        id: batDataSource
        engine: "executable"
        connectedSources: [
            "cat /sys/class/power_supply/BAT0/uevent 2>/dev/null || cat /sys/class/power_supply/BAT1/uevent 2>/dev/null"
        ]
        interval: sensorRoot.isPanelActive ? 3000 : 0
        onNewData: function(source, data) {
            sensorRoot.batInfo = parseBattery()
        }
        Component.onCompleted: {
            sensorRoot.batInfo = parseBattery()
        }
    }

    P5Support.DataSource {
        id: staticSysInfo
        engine: "executable"
        connectedSources: [
            "hostname 2>/dev/null || echo localhost"
        ]
        interval: 0 // Run once on startup
    }

    function getStaticInfo(cmd) {
        var d = staticSysInfo.data[cmd]
        return (d && d["stdout"]) ? d["stdout"].trim() : ""
    }

    function fmtB(b) {
        var n = parseFloat(b)
        if (isNaN(n) || n <= 0) return "0"
        if (n < 1073741824) return (n / 1048576).toFixed(0) + " MB"
        return (n / 1073741824).toFixed(1) + " GB"
    }

    function parseBattery() {
        var raw = (batDataSource.data["cat /sys/class/power_supply/BAT0/uevent 2>/dev/null || cat /sys/class/power_supply/BAT1/uevent 2>/dev/null"] || {})["stdout"] || ""
        if (!raw) return { status: "N/A", percent: 0, timeLeft: "STATIONARY", isCharging: false }
        var lines = raw.split("\n")
        var kv = {}
        for (var i = 0; i < lines.length; i++) {
            var idx = lines[i].indexOf("=")
            if (idx !== -1) {
                kv[lines[i].substring(0, idx).trim()] = lines[i].substring(idx + 1).trim()
            }
        }
        var status = (kv["POWER_SUPPLY_STATUS"] || "Unknown").toUpperCase()
        var capacity = parseFloat(kv["POWER_SUPPLY_CAPACITY"]) || 0
        var cNow = parseFloat(kv["POWER_SUPPLY_CHARGE_NOW"] || kv["POWER_SUPPLY_ENERGY_NOW"]) || 0
        var cFull = parseFloat(kv["POWER_SUPPLY_CHARGE_FULL"] || kv["POWER_SUPPLY_ENERGY_FULL"]) || 0
        var iNow = parseFloat(kv["POWER_SUPPLY_CURRENT_NOW"] || kv["POWER_SUPPLY_POWER_NOW"]) || 0

        var timeLeft = "STATIONARY"
        if (iNow > 0) {
            if (status === "DISCHARGING") {
                var mins = Math.round((cNow / iNow) * 60)
                var h = Math.floor(mins / 60)
                var m = mins % 60
                timeLeft = h + "H " + m + "M REMAINING"
            } else if (status === "CHARGING") {
                var mins = Math.round(((cFull - cNow) / iNow) * 60)
                var h = Math.floor(mins / 60)
                var m = mins % 60
                timeLeft = h + "H " + m + "M TO FULL"
            }
        }
        return {
            status: status,
            percent: capacity,
            timeLeft: timeLeft,
            isCharging: (status === "CHARGING")
        }
    }

    // ── Safe Inset Content ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Vertical list of spacious telemetry gauges
        GaugeBlock {
            label: "CPU.LOAD"
            accentColor: sensorRoot.accentColor
            highlightColor: sensorRoot.highlightColor
            fontFamily: sensorRoot.fontFamily
            fontScale: sensorRoot.fontScale
            segmentRadius: sensorRoot.cardRadius
            value: Math.round(parseFloat(cpuSensor.value) || 0)
            suffix: "%"
            extraText: "COGNITIVE CORES // HARDWARE SCALING"
        }

        GaugeBlock {
            label: "GPU.COMPUTE"
            accentColor: sensorRoot.accentColor
            highlightColor: sensorRoot.highlightColor
            fontFamily: sensorRoot.fontFamily
            fontScale: sensorRoot.fontScale
            segmentRadius: sensorRoot.cardRadius
            value: Math.round(parseFloat(gpuSensor.value) || 0)
            suffix: "%"
            extraText: "RASTER ENGINE // ACCEL: ACTIVE"
        }

        GaugeBlock {
            label: "RAM.USAGE"
            accentColor: sensorRoot.accentColor
            highlightColor: sensorRoot.highlightColor
            fontFamily: sensorRoot.fontFamily
            fontScale: sensorRoot.fontScale
            segmentRadius: sensorRoot.cardRadius
            value: (memTotalSensor.value > 0) ? (memUsedSensor.value / memTotalSensor.value * 100) : 0
            suffix: "%"
            extraText: fmtB(memUsedSensor.value) + " / " + fmtB(memTotalSensor.value)
        }

        GaugeBlock {
            label: "SYS.STORAGE"
            accentColor: sensorRoot.accentColor
            highlightColor: sensorRoot.highlightColor
            fontFamily: sensorRoot.fontFamily
            fontScale: sensorRoot.fontScale
            segmentRadius: sensorRoot.cardRadius
            value: (diskTotalSensor.value > 0) ? (diskUsedSensor.value / diskTotalSensor.value * 100) : 0
            suffix: "%"
            extraText: fmtB(diskUsedSensor.value) + " / " + fmtB(diskTotalSensor.value)
        }

        GaugeBlock {
            label: "SYS.THERMAL"
            accentColor: sensorRoot.accentColor
            highlightColor: sensorRoot.highlightColor
            fontFamily: sensorRoot.fontFamily
            fontScale: sensorRoot.fontScale
            segmentRadius: sensorRoot.cardRadius
            value: Math.round(parseFloat(tempSensor.value) || 0)
            suffix: "°C"
            maxValue: 100
            extraText: "CORE SENSORS // STATUS: NOMINAL"
        }

        GaugeBlock {
            id: batGauge
            label: "BATTERY.STATUS"
            fontFamily: sensorRoot.fontFamily
            fontScale: sensorRoot.fontScale
            segmentRadius: sensorRoot.cardRadius
            
            property bool isCharging: sensorRoot.batInfo ? sensorRoot.batInfo.isCharging : false
            
            // Turn battery neon hot-pink when charging
            accentColor: isCharging ? sensorRoot.highlightColor : sensorRoot.accentColor
            highlightColor: isCharging ? sensorRoot.accentColor : sensorRoot.highlightColor
            
            value: sensorRoot.batInfo ? sensorRoot.batInfo.percent : 0
            suffix: isCharging ? "% [AC_CHARGING]" : "%"
            extraText: sensorRoot.batInfo ? ("STATUS: " + sensorRoot.batInfo.status + " // " + sensorRoot.batInfo.timeLeft) : "STATUS: N/A // LINE POWER"
            warningThreshold: -1 // Full battery is healthy, don't trigger warning highlight
        }

        // Vertical spring spacer to absorb excess panel height and keep gauge heights perfectly uniform
        Item {
            Layout.fillHeight: true
        }
        
        // Visual spacer line before footer
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: sensorRoot.accentColor
            opacity: 0.12
        }

        // Faint cyber warning footer inside the panel
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                Layout.preferredWidth: 4; Layout.preferredHeight: 10
                color: (cpuSensor.value > 70) ? sensorRoot.highlightColor : sensorRoot.accentColor
                opacity: 0.6
            }
            Text {
                text: (cpuSensor.value > 70) ? "NEURAL OVERFLOW THRESHOLD EXCEEDED" : "NEURAL CORES RUNNING STABLE"
                color: (cpuSensor.value > 70) ? sensorRoot.highlightColor : sensorRoot.accentColor
                opacity: 0.55
                font.family: sensorRoot.fontFamily
                font.pixelSize: Math.round(7 * sensorRoot.fontScale)
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
