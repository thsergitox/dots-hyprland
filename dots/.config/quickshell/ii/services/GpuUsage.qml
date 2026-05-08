pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Métricas de la GPU NVIDIA vía nvidia-smi.
 * En laptops con Optimus/PRIME, la dGPU puede estar dormida → nvidia-smi falla.
 * En ese caso `available = false` y la UI muestra "GPU dormida".
 */
Singleton {
    id: root

    readonly property int updateInterval: 5000

    property bool available: false
    property real usagePercent: 0
    property real memUsedMB: 0
    property real memTotalMB: 1
    property real memUsedPercent: memTotalMB > 0 ? memUsedMB / memTotalMB : 0
    property real temperature: 0
    property real powerDraw: 0
    property real fanPercent: 0

    Process {
        id: smiProcess
        running: false
        command: ["bash", "-c",
            "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,fan.speed " +
            "--format=csv,noheader,nounits 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text || "").trim()
                if (t.length === 0) {
                    root.available = false
                    return
                }
                // Formato: "12, 1024, 6144, 55, 35.2, 30"
                const parts = t.split(",").map(s => s.trim())
                if (parts.length < 6) {
                    root.available = false
                    return
                }
                root.usagePercent = parseFloat(parts[0]) || 0
                root.memUsedMB = parseFloat(parts[1]) || 0
                root.memTotalMB = parseFloat(parts[2]) || 1
                root.temperature = parseFloat(parts[3]) || 0
                root.powerDraw = parseFloat(parts[4]) || 0
                root.fanPercent = parseFloat(parts[5]) || 0
                root.available = true
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: root.updateInterval
        triggeredOnStart: true
        onTriggered: {
            if (!smiProcess.running) smiProcess.running = true
        }
    }
}
