import QtQuick
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    property int coreIndex: 0
    property bool active: false
    radius: 3
    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
    Sensors.Sensor { id: core; sensorId: "cpu/cpu" + root.coreIndex + "/usage"; updateRateLimit: root.active ? 2000 : 60000 }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * Math.max(0, Math.min(1, Number(core.value) / 100))
        radius: 3
        // BC-250 has no efficiency cores; colour by SMT sibling instead (even = physical, odd = HT)
        color: root.coreIndex % 2 === 0 ? "#7775ef" : "#59ccd4"
        opacity: 0.95
    }
}
