pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root
    property bool expanded: false
    property bool active: false
    property var history: []
    Sensors.Sensor { id: usage; sensorId: "cpu/all/usage"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: temp; sensorId: "cpu/all/averageTemperature"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: system; sensorId: "cpu/all/system"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: user; sensorId: "cpu/all/user"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: wait; sensorId: "cpu/all/wait"; updateRateLimit: root.active ? 2000 : 60000 }
    Sensors.Sensor { id: avg1; sensorId: "cpu/loadaverages/loadaverage1"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: avg5; sensorId: "cpu/loadaverages/loadaverage5"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: avg15; sensorId: "cpu/loadaverages/loadaverage15"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: freq; sensorId: "cpu/all/averageFrequency"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: minfreq; sensorId: "cpu/all/minimumFrequency"; updateRateLimit: root.active ? 5000 : 60000 }
    Sensors.Sensor { id: maxfreq; sensorId: "cpu/all/maximumFrequency"; updateRateLimit: root.active ? 5000 : 60000 }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (sourceName, data) => {
            const raw = String(data.stdout || "0").trim();
            const seconds = Number(raw.split(" ")[0]);
            root.uptime = seconds >= 86400 ? Math.floor(seconds / 86400) + " days, " + Math.floor((seconds % 86400) / 3600) + " hours" : Math.floor(seconds / 3600) + " h " + Math.floor((seconds % 3600) / 60) + " min";
            disconnectSource(sourceName);
        }
    }
    property string uptime: "–"
    Sensors.Sensor { id: cpuCount; sensorId: "cpu/all/cpuCount"; updateRateLimit: 60000 }

    // ---- TUNE: links to tuning tools, each shown only if installed ----
    property string customLabel: ""
    property string customCommand: ""
    property var tools: ({})
    readonly property bool hasTools: !!(tools.lact || tools.governorConfig || tools["skillfish-tuner"]) || customCommand !== ""
    signal launched()
    readonly property string governorConf: "/etc/cyan-skillfish-governor-smu/config.toml"
    readonly property string detectCmd: "for c in lact skillfish-tuner kate pkexec; do command -v \"$c\" >/dev/null 2>&1 && echo \"$c\"; done; test -f " + governorConf + " && echo governorConfig; systemctl is-active --quiet cyan-skillfish-governor-smu && echo governorRunning; for p in /usr/lib/qt6/plugins/kf6/kio/admin.so /usr/lib64/qt6/plugins/kf6/kio/admin.so /usr/lib/*/qt6/plugins/kf6/kio/admin.so; do test -r \"$p\" && { echo kioAdmin; break; }; done; true"
    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function launch(cmd) {
        // setsid -f detaches the app so it outlives this popup (and plasmashell restarts)
        launcher.connectSource("setsid -f sh -c " + quote(cmd) + " >/dev/null 2>&1");
        root.launched();
    }
    P5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: (sourceName, data) => {
            if (sourceName === root.detectCmd) {
                const found = {};
                String(data.stdout || "").split("\n").forEach(l => { if (l.trim()) found[l.trim()] = true; });
                root.tools = found;
            }
            disconnectSource(sourceName);
        }
    }
    Component.onCompleted: launcher.connectSource(detectCmd)
    Timer { interval: 60000; repeat: true; running: root.active; triggeredOnStart: true; onTriggered: exec.connectSource("cat /proc/uptime") }

    Flickable {
        anchors.fill: parent
        contentHeight: body.implicitHeight
        clip: true
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 7
            Item { Layout.preferredHeight: 7 }
            RowLayout {
                Layout.fillWidth: true
                Ring { value: isFinite(temp.value) ? temp.value : 0; centerText: isFinite(temp.value) && temp.value > 0 ? (temp.value * 9 / 5 + 32).toFixed(0) + "°F" : "–°F"; caption: "Temperature"; ringColor: "#ffb21d"; implicitWidth: 60 }
                Ring { value: usage.value ?? 0; caption: "CPU"; implicitWidth: 67 }
                Ring { value: freq.value > 0 ? Math.min(freq.value / 5000 * 100, 100) : 0; centerText: freq.value > 0 ? (freq.value / 1000).toFixed(1) : "–"; caption: "GHz"; ringColor: "#458cff"; implicitWidth: 60 }
            }
            SectionHeader { title: "Usage history" }
            HistoryGraph { Layout.fillWidth: true; implicitHeight: 70; maxValue: 100; values: root.history; fillColor: "#a74bad"; lineColor: "#d566c6" }
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: cpuCount.value > 0 ? cpuCount.value : 16
                    delegate: CoreBar {
                        required property int index
                        coreIndex: index
                        active: root.active
                        Layout.fillWidth: true; Layout.preferredHeight: 42
                    }
                }
            }
            SectionHeader {
                title: "Tuning tools"
                visible: root.hasTools
            }
            Flow {
                id: tuneRow
                Layout.fillWidth: true
                spacing: 4
                visible: root.hasTools
                PC3.ToolButton {
                    visible: !!root.tools.lact
                    text: "LACT (GPU)"; icon.name: "io.github.ilya_zlobintsev.LACT"
                    display: PC3.AbstractButton.TextBesideIcon; font.pixelSize: 11
                    onClicked: root.launch("lact gui")
                }
                PC3.ToolButton {
                    visible: !!root.tools.governorConfig && !!root.tools.kate && !!root.tools.kioAdmin
                    text: "Governor settings"; icon.name: "document-edit"
                    display: PC3.AbstractButton.TextBesideIcon; font.pixelSize: 11
                    onClicked: root.launch("kate " + root.quote("admin://" + root.governorConf))
                }
                PC3.ToolButton {
                    visible: !!root.tools.governorRunning && !!root.tools.pkexec
                    text: "Restart GPU governor"; icon.name: "view-refresh"
                    display: PC3.AbstractButton.TextBesideIcon; font.pixelSize: 11
                    onClicked: root.launch("pkexec /usr/bin/systemctl restart cyan-skillfish-governor-smu")
                }
                PC3.ToolButton {
                    visible: !!root.tools["skillfish-tuner"]
                    text: "SkillFish Tuner"; icon.name: "skillfish-tuner"
                    display: PC3.AbstractButton.TextBesideIcon; font.pixelSize: 11
                    onClicked: root.launch("skillfish-tuner")
                }
                PC3.ToolButton {
                    visible: root.customCommand !== ""
                    text: root.customLabel || "Tune…"; icon.name: "configure"
                    display: PC3.AbstractButton.TextBesideIcon; font.pixelSize: 11
                    onClicked: root.launch(root.customCommand)
                }
            }
            SectionHeader { title: "Details" }
            DetailRow { label: "System:"; value: isFinite(system.value) ? Math.round(system.value) + "%" : "–"; dotColor: "#ff514e" }
            DetailRow { label: "User:"; value: isFinite(user.value) ? Math.round(user.value) + "%" : "–"; dotColor: "#428bff" }
            DetailRow { label: "Idle:"; value: isFinite(usage.value) ? Math.round(100 - usage.value - (wait.value || 0)) + "%" : "–"; dotColor: "#888888" }
            DetailRow { label: "Wait:"; value: isFinite(wait.value) ? Math.round(wait.value) + "%" : "–"; dotColor: "#58cbd5" }
            DetailRow { label: "Uptime:"; value: root.uptime }
            SectionHeader { title: "Average load" }
            DetailRow { label: "1 minute:"; value: isFinite(avg1.value) ? Number(avg1.value).toFixed(2) : "–" }
            DetailRow { label: "5 minutes:"; value: isFinite(avg5.value) ? Number(avg5.value).toFixed(2) : "–" }
            DetailRow { label: "15 minutes:"; value: isFinite(avg15.value) ? Number(avg15.value).toFixed(2) : "–" }
            SectionHeader { title: "Frequency" }
            DetailRow { label: "All cores average:"; value: freq.value > 0 ? Math.round(freq.value) + " MHz" : "–" }
            DetailRow { label: "Minimum:"; value: minfreq.value > 0 ? Math.round(minfreq.value) + " MHz" : "–"; dotColor: "#58cbd5" }
            DetailRow { label: "Maximum:"; value: maxfreq.value > 0 ? Math.round(maxfreq.value) + " MHz" : "–"; dotColor: "#7775ef" }
            SectionHeader { title: "Top processes" }
            ProcessList { Layout.fillWidth: true; active: root.active; metric: "cpu" }
        }
    }
}
