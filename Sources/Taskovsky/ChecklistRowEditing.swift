import TaskovskyCore

enum ChecklistRowEditing {
    static func canEdit(_ task: TaskItem, readOnly: Bool) -> Bool {
        !readOnly && task.deletedAt == nil
    }
}
