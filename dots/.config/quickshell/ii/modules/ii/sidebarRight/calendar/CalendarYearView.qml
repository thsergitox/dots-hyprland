import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int year: new Date().getFullYear()
    property int cellSize: 16

    signal monthSelected(int year, int monthIndex)

    implicitWidth: grid.implicitWidth + 8
    implicitHeight: grid.implicitHeight + 8

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: 3
        rowSpacing: 6
        columnSpacing: 6
        Repeater {
            model: 12
            delegate: CalendarMiniMonth {
                year: root.year
                monthIndex: index
                cellSize: root.cellSize
                onMonthClicked: (y, m) => root.monthSelected(y, m)
            }
        }
    }
}
