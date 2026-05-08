pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Temperaturas, fans y frecuencia de CPU.
 * Descubre los hwmon paths por `name` (no por número) porque los índices
 * no son estables entre reinicios.
 */
Singleton {
    id: root

    readonly property int updateInterval: 3000

    // Temperaturas (°C). 0 si no se descubrió.
    property real cpuTemp: 0
    property real gpuAmdTemp: 0
    property real ssdTemp: 0
    property real chassisTemp: 0

    // Velocidades de ventiladores (RPM). 0 si no se descubrió.
    property int fan1Rpm: 0
    property int fan2Rpm: 0

    // Frecuencia CPU promedio (MHz)
    property int cpuFreqMhz: 0

    Process {
        id: sensorsProcess
        running: false
        // Descubre hwmon paths por nombre y lee temps + fans + cpu freq en una sola pasada.
        // (uso una string normal para evitar conflictos de template literals con sintaxis bash)
        command: ["bash", "-c",
            "declare -A hw\n" +
            "for f in /sys/class/hwmon/*/name; do\n" +
            "    n=$(cat \"$f\" 2>/dev/null)\n" +
            "    [ -n \"$n\" ] && hw[$n]=$(dirname \"$f\")\n" +
            "done\n" +
            "read_temp() {\n" +
            "    local path=\"$1/temp1_input\"\n" +
            "    [ -r \"$path\" ] && awk '{printf \"%.0f\", $1/1000}' \"$path\" || echo 0\n" +
            "}\n" +
            "read_fan() {\n" +
            "    [ -r \"$1\" ] && cat \"$1\" || echo 0\n" +
            "}\n" +
            "cpu_temp=$(read_temp \"${hw[k10temp]:-${hw[coretemp]:-}}\")\n" +
            "gpu_amd_temp=$(read_temp \"${hw[amdgpu]:-}\")\n" +
            "ssd_temp=$(read_temp \"${hw[nvme]:-}\")\n" +
            "chassis_temp=$(read_temp \"${hw[acpitz]:-}\")\n" +
            "fan1=$(read_fan \"${hw[asus]:-}/fan1_input\")\n" +
            "fan2=$(read_fan \"${hw[asus]:-}/fan2_input\")\n" +
            "freq=$(awk -F': ' '/^cpu MHz/ {sum+=$2; n++} END {if (n>0) printf \"%.0f\", sum/n; else print 0}' /proc/cpuinfo)\n" +
            "printf '{\"cpuTemp\":%s,\"gpuAmdTemp\":%s,\"ssdTemp\":%s,\"chassisTemp\":%s,\"fan1\":%s,\"fan2\":%s,\"freq\":%s}\\n' \\\n" +
            "    \"$cpu_temp\" \"$gpu_amd_temp\" \"$ssd_temp\" \"$chassis_temp\" \"$fan1\" \"$fan2\" \"$freq\"\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.length === 0) return
                try {
                    const data = JSON.parse(text)
                    root.cpuTemp = data.cpuTemp || 0
                    root.gpuAmdTemp = data.gpuAmdTemp || 0
                    root.ssdTemp = data.ssdTemp || 0
                    root.chassisTemp = data.chassisTemp || 0
                    root.fan1Rpm = data.fan1 || 0
                    root.fan2Rpm = data.fan2 || 0
                    root.cpuFreqMhz = data.freq || 0
                } catch (e) {
                    console.warn("[SystemSensors] parse error:", e.message)
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
            if (!sensorsProcess.running) sensorsProcess.running = true
        }
    }
}
