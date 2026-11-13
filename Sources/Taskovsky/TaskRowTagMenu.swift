import SwiftUI
import TaskovskyCore

/// Task-row assignment uses the existing tags and title-path vocabulary, not
/// tag management. The target is the context-clicked record, never selection.
struct TaskRowTagMenu: View {
    @ObservedObject var store: TaskStore
    let taskID: UUID

    var body: some View {
        Menu("Tags") {
            if store.data.tags.isEmpty {
                Text("No tags available")
            } else {
                ForEach(store.data.tags) { tag in
                    Toggle(TaskRowTagAssignment.label(for: tag, in: store.data.tags), isOn: Binding(
                        get: { store.data.tasks.first(where: { $0.id == taskID })?.tagIDs.contains(tag.id) == true },
                        set: { enabled in
                            if let updated = TaskRowTagAssignment.updating(taskID: taskID, tagID: tag.id, enabled: enabled, in: store.data) {
                                store.updateTask(updated)
                            }
                        }))
                    .accessibilityIdentifier("taskRowTag-" + tag.id.uuidString)
                }
            }
        }
    }
}

enum TaskRowTagAssignment {
    static func label(for tag: TaskTag, in tags: [TaskTag]) -> String {
        (TagHierarchy.ancestors(of: tag.id, in: tags).reversed().map { "#" + $0.name } + ["#" + tag.name]).joined(separator: " / ")
    }

    /// Resolve current state when the menu command fires; don't write a stale
    /// row snapshot or discard retained unknown tag IDs / unrelated fields.
    static func updating(taskID: UUID, tagID: UUID, enabled: Bool, in data: WorkspaceData) -> TaskItem? {
        let matches = data.tasks.filter { $0.id == taskID }
        guard matches.count == 1, var task = matches.first,
              task.deletedAt == nil, !SmartListEligibility.isArchived(task, lists: data.lists),
              data.tags.contains(where: { $0.id == tagID }),
              task.tagIDs.contains(tagID) != enabled else { return nil }
        if enabled { task.tagIDs.append(tagID) }
        else { task.tagIDs.removeAll { $0 == tagID } }
        return task
    }
}
