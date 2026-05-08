pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Espacio del filesystem raíz (/). df cada 30s — los cambios son lentos.
 */
Singleton {
    id: root

    readonly property int updateInterval: 30000

    property real totalGB: 0
    property real usedGB: 0
    property real freeGB: 0
    property real usedPercent: totalGB > 0 ? usedGB / totalGB : 0

    Process {
        id: dfProcess
        running: false
        command: ["bash", "-c",
            "df -B1 / | awk 'NR==2 {printf \"%s %s %s\", $2, $3, $4}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text || "").trim()
                if (t.length === 0) return
                const parts = t.split(/\s+/).map(Number)
                if (parts.length < 3 || isNaN(parts[0])) return
                const GB = 1024 * 1024 * 1024
                root.totalGB = parts[0] / GB
                root.usedGB = parts[1] / GB
                root.freeGB = parts[2] / GB
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: root.updateInterval
        triggeredOnStart: true
        onTriggered: {
            if (!dfProcess.running) dfProcess.running = true
        }
    }
}
