pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Read-only feed of Google Tasks (@default list).
 * Backed by ~/.config/quickshell/ii/scripts/google/tasks.sh list.
 * Refreshes on a 5-minute timer once the user has authenticated.
 */
Singleton {
    id: root

    readonly property int fetchInterval: 5 * 60 * 1000
    property var list: []
    property var sortedList: buildSortedList(list)
    property bool loading: false
    property string lastError: ""
    property string lastFetchedAt: ""

    function buildSortedList(tasks) {
        if (!tasks || tasks.length === 0) return []
        const topLevel = []
        const subtasksByParent = {}
        const knownIds = {}
        for (const t of tasks) knownIds[t.id] = true
        for (const t of tasks) {
            if (t.parent && knownIds[t.parent]) {
                if (!subtasksByParent[t.parent]) subtasksByParent[t.parent] = []
                subtasksByParent[t.parent].push(t)
            } else {
                // Orphans (parent missing from list) treated as top-level
                topLevel.push(t)
            }
        }
        for (const k of Object.keys(subtasksByParent)) {
            subtasksByParent[k].sort((a, b) => (a.position || "").localeCompare(b.position || ""))
        }
        const withDue = topLevel.filter(t => t.due).sort((a, b) => a.due.localeCompare(b.due))
        const noDue = topLevel.filter(t => !t.due).sort((a, b) => (a.position || "").localeCompare(b.position || ""))
        const ordered = withDue.concat(noDue)
        const result = []
        for (const parent of ordered) {
            result.push(Object.assign({}, parent, { isSubtask: false }))
            const kids = subtasksByParent[parent.id] || []
            for (const k of kids) result.push(Object.assign({}, k, { isSubtask: true }))
        }
        return result
    }

    function refresh() {
        if (fetcher.running) return
        root.loading = true
        fetcher.running = true
    }

    function complete(taskId) {
        invokeAction("complete", taskId)
    }

    function uncomplete(taskId) {
        invokeAction("uncomplete", taskId)
    }

    function invokeAction(action, taskId) {
        if (!taskId || !action) return
        if (actionProc.running) return  // descarta clicks mientras hay otra acción en curso
        actionProc.command = ["bash", `${Directories.scriptPath}/google/tasks.sh`, action, taskId]
        actionProc.running = true
    }

    function refreshSoon() {
        kickoffTimer.restart()
    }

    Component.onCompleted: refreshSoon()

    Timer {
        id: kickoffTimer
        interval: 1500
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        running: true
        repeat: true
        interval: root.fetchInterval
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher
        command: ["bash", `${Directories.scriptPath}/google/tasks.sh`, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                if (text.length === 0) {
                    root.lastError = "empty_response"
                    return
                }
                try {
                    const parsed = JSON.parse(text)
                    if (parsed.ok) {
                        root.list = parsed.tasks || []
                        root.lastFetchedAt = parsed.fetchedAt || ""
                        root.lastError = ""
                    } else {
                        root.lastError = parsed.error || "unknown"
                    }
                } catch (e) {
                    root.lastError = `parse_error: ${e.message}`
                    console.error(`[GoogleTasks] ${e.message}`)
                }
            }
        }
    }

    Process {
        id: actionProc
        command: ["bash", "-c", "true"]  // overrideado en invokeAction()
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    root.lastError = "empty_action_response"
                    return
                }
                try {
                    const parsed = JSON.parse(text)
                    if (parsed.ok) {
                        // Refresca para reflejar el cambio (la tarea completada desaparece de la lista filtrada)
                        root.refresh()
                    } else {
                        root.lastError = parsed.error || "action_failed"
                        console.error(`[GoogleTasks] action failed: ${root.lastError}`)
                    }
                } catch (e) {
                    root.lastError = `action_parse_error: ${e.message}`
                    console.error(`[GoogleTasks] ${e.message}`)
                }
            }
        }
    }
}
