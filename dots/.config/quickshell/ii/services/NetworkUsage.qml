pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Tasa de transferencia (down/up bytes/s) de la interfaz activa + SSID si es WiFi.
 * Calcula por diferencia entre lecturas consecutivas de /proc/net/dev.
 */
Singleton {
    id: root

    readonly property int updateInterval: 3000

    property string interfaceName: ""
    property string ssid: ""
    property real downBytesPerSec: 0
    property real upBytesPerSec: 0

    // Estado para diff
    property real _lastRxBytes: 0
    property real _lastTxBytes: 0
    property real _lastTimestamp: 0

    function formatRate(bytesPerSec) {
        if (bytesPerSec < 1024) return `${bytesPerSec.toFixed(0)} B/s`
        if (bytesPerSec < 1024 * 1024) return `${(bytesPerSec / 1024).toFixed(1)} KB/s`
        if (bytesPerSec < 1024 * 1024 * 1024) return `${(bytesPerSec / (1024 * 1024)).toFixed(1)} MB/s`
        return `${(bytesPerSec / (1024 * 1024 * 1024)).toFixed(2)} GB/s`
    }

    // Descubre la interfaz activa (la que tiene la default route) cada vez.
    Process {
        id: ifaceProcess
        running: false
        command: ["bash", "-c",
            "iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}'); " +
            "ssid=$(iwgetid -r 2>/dev/null); " +
            "if [ -n \"$iface\" ] && [ -r /proc/net/dev ]; then " +
            "  line=$(grep -E \"^\\s*$iface:\" /proc/net/dev | head -1); " +
            "  rx=$(echo \"$line\" | awk '{print $2}'); " +
            "  tx=$(echo \"$line\" | awk '{print $10}'); " +
            "  printf '{\"iface\":\"%s\",\"ssid\":\"%s\",\"rx\":%s,\"tx\":%s,\"ts\":%s}\\n' " +
            "    \"$iface\" \"$ssid\" \"${rx:-0}\" \"${tx:-0}\" \"$(date +%s.%N)\"; " +
            "else " +
            "  echo '{\"iface\":\"\",\"ssid\":\"\",\"rx\":0,\"tx\":0,\"ts\":0}'; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text || "").trim()
                if (t.length === 0) return
                try {
                    const data = JSON.parse(t)
                    root.interfaceName = data.iface || ""
                    root.ssid = data.ssid || ""
                    const rx = data.rx
                    const tx = data.tx
                    const ts = data.ts
                    if (root._lastTimestamp > 0 && ts > root._lastTimestamp) {
                        const dt = ts - root._lastTimestamp
                        root.downBytesPerSec = Math.max(0, (rx - root._lastRxBytes) / dt)
                        root.upBytesPerSec = Math.max(0, (tx - root._lastTxBytes) / dt)
                    }
                    root._lastRxBytes = rx
                    root._lastTxBytes = tx
                    root._lastTimestamp = ts
                } catch (e) {
                    console.warn("[NetworkUsage] parse error:", e.message)
                }
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: root.updateInterval
        triggeredOnStart: true
        onTriggered: {
            if (!ifaceProcess.running) ifaceProcess.running = true
        }
    }
}
