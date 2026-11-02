import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    property bool active: false
    property string metric: "rss"
    property var rows: []
    property var previousIo: ({})
    property double previousIoTime: 0
    spacing: 3
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (sourceName, data) => {
            if (data.stdout !== undefined) {
                const outputLines = String(data.stdout).trim().split("\n").filter(line => line.length > 0);
                const lines = root.metric === "disk" ? outputLines : outputLines.slice(1);
                if (root.metric === "disk") {
                    const now = Date.now();
                    const seconds = root.previousIoTime > 0 ? Math.max(1, (now - root.previousIoTime) / 1000) : 5;
                    const next = {};
                    root.rows = lines.map(line => {
                        const p = line.trim().split(/\s+/);
                        const bytes = Number(p[1]) || 0;
                        const rate = root.previousIo[p[0]] === undefined ? 0 : Math.max(0, bytes - root.previousIo[p[0]]) / seconds;
                        next[p[0]] = bytes;
                        return { name: p.slice(2).join(" "), cpu: 0, mem: rate };
                    }).filter(r => r.name.length > 0).sort((a, b) => b.mem - a.mem).slice(0, 8);
                    root.previousIo = next;
                    root.previousIoTime = now;
                } else {
                    root.rows = lines.slice(0, 8).map(line => {
                        const p = line.trim().split(/\s+/);
                        return { name: p.slice(0, -2).join(" "), cpu: Number(p[p.length - 2]) || 0, mem: Number(p[p.length - 1]) || 0 };
                    });
                }
            }
            disconnectSource(sourceName);
        }
    }
    Timer {
        interval: 5000; repeat: true; running: root.active; triggeredOnStart: true
        // ps %cpu is a lifetime average, so take top's second (live) sample instead
        onTriggered: exec.connectSource(root.metric === "cpu"
                    ? "echo header; top -b -n 2 -d 0.5 -o %CPU -w 512 | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ {print $12, $9, 0}' | head -n 8"
                    : root.metric === "disk"
                      ? "for p in $(ps -u $(id -u) -o pid=); do b=$(awk '/^(read_bytes|write_bytes):/ {s+=$2} END {print s+0}' /proc/$p/io 2>/dev/null); printf '%s %s %s\\n' \"$p\" \"$b\" \"$(cat /proc/$p/comm 2>/dev/null)\"; done"
                      : "ps -eo comm,%cpu,rss --sort=-rss | head -n 9")
    }
    RowLayout {
        Layout.fillWidth: true
        PC3.Label { text: "Process"; font.pixelSize: 10; opacity: 0.48; Layout.fillWidth: true }
        PC3.Label { text: root.metric === "cpu" ? "Usage" : root.metric === "disk" ? "I/O" : "Memory"; font.pixelSize: 10; opacity: 0.48 }
    }
    Repeater {
        model: root.rows
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            PC3.Label { text: "▪"; color: Kirigami.Theme.highlightColor; font.pixelSize: 10 }
            PC3.Label { text: modelData.name; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
            PC3.Label {
                text: root.metric === "cpu" ? modelData.cpu.toFixed(1) + "%" : root.metric === "disk" ? modelData.mem >= 1024 * 1024 ? (modelData.mem / 1048576).toFixed(1) + " MB/s" : (modelData.mem / 1024).toFixed(0) + " KB/s" : modelData.mem > 1024 ? (modelData.mem / 1024).toFixed(0) + " MB" : modelData.mem + " KB"
                font.pixelSize: 10; font.bold: true
            }
        }
    }
    PC3.Label { visible: root.rows.length === 0; text: root.active ? "Collecting process data…" : "Open popup to collect"; font.pixelSize: 10; opacity: 0.55 }
}
