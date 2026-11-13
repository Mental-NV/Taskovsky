import SwiftUI
import TaskovskyCore

/// A row-owned presentation keeps scheduling independent of detail selection
/// and its docked/drawer/pop-up preference. Draft/save semantics stay shared.
struct TaskRowSchedulePresentation: ViewModifier {
    @ObservedObject var store: TaskStore
    let taskID: UUID
    @Binding var requestedID: UUID?

    private var task: TaskItem? { TaskRowScheduleTarget.resolve(taskID, in: store.data) }
    private var presented: Binding<Bool> {
        Binding(get: { requestedID == taskID && task != nil }, set: { value in
            if !value && requestedID == taskID { requestedID = nil }
        })
    }

    func body(content: Content) -> some View {
        content
            .popover(isPresented: presented, arrowEdge: .trailing) {
                if let task {
                    ScheduleEditor(task: task, settings: store.settings) { updated, expected in
                        guard TaskRowScheduleTarget.resolve(taskID, in: store.data) != nil else { return false }
                        return store.saveSchedule(updated, expected: expected)
                    }
                }
            }
            .onChange(of: task != nil) { _, available in
                if !available && requestedID == taskID { requestedID = nil }
            }
            .onDisappear { if requestedID == taskID { requestedID = nil } }
    }
}

enum TaskRowScheduleTarget {
    static func resolve(_ id: UUID, in data: WorkspaceData) -> TaskItem? {
        let matches = data.tasks.filter { $0.id == id }
        guard matches.count == 1, let task = matches.first,
              task.kind == .task, task.deletedAt == nil,
              task.completedAt == nil, task.wontDoAt == nil,
              !SmartListEligibility.isArchived(task, lists: data.lists) else { return nil }
        return task
    }
}
