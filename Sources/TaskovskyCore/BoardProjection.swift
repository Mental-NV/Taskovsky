import Foundation

/// Status-board dataset shared by the Kanban UI and its tests.
///
/// A board shows every non-deleted task in its list — all statuses — so a
/// drop into Completed/Won't Do always lands somewhere visible. The list
/// view's Show Completed toggle affects rows only, never the board: hiding
/// history must not make a completed drop vanish, and a list holding only
/// completed tasks still renders its Completed column instead of an
/// "All clear" empty state. Archived lists keep their tasks (the UI renders
/// them read-only). Notes stay in Open; terminal-column drops arriving from
/// the UI refuse them with a message.
public enum BoardProjection {
    /// Every non-deleted task in `listID` (nil = Inbox), in stored order.
    public static func tasks(forList listID: UUID?, in data: WorkspaceData) -> [TaskItem] {
        data.tasks.filter { $0.deletedAt == nil && $0.listID == listID }
    }

    /// Status split over a board dataset. Each record appears exactly once;
    /// notes always land in Open regardless of status flags (a note can
    /// never be completed or marked Won't Do through the store layer).
    public static func split(_ tasks: [TaskItem]) -> (open: [TaskItem], completed: [TaskItem], wontDo: [TaskItem]) {
        var open: [TaskItem] = []
        var completed: [TaskItem] = []
        var wont: [TaskItem] = []
        for task in tasks {
            if task.completedAt != nil { completed.append(task) }
            else if task.wontDoAt != nil { wont.append(task) }
            else { open.append(task) }
        }
        return (open, completed, wont)
    }
}
