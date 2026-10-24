/*
 *  NerveCenter — ControlsPanel.qml
 *  Custom cyberpunk mixing console for system volume, brightness, and night light.
 *  Includes expanded 32px click hitboxes and intuitive mouse scroll wheel controls.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasma5support as P5Support
import QtCore

NervePanel {
    id: ctrlPanel
    panelId: "rightControlsPanel"
    title: "DECK_CONTROL // HOST_MIXER"
    subLabel: "POWER: " + powerMode.toUpperCase()

    minWidth: 200
    minHeight: 310

    property real volVal: 50
    property real brightVal: 50
    property bool nlVal: false
    property string powerMode: "normal"

    property real maxBright: 10000

    property var forecastDays: [
        { day: "TODAY", weatherCode: 0, condition: "CLEAR SKY", maxTemp: 36, minTemp: 24, temp: "36° / 24°" },
        { day: "MON", weatherCode: 61, condition: "RAIN", maxTemp: 36, minTemp: 25, temp: "36° / 25°" },
        { day: "TUE", weatherCode: 0, condition: "CLEAR SKY", maxTemp: 36, minTemp: 25, temp: "36° / 25°" }
    ]

    Settings {
        id: weatherSettings
        category: "DeckWeather"
        property string cachedJson: ""
    }

    function parseWeatherJson(jsonStr) {
        try {
            var data = JSON.parse(jsonStr);
            if (!data || !data.daily || !data.daily.time) return;
            var days = [];
            var weekdayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
            for (var i = 0; i < Math.min(3, data.daily.time.length); i++) {
                var dateStr = data.daily.time[i];
                var code = data.daily.weathercode ? data.daily.weathercode[i] : 0;
                var maxT = data.daily.temperature_2m_max ? Math.round(data.daily.temperature_2m_max[i]) : 25;
                var minT = data.daily.temperature_2m_min ? Math.round(data.daily.temperature_2m_min[i]) : 15;

                var dayLabel = "TODAY";
                if (i > 0) {
                    var d = new Date(dateStr + "T12:00:00");
                    dayLabel = weekdayNames[d.getDay()] || ("D+" + i);
                }

                var cond = "CLEAR SKY";
                if (code === 0) { cond = "CLEAR SKY"; }
                else if (code <= 2) { cond = "PARTLY CLOUDY"; }
                else if (code === 3) { cond = "OVERCAST"; }
                else if (code <= 48) { cond = "FOGGY"; }
                else if (code <= 67) { cond = "RAIN"; }
                else if (code <= 77) { cond = "SNOW"; }
                else if (code <= 82) { cond = "SHOWERS"; }
                else if (code >= 95) { cond = "THUNDERSTORM"; }

                days.push({
                    day: dayLabel,
                    weatherCode: code,
                    condition: cond,
                    maxTemp: maxT,
                    minTemp: minT,
                    temp: maxT + "° / " + minT + "°"
                });
            }
            if (days.length === 3) {
                ctrlPanel.forecastDays = days;
            }
        } catch (e) {
            // retain existing
        }
    }

    Component.onCompleted: {
        if (weatherSettings.cachedJson && weatherSettings.cachedJson.length > 10) {
            parseWeatherJson(weatherSettings.cachedJson);
        }
    }

    P5Support.DataSource {
        id: weatherExec
        engine: "executable"
        connectedSources: [
            "curl -s --max-time 4 'https://api.open-meteo.com/v1/forecast?latitude=33.85&longitude=72.42&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto' 2>/dev/null"
        ]
        interval: 1800000 // 30 mins
        onNewData: function(source, data) {
            var out = (data["stdout"] || "").trim();
            if (out.indexOf("temperature_2m_max") >= 0) {
                weatherSettings.cachedJson = out;
                parseWeatherJson(out);
            }
        }
    }

    P5Support.DataSource {
        id: ctrlExec
        engine: "executable"
        connectedSources: [
            "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '[0-9]+%' | head -1 | tr -d '%'",
            "qdbus-qt6 org.kde.org_kde_powerdevil /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightnessMax 2>/dev/null",
            "qdbus-qt6 org.kde.org_kde_powerdevil /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightness 2>/dev/null",
            "qdbus-qt6 org.kde.KWin.NightLight /org/kde/KWin/NightLight org.kde.KWin.NightLight.running 2>/dev/null",
            "qdbus-qt6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/PowerProfile org.kde.Solid.PowerManagement.Actions.PowerProfile.currentProfile 2>/dev/null"
        ]
        interval: 3000
        onNewData: function(source, data) {
            var out = (data["stdout"] || "").trim();
            if (source.indexOf("get-sink-volume") >= 0) {
                var v = parseInt(out);
                if (!isNaN(v)) volVal = v;
            }
            if (source.indexOf("brightnessMax") >= 0) {
                var m = parseInt(out);
                if (!isNaN(m) && m > 0) maxBright = m;
            }
            if (source.indexOf("brightnessControl.brightness") >= 0 || (source.indexOf("brightness") >= 0 && source.indexOf("brightnessMax") < 0)) {
                var cur = parseInt(out);
                if (!isNaN(cur) && cur >= 0) {
                    brightVal = Math.round((cur / maxBright) * 100);
                }
            }
            if (source.indexOf("NightLight.running") >= 0) {
                nlVal = (out === "true");
            }
            if (source.indexOf("currentProfile") >= 0) {
                if (out === "power-saver") powerMode = "low";
                else if (out === "performance") powerMode = "ultra";
                else powerMode = "normal";
            }
        }
    }

    P5Support.DataSource {
        id: ctrlSet
        engine: "executable"
        connectedSources: []
        onNewData: function(s) { disconnectSource(s); }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 5

            // VOLUME SLIDER (Unified 6px Track + Wheel Control)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Text { text: ":: VOL.OUTPUT"; color: ctrlPanel.accentColor; font.family: ctrlPanel.fontFamily; font.pixelSize: Math.round(9 * ctrlPanel.fontScale); font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(volVal) + "%"; color: ctrlPanel.accentColor; font.family: ctrlPanel.fontFamily; font.pixelSize: Math.round(9 * ctrlPanel.fontScale); font.bold: true }
                }

                // Compact interactive container
                Item {
                    Layout.fillWidth: true
                    height: 20

                    // Slider Track Visual
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, 0.14)
                        radius: ctrlPanel.cardRadius

                        // Filled portion
                        Rectangle {
                            height: parent.height
                            width: parent.width * (volVal / 100)
                            color: ctrlPanel.accentColor
                            radius: ctrlPanel.cardRadius
                            opacity: 0.85
                        }
                        // Knob
                        Rectangle {
                            x: Math.max(0, parent.width * (volVal / 100) - 4)
                            y: -4
                            width: 8; height: 14
                            color: ctrlPanel.highlightColor
                            radius: ctrlPanel.buttonRadius
                            border.color: ctrlPanel.highlightColor
                            border.width: 1
                            opacity: 0.95
                        }
                    }

                    // Click, drag, and mouse-wheel scrolling hitbox
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onPressed: function(mouse) {
                            var percent = Math.max(0, Math.min(100, (mouse.x / width) * 100))
                            volVal = percent
                            ctrlSet.connectSource("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(percent) + "%")
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                var percent = Math.max(0, Math.min(100, (mouse.x / width) * 100))
                                volVal = percent
                                ctrlSet.connectSource("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(percent) + "%")
                            }
                        }

                        // Enable intuitive mouse wheel scrolling over slider
                        onWheel: function(event) {
                            var step = event.angleDelta.y > 0 ? 2 : -2
                            var percent = Math.max(0, Math.min(100, volVal + step))
                            volVal = percent
                            ctrlSet.connectSource("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(percent) + "%")
                        }
                    }
                }
            }

            // BRIGHTNESS SLIDER (Unified 6px Track + Wheel Control)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Text { text: ":: SCR.LUMINANCE"; color: ctrlPanel.accentColor; font.family: ctrlPanel.fontFamily; font.pixelSize: Math.round(9 * ctrlPanel.fontScale); font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(brightVal) + "%"; color: ctrlPanel.accentColor; font.family: ctrlPanel.fontFamily; font.pixelSize: Math.round(9 * ctrlPanel.fontScale); font.bold: true }
                }

                // Compact interactive container
                Item {
                    Layout.fillWidth: true
                    height: 20

                    // Slider Track Visual
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, 0.14)
                        radius: ctrlPanel.cardRadius

                        // Filled portion
                        Rectangle {
                            height: parent.height
                            width: parent.width * (brightVal / 100)
                            color: ctrlPanel.accentColor
                            radius: ctrlPanel.cardRadius
                            opacity: 0.85
                        }
                        // Knob
                        Rectangle {
                            x: Math.max(0, parent.width * (brightVal / 100) - 4)
                            y: -4
                            width: 8; height: 14
                            color: ctrlPanel.highlightColor
                            radius: ctrlPanel.buttonRadius
                            border.color: ctrlPanel.highlightColor
                            border.width: 1
                            opacity: 0.95
                        }
                    }

                    // Click, drag, and mouse-wheel scrolling hitbox
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onPressed: function(mouse) {
                            var percent = Math.max(1, Math.min(100, (mouse.x / width) * 100))
                            brightVal = percent
                            var absoluteVal = Math.round((percent / 100) * maxBright)
                            ctrlSet.connectSource("qdbus-qt6 org.kde.org_kde_powerdevil /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness " + absoluteVal)
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                var percent = Math.max(1, Math.min(100, (mouse.x / width) * 100))
                                brightVal = percent
                                var absoluteVal = Math.round((percent / 100) * maxBright)
                                ctrlSet.connectSource("qdbus-qt6 org.kde.org_kde_powerdevil /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness " + absoluteVal)
                            }
                        }

                        // Enable intuitive mouse wheel scrolling over slider
                        onWheel: function(event) {
                            var step = event.angleDelta.y > 0 ? 2 : -2
                            var percent = Math.max(1, Math.min(100, brightVal + step))
                            brightVal = percent
                            var absoluteVal = Math.round((percent / 100) * maxBright)
                            ctrlSet.connectSource("qdbus-qt6 org.kde.org_kde_powerdevil /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness " + absoluteVal)
                        }
                    }
                }
            }

            // NIGHT LIGHT TOGGLE (Tactical HUD Latch Indicator)
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: ":: COGNITIVE_WARMTH // NIGHT_SHIFT"
                    color: ctrlPanel.accentColor; opacity: 0.8
                    font.family: ctrlPanel.fontFamily
                    font.pixelSize: Math.round(9 * ctrlPanel.fontScale)
                    font.bold: true
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 52; height: 18
                    radius: ctrlPanel.buttonRadius
                    color: nlVal ? Qt.rgba(ctrlPanel.highlightColor.r, ctrlPanel.highlightColor.g, ctrlPanel.highlightColor.b, 0.2)
                                 : Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, 0.08)
                    border.color: nlVal ? ctrlPanel.highlightColor : Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, ctrlPanel.hudBorderOpacity)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: nlVal ? "ENGAGED" : "BYPASS"
                        color: nlVal ? ctrlPanel.highlightColor : ctrlPanel.accentColor
                        font.family: ctrlPanel.fontFamily
                        font.pixelSize: Math.round(7.5 * ctrlPanel.fontScale)
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var val = !nlVal
                            nlVal = val
                            ctrlSet.connectSource("qdbus-qt6 org.kde.kglobalaccel /component/kwin invokeShortcut \"Toggle Night Color\"")
                        }
                    }
                }
            }

            // POWER MODE SELECTION
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 4

                Text {
                    text: ":: POWER_PROFILE"
                    color: ctrlPanel.accentColor; opacity: 0.8
                    font.family: ctrlPanel.fontFamily
                    font.pixelSize: Math.round(9 * ctrlPanel.fontScale)
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 22
                    color: "transparent"
                    border.color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, ctrlPanel.hudBorderOpacity)
                    border.width: 1
                    radius: ctrlPanel.cardRadius

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        Repeater {
                            model: [
                                { label: "LOW", cmd: "power-saver" },
                                { label: "NORMAL", cmd: "balanced" },
                                { label: "ULTRA", cmd: "performance" }
                            ]
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: ctrlPanel.cardRadius
                                color: ctrlPanel.powerMode === modelData.label.toLowerCase() ? Qt.rgba(ctrlPanel.highlightColor.r, ctrlPanel.highlightColor.g, ctrlPanel.highlightColor.b, 0.22) : "transparent"

                                Rectangle {
                                    anchors.right: parent.right
                                    width: 1; height: parent.height
                                    color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, ctrlPanel.hudBorderOpacity)
                                    visible: index < 2
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: ctrlPanel.powerMode === modelData.label.toLowerCase() ? ctrlPanel.highlightColor : ctrlPanel.accentColor
                                    font.family: ctrlPanel.fontFamily
                                    font.pixelSize: Math.round(8.5 * ctrlPanel.fontScale)
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ctrlPanel.powerMode = modelData.label.toLowerCase()
                                        ctrlSet.connectSource("qdbus-qt6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/PowerProfile org.kde.Solid.PowerManagement.Actions.PowerProfile.setProfile " + modelData.cmd)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // SPACER
            Item { Layout.fillHeight: true }

            // ── UNIFIED TACTICAL DECK: 3-DAY WEATHER TELEMETRY (LEFT) + CHRONO (RIGHT) ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                Layout.alignment: Qt.AlignBottom

                // RIGHT SIDE: SYSTEM CHRONO (pinned to right)
                ColumnLayout {
                    id: clockCol
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        id: timeText
                        Layout.alignment: Qt.AlignRight
                        horizontalAlignment: Text.AlignRight
                        color: ctrlPanel.highlightColor
                        font.family: ctrlPanel.fontFamily
                        font.pixelSize: Math.round(23 * ctrlPanel.fontScale)
                        font.bold: true
                        font.letterSpacing: 1.5
                        opacity: 0.95
                    }

                    Text {
                        id: dateText
                        Layout.alignment: Qt.AlignRight
                        horizontalAlignment: Text.AlignRight
                        color: ctrlPanel.accentColor
                        font.family: ctrlPanel.fontFamily
                        font.pixelSize: Math.round(8.5 * ctrlPanel.fontScale)
                        font.bold: true
                        font.letterSpacing: 1.5
                        opacity: 0.7
                    }

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            var d = new Date();
                            timeText.text = Qt.formatTime(d, "hh:mm:ss");
                            dateText.text = Qt.formatDate(d, "ddd // yyyy.MM.dd").toUpperCase();
                        }
                        Component.onCompleted: {
                            var d = new Date();
                            timeText.text = Qt.formatTime(d, "hh:mm:ss");
                            dateText.text = Qt.formatDate(d, "ddd // yyyy.MM.dd").toUpperCase();
                        }
                    }
                }

                // VERTICAL TACTICAL DIVIDER
                Item {
                    id: deckDivider
                    anchors.right: clockCol.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 54
                    width: 5

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, 0.22)
                    }
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 5; height: 1
                        color: ctrlPanel.accentColor
                        opacity: 0.6
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 5; height: 1
                        color: ctrlPanel.accentColor
                        opacity: 0.6
                    }
                }

                // LEFT SIDE: TACTICAL 3-DAY WEATHER TELEMETRY BAY
                Rectangle {
                    id: weatherCapsule
                    anchors.left: parent.left
                    anchors.right: deckDivider.left
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, 0.03)
                    border.color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, ctrlPanel.hudBorderOpacity)
                    border.width: 1
                    radius: ctrlPanel.cardRadius
                    clip: true

                    // High-tech symmetrical corner bracket ticks
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top
                        width: 5; height: 1.5; color: ctrlPanel.highlightColor
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top
                        width: 1.5; height: 5; color: ctrlPanel.highlightColor
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.top: parent.top
                        width: 5; height: 1.5; color: ctrlPanel.highlightColor
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.top: parent.top
                        width: 1.5; height: 5; color: ctrlPanel.highlightColor
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        width: 5; height: 1.5; color: ctrlPanel.accentColor; opacity: 0.6
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        width: 1.5; height: 5; color: ctrlPanel.accentColor; opacity: 0.6
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        width: 5; height: 1.5; color: ctrlPanel.accentColor; opacity: 0.6
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        width: 1.5; height: 5; color: ctrlPanel.accentColor; opacity: 0.6
                    }

                    Row {
                        id: weatherRow
                        anchors.fill: parent
                        anchors.margins: 4

                        Repeater {
                            model: ctrlPanel.forecastDays
                            Item {
                                width: weatherRow.width / 3
                                height: weatherRow.height

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    spacing: 1

                                    // Day header
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: index === 0 ? ("[ TODAY ]") : ("D+" + index + " // " + modelData.day)
                                        color: index === 0 ? ctrlPanel.highlightColor : ctrlPanel.accentColor
                                        opacity: index === 0 ? 1.0 : 0.75
                                        font.family: ctrlPanel.fontFamily
                                        font.pixelSize: Math.round(8 * ctrlPanel.fontScale)
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }

                                    // Monochromatic Tactical Weather Vector Glyph
                                    CyberWeatherGlyph {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 24; height: 24
                                        weatherCode: (modelData.weatherCode !== undefined) ? modelData.weatherCode : 0
                                        primaryColor: index === 0 ? ctrlPanel.highlightColor : ctrlPanel.accentColor
                                        secondaryColor: ctrlPanel.highlightColor
                                        isToday: index === 0
                                    }

                                    // Temperature telemetry readout (HI / LO)
                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 2
                                        Text {
                                            text: (modelData.maxTemp !== undefined ? modelData.maxTemp : "--") + "°C"
                                            color: "white"
                                            font.family: ctrlPanel.fontFamily
                                            font.pixelSize: Math.round(10.5 * ctrlPanel.fontScale)
                                            font.bold: true
                                        }
                                        Text {
                                            text: "/ " + (modelData.minTemp !== undefined ? modelData.minTemp : "--") + "°"
                                            color: ctrlPanel.accentColor
                                            opacity: 0.6
                                            font.family: ctrlPanel.fontFamily
                                            font.pixelSize: Math.round(8.5 * ctrlPanel.fontScale)
                                        }
                                    }

                                    // Technical condition label
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: (modelData.condition || "").toUpperCase().replace(/ /g, "_")
                                        color: ctrlPanel.accentColor
                                        opacity: 0.7
                                        font.family: ctrlPanel.fontFamily
                                        font.pixelSize: Math.round(7 * ctrlPanel.fontScale)
                                        font.bold: true
                                        font.letterSpacing: 0.5
                                        elide: Text.ElideRight
                                    }
                                }

                                // Subtle vertical divider between days
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 1
                                    height: Math.round(parent.height * 0.55)
                                    color: Qt.rgba(ctrlPanel.accentColor.r, ctrlPanel.accentColor.g, ctrlPanel.accentColor.b, 0.15)
                                    visible: index < 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }
