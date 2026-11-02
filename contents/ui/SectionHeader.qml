import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

RowLayout {
    property string title
    spacing: 6
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Kirigami.Theme.textColor; opacity: 0.15 }
    PC3.Label { text: parent.title.toUpperCase(); font.pixelSize: 9; font.bold: true; opacity: 0.42 }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Kirigami.Theme.textColor; opacity: 0.15 }
}
