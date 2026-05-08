import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.calendar
import qs.modules.ii.sidebarRight.todo
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property string formattedDate: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM dd, yyyy")
    property string formattedTime: DateTime.time
    property string formattedUptime: DateTime.uptime
    property int urgentLimit: 5
    property var urgentTasks: getUrgentTasks(urgentLimit)
    property int totalPending: {
        const local = (Todo.list || []).filter(function (t) { return !t.done }).length
        const google = (GoogleTasks.sortedList || []).length
        return local + google
    }

    function getUrgentTasks(limit) {
        const localItems = (Todo.list || [])
            .map(function (t, i) {
                return {
                    content: t.content,
                    originalIndex: i,
                    googleId: "",
                    due: null,
                    isSubtask: false,
                    done: !!t.done
                }
            })
            .filter(function (t) { return !t.done })
        const googleItems = (GoogleTasks.sortedList || []).map(function (t) {
            return {
                content: t.title,
                originalIndex: -1,
                googleId: t.id,
                due: t.due || null,
                isSubtask: !!t.isSubtask,
                done: false
            }
        })
        const combined = googleItems.concat(localItems)
        const withDue = combined.filter(function (t) { return !!t.due })
            .sort(function (a, b) { return a.due.localeCompare(b.due) })
        const noDue = combined.filter(function (t) { return !t.due })
        return withDue.concat(noDue).slice(0, limit)
    }

    // Google Tasks "due" siempre llega como 00:00 UTC pero representa un día
    // calendario. Parseamos YYYY-MM-DD directo del string para evitar el
    // corrimiento de timezone (en UTC-5 si interpretamos como instante UTC,
    // el día se atrasa 1).
    function parseDueDay(iso) {
        if (!iso) return null
        const m = String(iso).match(/^(\d{4})-(\d{2})-(\d{2})/)
        if (!m) return null
        return new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
    }

    function formatDueShort(iso) {
        const dueDay = parseDueDay(iso)
        if (!dueDay) return ""
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        const diffDays = Math.round((dueDay.getTime() - today.getTime()) / (24 * 60 * 60 * 1000))
        if (diffDays === 0) return "hoy"
        if (diffDays === 1) return "mañana"
        if (diffDays === -1) return "ayer"
        if (diffDays > 1) return `en ${diffDays}d`
        return `hace ${-diffDays}d`
    }

    function isOverdue(iso) {
        const dueDay = parseDueDay(iso)
        if (!dueDay) return false
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        return dueDay.getTime() < today.getTime()
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 4

        StyledPopupHeaderRow {
            icon: "calendar_month"
            label: root.formattedDate
        }

        CalendarWidget {
            Layout.alignment: Qt.AlignHCenter
            showYearToggle: true
            yearCellSize: 13
        }

        StyledPopupValueRow {
            icon: "timelapse"
            label: Translation.tr("System uptime:")
            value: root.formattedUptime
        }

        // Tasks (local + Google, top N urgentes)
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            Layout.minimumWidth: 280

            StyledPopupValueRow {
                icon: "checklist"
                label: Translation.tr("To Do:")
                value: root.totalPending > 0 ? `${root.totalPending}` : ""
            }

            StyledText {
                visible: root.urgentTasks.length === 0
                Layout.leftMargin: 4
                color: Appearance.colors.colOnSurfaceVariant
                text: Translation.tr("No pending tasks")
            }

            Repeater {
                model: root.urgentTasks
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 4 + (modelData.isSubtask ? 14 : 0)
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: modelData.googleId ? "cloud" : "circle"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        text: modelData.content
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    StyledText {
                        visible: !!modelData.due
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.isOverdue(modelData.due) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                        text: root.formatDueShort(modelData.due)
                    }

                    TodoItemActionButton {
                        Layout.fillWidth: false
                        implicitWidth: 24
                        implicitHeight: 24
                        onClicked: {
                            if (modelData.googleId) {
                                GoogleTasks.complete(modelData.googleId);
                            } else if (modelData.originalIndex >= 0) {
                                Todo.markDone(modelData.originalIndex);
                            }
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "check"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            StyledText {
                visible: root.totalPending > root.urgentLimit
                Layout.leftMargin: 4
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
                text: Translation.tr("+ %1 más").arg(root.totalPending - root.urgentLimit)
            }
        }
    }
}
