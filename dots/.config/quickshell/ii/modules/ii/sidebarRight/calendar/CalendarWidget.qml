import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    anchors.topMargin: 10

    property int monthShift: 0
    property string viewMode: "month"  // "month" | "year"
    property bool showYearToggle: true
    property int yearViewYear: new Date().getFullYear()
    property int yearCellSize: 16  // tamaño de celda en mini-meses (vista año)

    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)

    width: Math.max(monthLayout.implicitWidth, yearLoader.implicitWidth, 0) + 20
    implicitHeight: outerColumn.height + 20

    function jumpToMonth(year, monthIndex) {
        const today = new Date()
        const targetMonths = year * 12 + monthIndex
        const todayMonths = today.getFullYear() * 12 + today.getMonth()
        root.monthShift = targetMonths - todayMonths
    }

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            if (root.viewMode === "month") {
                if (event.key === Qt.Key_PageDown) root.monthShift++;
                else if (event.key === Qt.Key_PageUp) root.monthShift--;
            } else {
                if (event.key === Qt.Key_PageDown) root.yearViewYear++;
                else if (event.key === Qt.Key_PageUp) root.yearViewYear--;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && picker.opacity > 0) {
            picker.close()
            event.accepted = true
        }
    }

    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            // Solo cambia mes en vista mes. En vista año el scroll NO hace nada
            // (para evitar cambios accidentales). Usar flechas o el picker.
            if (root.viewMode === "month") {
                if (event.angleDelta.y > 0) root.monthShift--;
                else if (event.angleDelta.y < 0) root.monthShift++;
                event.accepted = true
            }
        }
    }

    ColumnLayout {
        id: outerColumn
        anchors.centerIn: parent
        spacing: 5

        // Header (uno solo, dinámico según viewMode)
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 5

            CalendarHeaderButton {
                clip: true
                fontSize: root.viewMode === "year" ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.larger
                buttonText: {
                    if (root.viewMode === "year") {
                        const isThisYear = root.yearViewYear === new Date().getFullYear()
                        return `${isThisYear ? "" : "• "}${root.yearViewYear}`
                    }
                    return `${root.monthShift !== 0 ? "• " : ""}${root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")}`
                }
                tooltipText: Translation.tr("Saltar a año/mes")
                downAction: () => {
                    if (root.viewMode === "year") {
                        picker.open(root.yearViewYear, -1)
                    } else {
                        picker.open(root.viewingDate.getFullYear(), root.viewingDate.getMonth())
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            // Toggle mes/año (solo si showYearToggle)
            CalendarHeaderButton {
                visible: root.showYearToggle
                forceCircle: true
                tooltipText: root.viewMode === "month" ? Translation.tr("Vista año") : Translation.tr("Vista mes")
                downAction: () => {
                    if (root.viewMode === "month") {
                        root.yearViewYear = root.viewingDate.getFullYear()
                        root.viewMode = "year"
                    } else {
                        root.viewMode = "month"
                    }
                }
                contentItem: MaterialSymbol {
                    text: root.viewMode === "month" ? "calendar_view_month" : "calendar_view_day"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }

            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    if (root.viewMode === "month") root.monthShift--;
                    else root.yearViewYear--;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    if (root.viewMode === "month") root.monthShift++;
                    else root.yearViewYear++;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        // Vista mes (default)
        ColumnLayout {
            id: monthLayout
            visible: root.viewMode === "month"
            Layout.alignment: Qt.AlignHCenter
            spacing: 5

            // Week days row
            RowLayout {
                id: weekDaysRow
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                spacing: 5
                Repeater {
                    model: CalendarLayout.weekDays
                    delegate: CalendarDayButton {
                        day: Translation.tr(modelData.day)
                        isToday: modelData.today
                        bold: true
                        enabled: false
                    }
                }
            }

            // Real week rows
            Repeater {
                id: calendarRows
                model: 6
                delegate: RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: false
                    spacing: 5
                    Repeater {
                        model: Array(7).fill(modelData)
                        delegate: CalendarDayButton {
                            day: root.calendarLayout[modelData][index].day
                            isToday: root.calendarLayout[modelData][index].today
                        }
                    }
                }
            }
        }

        // Vista año (loader, solo se carga cuando se usa)
        Loader {
            id: yearLoader
            Layout.alignment: Qt.AlignHCenter
            visible: root.viewMode === "year"
            active: root.viewMode === "year"
            sourceComponent: yearViewComponent
        }

        Component {
            id: yearViewComponent
            CalendarYearView {
                year: root.yearViewYear
                cellSize: root.yearCellSize
                onMonthSelected: (y, m) => {
                    root.jumpToMonth(y, m)
                    root.viewMode = "month"
                }
            }
        }
    }

    // Picker overlay encima de todo
    CalendarMonthYearPicker {
        id: picker
        anchors.fill: parent
        z: 100
        onSelected: (y, m) => {
            root.jumpToMonth(y, m)
            if (root.viewMode === "year") root.viewMode = "month"
        }
    }
}
