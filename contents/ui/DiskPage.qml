import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

Item {
    id: root
    property bool expanded: false
    property bool active: false
    property var history: []
    property real totalBytes: 0
    property real freeBytes: 0
    property var readHistory: []
    property var writeHistory: []
    // detected on first open: the physical disk behind "/" and its NVMe temperature sensor
    property string disk: ""
    property string nvmeChip: ""
    readonly property string diskCmd: "lsblk -lsno NAME,TYPE \"$(findmnt -no SOURCE / | sed 's/\\[.*//')\" | awk '$2==\"disk\"{print $1; exit}'"
    readonly property string chipCmd: "sensors 2>/dev/null | grep -m1 '^nvme-'"
    readonly property string dfCmd: "df -B1 --output=size,avail / | tail -n 1"
    Sensors.Sensor { id: read; sensorId: root.disk ? "disk/" + root.disk + "/read" : ""; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: write; sensorId: root.disk ? "disk/" + root.disk + "/write" : ""; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: used; sensorId: "disk/all/usedPercent"; updateRateLimit: root.active ? 10000 : 60000 }
    Sensors.Sensor { id: temp; sensorId: root.nvmeChip ? "lmsensors/" + root.nvmeChip + "/temp1" : ""; updateRateLimit: root.active ? 10000 : 60000 }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (sourceName, data) => {
            const out = String(data.stdout || "").trim();
            if (sourceName === root.diskCmd) {
                root.disk = out;
            } else if (sourceName === root.chipCmd) {
                root.nvmeChip = out;
            } else {
                const fields = out.split(/\s+/);
                root.totalBytes = Number(fields[0]) || root.totalBytes;
                root.freeBytes = Number(fields[1]) || root.freeBytes;
            }
            disconnectSource(sourceName);
        }
    }
    function detect() { if (!disk) { exec.connectSource(diskCmd); exec.connectSource(chipCmd); } }
    onActiveChanged: if (active) detect()
    Component.onCompleted: if (active) detect()
    Timer { interval: 30000; repeat: true; running: root.active; triggeredOnStart: true; onTriggered: exec.connectSource(root.dfCmd) }
    Timer {
        interval: 2000; repeat: true; running: root.active
        onTriggered: {
            let r = root.readHistory.slice(-58); r.push(Number(read.value) || 0); root.readHistory = r;
            let w = root.writeHistory.slice(-58); w.push(Number(write.value) || 0); root.writeHistory = w;
        }
    }
    function rate(v) { if (!isFinite(v)) return "–"; if (v >= 1048576) return (v / 1048576).toFixed(1) + " MB/s"; return Math.round(v / 1024) + " KB/s"; }
    function capacity(v) { return v >= 1e12 ? (v / 1e12).toFixed(1) + " TB" : (v / 1e9).toFixed(1) + " GB"; }
    Flickable {
        anchors.fill: parent; contentHeight: body.implicitHeight; clip: true
        ColumnLayout {
            id: body; width: parent.width; spacing: 8
            Item { Layout.preferredHeight: 2 }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: card.implicitHeight + 18; radius: 7
                color: Qt.alpha(Kirigami.Theme.textColor, 0.07)
                ColumnLayout {
                    id: card; anchors.fill: parent; anchors.margins: 9; spacing: 4
                    RowLayout {
                        PC3.Label { text: (root.disk || "Disk") + " · /"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                        PC3.Label { text: "⋮"; opacity: 0.5 }
                    }
                    RowLayout {
                        ColumnLayout {
                            Layout.preferredWidth: 72; spacing: 0
                            DetailRow { label: ""; value: root.rate(read.value); dotColor: "#ff4655" }
                            DetailRow { label: ""; value: root.rate(write.value); dotColor: "#168cff" }
                        }
                        HistoryGraph {
                            Layout.fillWidth: true; implicitHeight: 38
                            values: root.readHistory; lineColor: "#ff4655"
                            secondaryValues: root.writeHistory; secondaryColor: "#168cff"
                            mirrored: true; mirrorDirection: -1; secondaryDirection: 1
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, 1 - (root.freeBytes / Math.max(1, root.totalBytes)))); height: parent.height; radius: 4; color: Kirigami.Theme.highlightColor }
                    }
                    RowLayout {
                        PC3.Label { text: root.totalBytes > 0 ? root.capacity(root.freeBytes) + " of " + root.capacity(root.totalBytes) + " free" : "Root filesystem capacity unavailable"; font.pixelSize: 10; Layout.fillWidth: true }
                        PC3.Label { text: root.totalBytes > 0 ? Math.round(root.freeBytes / root.totalBytes * 100) + "% free" : "–"; font.pixelSize: 10; font.bold: true }
                    }
                }
            }
            DetailRow { label: "NVMe temperature:"; value: isFinite(temp.value) ? Number(temp.value).toFixed(0) + "°C" : "–" }
            PC3.Label { text: "Storage reports the mounted root filesystem."; font.pixelSize: 10; opacity: 0.55; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            SectionHeader { title: "Top processes by disk I/O" }
            ProcessList { Layout.fillWidth: true; active: root.active; metric: "disk" }
        }
    }
}
