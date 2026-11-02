pragma ComponentBehavior: Bound

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
    property var connectivity: []
    property string iface: ""  // detected from the default route when the page opens
    property string interfaceStatus: "CHECKING"
    property string localAddress: "–"
    property string publicAddress: "Checking…"
    property string macAddress: "–"
    property string latencyText: "–"
    property string jitterText: "–"
    property real totalUpload: 0
    property real totalDownload: 0
    property double lastPublicCheck: 0
    property var uploadHistory: []
    Sensors.Sensor { id: upload; sensorId: "network/all/upload"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: download; sensorId: "network/all/download"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: localIp; sensorId: root.iface ? "network/" + root.iface + "/ipv4address" : ""; updateRateLimit: root.active ? 10000 : 60000 }
    Sensors.Sensor { id: tx; sensorId: root.iface ? "network/" + root.iface + "/totalUpload" : ""; updateRateLimit: root.active ? 10000 : 60000 }
    Sensors.Sensor { id: rx; sensorId: root.iface ? "network/" + root.iface + "/totalDownload" : ""; updateRateLimit: root.active ? 10000 : 60000 }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (sourceName, data) => {
            const out = String(data.stdout || "").trim();
            if (sourceName.indexOf("route get") >= 0) {
                const m = out.match(/\bdev\s+(\S+)/); if (m) root.iface = m[1];
                exec.connectSource("ip -o -4 addr show dev " + root.iface);
                exec.connectSource("cat /sys/class/net/" + root.iface + "/address");
                exec.connectSource("cat /sys/class/net/" + root.iface + "/operstate");
                exec.connectSource("cat /sys/class/net/" + root.iface + "/statistics/tx_bytes /sys/class/net/" + root.iface + "/statistics/rx_bytes");
            } else if (sourceName.indexOf("addr show") >= 0) {
                const m = out.match(/\binet\s+(\S+)/); if (m) root.localAddress = m[1].split("/")[0];
            } else if (sourceName.indexOf("address") >= 0) {
                root.macAddress = out || "–";
            } else if (sourceName.indexOf("curl") >= 0) {
                root.publicAddress = out || "Unavailable";
            } else if (sourceName.indexOf("ping") >= 0) {
                const m = out.match(/time[=<]([0-9.]+)\s*ms/); root.latencyText = m ? m[1] + " ms" : "Timeout";
            } else if (sourceName.indexOf("statistics") >= 0) {
                const fields = out.split(/\s+/); root.totalUpload = Number(fields[0]) || 0; root.totalDownload = Number(fields[1]) || 0;
            } else if (sourceName.indexOf("operstate") >= 0) {
                root.interfaceStatus = out.toUpperCase() || "UNKNOWN";
            }
            disconnectSource(sourceName);
        }
    }
    function checkPublicIp() {
        if (Date.now() - lastPublicCheck >= 600000) {
            lastPublicCheck = Date.now();
            publicAddress = "Checking…";
            exec.connectSource("curl -s --max-time 3 https://api.ipify.org");
        }
    }
    function refresh() { exec.connectSource("ip route get 1.1.1.1"); checkPublicIp(); }
    onActiveChanged: if (active) refresh()
    Component.onCompleted: if (active) refresh()
    Timer { interval: 600000; repeat: true; running: root.active; onTriggered: root.checkPublicIp() }
    Timer {
        interval: 30000; repeat: true; running: root.active && root.iface !== ""
        onTriggered: {
            exec.connectSource("cat /sys/class/net/" + root.iface + "/statistics/tx_bytes /sys/class/net/" + root.iface + "/statistics/rx_bytes");
            exec.connectSource("cat /sys/class/net/" + root.iface + "/operstate");
        }
    }
    function rate(v) { if (!isFinite(v)) return "–"; return v < 1000 * 1024 ? Math.round(v / 1024) + " KB/s" : (v / 1048576).toFixed(1) + " MB/s"; }
    function size(v) { return v >= 1e12 ? (v / 1e12).toFixed(2) + " TB" : v >= 1e9 ? (v / 1e9).toFixed(2) + " GB" : (v / 1e6).toFixed(1) + " MB"; }
    Flickable {
        anchors.fill: parent; contentHeight: body.implicitHeight; clip: true
        ColumnLayout {
            id: body; width: parent.width; spacing: 5
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: 0
                    PC3.Label { text: root.rate(download.value); font.pixelSize: 23; Layout.alignment: Qt.AlignHCenter }
                    RowLayout {
                        PC3.Label { text: "●"; color: "#168cff"; font.pixelSize: 10 }
                        PC3.Label { text: "Download"; font.pixelSize: 10 }
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: 0
                    PC3.Label { text: root.rate(upload.value); font.pixelSize: 23; Layout.alignment: Qt.AlignHCenter }
                    RowLayout {
                        PC3.Label { text: "●"; color: "#ff4655"; font.pixelSize: 10 }
                        PC3.Label { text: "Upload"; font.pixelSize: 10 }
                    }
                }
                Item { Layout.fillWidth: true }
            }
            Item { Layout.preferredHeight: 10 }
            SectionHeader { title: "Usage history" }
            HistoryGraph {
                Layout.fillWidth: true; implicitHeight: 84
                values: root.uploadHistory; lineColor: "#ff4655"
                secondaryValues: root.history; secondaryColor: "#168cff"
                mirrored: true; mirrorDirection: -1; secondaryDirection: 1
            }
            SectionHeader { title: "Connectivity history" }
            Grid {
                Layout.fillWidth: true; columns: 30; rowSpacing: 3; columnSpacing: 2
                Repeater {
                    model: 60
                    delegate: Rectangle {
                        required property int index
                        width: 7; height: 9; radius: 1
                        color: index < root.connectivity.length ? (root.connectivity[index] ? "#24d35d" : "#ff4655") : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                    }
                }
            }
            SectionHeader { title: "Interface" }
            DetailRow { label: "Total upload:"; value: root.size(root.totalUpload > 0 ? root.totalUpload : (tx.value || 0)) }
            DetailRow { label: "Total download:"; value: root.size(root.totalDownload > 0 ? root.totalDownload : (rx.value || 0)) }
            DetailRow { label: "Status:"; value: root.interfaceStatus; dotColor: root.interfaceStatus === "UP" ? "#2cc95d" : "#ff4655" }
            DetailRow { label: "Internet connection:"; value: root.latencyText === "–" ? "CHECKING" : root.latencyText === "Timeout" ? "DOWN" : "UP"; dotColor: root.latencyText === "–" ? "#888888" : root.latencyText === "Timeout" ? "#ff4655" : "#2cc95d" }
            DetailRow { label: "Latency:"; value: root.latencyText }
            DetailRow { label: "Jitter:"; value: root.jitterText }
            SectionHeader { title: "Interface details" }
            DetailRow { label: "Interface:"; value: root.iface }
            DetailRow { label: "Status:"; value: root.interfaceStatus; dotColor: root.interfaceStatus === "UP" ? "#2cc95d" : "#ff4655" }
            DetailRow { label: "Physical address:"; value: root.macAddress }
            SectionHeader { title: "Address" }
            DetailRow { label: "Local IP:"; value: localIp.value ? String(localIp.value) : root.localAddress }
            DetailRow { label: "Public IP:"; value: root.publicAddress }
        }
    }
}
