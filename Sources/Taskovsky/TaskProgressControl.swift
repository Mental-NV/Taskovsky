import SwiftUI
import TaskovskyCore

struct TaskProgressControl: View {
    @ObservedObject var store: TaskStore
    let task: TaskItem
    let locked: Bool
    @State private var editTask: TaskItem?

    var body: some View {
        if task.canEditManualProgress && !locked {
            Button { editTask = task } label: { indicator }
                .buttonStyle(.plain)
                .accessibilityLabel("Set task progress")
                .accessibilityValue("\(task.progressPercent)%")
                .popover(item: $editTask, arrowEdge: .bottom) { task in
                    TaskProgressEditor(store: store, task: task)
                }
        } else {
            indicator
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(task.checklist.isEmpty ? "Task progress" : "Task progress from checklist")
                .accessibilityValue("\(task.progressPercent)%")
        }
    }

    private var indicator: some View {
        HStack(spacing: 8) {
            ProgressView(value: Double(task.progressPercent), total: 100)
                .progressViewStyle(.linear).controlSize(.small).accessibilityHidden(true)
            Text("\(task.progressPercent)%").monospacedDigit()
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct TaskProgressEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TaskStore
    let task: TaskItem
    @State private var percent: Double
    @State private var error: String?

    init(store: TaskStore, task: TaskItem) {
        self.store = store
        self.task = task
        _percent = State(initialValue: Double(task.progressPercent))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Task Progress").font(.headline)
                Spacer()
                Text("\(Int(percent))%").monospacedDigit()
                Stepper("Adjust progress by one percent", value: $percent, in: 0...100).labelsHidden()
            }
            Slider(value: Binding(get: { percent }, set: { percent = $0.rounded() }), in: 0...100) {
                Text("Progress percentage")
            }.labelsHidden()
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Done") {
                    if store.setTaskProgress(taskID: task.id, percent: Int(percent), expected: task.manualProgress) {
                        dismiss()
                    } else {
                        error = store.storageError ?? "The task changed. Reopen the editor and try again."
                    }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(16).frame(width: 280)
    }
}
