import SwiftUI
import AppKit
import TaskovskyCore

struct TaskRow: View {
    @ObservedObject var store: TaskStore
    let id: UUID
    let selected: Bool
    let now: Date
    let listContext: String?
    let showPreview: Bool
    let showSteps: Bool
    /// Inline rename is disabled where double-click opens a pop-up window.
    let allowRename: Bool
    let toggle: () -> Void
    let onSelect: () -> Void
    /// Single routing for title double-click: rename, or the pop-up action.
    /// The inner recognizer is never a no-op that consumes the gesture.
    let onTitleDoubleClick: () -> Void
    /// Row-background double-click (pop-up mode only; otherwise empty).
    let onRowDoubleClick: () -> Void
    @State private var editing = false
    @State private var draft = ""
    @State private var hovering = false
    @State private var rowWidth: CGFloat = 320
    @State private var swallowSelect = false
    @FocusState private var titleFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var task: TaskItem { store.data.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "") }
    private var tag: TaskTag? { store.data.tags.first { task.tagIDs.contains($0.id) } }
    private var listName: String? { store.data.lists.first { $0.id == task.listID }?.name }
    private var finished: Bool { task.completedAt != nil || task.wontDoAt != nil }
    private var previewLine: String? {
        guard showPreview else { return nil }
        let line = String(task.body.prefix(while: { $0 != "\n" && $0 != "\r" })).trimmingCharacters(in: .whitespaces)
        return line.isEmpty ? nil : line
    }
    private var hasExtras: Bool { previewLine != nil || (showSteps && !task.checklist.isEmpty) }
    /// Measured completed-title gray (#A0A0A0 in light mode).
    private var finishedTitleColor: Color {
        colorScheme == .dark ? Color(nsColor: .tertiaryLabelColor) : Color(hex: "#A0A0A0")
    }
    private var boxState: TaskCheckbox.State {
        if task.wontDoAt != nil { return .wontDo }
        if task.completedAt != nil { return .completed }
        return .open
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                if task.kind == .note { Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 18, height: 20) }
                else {
                    Button(action: { consumeNextSelect(); toggle() }) {
                        TaskCheckbox(state: boxState, color: boxColor).frame(width: 18, height: 20).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(task.deletedAt != nil).help(finished ? "Mark incomplete" : "Complete task").accessibilityLabel((finished ? "Reopen " : "Complete ") + task.title)
                }
                Group {
                    if editing {
                        TextField("Task title", text: $draft).textFieldStyle(.plain).focused($titleFocused).onSubmit(commit)
                            .onExitCommand { editing = false }.onChange(of: titleFocused) { _, focused in if !focused { commit() } }
                    } else {
                        Text(task.title.isEmpty ? "Untitled" : task.title).foregroundStyle(finished ? finishedTitleColor : Palette.bodyText(colorScheme))
                            .onTapGesture(count: 2) { if allowRename { rename() } else { onTitleDoubleClick() } }
                            .simultaneousGesture(TapGesture().onEnded { onSelect() })
                    }
                }.font(.system(size: 14)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
                if !editing && presentation != .none {
                    Group {
                        switch presentation {
                        case .full: metadata(showTag: true, showExtras: true, showList: true)
                        case .compact: metadata(showTag: false, showExtras: true, showList: true)
                        case .date: metadata(showTag: false, showExtras: false, showList: false)
                        case .calendar: Image(systemName: "calendar").foregroundStyle(accent)
                        case .none: EmptyView()
                        }
                    }.fixedSize().help(metadataDescription)
                }
            }.frame(height: hasExtras ? 24 : 40)
            if let previewLine {
                Text(previewLine).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    .padding(.leading, 28)
            }
            if showSteps && !task.checklist.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(task.checklist) { step in
                        HStack(spacing: 8) {
                            Button(action: { consumeNextSelect(); toggleStep(step.id) }) {
                                TaskCheckbox(state: step.isCompleted ? .completed : .open, color: .secondary, size: 12)
                            }.buttonStyle(.plain).help(step.isCompleted ? "Uncheck subtask" : "Check subtask")
                                .accessibilityLabel((step.isCompleted ? "Uncheck " : "Check ") + step.title)
                            Text(step.title.isEmpty ? "Untitled" : step.title).font(.system(size: 13))
                                .foregroundStyle(step.isCompleted ? Color(nsColor: .tertiaryLabelColor) : Color.secondary).lineLimit(1)
                        }
                    }
                }.padding(.leading, 28)
            }
        }.padding(.horizontal, 12).padding(.vertical, hasExtras ? 8 : 0)
        .frame(minHeight: 40)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rowWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in rowWidth = width }
            }
        )
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 1).padding(.leading, 40).padding(.trailing, 12) }
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture { if swallowSelect { swallowSelect = false } else { onSelect() } }
        .onTapGesture(count: 2) { onRowDoubleClick() }
        .accessibilityAction(named: "Rename", rename)
    }
    /// The child Button action runs before this row's tap. The flag is cleared
    /// on the next runloop turn, so a consumed tap can never suppress a later
    /// genuine row click even if the row tap never fires for this event.
    private func consumeNextSelect() {
        swallowSelect = true
        DispatchQueue.main.async { swallowSelect = false }
    }
    private var rowBackground: Color {
        if selected { return Color.primary.opacity(0.055) }
        if hovering { return Color.primary.opacity(0.032) }
        return .clear
    }
    private var boxColor: Color {
        if finished || task.deletedAt != nil { return .secondary }
        if task.priority == .none { return Palette.taskOutline(colorScheme) }
        return task.priority.color
    }
    private enum MetadataPresentation { case full, compact, date, calendar, none }
    private var presentation: MetadataPresentation {
        metadataPresentation(budget: min(190, rowWidth * 0.48))
    }
    private func metadataPresentation(budget: CGFloat) -> MetadataPresentation {
        let full = metadataWidths(showTag: true, showExtras: true, showList: true)
        if !full.isEmpty && totalWidth(full) <= budget { return .full }
        let compact = metadataWidths(showTag: false, showExtras: true, showList: true)
        if !compact.isEmpty && totalWidth(compact) <= budget { return .compact }
        if let due = task.dueDate { return textWidth(dueText(due)) <= budget ? .date : .calendar }
        return .none
    }
    private func textWidth(_ text: String) -> CGFloat { ceil((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width) }
    private func totalWidth(_ widths: [CGFloat]) -> CGFloat { widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * 6 + 4 }
    private func metadataWidths(showTag: Bool, showExtras: Bool, showList: Bool) -> [CGFloat] {
        var widths: [CGFloat] = []
        if showList, listContext != nil { widths.append(textWidth(listContext!)) }
        if showExtras {
            if !task.body.isEmpty { widths.append(12) }
            if !task.checklist.isEmpty { widths.append(textWidth("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)")) }
            if showTag, let tag { widths.append(textWidth("#" + tag.name)) }
            if task.recurrence != .none { widths.append(12) }
            if task.reminderDate != nil { widths.append(12) }
        }
        if let due = task.dueDate { widths.append(textWidth(dueText(due))) }
        return widths
    }
    @ViewBuilder private func metadata(showTag: Bool, showExtras: Bool, showList: Bool) -> some View {
        HStack(spacing: 6) {
            if showList, let listContext { Text(listContext).foregroundStyle(metaColor) }
            if showExtras {
                if !task.body.isEmpty { Image(systemName: "doc.plaintext").foregroundStyle(metaColor) }
                if !task.checklist.isEmpty { Text("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)").foregroundStyle(metaColor) }
                if showTag, let tag { Text("#" + tag.name).foregroundStyle(finished ? metaColor : Color(hex: tag.color)) }
                if task.recurrence != .none { Image(systemName: "repeat").foregroundStyle(metaColor) }
                if task.reminderDate != nil { Image(systemName: "bell").foregroundStyle(finished ? metaColor : task.reminderDate! <= now ? .orange : .secondary) }
            }
            if let due = task.dueDate { Text(dueText(due)).foregroundStyle(dueColor(due)) }
        }.font(.system(size: 11)).lineLimit(1)
    }
    private var metaColor: Color { finished ? Color(nsColor: .tertiaryLabelColor) : Color(nsColor: .secondaryLabelColor) }
    private func dueColor(_ due: Date) -> Color {
        if finished { return Color(nsColor: .tertiaryLabelColor) }
        return DueLabels.isOverdue(due: due, now: now, calendar: task.scheduleCalendar) ? .red : accent
    }
    private var metadataDescription: String {
        ([tag.map { "#" + $0.name }, task.dueDate.map(dueText), listContext ?? listName].compactMap { $0 }).joined(separator: " · ")
    }
    private func rename() { guard allowRename, task.deletedAt == nil else { return }; draft = task.title; editing = true; titleFocused = true }
    private func commit() {
        guard editing else { return }; editing = false
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty && value != task.title { var updated = task; updated.title = value; store.updateTask(updated) }
    }
    private func toggleStep(_ stepID: UUID) {
        var updated = task
        if let i = updated.checklist.firstIndex(where: { $0.id == stepID }) { updated.checklist[i].isCompleted.toggle(); store.updateTask(updated) }
    }
    private func dueText(_ due: Date) -> String {
        let cal = task.scheduleCalendar
        let day = DueLabels.day(for: due, now: now, calendar: cal)
        let label: String
        switch day {
        case .yesterday: label = "Yesterday"
        case .today: label = "Today"
        case .tomorrow: label = "Tomorrow"
        case .past, .future: label = task.dayText(due)
        }
        return DueLabels.rowLabel(for: day, dayText: label, timeText: task.hasDueTime ? task.timeText(due) : nil)
    }
}
