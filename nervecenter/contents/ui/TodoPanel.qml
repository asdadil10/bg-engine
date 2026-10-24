/*
 *  NerveCenter — TodoPanel.qml
 *  Cyberpunk task directives HUD panel with persistence and completion tracking.
 *  Inherits standard NervePanel for effortless, unified HUD integration.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore

NervePanel {
    id: todoRoot
    panelId: "todoPanel"
    title: "TASK_CORE // DIRECTIVES"
    subLabel: "[" + getCompletedCount() + "/" + taskList.length + "]"

    minWidth: 200
    minHeight: 180

    Settings {
        id: todoSettings
        category: "Directives"
        property string tasksJson: '[{"text":"Initialize NerveCenter HUD telemetry","done":true},{"text":"Review system performance diagnostics","done":false},{"text":"Deploy neural audio equalizer profiles","done":false}]'
    }

    property var taskList: []

    function loadTasks() {
        try {
            var arr = JSON.parse(todoSettings.tasksJson);
            if (Array.isArray(arr)) {
                taskList = arr;
            } else {
                taskList = [];
            }
        } catch (e) {
            taskList = [];
        }
    }

    function saveTasks() {
        todoSettings.tasksJson = JSON.stringify(taskList);
        var copy = [];
        for (var i = 0; i < taskList.length; i++) {
            copy.push(taskList[i]);
        }
        taskList = copy;
    }

    function addTask(title) {
        if (!title || title.trim().length === 0) return;
        taskList.push({ text: title.trim(), done: false });
        saveTasks();
    }

    function toggleTask(index) {
        if (index >= 0 && index < taskList.length) {
            taskList[index].done = !taskList[index].done;
            saveTasks();
        }
    }

    function removeTask(index) {
        if (index >= 0 && index < taskList.length) {
            taskList.splice(index, 1);
            saveTasks();
        }
    }

    function clearCompleted() {
        taskList = taskList.filter(function(item) { return !item.done; });
        saveTasks();
    }

    function getCompletedCount() {
        var count = 0;
        for (var i = 0; i < taskList.length; i++) {
            if (taskList[i].done) count++;
        }
        return count;
    }

    Component.onCompleted: loadTasks()

    // Titlebar Purge Action
    headerActions: [
        Rectangle {
            Layout.preferredWidth: 42; Layout.preferredHeight: 15
            color: clearMa.containsMouse ? Qt.rgba(todoRoot.accentColor.r, todoRoot.accentColor.g, todoRoot.accentColor.b, 0.18) : "transparent"
            border.color: clearMa.containsMouse ? todoRoot.highlightColor : Qt.rgba(todoRoot.accentColor.r, todoRoot.accentColor.g, todoRoot.accentColor.b, todoRoot.hudBorderOpacity)
            border.width: 1
            radius: todoRoot.buttonRadius
            opacity: clearMa.containsMouse ? 1.0 : 0.75
            visible: todoRoot.getCompletedCount() > 0

            Text {
                anchors.centerIn: parent
                text: "PURGE"
                color: clearMa.containsMouse ? todoRoot.highlightColor : todoRoot.accentColor
                font.family: todoRoot.fontFamily
                font.pixelSize: Math.round(7.5 * todoRoot.fontScale)
                font.bold: true
            }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: todoRoot.clearCompleted()
            }
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Input Row: Add New Directive
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                color: Qt.rgba(0, 0, 0, 0.45)
                border.color: taskInput.activeFocus ? todoRoot.highlightColor : Qt.rgba(todoRoot.accentColor.r, todoRoot.accentColor.g, todoRoot.accentColor.b, todoRoot.hudBorderOpacity)
                border.width: 1
                radius: todoRoot.cardRadius

                TextInput {
                    id: taskInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    font.family: todoRoot.fontFamily
                    font.pixelSize: Math.round(10 * todoRoot.fontScale)
                    clip: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "+ New directive..."
                        color: todoRoot.accentColor
                        opacity: 0.45
                        font: taskInput.font
                        visible: !taskInput.text && !taskInput.activeFocus
                    }

                    onAccepted: {
                        todoRoot.addTask(taskInput.text);
                        taskInput.text = "";
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 44; Layout.preferredHeight: 26
                color: addMa.containsMouse ? Qt.rgba(todoRoot.highlightColor.r, todoRoot.highlightColor.g, todoRoot.highlightColor.b, 0.2) : "transparent"
                border.color: todoRoot.highlightColor
                border.width: 1
                radius: todoRoot.buttonRadius

                Text {
                    anchors.centerIn: parent
                    text: "ADD"
                    color: todoRoot.highlightColor
                    font.family: todoRoot.fontFamily
                    font.pixelSize: Math.round(9 * todoRoot.fontScale)
                    font.bold: true
                }

                MouseArea {
                    id: addMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        todoRoot.addTask(taskInput.text);
                        taskInput.text = "";
                    }
                }
            }
        }

        // Tasks ListView
        ListView {
            id: tasksListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5
            model: todoRoot.taskList

            delegate: Rectangle {
                id: taskDelegate
                width: tasksListView.width
                height: 28
                color: itemMa.containsMouse ? Qt.rgba(todoRoot.accentColor.r, todoRoot.accentColor.g, todoRoot.accentColor.b, 0.08) : "transparent"
                radius: todoRoot.cardRadius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 10

                    // Checkbox
                    Rectangle {
                        Layout.preferredWidth: 14; Layout.preferredHeight: 14
                        radius: Math.min(2, todoRoot.cardRadius)
                        color: modelData.done ? Qt.rgba(todoRoot.highlightColor.r, todoRoot.highlightColor.g, todoRoot.highlightColor.b, 0.25) : "transparent"
                        border.color: modelData.done ? todoRoot.highlightColor : Qt.rgba(todoRoot.accentColor.r, todoRoot.accentColor.g, todoRoot.accentColor.b, todoRoot.hudBorderOpacity)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: todoRoot.highlightColor
                            font.pixelSize: 9
                            font.bold: true
                            visible: modelData.done
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: todoRoot.toggleTask(index)
                        }
                    }

                    // Task Text
                    Text {
                        Layout.fillWidth: true
                        text: modelData.text
                        color: modelData.done ? Qt.rgba(1, 1, 1, 0.4) : "white"
                        font.family: todoRoot.fontFamily
                        font.pixelSize: Math.round(10.5 * todoRoot.fontScale)
                        font.strikeout: modelData.done
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: todoRoot.toggleTask(index)
                        }
                    }

                    // Delete Button
                    Text {
                        text: "×"
                        color: delMa.containsMouse ? todoRoot.highlightColor : Qt.rgba(todoRoot.accentColor.r, todoRoot.accentColor.g, todoRoot.accentColor.b, 0.45)
                        font.pixelSize: 14
                        font.bold: true
                        visible: itemMa.containsMouse || delMa.containsMouse

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: todoRoot.removeTask(index)
                        }
                    }
                }

                MouseArea {
                    id: itemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                }
            }

            // Empty state text
            Text {
                anchors.centerIn: parent
                text: "// ALL DIRECTIVES SATISFIED //"
                color: todoRoot.accentColor
                opacity: 0.35
                font.family: todoRoot.fontFamily
                font.pixelSize: Math.round(9 * todoRoot.fontScale)
                font.letterSpacing: 1
                visible: todoRoot.taskList.length === 0
            }
        }
    }
}
