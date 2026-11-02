import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root
    property var values: []
    property var secondaryValues: []
    property color fillColor: "#b04bab"
    property color lineColor: "#dc4d5a"
    property color secondaryColor: "#168cff"
    property bool mirrored: false
    property real maxValue: 0  // 0 = auto-scale to the largest sample
    property real mirrorDirection: -1
    property real secondaryDirection: 1
    implicitHeight: 80
    Rectangle { anchors.fill: parent; radius: 5; color: Qt.alpha(Kirigami.Theme.textColor, 0.08) }
    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 2
        onPaint: {
            const c = getContext("2d"); c.clearRect(0, 0, width, height);
            function series(values, color, direction) {
                const a = values || []; if (!a.length) return;
                let max = root.maxValue > 0 ? root.maxValue : 1; if (root.maxValue <= 0) for (let i = 0; i < a.length; ++i) max = Math.max(max, Number(a[i]) || 0);
                const step = width / Math.max(1, a.length - 1);
                c.beginPath();
                for (let j = 0; j < a.length; ++j) {
                    const v = Math.max(0, Number(a[j]) || 0) / max;
                    const y = root.mirrored ? height / 2 + direction * v * height / 2 : height - v * height * 0.9;
                    if (j === 0) c.moveTo(0, y); else c.lineTo(j * step, y);
                }
                if (root.mirrored) { c.lineTo(width, height / 2); c.lineTo(0, height / 2); c.closePath(); }
                else { c.lineTo(width, height); c.lineTo(0, height); c.closePath(); }
                c.fillStyle = Qt.alpha(color, 0.65); c.fill();
                c.strokeStyle = color; c.lineWidth = 1.5; c.stroke();
            }
            series(root.values, root.lineColor, root.mirrorDirection);
            series(root.secondaryValues, root.secondaryColor, root.secondaryDirection);
        }
    }
    onValuesChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
