import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    required property var taskList
    property string emptyPlaceholderIcon
    property string emptyPlaceholderText
    property int todoListItemSpacing: 5
    property int todoListItemPadding: 8
    property int listBottomPadding: 80
    property bool readonly: false

    signal toggleExpand(string parentId)

    // Las tareas de Google Tasks son "all day": la API siempre devuelve la hora
    // 00:00 UTC pero representan un día calendario, no un instante. Hay que
    // extraer YYYY-MM-DD del string ISO sin pasar por timezone, sino la fecha
    // se corre 1 día en zonas distintas de UTC.
    function parseDueDay(iso) {
        if (!iso) return null
        const m = String(iso).match(/^(\d{4})-(\d{2})-(\d{2})/)
        if (!m) return null
        return new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
    }

    function formatDue(iso) {
        const dueDay = parseDueDay(iso)
        if (!dueDay) return ""
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        const diffDays = Math.round((dueDay.getTime() - today.getTime()) / (24 * 60 * 60 * 1000))
        const absDate = dueDay.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
        let rel
        if (diffDays === 0) rel = "Vence hoy"
        else if (diffDays === 1) rel = "Vence mañana"
        else if (diffDays === -1) rel = "Venció ayer"
        else if (diffDays > 1) rel = `Vence en ${diffDays} días`
        else rel = `Vencida hace ${-diffDays} días`
        return `${rel} · ${absDate}`
    }

    function isOverdue(iso) {
        const dueDay = parseDueDay(iso)
        if (!dueDay) return false
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        return dueDay.getTime() < today.getTime()
    }

    StyledListView {
        id: listView
        anchors.fill: parent
        spacing: root.todoListItemSpacing
        animateAppearance: false
        model: ScriptModel {
            values: root.taskList
        }
        delegate: Item {
            id: todoItem
            required property var modelData
            property bool pendingDoneToggle: false
            property bool pendingDelete: false
            property bool enableHeightAnimation: false

            implicitHeight: todoItemRectangle.implicitHeight
            width: ListView.view.width
            clip: true

            Behavior on implicitHeight {
                enabled: enableHeightAnimation
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Rectangle {
                id: todoItemRectangle
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: todoContentRowLayout.implicitHeight
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small

                ColumnLayout {
                    id: todoContentRowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10 + (todoItem.modelData.isSubtask ? 16 : 0)
                        Layout.rightMargin: 10
                        Layout.topMargin: todoListItemPadding
                        spacing: 4
                        opacity: todoItem.modelData.isSubtask ? 0.78 : 1

                        MaterialSymbol {
                            visible: !!todoItem.modelData.isSubtask
                            Layout.alignment: Qt.AlignTop
                            text: "subdirectory_arrow_right"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            id: todoContentText
                            Layout.fillWidth: true // Needed for wrapping
                            text: todoItem.modelData.content
                            wrapMode: Text.Wrap
                        }
                    }
                    StyledText {
                        visible: !!todoItem.modelData.due
                        Layout.leftMargin: 10 + (todoItem.modelData.isSubtask ? 16 + 4 + Appearance.font.pixelSize.normal : 0)
                        Layout.rightMargin: 10
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.isOverdue(todoItem.modelData.due) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                        text: root.formatDue(todoItem.modelData.due)
                    }
                    StyledText {
                        visible: !!(todoItem.modelData.notes && todoItem.modelData.notes.length > 0)
                        Layout.leftMargin: 10 + (todoItem.modelData.isSubtask ? 16 + 4 + Appearance.font.pixelSize.normal : 0)
                        Layout.rightMargin: 10
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                        wrapMode: Text.Wrap
                        text: todoItem.modelData.notes || ""
                    }
                    RowLayout {
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.bottomMargin: todoListItemPadding
                        Item {
                            Layout.fillWidth: true
                        }
                        // Conteo de hijos en texto chico, fuera del botón
                        StyledText {
                            visible: root.readonly && (todoItem.modelData.childCount || 0) > 0
                            text: `${todoItem.modelData.childCount || 0}`
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        // Chevron expand/collapse cuando hay hijos (Google)
                        TodoItemActionButton {
                            visible: root.readonly && (todoItem.modelData.childCount || 0) > 0
                            Layout.fillWidth: false
                            onClicked: root.toggleExpand(todoItem.modelData.googleId || "")
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: todoItem.modelData.expanded ? "expand_less" : "expand_more"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                        // Check: marca done para local; complete para Google
                        TodoItemActionButton {
                            visible: !root.readonly || !!todoItem.modelData.googleId
                            Layout.fillWidth: false
                            onClicked: {
                                if (todoItem.modelData.googleId) {
                                    GoogleTasks.complete(todoItem.modelData.googleId);
                                } else if (!todoItem.modelData.done) {
                                    Todo.markDone(todoItem.modelData.originalIndex);
                                } else {
                                    Todo.markUnfinished(todoItem.modelData.originalIndex);
                                }
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: todoItem.modelData.done ? "remove_done" : "check"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                        // Delete: solo locales
                        TodoItemActionButton {
                            visible: !root.readonly
                            Layout.fillWidth: false
                            onClicked: {
                                Todo.deleteItem(todoItem.modelData.originalIndex);
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "delete_forever"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        // Placeholder when list is empty
        visible: opacity > 0
        opacity: taskList.length === 0 ? 1 : 0
        anchors.fill: parent

        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: emptyPlaceholderIcon
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: emptyPlaceholderText
            }
        }
    }
}
