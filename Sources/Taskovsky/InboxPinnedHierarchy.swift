import Foundation
import TaskovskyCore

/// Display-only exception for the standard Mac Inbox Date list. Move only
/// a continuous chain of visible, active, undated Inbox tasks with its pinned
/// parent. The records and their individual pin flags remain unchanged.
enum InboxPinnedHierarchy {
    static func partition(_ tasks: [TaskItem]) -> (pinned: [TaskItem], rest: [TaskItem]) {
        let original = PinnedGrouping.partition(tasks)
        let roots = original.pinned.filter(isEligible).map(\.id)
        guard !roots.isEmpty, Set(tasks.map(\.id)).count == tasks.count else { return original }

        var children: [UUID: [UUID]] = [:]
        for task in tasks where isEligible(task) {
            if let parent = task.parentID { children[parent, default: []].append(task.id) }
        }
        var included = Set(roots)
        var pending = roots
        while let parent = pending.popLast() {
            for child in children[parent, default: []] where included.insert(child).inserted {
                pending.append(child)
            }
        }

        var pinned: [TaskItem] = []
        var rest: [TaskItem] = []
        for task in tasks {
            if PinnedGrouping.isPinnedRow(task) || included.contains(task.id) {
                pinned.append(task)
            } else {
                rest.append(task)
            }
        }
        return (pinned, rest)
    }

    private static func isEligible(_ task: TaskItem) -> Bool {
        task.kind == .task && task.listID == nil && task.sectionID == nil && task.dueDate == nil &&
            task.completedAt == nil && task.wontDoAt == nil && task.deletedAt == nil
    }
}
