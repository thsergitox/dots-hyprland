import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int displayYear: new Date().getFullYear()
    property int currentYear: new Date().getFullYear()
    property int currentMonth: new Date().getMonth()

    signal selected(int year, int monthIndex)
    signal dismissed()

    visible: opacity > 0
    opacity: 0
    enabled: opacity > 0.5

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    function open(year, month) {
        root.displayYear = year
        root.currentYear = year
        root.currentMonth = month
        root.opacity = 1
    }

    function close() {
        root.opacity = 0
    }

    // Scrim that swallows clicks outside the panel
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.close()
            root.dismissed()
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: pickerLayout.implicitWidth + 24
        height: pickerLayout.implicitHeight + 24
        color: Appearance.m3colors.m3surfaceContainerHigh
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        // Block click-through inside the panel
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onClicked: {}
        }

        ColumnLayout {
            id: pickerLayout
            anchors.centerIn: parent
            spacing: 10

            // Year header with arrows + center label
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                CalendarHeaderButton {
                    forceCircle: true
                    downAction: () => { root.displayYear-- }
                    contentItem: MaterialSymbol {
                        text: "chevron_left"
                        iconSize: Appearance.font.pixelSize.larger
                        horizontalAlignment: Text.AlignHCenter
                        color: Appearance.colors.colOnLayer1
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: `${root.displayYear}`
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                CalendarHeaderButton {
                    forceCircle: true
                    downAction: () => { root.displayYear++ }
                    contentItem: MaterialSymbol {
                        text: "chevron_right"
                        iconSize: Appearance.font.pixelSize.larger
                        horizontalAlignment: Text.AlignHCenter
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            // Months grid 4×3
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 4
                rowSpacing: 4
                columnSpacing: 4
                Repeater {
                    model: 12
                    delegate: RippleButton {
                        readonly property bool isToday: root.displayYear === new Date().getFullYear() && index === new Date().getMonth()
                        readonly property bool isCurrent: root.displayYear === root.currentYear && index === root.currentMonth
                        Layout.fillWidth: false
                        Layout.fillHeight: false
                        implicitWidth: 56
                        implicitHeight: 32
                        toggled: isCurrent
                        buttonRadius: Appearance.rounding.full
                        contentItem: StyledText {
                            anchors.fill: parent
                            text: new Date(2000, index, 1).toLocaleDateString(Qt.locale(), "MMM")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                            color: parent.isCurrent ? Appearance.m3colors.m3onPrimary
                                : parent.isToday ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnLayer1
                        }
                        onClicked: {
                            root.selected(root.displayYear, index)
                            root.close()
                        }
                    }
                }
            }

            // "Hoy" shortcut button
            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 30
                implicitWidth: 80
                buttonRadius: Appearance.rounding.full
                visible: !(root.currentYear === new Date().getFullYear() && root.currentMonth === new Date().getMonth())
                contentItem: StyledText {
                    anchors.fill: parent
                    text: Translation.tr("Hoy")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: {
                    const today = new Date()
                    root.selected(today.getFullYear(), today.getMonth())
                    root.close()
                }
            }
        }
    }
}
