import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var tabButtonList: [{"icon": "checklist", "name": Translation.tr("Unfinished")}, {"name": Translation.tr("Done"), "icon": "check_circle"}, {"name": Translation.tr("Google"), "icon": "cloud"}]
    property bool showAddDialog: false
    property int dialogMargins: 20
    property int fabSize: 48
    property int fabMargins: 14

    // Accordion state for Google subtasks. Key = parent task id.
    // Default behavior is "expanded" — entries flip to false to collapse.
    property var expandedGoogleParents: ({})

    function toggleGoogleExpand(parentId) {
        if (!parentId) return
        const current = root.expandedGoogleParents[parentId]
        // undefined (default) is treated as expanded; first toggle collapses.
        const next = Object.assign({}, root.expandedGoogleParents)
        next[parentId] = current === false ? true : false
        root.expandedGoogleParents = next
    }

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
            } else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
            }
            event.accepted = true;
        }
        // Open add dialog on "N" (any modifiers)
        else if (event.key === Qt.Key_N) {
            root.showAddDialog = true
            event.accepted = true;
        }
        // Close dialog on Esc if open
        else if (event.key === Qt.Key_Escape && root.showAddDialog) {
            root.showAddDialog = false
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SecondaryTabBar {
            id: tabBar
            currentIndex: swipeView.currentIndex

            Repeater {
                model: root.tabButtonList
                delegate: SecondaryTabButton {
                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: tabBar.currentIndex

            // To Do tab
            TaskList {
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "check_circle"
                emptyPlaceholderText: Translation.tr("Nothing here!")
                taskList: Todo.list
                    .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                    .filter(function(item) { return !item.done; })
            }
            TaskList {
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "checklist"
                emptyPlaceholderText: Translation.tr("Finished tasks will go here")
                taskList: Todo.list
                    .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                    .filter(function(item) { return item.done; })
            }

            // Google Tasks (con header de estado + refresh manual)
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: 4
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                            text: {
                                if (GoogleTasks.loading) return Translation.tr("Actualizando…")
                                if (GoogleTasks.lastError.length > 0) return Translation.tr("Error: %1").arg(GoogleTasks.lastError)
                                if (GoogleTasks.lastFetchedAt) {
                                    const d = new Date(GoogleTasks.lastFetchedAt)
                                    if (!isNaN(d.getTime())) {
                                        return Translation.tr("Actualizado %1").arg(d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat))
                                    }
                                }
                                return ""
                            }
                        }

                        TodoItemActionButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            enabled: !GoogleTasks.loading
                            onClicked: GoogleTasks.refresh()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: GoogleTasks.loading ? "sync" : "refresh"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                                rotation: GoogleTasks.loading ? rotationAnim.runValue : 0

                                NumberAnimation on rotation {
                                    id: rotationAnim
                                    property real runValue: 0
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: GoogleTasks.loading
                                }
                            }
                        }
                    }

                    TaskList {
                        id: googleTaskList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readonly: true
                        listBottomPadding: root.fabMargins * 2
                        emptyPlaceholderIcon: GoogleTasks.lastError.length > 0 ? "cloud_off" : "cloud_done"
                        emptyPlaceholderText: {
                            if (GoogleTasks.lastError === "missing_credentials" || GoogleTasks.lastError === "not_authenticated")
                                return Translation.tr("Run scripts/google/setup.sh to connect")
                            if (GoogleTasks.lastError.length > 0)
                                return Translation.tr("Could not load Google Tasks (%1)").arg(GoogleTasks.lastError)
                            return Translation.tr("No pending Google Tasks")
                        }
                        onToggleExpand: parentId => root.toggleGoogleExpand(parentId)
                taskList: {
                    const sorted = GoogleTasks.sortedList || []
                    if (sorted.length === 0) return []
                    // Count children per parent id
                    const childCount = ({})
                    for (let i = 0; i < sorted.length; i++) {
                        const t = sorted[i]
                        if (t.isSubtask && t.parent) {
                            childCount[t.parent] = (childCount[t.parent] || 0) + 1
                        }
                    }
                    // Flatten respecting expansion state (default = expanded)
                    const result = []
                    let lastParentId = null
                    let lastParentExpanded = true
                    for (let i = 0; i < sorted.length; i++) {
                        const t = sorted[i]
                        if (!t.isSubtask) {
                            const exp = root.expandedGoogleParents[t.id] !== false
                            lastParentId = t.id
                            lastParentExpanded = exp
                            result.push({
                                content: t.title,
                                done: false,
                                originalIndex: -1,
                                googleId: t.id,
                                due: t.due,
                                notes: t.notes || "",
                                isSubtask: false,
                                childCount: childCount[t.id] || 0,
                                expanded: exp
                            })
                        } else if (lastParentExpanded) {
                            result.push({
                                content: t.title,
                                done: false,
                                originalIndex: -1,
                                googleId: t.id,
                                due: t.due,
                                notes: t.notes || "",
                                isSubtask: true,
                                childCount: 0,
                                expanded: false
                            })
                        }
                    }
                    return result
                }
                    }
                }
            }
        }
    }

    // + FAB
    StyledRectangularShadow {
        target: fabButton
        radius: fabButton.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
        visible: fabButton.visible
    }
    FloatingActionButton {
        id: fabButton
        visible: swipeView.currentIndex !== 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins

        onClicked: root.showAddDialog = true
        iconText: "add"
    }

    Item {
        anchors.fill: parent
        z: 9999

        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation { 
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (!visible) {
                todoInput.text = ""
                fabButton.focus = true
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
            }
        }

        Rectangle { // The dialog
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            implicitHeight: dialogColumnLayout.implicitHeight

            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: Appearance.rounding.normal

            function addTask() {
                if (todoInput.text.length > 0) {
                    Todo.addTask(todoInput.text)
                    todoInput.text = ""
                    root.showAddDialog = false
                    tabBar.setCurrentIndex(0) // Show unfinished tasks
                }
            }

            ColumnLayout {
                id: dialogColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignLeft
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: Translation.tr("Add task")
                }

                TextField {
                    id: todoInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: Translation.tr("Task description")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    focus: root.showAddDialog
                    onAccepted: dialog.addTask()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: todoInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: todoInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }

                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignRight
                    spacing: 5

                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        onClicked: root.showAddDialog = false
                    }
                    DialogButton {
                        buttonText: Translation.tr("Add")
                        enabled: todoInput.text.length > 0
                        onClicked: dialog.addTask()
                    }
                }
            }
        }
    }
}
