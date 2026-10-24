/*
 *  NerveCenter — NetGraph.qml
 *  One reusable rate graph (used for both download and upload).
 *  Bind `rate` (bytes/s) from a sensor; the graph samples it on its own 1 s clock.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.quickcharts as Charts

Item {
    id: g

    property string title: ""
    property color  lineColor: "#00f0ff"
    property real   rate: 0                 // latest bytes/s
    property int    samples: 60             // seconds of history shown
    property string fontFamily: "monospace"
    property real   fontScale: 1.0

    property var  history: new Array(samples).fill(0)
    property real targetMax: 16384          // clean power-of-two ceiling (labels use this)
    property real displayMax: targetMax     // animated copy (chart uses this)
    Behavior on displayMax { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    function px(n) { return Math.round(n * fontScale) }

    function fmt(b, digits) {
        if (b < 1024)    return b.toFixed(0) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(digits) + " KiB/s"
        return (b / 1048576).toFixed(digits) + " MiB/s"
    }

    // Axis tops snap to 16K, 32K, 64K ... so labels are always round numbers
    function niceCeil(v) {
        return Math.pow(2, Math.ceil(Math.log(Math.max(v, 16384)) / Math.LN2))
    }

    function push(v) {
        var h = history.slice(1)
        h.push(Math.max(0, v))
        history = h
        var peak = 0
        for (var i = 0; i < h.length; i++) if (h[i] > peak) peak = h[i]
        targetMax = niceCeil(peak * 1.1)    // grows at once, shrinks when the peak leaves the window
    }

    // Fixed 1 s cadence: the time axis never stalls, even if the sensor value repeats
    Timer { interval: 1000; running: true; repeat: true; onTriggered: g.push(g.rate) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle { Layout.preferredWidth: 3; Layout.preferredHeight: 10; radius: 1; color: g.lineColor }
            Text {
                text: g.title; color: g.lineColor; opacity: 0.85
                font.family: g.fontFamily; font.pixelSize: g.px(9); font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: g.fmt(g.rate, 1); color: "#ffffff"
                font.family: g.fontFamily; font.pixelSize: g.px(9); font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // Axis labels sit in their own column, so they never cover the data
            Item {
                id: axis
                Layout.fillHeight: true
                Layout.preferredWidth: g.px(52)
                Repeater {
                    model: 3                                  // top, middle, zero
                    Text {
                        property real frac: index / 2
                        text: g.fmt(g.targetMax * (1 - frac), 0)
                        color: g.lineColor; opacity: 0.7
                        font.family: g.fontFamily; font.pixelSize: g.px(8)
                        anchors.right: parent.right
                        y: Math.max(0, Math.min(axis.height - height, frac * (axis.height - 1) - height / 2))
                    }
                }
            }

            Item {
                id: plot
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Grid lines at the same fractions the labels use
                Repeater {
                    model: 5
                    Rectangle {
                        width: plot.width; height: 1
                        y: index * (plot.height - 1) / 4
                        color: g.lineColor; opacity: index % 2 === 0 ? 0.22 : 0.10
                    }
                }

                Charts.LineChart {
                    anchors.fill: parent
                    interpolate: false          // smoothing overshoots below 0 on spikes
                    lineWidth: 1.5
                    fillOpacity: 0.25
                    direction: Charts.XYChart.ZeroAtStart
                    xRange { from: 0; to: g.samples - 1; automatic: false }
                    yRange { from: 0; to: g.displayMax; automatic: false }
                    valueSources: [ Charts.ArraySource { array: g.history } ]
                    colorSource: Charts.SingleValueSource { value: g.lineColor }
                }
            }
        }
    }
}
