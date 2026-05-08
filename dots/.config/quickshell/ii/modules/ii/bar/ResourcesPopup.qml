import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    // Helpers de formato
    function formatKB(kb) { return (kb / (1024 * 1024)).toFixed(1) + " GB" }
    function formatGB(gb) { return gb.toFixed(1) + " GB" }
    function formatPercent(frac) { return Math.round(frac * 100) + "%" }
    function formatFreq(mhz) {
        if (!mhz || mhz <= 0) return "—"
        return (mhz / 1000).toFixed(2) + " GHz"
    }
    function formatTemp(c) {
        if (!c || c <= 0) return "—"
        return Math.round(c) + "°C"
    }
    function formatRate(bps) {
        if (bps < 1024) return bps.toFixed(0) + " B/s"
        if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + " MB/s"
        return (bps / (1024 * 1024 * 1024)).toFixed(2) + " GB/s"
    }

    ColumnLayout {
        id: rootLayout
        anchors.centerIn: parent
        spacing: 10

        // === Header de glance ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // CPU resumen
            RowLayout {
                spacing: 4
                MaterialSymbol {
                    text: "memory"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: `CPU ${root.formatPercent(ResourceUsage.cpuUsage)} · ${root.formatFreq(SystemSensors.cpuFreqMhz)} · ${root.formatTemp(SystemSensors.cpuTemp)}`
                    color: Appearance.colors.colOnLayer1
                }
            }

            // RAM resumen
            RowLayout {
                spacing: 4
                MaterialSymbol {
                    text: "developer_board"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: `RAM ${root.formatPercent(ResourceUsage.memoryUsedPercentage)}`
                    color: Appearance.colors.colOnLayer1
                }
            }

            // GPU resumen
            RowLayout {
                spacing: 4
                MaterialSymbol {
                    text: "videogame_asset"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: GpuUsage.available
                        ? `GPU ${Math.round(GpuUsage.usagePercent)}% · ${root.formatTemp(GpuUsage.temperature)}`
                        : Translation.tr("GPU dormida")
                    color: GpuUsage.available ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnSurfaceVariant
                }
            }

            // Red resumen
            RowLayout {
                spacing: 4
                visible: NetworkUsage.interfaceName.length > 0
                MaterialSymbol {
                    text: "swap_vert"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: `↓ ${root.formatRate(NetworkUsage.downBytesPerSec)}  ↑ ${root.formatRate(NetworkUsage.upBytesPerSec)}`
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        // Separador sutil
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.colors.colLayer0Border
        }

        // === Grid de cards detalladas ===
        GridLayout {
            id: detailsGrid
            columns: 4
            rowSpacing: 14
            columnSpacing: 18
            Layout.fillWidth: true

            // ---- CPU ----
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                StyledPopupHeaderRow { icon: "planner_review"; label: "CPU" }
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: root.formatPercent(ResourceUsage.cpuUsage)
                }
                StyledPopupValueRow {
                    icon: "speed"
                    label: Translation.tr("Freq:")
                    value: root.formatFreq(SystemSensors.cpuFreqMhz)
                }
                StyledPopupValueRow {
                    icon: "thermostat"
                    label: Translation.tr("Temp:")
                    value: root.formatTemp(SystemSensors.cpuTemp)
                }
                StyledPopupValueRow {
                    icon: "mode_fan"
                    label: Translation.tr("Fans:")
                    value: SystemSensors.fan1Rpm > 0
                        ? `${SystemSensors.fan1Rpm} / ${SystemSensors.fan2Rpm} RPM`
                        : "—"
                }
            }

            // ---- RAM ----
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                StyledPopupHeaderRow { icon: "memory"; label: "RAM" }
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.memoryUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.memoryFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.memoryTotal)
                }
            }

            // ---- Swap (solo si hay) ----
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                visible: ResourceUsage.swapTotal > 1
                StyledPopupHeaderRow { icon: "swap_horiz"; label: "Swap" }
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.swapUsed)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.swapTotal)
                }
            }

            // ---- GPU ----
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                StyledPopupHeaderRow { icon: "videogame_asset"; label: "GPU" }
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: GpuUsage.available ? `${Math.round(GpuUsage.usagePercent)}%` : Translation.tr("dormida")
                }
                StyledPopupValueRow {
                    visible: GpuUsage.available
                    icon: "developer_board"
                    label: Translation.tr("VRAM:")
                    value: GpuUsage.available
                        ? `${(GpuUsage.memUsedMB / 1024).toFixed(1)} / ${(GpuUsage.memTotalMB / 1024).toFixed(1)} GB`
                        : "—"
                }
                StyledPopupValueRow {
                    visible: GpuUsage.available
                    icon: "thermostat"
                    label: Translation.tr("Temp:")
                    value: root.formatTemp(GpuUsage.temperature)
                }
                StyledPopupValueRow {
                    visible: GpuUsage.available
                    icon: "electrical_services"
                    label: Translation.tr("Power:")
                    value: GpuUsage.available ? `${GpuUsage.powerDraw.toFixed(1)} W` : "—"
                }
            }

            // ---- Disco ----
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                StyledPopupHeaderRow { icon: "storage"; label: Translation.tr("Disco") }
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatGB(DiskUsage.usedGB)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatGB(DiskUsage.freeGB)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatGB(DiskUsage.totalGB)
                }
            }

            // ---- Red ----
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                StyledPopupHeaderRow { icon: "wifi"; label: Translation.tr("Red") }
                StyledPopupValueRow {
                    icon: "download"
                    label: Translation.tr("Down:")
                    value: root.formatRate(NetworkUsage.downBytesPerSec)
                }
                StyledPopupValueRow {
                    icon: "upload"
                    label: Translation.tr("Up:")
                    value: root.formatRate(NetworkUsage.upBytesPerSec)
                }
                StyledPopupValueRow {
                    icon: "router"
                    label: Translation.tr("SSID:")
                    value: NetworkUsage.ssid.length > 0 ? NetworkUsage.ssid : (NetworkUsage.interfaceName || "—")
                }
            }

            // ---- Temperaturas adicionales ----
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                StyledPopupHeaderRow { icon: "thermostat"; label: Translation.tr("Otros temps") }
                StyledPopupValueRow {
                    icon: "save"
                    label: Translation.tr("SSD:")
                    value: root.formatTemp(SystemSensors.ssdTemp)
                }
                StyledPopupValueRow {
                    icon: "videogame_asset"
                    label: Translation.tr("iGPU:")
                    value: root.formatTemp(SystemSensors.gpuAmdTemp)
                }
                StyledPopupValueRow {
                    icon: "laptop"
                    label: Translation.tr("Chasis:")
                    value: root.formatTemp(SystemSensors.chassisTemp)
                }
            }

            // ---- Top procesos ----
            // memoryTotal viene en KB; (mem%/100)*(memoryTotal/1024/1024) → GB
            Column {
                spacing: 4
                Layout.alignment: Qt.AlignTop

                StyledPopupHeaderRow { icon: "format_list_numbered"; label: Translation.tr("Top CPU") }
                Repeater {
                    model: TopProcesses.topByCpu
                    delegate: StyledPopupValueRow {
                        required property var modelData
                        icon: "drag_indicator"
                        label: (modelData.name || "?").substring(0, 14)
                        value: `${modelData.cpu.toFixed(1)}%`
                    }
                }

                StyledPopupHeaderRow {
                    icon: "format_list_numbered"
                    label: Translation.tr("Top RAM")
                }
                Repeater {
                    model: TopProcesses.topByMem
                    delegate: Column {
                        required property var modelData
                        spacing: 0
                        StyledPopupValueRow {
                            icon: "drag_indicator"
                            label: (modelData.name || "?").substring(0, 14)
                            value: `${modelData.mem.toFixed(1)}%`
                        }
                        StyledText {
                            x: 24
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                            text: `${((modelData.mem / 100) * (ResourceUsage.memoryTotal / (1024 * 1024))).toFixed(2)} GB`
                        }
                    }
                }
            }
        }
    }
}
