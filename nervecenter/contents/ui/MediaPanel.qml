/*
 *  NerveCenter — MediaPanel.qml
 *  Custom cyberpunk MPRIS Media Controller HUD panel with Equalizer telemetry.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as P5Support
import QtCore

NervePanel {
    id: mediaPanel
    panelId: "leftMediaPanel"
    title: "MEDIA_LINK // " + (mprisModel.currentPlayer ? mprisModel.currentPlayer.identity.toUpperCase() : "NO SIGNAL")
    subLabel: (mprisModel.currentPlayer && mprisModel.currentPlayer.playbackStatus === 2) ? "PLAYING" : "STANDBY"
    status: (mprisModel.currentPlayer && mprisModel.currentPlayer.playbackStatus === 2) ? "active" : "nominal"

    minWidth: 200
    minHeight: 120

    property alias showVisualizer: mediaSettings.showVisualizer
    property bool eqEnabled: true

    P5Support.DataSource {
        id: eqExec
        engine: "executable"
        connectedSources: [
            "easyeffects -b 3 2>/dev/null"
        ]
        interval: mediaPanel.isPanelActive ? 3000 : 0
        onNewData: function(source, data) {
            var out = (data["stdout"] || "").trim();
            if (out === "2") {
                mediaPanel.eqEnabled = true;
            } else if (out === "1") {
                mediaPanel.eqEnabled = false;
            }
        }
    }

    P5Support.DataSource {
        id: eqCmd
        engine: "executable"
        connectedSources: []
        onNewData: function(s) { disconnectSource(s); }
    }

    function toggleEqualizer() {
        eqCmd.connectSource("easyeffects --bypass-toggle 2>/dev/null");
        mediaPanel.eqEnabled = !mediaPanel.eqEnabled;
    }

    Settings {
        id: mediaSettings
        category: "MediaPanel"
        property bool showVisualizer: true
    }

    function formatTime(us) {
        if (!us || us <= 0) return "0:00"
        var secs = Math.floor(us / 1000000)
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Mpris.Mpris2Model {
        id: mprisModel
    }

    property real currentTrackPosition: (mprisModel.currentPlayer && mprisModel.currentPlayer.position) ? mprisModel.currentPlayer.position : 0
    property bool isPlaying: mprisModel.currentPlayer && mprisModel.currentPlayer.playbackStatus === 2

    onIsPlayingChanged: {
        if (isPlaying && mprisModel.currentPlayer) {
            if (typeof mprisModel.currentPlayer.updatePosition === "function") {
                mprisModel.currentPlayer.updatePosition()
            }
            currentTrackPosition = mprisModel.currentPlayer.position
        }
    }

    Connections {
        target: mprisModel.currentPlayer
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (mprisModel.currentPlayer) {
                mediaPanel.currentTrackPosition = mprisModel.currentPlayer.position
            }
        }
        function onPlaybackStatusChanged() {
            if (mprisModel.currentPlayer) {
                if (typeof mprisModel.currentPlayer.updatePosition === "function") {
                    mprisModel.currentPlayer.updatePosition()
                }
                mediaPanel.currentTrackPosition = mprisModel.currentPlayer.position
            }
        }
        function onTrackChanged() {
            if (mprisModel.currentPlayer) {
                if (typeof mprisModel.currentPlayer.updatePosition === "function") {
                    mprisModel.currentPlayer.updatePosition()
                }
                mediaPanel.currentTrackPosition = mprisModel.currentPlayer.position
            }
        }
    }

    // Low-overhead position advance timer (1-second tick, 0% GPU load)
    Timer {
        id: positionTimer
        interval: 1000
        running: mediaPanel.isPanelActive && mediaPanel.isPlaying
        repeat: true

        onTriggered: {
            if (mprisModel.currentPlayer) {
                if (typeof mprisModel.currentPlayer.updatePosition === "function") {
                    mprisModel.currentPlayer.updatePosition();
                }
                mediaPanel.currentTrackPosition = mprisModel.currentPlayer.position;
            }
        }
    }

    // Auto-select playing source periodically (switches to active player if current is stopped or idle)
    Timer {
        id: scannerTimer
        interval: 1500
        running: mediaPanel.isPanelActive && mprisModel.rowCount() > 0
        repeat: true
        
        onTriggered: {
            if (mprisModel.currentPlayer && mprisModel.currentPlayer.playbackStatus === 2) {
                return; // Already focused on an actively playing source
            }
            var count = mprisModel.rowCount();
            for (var i = 0; i < count; i++) {
                if (i !== mprisModel.currentIndex) {
                    mprisModel.currentIndex = i;
                    if (mprisModel.currentPlayer && mprisModel.currentPlayer.playbackStatus === 2) {
                        return; // Successfully locked onto the active player
                    }
                }
            }
        }
    }

    // Titlebar Header Actions: Equalizer button + Source Cycler
    headerActions: [
        Rectangle {
            id: eqToggleBtn
            Layout.preferredWidth: 46; Layout.preferredHeight: 15
            radius: mediaPanel.buttonRadius
            color: eqToggleMa.containsMouse ? Qt.rgba(mediaPanel.highlightColor.r, mediaPanel.highlightColor.g, mediaPanel.highlightColor.b, 0.18) : "transparent"
            border.color: mediaPanel.eqEnabled ? mediaPanel.highlightColor : Qt.rgba(mediaPanel.accentColor.r, mediaPanel.accentColor.g, mediaPanel.accentColor.b, mediaPanel.hudBorderOpacity)
            border.width: 1
            opacity: eqToggleMa.containsMouse ? 1.0 : (mediaPanel.eqEnabled ? 0.95 : 0.6)
            
            Text {
                anchors.centerIn: parent
                text: mediaPanel.eqEnabled ? "EQ ON" : "EQ OFF"
                color: mediaPanel.eqEnabled ? mediaPanel.highlightColor : mediaPanel.accentColor
                font.family: mediaPanel.fontFamily
                font.pixelSize: Math.round(7.5 * mediaPanel.fontScale)
                font.bold: true
            }
            MouseArea {
                id: eqToggleMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mediaPanel.toggleEqualizer()
            }
        },
        Rectangle {
            Layout.preferredWidth: 38; Layout.preferredHeight: 15
            radius: mediaPanel.buttonRadius
            color: swapMa.containsMouse ? Qt.rgba(mediaPanel.accentColor.r, mediaPanel.accentColor.g, mediaPanel.accentColor.b, 0.18) : "transparent"
            border.color: swapMa.containsMouse ? mediaPanel.highlightColor : Qt.rgba(mediaPanel.accentColor.r, mediaPanel.accentColor.g, mediaPanel.accentColor.b, mediaPanel.hudBorderOpacity)
            border.width: 1
            visible: mprisModel.rowCount() > 1
            Text {
                anchors.centerIn: parent
                text: "SWAP"
                color: swapMa.containsMouse ? mediaPanel.highlightColor : mediaPanel.accentColor
                font.family: mediaPanel.fontFamily
                font.pixelSize: Math.round(7.5 * mediaPanel.fontScale)
                font.bold: true
            }
            MouseArea {
                id: swapMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (mprisModel.rowCount() > 0) {
                        mprisModel.currentIndex = (mprisModel.currentIndex + 1) % mprisModel.rowCount()
                    }
                }
            }
        }
    ]

    // Passive HUD audio line (0% GPU)

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item { Layout.fillHeight: true }

        // TRACK INFO
        Text {
            Layout.fillWidth: true
            text: {
                if (mprisModel.currentPlayer && mprisModel.currentPlayer.track && mprisModel.currentPlayer.track.length > 0) {
                    return mprisModel.currentPlayer.track
                }
                return mprisModel.currentPlayer ? "NO TRACK LOADED" : "AWAITING TELEMETRY..."
            }
            color: (mprisModel.currentPlayer && mprisModel.currentPlayer.playbackStatus === 2) ? "white" : Qt.rgba(1, 1, 1, 0.8)
            font.family: mediaPanel.fontFamily
            font.pixelSize: Math.round(11 * mediaPanel.fontScale)
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: {
                if (mprisModel.currentPlayer && mprisModel.currentPlayer.artist && mprisModel.currentPlayer.artist.length > 0) {
                    var info = mprisModel.currentPlayer.artist
                    if (mprisModel.currentPlayer.album && mprisModel.currentPlayer.album.length > 0) {
                        info += " // " + mprisModel.currentPlayer.album
                    }
                    return info
                }
                return mprisModel.currentPlayer ? "UNKNOWN ARTIST" : "NO ACTIVE MEDIA LINK"
            }
            color: mediaPanel.accentColor
            font.family: mediaPanel.fontFamily
            font.pixelSize: Math.round(9 * mediaPanel.fontScale)
            opacity: 0.8
            elide: Text.ElideRight
        }
        
        Item { Layout.preferredHeight: 4 }

        // PROGRESS BAR
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: formatTime(mediaPanel.currentTrackPosition)
                color: mediaPanel.accentColor
                font.family: mediaPanel.fontFamily
                font.pixelSize: Math.round(9 * mediaPanel.fontScale)
            }
            
            // Seek Bar (Unified 6px Track + Style-Adaptive Geometry)
            Rectangle {
                id: seekTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                color: Qt.rgba(mediaPanel.accentColor.r, mediaPanel.accentColor.g, mediaPanel.accentColor.b, 0.16)
                radius: mediaPanel.cardRadius
                
                Rectangle {
                    height: parent.height
                    width: mprisModel.currentPlayer && mprisModel.currentPlayer.length > 0 ? Math.min(parent.width, Math.max(0, (mediaPanel.currentTrackPosition / mprisModel.currentPlayer.length) * parent.width)) : 0
                    color: mediaPanel.highlightColor
                    radius: mediaPanel.cardRadius
                }

                // Glowing Playhead Thumb (Harmonized with Mixing Sliders)
                Rectangle {
                    width: 8; height: 12
                    radius: mediaPanel.buttonRadius
                    color: mediaPanel.highlightColor
                    border.color: mediaPanel.highlightColor
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    x: mprisModel.currentPlayer && mprisModel.currentPlayer.length > 0 ? Math.min(parent.width - 4, Math.max(0, (mediaPanel.currentTrackPosition / mprisModel.currentPlayer.length) * parent.width - 4)) : 0
                    visible: mprisModel.currentPlayer && mprisModel.currentPlayer.length > 0
                }
                
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mprisModel.currentPlayer && mprisModel.currentPlayer.canSeek && mprisModel.currentPlayer.length > 0) {
                            var pct = Math.max(0, Math.min(1, mouse.x / width))
                            var targetUs = pct * mprisModel.currentPlayer.length
                            mediaPanel.currentTrackPosition = targetUs
                            mprisModel.currentPlayer.position = targetUs
                        }
                    }
                }
            }

            Text {
                text: formatTime(mprisModel.currentPlayer ? mprisModel.currentPlayer.length : 0)
                color: mediaPanel.accentColor
                font.family: mediaPanel.fontFamily
                font.pixelSize: Math.round(9 * mediaPanel.fontScale)
                opacity: 0.6
            }
        }
        
        Item { Layout.preferredHeight: 2 }

        // CONTROLS
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24
            
            // Previous
            Text {
                text: "[ << ]"
                color: (mprisModel.currentPlayer && mprisModel.currentPlayer.canGoPrevious) ? mediaPanel.accentColor : Qt.rgba(mediaPanel.accentColor.r, mediaPanel.accentColor.g, mediaPanel.accentColor.b, 0.3)
                font.family: mediaPanel.fontFamily
                font.pixelSize: Math.round(11 * mediaPanel.fontScale)
                font.bold: true
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                    onClicked: if (mprisModel.currentPlayer) mprisModel.currentPlayer.Previous()
                }
            }
            // Play/Pause
            Text {
                text: mprisModel.currentPlayer && mprisModel.currentPlayer.playbackStatus === 2 /* Playing */ ? "[ || ]" : "[ > ]"
                color: (mprisModel.currentPlayer && mprisModel.currentPlayer.canControl) ? mediaPanel.highlightColor : Qt.rgba(mediaPanel.accentColor.r, mediaPanel.accentColor.g, mediaPanel.accentColor.b, 0.3)
                font.family: mediaPanel.fontFamily
                font.pixelSize: Math.round(11 * mediaPanel.fontScale)
                font.bold: true
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                    onClicked: if (mprisModel.currentPlayer) mprisModel.currentPlayer.PlayPause()
                }
            }
            // Next
            Text {
                text: "[ >> ]"
                color: (mprisModel.currentPlayer && mprisModel.currentPlayer.canGoNext) ? mediaPanel.accentColor : Qt.rgba(mediaPanel.accentColor.r, mediaPanel.accentColor.g, mediaPanel.accentColor.b, 0.3)
                font.family: mediaPanel.fontFamily
                font.pixelSize: Math.round(11 * mediaPanel.fontScale)
                font.bold: true
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                    onClicked: if (mprisModel.currentPlayer) mprisModel.currentPlayer.Next()
                }
            }
        }
    }
}
