/*
 *  NerveCenter — CyberWeatherGlyph.qml
 *  Monochromatic vector tactical HUD weather glyph renderer.
 *  Draws clean cybernetic weather symbols styled strictly in HUD palette.
 */
import QtQuick

Item {
    id: glyphRoot
    width: 26
    height: 26

    property int weatherCode: 0
    property color primaryColor: "#00f0ff"
    property color secondaryColor: "#ff007f"
    property bool isToday: false

    onWeatherCodeChanged: canvas.requestPaint()
    onPrimaryColorChanged: canvas.requestPaint()
    onSecondaryColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var w = width;
            var h = height;
            var cx = w / 2;
            var cy = h / 2;
            var code = glyphRoot.weatherCode;
            var color = glyphRoot.primaryColor;
            var altColor = glyphRoot.secondaryColor;

            ctx.lineWidth = 1.4;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            if (code === 0) {
                // ── CLEAR SKY: Tactical Solar Reticle ──
                ctx.strokeStyle = color;
                // Center ring
                ctx.beginPath();
                ctx.arc(cx, cy, 4.5, 0, Math.PI * 2);
                ctx.stroke();

                // 8 radial tactical rays
                for (var i = 0; i < 8; i++) {
                    var angle = (i * Math.PI) / 4;
                    var x1 = cx + Math.cos(angle) * 7.0;
                    var y1 = cy + Math.sin(angle) * 7.0;
                    var x2 = cx + Math.cos(angle) * 10.5;
                    var y2 = cy + Math.sin(angle) * 10.5;
                    ctx.beginPath();
                    ctx.moveTo(x1, y1);
                    ctx.lineTo(x2, y2);
                    ctx.stroke();
                }
            } else if (code <= 2) {
                // ── PARTLY CLOUDY: Solar Reticle behind Cloud ──
                // Mini sun in upper right
                ctx.strokeStyle = color;
                ctx.beginPath();
                ctx.arc(cx + 4, cy - 4, 3.2, 0, Math.PI * 2);
                ctx.stroke();
                // 3 solar ticks
                var sunRays = [-Math.PI / 4, 0, -Math.PI / 2];
                for (var r = 0; r < sunRays.length; r++) {
                    var a = sunRays[r];
                    ctx.beginPath();
                    ctx.moveTo(cx + 4 + Math.cos(a) * 5.0, cy - 4 + Math.sin(a) * 5.0);
                    ctx.lineTo(cx + 4 + Math.cos(a) * 7.8, cy - 4 + Math.sin(a) * 7.8);
                    ctx.stroke();
                }

                // Cloud outline in foreground
                ctx.strokeStyle = altColor;
                ctx.beginPath();
                ctx.moveTo(cx - 8, cy + 5);
                ctx.lineTo(cx + 6, cy + 5);
                ctx.arc(cx + 4, cy + 2, 3.5, 0, -Math.PI / 2, true);
                ctx.arc(cx - 1, cy - 1, 4.5, 0, -Math.PI * 0.8, true);
                ctx.arc(cx - 6, cy + 2, 3.0, -Math.PI * 0.7, Math.PI / 2, true);
                ctx.closePath();
                ctx.stroke();
            } else if (code === 3 || (code >= 45 && code <= 48)) {
                // ── OVERCAST / FOG: Technical Dual Cloud Silhouettes ──
                ctx.strokeStyle = color;
                // Cloud silhouette
                ctx.beginPath();
                ctx.moveTo(cx - 7, cy + 3);
                ctx.lineTo(cx + 7, cy + 3);
                ctx.arc(cx + 5, cy, 3.5, 0, -Math.PI / 2, true);
                ctx.arc(cx, cy - 3, 5.0, 0, -Math.PI * 0.8, true);
                ctx.arc(cx - 5, cy, 3.2, -Math.PI * 0.7, Math.PI / 2, true);
                ctx.closePath();
                ctx.stroke();

                // Horizontal scanline or fog bars
                ctx.beginPath();
                ctx.moveTo(cx - 6, cy + 7);
                ctx.lineTo(cx + 6, cy + 7);
                ctx.stroke();
            } else if (code <= 67 || (code >= 80 && code <= 82)) {
                // ── RAIN / SHOWERS: Cloud with Angled Velocity Dashes ──
                ctx.strokeStyle = color;
                ctx.beginPath();
                ctx.moveTo(cx - 7, cy - 1);
                ctx.lineTo(cx + 7, cy - 1);
                ctx.arc(cx + 5, cy - 4, 3.5, 0, -Math.PI / 2, true);
                ctx.arc(cx, cy - 7, 5.0, 0, -Math.PI * 0.8, true);
                ctx.arc(cx - 5, cy - 4, 3.2, -Math.PI * 0.7, Math.PI / 2, true);
                ctx.closePath();
                ctx.stroke();

                // 3 angled rain velocity streaks
                ctx.strokeStyle = altColor;
                ctx.beginPath();
                ctx.moveTo(cx - 5, cy + 3); ctx.lineTo(cx - 7, cy + 8);
                ctx.moveTo(cx, cy + 3);     ctx.lineTo(cx - 2, cy + 8);
                ctx.moveTo(cx + 5, cy + 3); ctx.lineTo(cx + 3, cy + 8);
                ctx.stroke();
            } else if (code >= 95) {
                // ── THUNDERSTORM: Tactical Lightning Vector ──
                ctx.strokeStyle = color;
                // Cloud on top
                ctx.beginPath();
                ctx.moveTo(cx - 7, cy - 2);
                ctx.lineTo(cx + 7, cy - 2);
                ctx.arc(cx + 5, cy - 5, 3.5, 0, -Math.PI / 2, true);
                ctx.arc(cx, cy - 8, 5.0, 0, -Math.PI * 0.8, true);
                ctx.arc(cx - 5, cy - 5, 3.2, -Math.PI * 0.7, Math.PI / 2, true);
                ctx.closePath();
                ctx.stroke();

                // High-voltage lightning bolt
                ctx.strokeStyle = altColor;
                ctx.fillStyle = altColor;
                ctx.beginPath();
                ctx.moveTo(cx + 1, cy);
                ctx.lineTo(cx - 3, cy + 5);
                ctx.lineTo(cx, cy + 5);
                ctx.lineTo(cx - 2, cy + 10);
                ctx.lineTo(cx + 3, cy + 4);
                ctx.lineTo(cx, cy + 4);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();
            } else {
                // ── SNOW / FROST: 6-Ray Reticle Crystal ──
                ctx.strokeStyle = color;
                for (var s = 0; s < 3; s++) {
                    var sang = (s * Math.PI) / 3;
                    var sx1 = cx + Math.cos(sang) * 8.5;
                    var sy1 = cy + Math.sin(sang) * 8.5;
                    var sx2 = cx - Math.cos(sang) * 8.5;
                    var sy2 = cy - Math.sin(sang) * 8.5;
                    ctx.beginPath();
                    ctx.moveTo(sx1, sy1); ctx.lineTo(sx2, sy2);
                    ctx.stroke();
                }
                ctx.beginPath();
                ctx.arc(cx, cy, 2.0, 0, Math.PI * 2);
                ctx.stroke();
            }
        }
    }
}
