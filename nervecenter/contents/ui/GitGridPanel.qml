/*
 *  NerveCenter — GitGridPanel.qml
 *  Live GitHub Contribution Graph & local repository telemetry.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasma5support as P5Support
import QtCore

NervePanel {
    id: gitRoot
    panelId: "gitGridPanel"
    title: "GITHUB" + (githubUser.length > 0 ? (" // " + githubUser.toUpperCase()) : " // TELEMETRY")
    subLabel: totalContributions + " COMMITS"
    status: isSyncing ? "warning" : "nominal"

    minWidth: 240
    minHeight: 180

    property string githubUser: gitSettings.username || ""
    property int totalContributions: 0
    property int maxDayContributions: 1
    property string hoveredInfo: ""
    property string latestCommitText: "git: idle"
    property bool isSyncing: false

    // Grid data: 7 rows x N weeks
    property var contributionList: []

    Settings {
        id: gitSettings
        category: "GitGrid"
        property string username: ""
        property string repoPath: ""
        property string cachedJson: ""
        property int cachedTotal: 0
    }

    function rescan() {
        var user = gitSettings.username || gitRoot.githubUser;
        var sources = [];
        if (user && user.length > 0) {
            gitRoot.isSyncing = true;
            sources.push("curl -s --max-time 4 'https://github-contributions-api.jogruber.de/v4/" + user + "?y=last' 2>/dev/null");
        } else {
            gitRoot.isSyncing = false;
        }

        var path = gitSettings.repoPath;
        if (path && path.length > 0) {
            sources.push("git -C '" + path + "' log -1 --pretty=format:'%h // %s' 2>/dev/null");
        } else {
            sources.push("git log -1 --pretty=format:'%h // %s' 2>/dev/null");
        }
        gitExec.connectedSources = sources;
    }

    P5Support.DataSource {
        id: gitExec
        engine: "executable"
        connectedSources: []
        interval: gitRoot.isPanelActive ? 180000 : 0
        onNewData: function(source, data) {
            gitRoot.isSyncing = false;
            var out = (data["stdout"] || "").trim();
            if (source.indexOf("github-contributions-api") >= 0) {
                if (out.indexOf("contributions") >= 0) {
                    gitSettings.cachedJson = out;
                    parseGitHubJson(out);
                }
            } else if (source.indexOf("log -1") >= 0) {
                if (out.length > 0) gitRoot.latestCommitText = out;
                else gitRoot.latestCommitText = "No local commits detected";
            }
        }
    }

    function parseGitHubJson(jsonStr) {
        try {
            var data = JSON.parse(jsonStr);
            if (!data || !data.contributions || !Array.isArray(data.contributions)) return;

            if (data.total && typeof data.total.lastYear === "number") {
                gitRoot.totalContributions = data.total.lastYear;
                gitSettings.cachedTotal = data.total.lastYear;
            }

            var arr = data.contributions;
            var maxCount = 0;
            for (var i = 0; i < arr.length; i++) {
                if (arr[i].count > maxCount) maxCount = arr[i].count;
            }
            gitRoot.maxDayContributions = maxCount;
            gitRoot.contributionList = arr;
        } catch (e) {
            // retain existing
        }
    }

    Component.onCompleted: {
        if (gitSettings.cachedJson && gitSettings.cachedJson.length > 10) {
            parseGitHubJson(gitSettings.cachedJson);
        }
        rescan();
    }

    // Titlebar Header Actions
    headerActions: [
        Rectangle {
            Layout.preferredHeight: 15
            Layout.preferredWidth: profileLabel.implicitWidth + 10
            visible: gitRoot.githubUser.length > 0
            color: profileMa.containsMouse ? Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.18) : "transparent"
            border.color: profileMa.containsMouse ? gitRoot.highlightColor : Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, gitRoot.hudBorderOpacity)
            border.width: 1
            radius: gitRoot.buttonRadius

            Text {
                id: profileLabel
                anchors.centerIn: parent
                text: "↗ PROFILE"
                color: profileMa.containsMouse ? gitRoot.highlightColor : gitRoot.accentColor
                font.family: gitRoot.fontFamily
                font.pixelSize: Math.round(7.5 * gitRoot.fontScale)
                font.bold: true
            }

            MouseArea {
                id: profileMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://github.com/" + gitRoot.githubUser)
            }
        },
        Rectangle {
            Layout.preferredWidth: 42; Layout.preferredHeight: 15
            color: scanMa.containsMouse ? Qt.rgba(gitRoot.highlightColor.r, gitRoot.highlightColor.g, gitRoot.highlightColor.b, 0.18) : "transparent"
            border.color: gitRoot.highlightColor
            border.width: 1
            radius: gitRoot.buttonRadius
            opacity: scanMa.containsMouse ? 1.0 : 0.85

            Text {
                anchors.centerIn: parent
                text: gitRoot.isSyncing ? "SYNC" : "RESCAN"
                color: gitRoot.highlightColor
                font.family: gitRoot.fontFamily
                font.pixelSize: Math.round(7.5 * gitRoot.fontScale)
                font.bold: true
            }

            MouseArea {
                id: scanMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: gitRoot.rescan()
            }
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Telemetry / Hover Stats Banner
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: gitRoot.hoveredInfo !== ""
                      ? gitRoot.hoveredInfo
                      : (gitRoot.totalContributions + " CONTRIBUTIONS IN 2026 // PEAK: " + gitRoot.maxDayContributions + " COMMITS/DAY")
                color: gitRoot.hoveredInfo !== "" ? gitRoot.highlightColor : gitRoot.accentColor
                font.family: gitRoot.fontFamily
                font.pixelSize: Math.round(8.5 * gitRoot.fontScale)
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // GitHub Level Legend (0 to 4)
            RowLayout {
                spacing: 3
                Text { text: "LESS"; color: gitRoot.accentColor; opacity: 0.5; font.family: gitRoot.fontFamily; font.pixelSize: 7 }
                Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: Math.min(1.5, gitRoot.cardRadius); color: Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.08) }
                Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: Math.min(1.5, gitRoot.cardRadius); color: Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.38) }
                Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: Math.min(1.5, gitRoot.cardRadius); color: Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.70) }
                Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: Math.min(1.5, gitRoot.cardRadius); color: gitRoot.accentColor }
                Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: Math.min(1.5, gitRoot.cardRadius); color: gitRoot.highlightColor }
                Text { text: "MORE"; color: gitRoot.accentColor; opacity: 0.5; font.family: gitRoot.fontFamily; font.pixelSize: 7 }
            }
        }

        // The Activity Heatmap Grid (1:1 True Square Tiles with Unified Spacing)
        Item {
            id: gridContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real gridGutter: 2.5
            readonly property real tileSize: Math.max(6, Math.min(14, Math.floor((height - (6 * gridGutter)) / 7)))
            readonly property int numWeeks: Math.max(12, Math.floor((width - 18) / (tileSize + gridGutter)))
            property int totalDaysToShow: numWeeks * 7

            Row {
                anchors.centerIn: parent
                spacing: gridContainer.gridGutter

                // Weekday Labels (Sun, Tue, Thu, Sat)
                Column {
                    spacing: gridContainer.gridGutter
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        Item {
                            width: 10
                            height: gridContainer.tileSize
                            Text {
                                anchors.centerIn: parent
                                text: (index % 2 === 1) ? modelData : ""
                                color: gitRoot.accentColor
                                opacity: 0.5
                                font.family: gitRoot.fontFamily
                                font.pixelSize: 7
                            }
                        }
                    }
                }

                // Columns (Each column is 1 week of 7 days)
                Row {
                    spacing: gridContainer.gridGutter

                    Repeater {
                        model: gridContainer.numWeeks
                        delegate: Column {
                            id: colLayout
                            spacing: gridContainer.gridGutter
                            property int colIdx: index

                            Repeater {
                                model: 7 // 7 days (Sun=0 to Sat=6)
                                delegate: Rectangle {
                                    id: cellRect
                                    width: gridContainer.tileSize
                                    height: gridContainer.tileSize
                                    radius: Math.min(1.5, gitRoot.cardRadius)

                                    property int dayOffsetFromEnd: (gridContainer.numWeeks - 1 - colLayout.colIdx) * 7 + (6 - index)
                                    property int itemIndex: (gitRoot.contributionList.length - 1) - dayOffsetFromEnd
                                    property var itemData: (itemIndex >= 0 && itemIndex < gitRoot.contributionList.length) ? gitRoot.contributionList[itemIndex] : null
                                    property int count: itemData ? itemData.count : 0
                                    property int level: itemData ? itemData.level : 0

                                    color: {
                                        if (!itemData) return Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.05);
                                        if (level === 0) return Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.08);
                                        if (level === 1) return Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.38);
                                        if (level === 2) return Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.70);
                                        if (level === 3) return gitRoot.accentColor;
                                        return gitRoot.highlightColor;
                                    }

                                    border.color: cellMa.containsMouse ? gitRoot.highlightColor
                                                : (level > 0 ? Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.45)
                                                             : Qt.rgba(gitRoot.accentColor.r, gitRoot.accentColor.g, gitRoot.accentColor.b, 0.12))
                                    border.width: 1

                                    MouseArea {
                                        id: cellMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            if (itemData) {
                                                gitRoot.hoveredInfo = itemData.date + " : " + itemData.count + " contribution" + (itemData.count === 1 ? "" : "s") + " on GitHub";
                                            }
                                        }
                                        onExited: {
                                            gitRoot.hoveredInfo = "";
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom telemetry strip: Latest local repo commit
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "LOCAL COMMIT:"
                color: gitRoot.accentColor
                opacity: 0.65
                font.family: gitRoot.fontFamily
                font.pixelSize: Math.round(8 * gitRoot.fontScale)
                font.bold: true
            }
            Text {
                text: gitRoot.latestCommitText
                color: "white"
                font.family: gitRoot.fontFamily
                font.pixelSize: Math.round(8 * gitRoot.fontScale)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
