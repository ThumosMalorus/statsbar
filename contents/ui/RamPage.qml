import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

Item {
    id: root
    property bool expanded: false
    property bool active: false
    property var history: []
    Sensors.Sensor { id: used; sensorId: "memory/physical/used"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: usedPct; sensorId: "memory/physical/usedPercent"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: total; sensorId: "memory/physical/total"; updateRateLimit: root.active ? 10000 : 60000 }
    Sensors.Sensor { id: app; sensorId: "memory/physical/application"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: buffers; sensorId: "memory/physical/buffer"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: cache; sensorId: "memory/physical/cache"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: free; sensorId: "memory/physical/free"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: swap; sensorId: "memory/swap/used"; updateRateLimit: root.active ? 5000 : 60000 }
    function size(v) { return !isFinite(v) ? "–" : v >= 1073741824 ? (v / 1073741824).toFixed(2) + " GB" : Math.round(v / 1048576) + " MB"; }
    Flickable {
        anchors.fill: parent
        contentHeight: body.implicitHeight
        clip: true
        ColumnLayout {
            id: body; width: parent.width; spacing: 6
            Item { Layout.preferredHeight: 8 }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Ring {
                    value: usedPct.value ?? 0
                    centerText: usedPct.value < 60 ? "Normal" : usedPct.value < 85 ? "Moderate" : "High"
                    caption: "Memory pressure"
                    ringColor: usedPct.value < 60 ? "#36d36b" : usedPct.value < 85 ? "#ffc42b" : "#ff465d"
                    implicitWidth: 72
                }
                Item { Layout.fillWidth: true }
                Ring { value: usedPct.value ?? 0; implicitWidth: 78 }
                Item { Layout.fillWidth: true }
            }
            SectionHeader { title: "Usage history" }
            HistoryGraph { Layout.fillWidth: true; implicitHeight: 90; maxValue: 100; values: root.history; fillColor: "#b24caf"; lineColor: "#b24caf" }
            SectionHeader { title: "Details" }
            DetailRow { label: "Used:"; value: root.size(used.value) }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 10; radius: 4; color: Qt.alpha(Kirigami.Theme.textColor, 0.13)
                Row {
                    anchors.fill: parent
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(app.value) / Math.max(1, Number(total.value)))); height: parent.height; color: "#168cff" }
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(buffers.value) / Math.max(1, Number(total.value)))); height: parent.height; color: "#ff942e" }
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(cache.value) / Math.max(1, Number(total.value)))); height: parent.height; color: "#ff375f" }
                }
            }
            DetailRow { label: "Application:"; value: root.size(app.value); dotColor: "#168cff" }
            DetailRow { label: "Buffers:"; value: root.size(buffers.value); dotColor: "#ff942e" }
            DetailRow { label: "Cache:"; value: root.size(cache.value); dotColor: "#ff375f" }
            DetailRow { label: "Free:"; value: root.size(free.value); dotColor: "#888888" }
            DetailRow { label: "Swap used:"; value: root.size(swap.value) }
            SectionHeader { title: "Top processes" }
            ProcessList { Layout.fillWidth: true; active: root.active; metric: "memory" }
        }
    }
}
