import SwiftUI
import AppKit
import TaskovskyCore

struct TaskRow: View {
    @ObservedObject var store: TaskStore
    let id: UUID
    /// Live selection binding: `selected` derives on every body evaluation,
    /// so the grip and highlight can never render a captured stale value
    /// while the detail already follows a newer selection.
    @Binding var selection: UUID?
    private var selected: Bool { selection == id }
    let now: Date
    let listContext: String?
    /// Pane content width for the stateless metadata budget (see metadataBudget).
    let paneWidth: CGFloat
    let showPreview: Bool
    let showSteps: Bool
    /// Inline rename is disabled where double-click opens a pop-up window.
    let allowRename: Bool
    /// Dedicated grip drag source. Built here (never passed in as a view) so
    /// visibility follows whole-row hover OR selection while the 14pt slot
    /// stays reserved and the row never reflows. Nil action means no grip
    /// (trashed read-only rows). The drag source lives on the grip only.
    var gripActive = false
    var onGripActivate: (() -> Void)? = nil
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
            HStack(spacing: 4) {
                // Reserved 14pt grip slot: dots appear on whole-row hover or
                // selection so the row never jumps; no pointer hunt for an
                // invisible target. Drag-out attaches to the grip only, so
                // title editing, text selection, and checks are unaffected.
                if gripActive, let onGrip = onGripActivate {
                    TaskReorderGrip(id: id, title: task.title, active: true, visible: selected || hovering, onActivate: onGrip)
                } else {
                    Color.clear.frame(width: 14, height: 20)
                }
                if task.kind == .note { Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 18, height: 20) }
                else {
                    Button(action: { consumeNextSelect(); toggle() }) {
                        TaskCheckbox(state: boxState, color: boxColor).frame(width: 18, height: 20).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(task.deletedAt != nil).help(finished ? "Mark incomplete" : "Complete task").accessibilityLabel((finished ? "Reopen " : "Complete ") + task.title)
                }
                if editing {
                    TextField("Task title", text: $draft).textFieldStyle(.plain).focused($titleFocused).onSubmit(commit)
                        .onExitCommand { editing = false }.onChange(of: titleFocused) { _, focused in if !focused { commit() } }
                        .font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Title + metadata share one Layout (not an HStack with a
                    // budgeted metadata frame): the Layout measures the fitted
                    // metadata against a finite budget first, pins it to the
                    // trailing edge at its exact intrinsic width, and hands
                    // every remaining point to the title. No measurement flows
                    // back into state, so live window resizes stay stable. The
                    // pane width still arrives as a plain value from the
                    // workspace geometry (never measured here); the budget
                    // keeps the historical relative rule — min(190, ~48% of row
                    // width) — so only the cap shrinks at compact widths while
                    // the title keeps the remainder.
                    TaskRowLineLayout(spacing: 4, maxMetadataWidth: metadataBudget) {
                        Text(task.title.isEmpty ? "Untitled" : task.title).foregroundStyle(finished ? finishedTitleColor : Palette.bodyText(colorScheme))
                            .font(.system(size: 14)).lineLimit(1).allowsTightening(false)
                            // Inflexible full-width single-line text inside a
                            // minWidth-0 flexible frame: the text itself never
                            // truncates (so no ellipsis is ever inserted), the
                            // frame unconditionally accepts the finite width
                            // the Layout assigns, and clipped() hard-clips it —
                            // including a partial glyph — at exactly that
                            // remainder. The full string stays in the
                            // accessibility tree; clipped + contentShape bound
                            // taps to the visible frame so tap-to-select and
                            // double-click rename work as before.
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { if allowRename { rename() } else { onTitleDoubleClick() } }
                            .simultaneousGesture(TapGesture().onEnded { onSelect() })
                        ViewThatFits(in: .horizontal) {
                            metadata(showTag: true, showExtras: true, showList: true).fixedSize()
                            metadata(showTag: false, showExtras: true, showList: true).fixedSize()
                            metadata(showTag: false, showExtras: false, showList: false).fixedSize()
                            if task.dueDate != nil {
                                Image(systemName: "calendar").foregroundStyle(accent).fixedSize()
                            }
                            // Terminal fallback: zero size when even the bare
                            // date icon cannot fit, so metadata never covers
                            // the title or controls.
                            Color.clear.frame(width: 0, height: 0)
                        }
                        .help(metadataDescription)
                    }
                }
            }.frame(height: hasExtras ? 24 : 40)
            if let previewLine {
                Text(previewLine).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    .padding(.leading, 20)
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
                }.padding(.leading, 20)
            }
        }.padding(.leading, 12).padding(.trailing, 7).padding(.vertical, hasExtras ? 8 : 0)
        .frame(minHeight: 40)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 1).padding(.leading, 40).padding(.trailing, 7) }
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture { if swallowSelect { swallowSelect = false } else { onSelect() } }
        .onTapGesture(count: 2) { onRowDoubleClick() }
        .accessibilityAction(named: "Rename", rename)
    }
    /// Pane content width passed down statelessly from the workspace geometry
    /// (list width docked, available width in overlay). The metadata budget is
    /// min(190, ~48% of the estimated row width after list padding), restoring
    /// the historical relative rule with no measurement and no state.
    private var metadataBudget: CGFloat { min(190, max(0, paneWidth - 32) * 0.48) }
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
    @ViewBuilder private func metadata(showTag: Bool, showExtras: Bool, showList: Bool) -> some View {
        HStack(spacing: 6) {
            // Optional free text (list/tag names) is capped so an unusually
            // long name truncates with an ellipsis instead of stealing title
            // room; the due date itself is never capped.
            if showList, let listContext { Text(listContext).foregroundStyle(metaColor).truncationMode(.tail).frame(maxWidth: 70, alignment: .trailing) }
            if showExtras {
                if !task.body.isEmpty { Image(systemName: "doc.plaintext").foregroundStyle(metaColor) }
                if !task.checklist.isEmpty { Text("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)").foregroundStyle(metaColor) }
                if showTag, let tag { Text("#" + tag.name).foregroundStyle(finished ? metaColor : Color(hex: tag.color)).truncationMode(.tail).frame(maxWidth: 96, alignment: .trailing) }
                if task.recurrence != .none { Image(systemName: "repeat").foregroundStyle(metaColor) }
                if task.reminderDate != nil { Image(systemName: "bell").foregroundStyle(finished ? metaColor : task.reminderDate! <= now ? .orange : .secondary) }
            }
            if let due = task.dueDate { Text(dueText(due)).foregroundStyle(dueColor(due)) }
        }.font(.system(size: 10)).lineLimit(1)
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

/// Title + trailing-metadata line for a task row. The metadata subview (a
/// ViewThatFits over rich-to-compact variants) is measured first against a
/// finite budget, pinned to the trailing edge at its exact fitted width, and
/// the title subview receives every remaining point after a fixed gap. Both
/// passes are pure functions of the proposal: no GeometryReader, no state
/// writes, so live window resizes stay stable.
private struct TaskRowLineLayout: Layout {
    var spacing: CGFloat = 4
    var maxMetadataWidth: CGFloat = 190

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? .infinity
        let metaWidth = fittedMetadataWidth(containerWidth: width, height: proposal.height, subview: subviews[1])
        if width.isFinite {
            let titleWidth = max(0, width - metaWidth - (metaWidth > 0 ? spacing : 0))
            let title = subviews[0].sizeThatFits(ProposedViewSize(width: titleWidth, height: proposal.height))
            let meta = subviews[1].sizeThatFits(ProposedViewSize(width: metaWidth, height: proposal.height))
            return CGSize(width: width, height: max(title.height, meta.height))
        }
        let title = subviews[0].sizeThatFits(ProposedViewSize(width: nil, height: proposal.height))
        let meta = subviews[1].sizeThatFits(ProposedViewSize(width: metaWidth, height: proposal.height))
        return CGSize(width: title.width + (metaWidth > 0 ? spacing : 0) + metaWidth, height: max(title.height, meta.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2, bounds.width.isFinite, bounds.width > 0 else { return }
        // The same finite budget proposal used in sizeThatFits: measure the
        // fitted width, then pin the selected metadata at the trailing edge.
        let metaWidth = fittedMetadataWidth(containerWidth: bounds.width, height: bounds.height, subview: subviews[1])
        let titleWidth = max(0, bounds.width - metaWidth - (metaWidth > 0 ? spacing : 0))
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: titleWidth, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(width: metaWidth, height: bounds.height)
        )
    }

    private func fittedMetadataWidth(containerWidth: CGFloat, height: CGFloat?, subview: LayoutSubview) -> CGFloat {
        let budget = max(0, min(maxMetadataWidth, containerWidth))
        guard budget > 0, budget.isFinite else { return 0 }
        let size = subview.sizeThatFits(ProposedViewSize(width: budget, height: height))
        return min(max(0, size.width), budget)
    }
}
