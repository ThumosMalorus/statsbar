import QtQuick
import org.kde.kirigami as Kirigami

// Circular gauge with an optional caption underneath; the caption is part of
// the item's height so layouts don't let it overlap whatever comes next.
Item {
    id: root
    property real value: 0
    property string centerText: Math.round(value) + "%"
    property string caption: ""
    property color ringColor: "#168cff"
    implicitWidth: 72
    implicitHeight: implicitWidth + (caption ? captionLabel.implicitHeight + 2 : 0)
    Canvas {
        id: canvas
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.implicitWidth
        height: root.implicitWidth
        onPaint: {
            const c = getContext("2d");
            c.clearRect(0, 0, width, height);
            const line = Math.max(5, width * 0.09);
            const r = Math.min(width, height) / 2 - line;
            c.lineWidth = line;
            c.lineCap = "round";
            c.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.17);
            c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke();
            c.strokeStyle = root.ringColor;
            c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(1, root.value / 100))); c.stroke();
        }
    }
    Text {
        anchors.centerIn: canvas
        text: root.centerText
        color: Kirigami.Theme.textColor
        font.pixelSize: root.centerText.length > 5 ? 13 : 16
        font.bold: true
    }
    Text {
        id: captionLabel
        anchors.top: canvas.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.caption !== ""
        text: root.caption
        color: Kirigami.Theme.textColor
        opacity: 0.7
        font.pixelSize: 10
    }
    onValueChanged: canvas.requestPaint()
    onRingColorChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
