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
    public enum Column: String, CaseIterable, Sendable {
        case open, completed, wontDo

        public var title: String {
            switch self {
            case .open: "Open"
            case .completed: "Completed"
            case .wontDo: "Won't Do"
            }
        }
    }

    public static func column(for task: TaskItem) -> Column {
        if task.completedAt != nil { return .completed }
        if task.wontDoAt != nil { return .wontDo }
        return .open
    }

    /// Maps a change of board column to one local lifecycle transaction.
    public static func move(_ task: TaskItem, to target: Column) -> TaskLifecycleCommand? {
        let source = column(for: task)
        guard task.kind == .task, task.deletedAt == nil, source != target else { return nil }
        switch target {
        case .open: return .reopen
        case .completed: return source == .wontDo ? .completeFromWontDo : .complete
        case .wontDo: return .wontDo
        }
    }

    /// Every non-deleted task in `listID` (nil = Inbox), in stored order.
    public static func tasks(forList listID: UUID?, in data: WorkspaceData) -> [TaskItem] {
        data.tasks.filter { $0.deletedAt == nil && $0.listID == listID }
    }

    /// Each record appears exactly once according to its saved status.
    /// Notes created and edited through the app stay in Open.
    public static func split(_ tasks: [TaskItem]) -> (open: [TaskItem], completed: [TaskItem], wontDo: [TaskItem]) {
        var open: [TaskItem] = []
        var completed: [TaskItem] = []
        var wont: [TaskItem] = []
        for task in tasks {
            switch column(for: task) {
            case .open: open.append(task)
            case .completed: completed.append(task)
            case .wontDo: wont.append(task)
            }
        }
        return (open, completed, wont)
    }
}
