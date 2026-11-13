import SwiftUI
import TaskovskyCore

struct TaskProgressControl: View {
    @ObservedObject var store: TaskStore
    let task: TaskItem
    let locked: Bool
    @State private var editTask: TaskItem?

    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        // The header separator is the progress surface, not a permanent row.
        // Keep a larger hit region without pushing the title down.
        separator
            .frame(height: 1)
            .overlay {
                Group {
                if task.canEditManualProgress && !locked {
                    Button { editTask = task } label: {
                        Color.clear.frame(height: 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focused($focused)
                    .accessibilityLabel("Set task progress")
                    .accessibilityValue("\(task.progressPercent)%")
                    .help("Set task progress")
                    .popover(item: $editTask, arrowEdge: .bottom) { task in
                        TaskProgressEditor(store: store, task: task)
                    }
                } else {
                    Color.clear.frame(height: 12).contentShape(Rectangle())
                }
                }.onHover { hovered = $0 }
            }
            .overlay(alignment: .topTrailing) {
                if hovered || focused || editTask != nil {
                    Text("\(task.progressPercent)%")
                        .font(.system(size: 10)).monospacedDigit()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3))
                        .offset(x: -16, y: -22)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .onChange(of: task.id) { _, _ in
                hovered = false; focused = false; editTask = nil
            }
            .accessibilityElement(children: .contain)
    }

    private var separator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(nsColor: .separatorColor))
                Rectangle().fill(Color.accentColor)
                    .frame(width: geometry.size.width * CGFloat(task.progressPercent) / 100)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.checklist.isEmpty ? "Task progress" : "Task progress from checklist")
        .accessibilityValue("\(task.progressPercent)%")
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
