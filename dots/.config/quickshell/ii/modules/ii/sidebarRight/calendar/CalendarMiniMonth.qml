import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int year: new Date().getFullYear()
    property int monthIndex: new Date().getMonth()
    property int cellSize: 16
    property int cellSpacing: 1

    readonly property bool isCurrentMonth: {
        const today = new Date()
        return today.getFullYear() === root.year && today.getMonth() === root.monthIndex
    }
    readonly property date refDate: new Date(root.year, root.monthIndex, 1)
    readonly property var layout: CalendarLayout.getCalendarLayout(refDate, root.isCurrentMonth)

    signal monthClicked(int year, int monthIndex)

    implicitWidth: column.implicitWidth + 8
    implicitHeight: column.implicitHeight + 8

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Appearance.rounding.small
        border.width: root.isCurrentMonth ? 1 : 0
        border.color: Appearance.colors.colPrimary
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.monthClicked(root.year, root.monthIndex)
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: 2

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.isCurrentMonth ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
            text: root.refDate.toLocaleDateString(Qt.locale(), "MMMM")
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.cellSpacing
            Repeater {
                model: CalendarLayout.weekDays
                delegate: Item {
                    implicitWidth: root.cellSize
                    implicitHeight: root.cellSize - 4
                    StyledText {
                        anchors.centerIn: parent
                        text: Translation.tr(modelData.day).slice(0, 1)
                        font.pixelSize: 9
                        color: Appearance.m3colors.m3outline
                    }
                }
            }
        }

        Repeater {
            model: 6
            delegate: RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.cellSpacing
                property int weekIndex: index
                Repeater {
                    model: 7
                    delegate: Item {
                        implicitWidth: root.cellSize
                        implicitHeight: root.cellSize
                        property var cellData: root.layout[parent.weekIndex][index]
                        Rectangle {
                            anchors.centerIn: parent
                            width: root.cellSize - 2
                            height: root.cellSize - 2
                            radius: width / 2
                            color: parent.cellData.today === 1 ? Appearance.colors.colPrimary : "transparent"
                        }
                        StyledText {
                            anchors.centerIn: parent
                            text: parent.cellData.day
                            font.pixelSize: 9
                            color: parent.cellData.today === 1 ? Appearance.m3colors.m3onPrimary
                                : parent.cellData.today === 0 ? Appearance.colors.colOnLayer1
                                : Appearance.m3colors.m3outline
                        }
                    }
                }
            }
        }
    }
}
