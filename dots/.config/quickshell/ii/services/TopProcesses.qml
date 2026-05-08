pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Top procesos por CPU y por RAM.
 * Cada item: { pid, name, cpu, mem }
 */
Singleton {
    id: root

    readonly property int updateInterval: 5000
    readonly property int topCount: 3

    property var topByCpu: []
    property var topByMem: []

    function parseLines(text) {
        const lines = (text || "").trim().split("\n")
        return lines.map(line => {
            const m = line.trim().match(/^(\S+)\s+(\S+)\s+(\S+)\s+(.+)$/)
            if (!m) return null
            return {
                pid: m[1],
                cpu: parseFloat(m[2]) || 0,
                mem: parseFloat(m[3]) || 0,
                name: m[4].trim()
            }
        }).filter(x => x !== null)
    }

    // ps reporta %CPU por core (convención UNIX): 100% = 1 core saturado.
    // Dividimos por nproc para que sea consistente con el "CPU total" del sistema.
    // También agrupamos por nombre (comm) y SUMAMOS — Vivaldi/Chrome lanzan
    // muchos procesos hijos que individualmente no dicen mucho, pero juntos
    // muestran el consumo real de la app.
    readonly property string aggregateScript:
        "ps -eo %cpu,%mem,comm --no-headers | " +
        "awk -v n=\"$(nproc)\" '" +
            "{ name = $3; for (i = 4; i <= NF; i++) name = name \" \" $i; " +
            "  cpu[name] += $1 / n; mem[name] += $2 } " +
            "END { for (name in cpu) printf \"%.4f %.4f %s\\n\", cpu[name], mem[name], name }'"
    readonly property string formatScript:
        "awk '{ name = $3; for (i = 4; i <= NF; i++) name = name \" \" $i; " +
        "       printf \"0 %.1f %.1f %s\\n\", $1, $2, name }'"

    Process {
        id: cpuProcess
        running: false
        command: ["bash", "-c",
            `${root.aggregateScript} | sort -k1 -gr | head -${root.topCount} | ${root.formatScript}`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.topByCpu = root.parseLines(text)
            }
        }
    }

    Process {
        id: memProcess
        running: false
        command: ["bash", "-c",
            `${root.aggregateScript} | sort -k2 -gr | head -${root.topCount} | ${root.formatScript}`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.topByMem = root.parseLines(text)
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: root.updateInterval
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProcess.running) cpuProcess.running = true
            if (!memProcess.running) memProcess.running = true
        }
    }
}
