pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root
    readonly property int interval: 2000
    property string page: "network"
    property var cpuHistory: []
    property var ramHistory: []
    property var networkUpHistory: []
    property var networkDownHistory: []
    property var connectivity: []
    property string pingLatency: "–"
    property string pingJitter: "–"
    property real lastPingMs: -1
    property var pingVariations: []

    function sample(array, value) {
        const next = array.slice(Math.max(0, array.length - 59));
        next.push(Number(value) || 0);
        return next;
    }
    // Clicking the panel makes Plasma close an open popup (focus loss), and that can
    // land just before or just after our tap. Decide from the state at press time,
    // and reopen if Plasma closes the popup right after we switched pages.
    property bool wasExpandedAtPress: false
    property double switchedAt: 0
    function choosePage(name) {
        if (root.wasExpandedAtPress && root.page === name) {
            root.expanded = false;
        } else {
            if (root.page !== name) root.switchedAt = Date.now();
            root.page = name;
            root.expanded = true;
        }
    }
    function rate(bytes) {
        if (!isFinite(bytes) || bytes < 0) bytes = 0;
        if (bytes < 1000 * 1024) return Math.round(bytes / 1024) + " KB/s";
        return (bytes / 1048576).toFixed(1) + " MB/s";
    }
    function pct(v) { return isFinite(v) ? Math.round(v) + "%" : "–"; }

    P5Support.DataSource {
        id: pingSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            const output = String(data.stdout || "");
            // "bytes from" only appears on a reply; "0% packet loss" would also match "100% packet loss"
            const ok = output.indexOf("bytes from") >= 0;
            const latency = output.match(/time[=<]([0-9.]+)\s*ms/);
            root.pingLatency = latency ? latency[1] + " ms" : "Timeout";
            if (latency) {
                const current = Number(latency[1]);
                if (root.lastPingMs >= 0) {
                    const values = root.pingVariations.slice(-10);
                    values.push(Math.abs(current - root.lastPingMs));
                    root.pingVariations = values;
                    const mean = values.reduce((sum, value) => sum + value, 0) / values.length;
                    root.pingJitter = mean.toFixed(2) + " ms";
                }
                root.lastPingMs = current;
            }
            const next = root.connectivity.slice(Math.max(0, root.connectivity.length - 59));
            next.push(ok);
            root.connectivity = next;
            disconnectSource(sourceName);
        }
    }
    Timer {
        id: pingTimer
        interval: root.expanded ? 5000 : 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: pingSource.connectSource("ping -c 1 -W 1 1.1.1.1")
    }
    // don't make the user wait up to a minute for latency when a popup opens
    onExpandedChanged: () => {
        if (root.expanded) {
            pingTimer.restart();
        } else if (Date.now() - root.switchedAt < 500) {
            root.switchedAt = 0;
            Qt.callLater(() => { root.expanded = true; });
        }
    }

    Component {
        id: cpuPage
        CpuPage {
            active: root.expanded && root.page === "cpu"
            history: root.cpuHistory
            // KConfigPropertyMap provides these schema keys dynamically.
            // qmllint disable missing-property
            customLabel: Plasmoid.configuration.customLabel
            customCommand: Plasmoid.configuration.customCommand
            // qmllint enable missing-property
            onLaunched: root.expanded = false
        }
    }
    Component {
        id: ramPage
        RamPage { active: root.expanded && root.page === "ram"; history: root.ramHistory }
    }
    Component {
        id: diskPage
        DiskPage { active: root.expanded && root.page === "disk" }
    }
    Component {
        id: networkPage
        NetworkPage {
            active: root.expanded && root.page === "network"
            history: root.networkDownHistory
            uploadHistory: root.networkUpHistory
            connectivity: root.connectivity
            latencyText: root.pingLatency
            jitterText: root.pingJitter
        }
    }

    Sensors.Sensor { id: up; sensorId: "network/all/upload"; updateRateLimit: root.interval }
    Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: root.interval }
    Sensors.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: root.interval }
    Sensors.Sensor { id: ssd; sensorId: "disk/all/usedPercent"; updateRateLimit: 60000 }
    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: root.interval }

    Timer {
        interval: root.interval
        repeat: true
        running: true
        onTriggered: {
            root.cpuHistory = root.sample(root.cpuHistory, cpu.value);
            root.ramHistory = root.sample(root.ramHistory, ram.value);
            root.networkUpHistory = root.sample(root.networkUpHistory, up.value);
            root.networkDownHistory = root.sample(root.networkDownHistory, down.value);
        }
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    activationTogglesExpanded: false
    preferredRepresentation: compactRepresentation

    // no hover tooltip: the bar only reacts to clicks
    toolTipMainText: ""
    toolTipSubText: ""

    // One clickable section of the bar; highlights while its popup is open
    component Section: Item {
        id: section
        property string name
        default property alias content: holder.data
        implicitWidth: holder.childrenRect.width + 8
        // take the panel's real thickness so content centres like the clock
        // (a fixed minimum; reading childrenRect here would be a binding loop)
        implicitHeight: 24
        Layout.fillHeight: true
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 4
            color: Kirigami.Theme.textColor
            opacity: root.expanded && root.page === section.name ? 0.12 : 0
        }
        Item {
            id: holder
            x: 4
            width: childrenRect.width
            height: parent.height
        }
        TapHandler {
            onPressedChanged: if (pressed) root.wasExpandedAtPress = root.expanded
            onTapped: root.choosePage(section.name)
        }
    }

    // Small spaced caption over a medium-weight number with a smaller, dimmer "%"
    component Stat: Section {
        id: stat
        property string label
        property real value
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -1
            PC3.Label {
                text: stat.label
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                opacity: 0.6
            }
            RowLayout {
                spacing: 0
                PC3.Label {
                    Layout.alignment: Qt.AlignBaseline
                    text: isFinite(stat.value) ? Math.round(stat.value) : "–"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                PC3.Label {
                    text: "%"
                    font.pixelSize: 9
                    opacity: 0.7
                    Layout.alignment: Qt.AlignBaseline
                }
            }
            // reserve room for "100%" so the bar doesn't shift as values change
            Item {
                width: digits.width + 7
                height: 0
                TextMetrics { id: digits; font.pixelSize: 13; font.weight: Font.Medium; text: "100" }
            }
        }
    }

    component NetRow: Row {
        id: netRow
        property color dot
        property real bytes
        spacing: 4
        Rectangle {
            width: 5; height: 5; radius: 2.5
            color: netRow.dot
            anchors.verticalCenter: parent.verticalCenter
        }
        PC3.Label {
            text: root.rate(netRow.bytes)
            font.pixelSize: 10
            font.features: { "tnum": 1 }
        }
    }

    compactRepresentation: RowLayout {
        spacing: 2
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        Section {
            name: "network"
            // reserve room for "999 KB/s" so the bar doesn't shift, but keep the
            // spare space on the left so the rates sit right next to RAM
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: netWide.width + 9
                height: netCol.height
                TextMetrics { id: netWide; font.pixelSize: 10; text: "999 KB/s" }
                Column {
                    id: netCol
                    anchors.right: parent.right
                    spacing: -2
                    NetRow { dot: "#ff453a"; bytes: up.value || 0 }
                    NetRow { dot: "#0a84ff"; bytes: down.value || 0 }
                }
            }
        }
        Stat { name: "ram"; label: "RAM"; value: ram.value ?? NaN }
        Stat { name: "disk"; label: "SSD"; value: ssd.value ?? NaN }
        Stat { name: "cpu"; label: "CPU"; value: cpu.value ?? NaN }
    }

    fullRepresentation: Item {
        implicitWidth: 280
        implicitHeight: 620
        // the Plasma popup already draws the frame and background
        Item {
            anchors.fill: parent
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 0
                PC3.Label {
                    text: root.page === "network" ? "Network" : root.page === "ram" ? "RAM" : root.page === "disk" ? "Disk" : "CPU"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 15
                    font.bold: true
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: root.page === "network" ? networkPage : root.page === "ram" ? ramPage : root.page === "disk" ? diskPage : cpuPage
                }
            }
        }
    }
}
