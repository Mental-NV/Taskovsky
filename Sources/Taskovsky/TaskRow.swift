import SwiftUI
import AppKit
import TaskovskyCore

struct TaskRow: View {
    @ObservedObject var store: TaskStore
    let id: UUID
    let selected: Bool
    let now: Date
    let toggle: () -> Void
    let onSelect: () -> Void
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var titleFocused: Bool
    private var task: TaskItem { store.data.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "") }
    private var tag: TaskTag? { store.data.tags.first { task.tagIDs.contains($0.id) } }
    private var listName: String? { store.data.lists.first { $0.id == task.listID }?.name }
    private var finished: Bool { task.completedAt != nil || task.wontDoAt != nil }

    var body: some View {
        GeometryReader { geometry in
            let presentation = metadataPresentation(budget: min(190, geometry.size.width * 0.48))
            HStack(spacing: 10) {
                if task.kind == .note { Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 18, height: 20) }
                else {
                    Button(action: toggle) { Image(systemName: task.wontDoAt != nil ? "xmark.square.fill" : task.completedAt == nil ? "square" : "checkmark.square.fill").font(.system(size: 16, weight: .light)).foregroundStyle(finished ? Color.secondary : task.priority.color).frame(width: 18, height: 20) }
                        .buttonStyle(.plain).disabled(task.deletedAt != nil).help(finished ? "Mark incomplete" : "Complete task").accessibilityLabel((finished ? "Reopen " : "Complete ") + task.title)
                }
                Group {
                    if editing {
                        TextField("Task title", text: $draft).textFieldStyle(.plain).focused($titleFocused).onSubmit(commit)
                            .onExitCommand { editing = false }.onChange(of: titleFocused) { _, focused in if !focused { commit() } }
                    } else {
                        Text(task.title.isEmpty ? "Untitled" : task.title).foregroundStyle(finished ? .secondary : .primary)
                            .onTapGesture(count: 2, perform: rename)
                            .simultaneousGesture(TapGesture().onEnded { onSelect() })
                    }
                }.font(.system(size: 14)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
                if !editing && presentation != .none {
                    Group {
                        switch presentation {
                        case .full: metadata(showTag: true, showExtras: true)
                        case .compact: metadata(showTag: false, showExtras: true)
                        case .date: metadata(showTag: false, showExtras: false)
                        case .calendar: Image(systemName: "calendar").foregroundStyle(accent)
                        case .none: EmptyView()
                        }
                    }.fixedSize().help(metadataDescription)
                }
            }.padding(.horizontal, 12).frame(height: 40)
        }.frame(height: 40)
            .background(selected ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 1).padding(.leading, 40).padding(.trailing, 12) }
            .accessibilityAction(named: "Rename", rename)
    }
    private enum MetadataPresentation { case full, compact, date, calendar, none }
    private func metadataPresentation(budget: CGFloat) -> MetadataPresentation {
        let full = metadataWidths(showTag: true, showExtras: true)
        if !full.isEmpty && totalWidth(full) <= budget { return .full }
        let compact = metadataWidths(showTag: false, showExtras: true)
        if !compact.isEmpty && totalWidth(compact) <= budget { return .compact }
        if let due = task.dueDate { return textWidth(dueText(due)) <= budget ? .date : .calendar }
        return .none
    }
    private func textWidth(_ text: String) -> CGFloat { ceil((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width) }
    private func totalWidth(_ widths: [CGFloat]) -> CGFloat { widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * 6 + 4 }
    private func metadataWidths(showTag: Bool, showExtras: Bool) -> [CGFloat] {
        var widths: [CGFloat] = []
        if showExtras {
            if !task.body.isEmpty { widths.append(12) }
            if !task.checklist.isEmpty { widths.append(textWidth("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)")) }
            if showTag, let tag { widths.append(textWidth("#" + tag.name)) }
            if task.recurrence != .none { widths.append(12) }
            if task.reminderDate != nil { widths.append(12) }
        }
        if let due = task.dueDate { widths.append(textWidth(dueText(due))) }
        else if showTag, let listName { widths.append(textWidth(listName)) }
        return widths
    }
    @ViewBuilder private func metadata(showTag: Bool, showExtras: Bool) -> some View {
        HStack(spacing: 6) {
            if showExtras {
                if !task.body.isEmpty { Image(systemName: "doc.plaintext").foregroundStyle(.tertiary) }
                if !task.checklist.isEmpty { Text("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)").foregroundStyle(.tertiary) }
                if showTag, let tag { Text("#" + tag.name).foregroundStyle(Color(hex: tag.color)) }
                if task.recurrence != .none { Image(systemName: "repeat").foregroundStyle(.tertiary) }
                if let reminder = task.reminderDate { Image(systemName: "bell").foregroundStyle(reminder <= now ? .orange : .secondary) }
            }
            if let due = task.dueDate { Text(dueText(due)).foregroundStyle(due < task.scheduleCalendar.startOfDay(for: now) ? .red : accent) }
            else if showTag, let listName { Text(listName).foregroundStyle(.tertiary) }
        }.font(.system(size: 11)).lineLimit(1)
    }
    private var metadataDescription: String {
        ([tag.map { "#" + $0.name }, task.dueDate.map(dueText), listName].compactMap { $0 }).joined(separator: " · ")
    }
    private func rename() { guard task.deletedAt == nil else { return }; draft = task.title; editing = true; titleFocused = true }
    private func commit() {
        guard editing else { return }; editing = false
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty && value != task.title { var updated = task; updated.title = value; store.updateTask(updated) }
    }
    private func dueText(_ due: Date) -> String {
        let cal = task.scheduleCalendar
        let text = cal.isDate(due, inSameDayAs: now) ? "Today" : cal.isDate(due, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now)!) ? "Tomorrow" : task.dayText(due)
        return text + (task.hasDueTime ? " " + task.timeText(due) : "")
    }
}
