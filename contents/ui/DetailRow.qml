import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3

RowLayout {
    property string label
    property string value
    property color dotColor: "transparent"
    spacing: 6
    Rectangle { Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 3; color: parent.dotColor; visible: parent.dotColor !== "transparent" }
    PC3.Label { text: parent.label; font.pixelSize: 11; opacity: 0.83; Layout.fillWidth: true; elide: Text.ElideRight }
    PC3.Label { text: parent.value; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignRight }
}
