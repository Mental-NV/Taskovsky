import Foundation

import TaskovskyCore

/// The row command reuses the existing detail conversion policy, resolving the
/// live context target rather than selection or a menu-opening snapshot.
enum TaskRowConversion {
    static func toNote(taskID: UUID, in data: WorkspaceData) -> TaskItem? {
        let matches = data.tasks.filter { $0.id == taskID }
        guard matches.count == 1, let task = matches.first,
              task.kind == .task, task.completedAt == nil, task.wontDoAt == nil,
              task.deletedAt == nil, !SmartListEligibility.isArchived(task, lists: data.lists) else { return nil }
        return task.converted(to: .note)
    }
}
