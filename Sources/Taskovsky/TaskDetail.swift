import SwiftUI
import TaskovskyCore

/// Unsaved per-task detail drafts (subtask text, tag field, popover visibility).
/// Owned by the workspace and keyed by task so dock/drawer/pop-up transitions
/// never lose half-entered text. Title/body persist immediately via bindings.
final class DetailDrafts: ObservableObject {
    @Published var newStep: [UUID: String] = [:]
    @Published var newSubtask: [UUID: String] = [:]
    @Published var tagName: [UUID: String] = [:]
    var shownTags: [UUID: Bool] = [:]
    var shownTemplates: [UUID: Bool] = [:]
    var scheduling: [UUID: Bool] = [:]
    func text(_ id: UUID, _ path: ReferenceWritableKeyPath<DetailDrafts, [UUID: String]>) -> Binding<String> {
        Binding(get: { self[keyPath: path][id] ?? "" }, set: { self[keyPath: path][id] = $0 })
    }
    func flag(_ id: UUID, _ path: ReferenceWritableKeyPath<DetailDrafts, [UUID: Bool]>) -> Binding<Bool> {
        Binding(get: { self[keyPath: path][id] ?? false }, set: { self.objectWillChange.send(); self[keyPath: path][id] = $0 })
    }
}

/// Presentation-only state: revealing tools never writes the task document.
struct DetailFormattingPresentation {
    private(set) var documentID: UUID?
    private(set) var isExpanded = false

    mutating func toggle(for id: UUID) {
        isExpanded = documentID == id ? !isExpanded : true
        documentID = id
    }

    func isVisible(for id: UUID, locked: Bool) -> Bool {
        !locked && documentID == id && isExpanded
    }

    mutating func reset() { documentID = nil; isExpanded = false }
}

struct TaskDetail: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var drafts: DetailDrafts
    let actions: TaskActionCenter
    @Environment(\.colorScheme) private var colorScheme
    let id: UUID
    let onTrash: () -> Void
    let onComplete: () -> Void
    let onWontDo: () -> Void
    /// Present only for the compact overlay drawer; the docked detail has no X.
    let onClose: (() -> Void)?
    /// Compact (drawer/pop-up) header: tighter spacing so day-relative due
    /// labels like "Yesterday, 1 Nov" still fit on one line at 300pt.
    var compact = false
    /// Standalone pop-up window: 52pt header below the native titlebar
    /// (reference geometry); main and drawer headers stay 58pt.
    var standalonePopup = false
    /// Restore and permanent-delete routing supplied by the host (workspace or
    /// pop-up). Direct store calls remain only as a fallback.
    var onRestore: (() -> Void)? = nil
    var onPurge: (() -> Void)? = nil
    /// Child/parent navigation supplied by the host (main, drawer, pop-up).
    /// Nil renders plain text (no navigation). Drafts stay keyed by task id,
    /// so partially entered subtask/tag text survives navigation.
    var onNavigateToTask: ((UUID) -> Void)? = nil
    private var scheduling: Binding<Bool> { drafts.flag(id, \.scheduling) }
    private var newStep: Binding<String> { drafts.text(id, \.newStep) }
    private var newSubtask: Binding<String> { drafts.text(id, \.newSubtask) }
    private var tagName: Binding<String> { drafts.text(id, \.tagName) }
    private var showTags: Binding<Bool> { drafts.flag(id, \.shownTags) }
    private var showTemplates: Binding<Bool> { drafts.flag(id, \.shownTemplates) }
    @StateObject private var richController = RichBodyController()
    @State private var occurrenceSkip: TaskOccurrenceSkipRequest?
    @State private var formatting = DetailFormattingPresentation()
    private var showFormatting: Bool { formatting.isVisible(for: id, locked: locked) }
    @State private var bodyFocused = false
    @State private var bodyHeight: CGFloat = 0
    @FocusState private var stepFocused: Bool
    @FocusState private var subtaskFocused: Bool
    @FocusState private var tagFocused: Bool
    /// Same-list active reparenting targets as the row menu; empty when there
    /// is nowhere valid to move (the Change menu hides itself then).
    private var subtaskParentOptions: [TaskItem] {
        TaskHierarchy.parentCandidates(for: task, in: store.data.tasks)
    }
    private var task: TaskItem { store.data.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "") }
    private var isDeleted: Bool { task.deletedAt != nil }
    /// Archived lists render read-only: no edits, no reminder actions,
    /// and the body editor locks. Deliberate moves happen from the row
    /// menu instead of the detail.
    private var archivedView: Bool { task.listID.flatMap { id in store.data.lists.first { $0.id == id } }?.isArchived ?? false }
    private var locked: Bool { isDeleted || archivedView }
    private func field<Value>(_ keyPath: WritableKeyPath<TaskItem, Value>) -> Binding<Value> {
        Binding(get: { task[keyPath: keyPath] }, set: { value in var updated = task; updated[keyPath: keyPath] = value; store.updateTask(updated) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader
            if task.kind == .task {
                TaskProgressControl(store: store, task: task, locked: locked)
            } else {
                Divider()
            }
            detailStatusBanner
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Title", text: field(\.title), axis: .vertical).font(.system(size: 20, weight: .semibold)).textFieldStyle(.plain).disabled(locked).accessibilityLabel("Task title")
                    if task.completedAt != nil { Label("Completed " + task.completedAt!.formatted(date: .abbreviated, time: .shortened), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
                    if task.wontDoAt != nil { Label("Won't Do", systemImage: "xmark.square.fill").font(.caption).foregroundStyle(.secondary) }
                    reminderSection
                    richBodySection
                    tagSection
                    if task.kind == .task {
                        checklistSection
                        subtaskSection
                    }
                    Spacer(minLength: 40)
                }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 24)
            }
            if showFormatting && !locked {
                RichBodyToolbar(controller: richController, disabled: false)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            }
            Divider()
            detailFooter
        }
        .onChange(of: id) { _, _ in formatting.reset() }
        .onChange(of: locked) { _, locked in if locked { formatting.reset() } }
        .taskOccurrenceSkipPrompt($occurrenceSkip, store: store, actions: actions)
    }

    // Keep the original view sections separate so Swift can type-check each
    // expression without changing state ownership, layout, bindings or actions.
    @ViewBuilder
    private var detailHeader: some View {
        HStack(spacing: compact ? 8 : 15) {
            if let onClose {
                Button(action: onClose) { HoverIcon { Image(systemName: "xmark").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).padding(4) } }.buttonStyle(.plain).help("Close details").accessibilityLabel("Close details")
            }
            if task.kind == .task {
                Button(action: onComplete) { HoverIcon { TaskCheckbox(state: task.wontDoAt != nil ? .wontDo : task.completedAt != nil ? .completed : .open, color: task.priority == .none ? Palette.taskOutline(colorScheme) : task.priority.color).padding(2).contentShape(Rectangle()) } }.buttonStyle(.plain).help(task.completedAt == nil && task.wontDoAt == nil ? "Complete task" : "Mark incomplete").accessibilityLabel("Toggle completion").disabled(locked)
                Divider().frame(height: 20)
            }
            Button { scheduling.wrappedValue = true } label: {
                HoverIcon {
                    HStack(spacing: compact ? 4 : 6) {
                        Image(systemName: "calendar")
                        Text((task.dueDate.map { dueHeaderText($0) } ?? "Set date") + durationSuffix).lineLimit(1)
                        if task.isRepeating { Image(systemName: "repeat").font(.system(size: 11)).help(task.repeatLabel()) }
                    }.font(.system(size: 12)).foregroundStyle(task.dueDate.map { pastDue($0) ? .red : accent } ?? .secondary).padding(4)
                }
            }.buttonStyle(.plain).help("Schedule, repeat, and reminders").disabled(locked)
                .popover(isPresented: scheduling, arrowEdge: .bottom) { ScheduleEditor(task: task, settings: store.settings) { updated, expected in store.saveSchedule(updated, expected: expected) } }
            Spacer(minLength: 5)
            Menu {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button { var updated = task; updated.priority = priority; store.updateTask(updated) } label: { Label(priority.label + (task.priority == priority ? " ✓" : ""), systemImage: "flag") }
                }
            } label: { HoverIcon { Image(systemName: task.priority == .none ? "flag" : "flag.fill").font(.system(size: 16)).foregroundStyle(task.priority.color).padding(4) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(task.priority.color).fixedSize().help(task.priority.label).disabled(locked)
        }.padding(.horizontal, compact ? 16 : 24).frame(height: standalonePopup ? 52 : 58)
    }

    @ViewBuilder
    private var detailStatusBanner: some View {
        if isDeleted {
            HStack { Text("This item is in Trash.").font(.caption); Spacer(); Button("Restore") { if let onRestore { onRestore() } else { store.restoreTask(id: id) } }.controlSize(.small) }.padding(14).background(.orange.opacity(0.07))
        } else if archivedView {
            HStack { Text("This list is archived — read-only. Unarchive it from the sidebar to edit.").font(.caption); Spacer() }.padding(14).background(Color.primary.opacity(0.05))
        }
    }

    @ViewBuilder
    private var reminderSection: some View {
        let dates = task.effectiveReminderDates
        if let reminder = dates.first, !archivedView {
            HStack(spacing: 8) {
                Image(systemName: "bell")
                Text((reminder <= Date() ? "Reminder due · " : "Remind me ") + task.dayText(reminder) + " at " + task.timeText(reminder) + (dates.count > 1 ? " · \(dates.count) reminders" : ""))
                Spacer()
                if reminder <= Date() && !isDeleted { Menu { Button("In 10 minutes") { setReminder(Date().addingTimeInterval(600)) }; Button("In 1 hour") { setReminder(Date().addingTimeInterval(3600)) }; Button("Tomorrow") { setReminder(Calendar.current.date(byAdding: .day, value: 1, to: Date())!) } } label: { Image(systemName: "clock.arrow.circlepath") }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().help("Snooze reminder") }
                if !isDeleted { Button { var updated = task; updated.reminderDates = []; updated.endReminderEnabled = false; store.updateTask(updated) } label: { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain).help("Dismiss all reminders") }
            }.font(.system(size: 11)).foregroundStyle(reminder <= Date() ? .orange : .secondary).padding(10).background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    @State private var showDescriptionReader = false

    @ViewBuilder
    private var richBodySection: some View {
        // Native rich-text body with an optional toolbar above the footer
        // and an auto-growing AppKit editor. The outer detail ScrollView scrolls; the editor
        // reports its content height so docked, drawer, and pop-up
        // layouts all size it without an inner scroller.
        let preview = task.richBody.flatMap { rich in
            rich.hasCodeBlocks || rich.blocks.contains { $0.validHeading != nil }
                ? RichDescriptionPreview(body: task.body, rich: rich) : nil
        }
        if let preview, !preview.foldableHeadings.isEmpty || !preview.codeBlocks.isEmpty {
            Button("Read Description", systemImage: "doc.text.magnifyingglass") { showDescriptionReader = true }
                .sheet(isPresented: $showDescriptionReader) {
                    RichBodyReader(documentID: task.id, preview: preview)
                }
        }
        ZStack(alignment: .topLeading) {
            RichBodyEditor(
                controller: richController,
                documentID: task.id,
                text: task.body,
                rich: task.richBody?.valid(for: task.body),
                disabled: locked,
                onChange: updateBody,
                onHeightChange: { bodyHeight = $0 },
                onFocusChange: { bodyFocused = $0 }
            )
            .frame(height: max(task.kind == .note ? 120 : 60, bodyHeight))
            .accessibilityLabel(task.kind == .note ? "Note content" : "Task description")
            if task.body.isEmpty && !bodyFocused && !locked {
                HStack(spacing: 4) {
                    Button("Write something") { richController.focus() }.foregroundStyle(.tertiary)
                    Text("or").foregroundStyle(.tertiary)
                    Button("use a template") { showTemplates.wrappedValue = true }.foregroundStyle(accent)
                }.buttonStyle(.plain).font(.system(size: 14)).padding(.top, 4).padding(.leading, 1)
            }
        }.frame(minHeight: task.kind == .note ? 120 : 60, alignment: .topLeading)
            .sheet(isPresented: showTemplates) { TemplatePicker(store: store, onChoose: applyTemplate) }
    }

    @ViewBuilder
    private var tagSection: some View {
        HStack(spacing: 6) {
            ForEach(store.data.tags.filter { task.tagIDs.contains($0.id) }) { tag in
                Button { if !locked { var updated = task; updated.tagIDs.removeAll { $0 == tag.id }; store.updateTask(updated) } } label: { Text("#" + tag.name).font(.system(size: 11)).foregroundStyle(Color(hex: tag.color)).padding(.horizontal, 8).padding(.vertical, 5).background(Color(hex: tag.color).opacity(0.08), in: Capsule()) }.buttonStyle(.plain).disabled(locked).help(locked ? "Tag \(tag.name) (read-only)" : "Remove tag \(tag.name)")
                    .accessibilityLabel(locked ? "Tag \(tag.name) (read-only)" : "Remove tag \(tag.name)")
            }
            if !locked { Button { showTags.wrappedValue.toggle() } label: { Image(systemName: "number").font(.system(size: 12)).foregroundStyle(.tertiary).padding(5) }.buttonStyle(.plain).help("Add tags").popover(isPresented: showTags, arrowEdge: .bottom) { tagPicker } }
        }
    }

    @ViewBuilder
    private var checklistSection: some View {
        Divider()
        // Checklist steps are quick items stored ON this task
        // (titles and ticks travel with templates and
        // duplicates); subtasks below are real linked records
        // with their own dates, lists, and completion.
        HStack { Text("Checklist").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary); Spacer(); if !task.checklist.isEmpty { Text("\(task.checklist.filter(\.isCompleted).count) of \(task.checklist.count)").font(.system(size: 10)).foregroundStyle(.tertiary) } }
        VStack(spacing: 8) {
            ForEach(task.checklist) { step in
                HStack(spacing: 10) {
                    Button { var updated = task; if let i = updated.checklist.firstIndex(where: { $0.id == step.id }) { updated.checklist[i].isCompleted.toggle(); store.updateTask(updated) } } label: { TaskCheckbox(state: step.isCompleted ? .completed : .open, color: .secondary) }.buttonStyle(.plain).help("Toggle checklist item")
                    TextField("Checklist item", text: Binding(get: { task.checklist.first { $0.id == step.id }?.title ?? "" }, set: { text in var updated = task; if let i = updated.checklist.firstIndex(where: { $0.id == step.id }) { updated.checklist[i].title = text; store.updateTask(updated) } })).textFieldStyle(.plain).font(.system(size: 14)).strikethrough(step.isCompleted).foregroundStyle(step.isCompleted ? .secondary : .primary)
                    Button { var updated = task; updated.checklist.removeAll { $0.id == step.id }; store.updateTask(updated) } label: { Image(systemName: "minus.circle").font(.system(size: 11)).foregroundStyle(.tertiary) }.buttonStyle(.plain).help("Remove checklist item")
                }.disabled(locked)
            }
            if !locked {
                HStack(spacing: 10) { Image(systemName: "plus").foregroundStyle(.tertiary); TextField("Add Checklist Item", text: newStep).textFieldStyle(.plain).font(.system(size: 14)).focused($stepFocused).onSubmit(addStep); if !newStep.wrappedValue.isEmpty { Button(action: addStep) { Image(systemName: "return") }.buttonStyle(.plain) } }
            }
        }
    }

    @ViewBuilder
    private var subtaskSection: some View {
        Divider()
        HStack { Text("Subtasks").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).help("Linked child tasks — each keeps its own dates, list, and completion"); Spacer(); if let progress = TaskHierarchy.progress(of: task.id, in: store.data.tasks) { Text("\(progress.done) of \(progress.total)").font(.system(size: 10)).foregroundStyle(.tertiary) } }
        VStack(spacing: 8) {
            if let parent = store.data.tasks.first(where: { $0.id == task.parentID }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.up.right").foregroundStyle(.tertiary)
                    Text("Subtask of").font(.system(size: 13)).foregroundStyle(.secondary)
                    if let navigate = onNavigateToTask {
                        Button(parent.title.isEmpty ? "Untitled" : parent.title) { navigate(parent.id) }
                            .buttonStyle(.plain).font(.system(size: 13)).lineLimit(1)
                            .foregroundStyle(accent).help("Open parent task")
                            .accessibilityLabel("Open parent task \(parent.title)")
                    } else {
                        Text(parent.title.isEmpty ? "Untitled" : parent.title).font(.system(size: 13)).lineLimit(1)
                    }
                    Spacer()
                    if !locked, !subtaskParentOptions.isEmpty {
                        Menu("Change") { ForEach(subtaskParentOptions) { option in Button(option.title.isEmpty ? "Untitled" : option.title) { _ = store.setTaskParent(id: task.id, parentID: option.id) } } }
                            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().font(.system(size: 12))
                        Button("Remove") { _ = store.setTaskParent(id: task.id, parentID: nil) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary).help("Move to top level")
                    }
                }
            }
            ForEach(TaskHierarchy.children(of: task.id, in: store.data.tasks)) { child in
                HStack(spacing: 10) {
                    Button { store.toggleComplete(id: child.id) } label: { TaskCheckbox(state: child.wontDoAt != nil ? .wontDo : child.completedAt != nil ? .completed : .open, color: .secondary) }.buttonStyle(.plain).disabled(locked).help(child.completedAt == nil && child.wontDoAt == nil ? "Complete subtask" : "Reopen subtask")
                    if let navigate = onNavigateToTask {
                        Button(child.title.isEmpty ? "Untitled" : child.title) { navigate(child.id) }
                            .buttonStyle(.plain).font(.system(size: 14)).strikethrough(child.completedAt != nil).foregroundStyle(child.completedAt != nil || child.wontDoAt != nil ? .secondary : .primary).lineLimit(1)
                            .help("Open subtask").accessibilityLabel("Open subtask \(child.title)")
                    } else {
                        Text(child.title.isEmpty ? "Untitled" : child.title).font(.system(size: 14)).strikethrough(child.completedAt != nil).foregroundStyle(child.completedAt != nil || child.wontDoAt != nil ? .secondary : .primary).lineLimit(1)
                    }
                    Spacer()
                    if !locked {
                        Button { _ = store.setTaskParent(id: child.id, parentID: nil) } label: { Image(systemName: "minus.circle").font(.system(size: 11)).foregroundStyle(.tertiary) }.buttonStyle(.plain).help("Move subtask to top level")
                    }
                }
            }
            if !locked {
                HStack(spacing: 10) { Image(systemName: "plus").foregroundStyle(.tertiary); TextField("Add Subtask", text: newSubtask).textFieldStyle(.plain).font(.system(size: 14)).focused($subtaskFocused).onSubmit(addSubtask); if !newSubtask.wrappedValue.isEmpty { Button(action: addSubtask) { Image(systemName: "return") }.buttonStyle(.plain) } }
            }
        }
    }

    @ViewBuilder
    private var detailFooter: some View {
        HStack {
            Menu {
                Button("Inbox") { var updated = task; updated.listID = nil; store.updateTask(updated) }
                ForEach(store.data.lists.filter { !$0.isArchived }) { list in Button(list.name) { var updated = task; updated.listID = list.id; store.updateTask(updated) } }
            } label: { HoverIcon { Label(store.data.lists.first { $0.id == task.listID }?.name ?? "Inbox", systemImage: "tray").font(.system(size: 12)).foregroundStyle(.secondary).padding(4) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().disabled(locked).help("Move to list")
            Spacer()
            if !locked {
                Button { formatting.toggle(for: id) } label: {
                    Image(systemName: "textformat")
                        .font(.system(size: 14)).frame(width: 28, height: 28)
                        .foregroundStyle(showFormatting ? accent : Color.secondary)
                        .background(showFormatting ? accent.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(showFormatting ? "Hide formatting" : "Show formatting")
                .accessibilityLabel(showFormatting ? "Hide formatting" : "Show formatting")
                .accessibilityValue(showFormatting ? "Expanded" : "Collapsed")
            }
            Menu {
                Text("Created " + task.createdAt.formatted(date: .abbreviated, time: .shortened))
                if !locked {
                    if task.kind == .task && task.wontDoAt == nil { Button("Won't Do", action: onWontDo) }
                    if task.wontDoAt != nil { Button("Mark incomplete") { store.reopenTask(id: id) } }
                    if task.completedAt == nil && task.wontDoAt == nil {
                        Button(task.isPinned ? "Unpin" : "Pin") { _ = store.setPinned(id: id, pinned: !task.isPinned) }
                    }
                    if CalendarScheduling.canSkipCurrentOccurrence(task, in: store.data.tasks, calendar: store.settings.calendar) {
                        Button("Skip this occurrence…") { occurrenceSkip = TaskOccurrenceSkipRequest(task) }
                    }
                    Button("Save as Template") { _ = store.saveTemplate(from: id) }
                    Menu("Apply Template") {
                        Button("Browse Templates…") { showTemplates.wrappedValue = true }
                        Divider()
                        ForEach(store.data.templates) { template in
                            Button(template.name) { applyTemplate(template) }
                        }
                    }
                    Button("Duplicate") { _ = store.duplicateTask(id: id) }
                    let kind: TaskKind = task.kind == .task ? .note : .task
                    Button(kind == .note ? "Convert to Note" : "Convert to Task") {
                        if let updated = task.converted(to: kind) { store.updateTask(updated) }
                    }
                    Divider()
                    Button("Move to Trash", role: .destructive, action: onTrash)
                } else if archivedView {
                    Text("Archived — read-only")
                } else {
                    Button("Restore") { if let onRestore { onRestore() } else { store.restoreTask(id: id) } }
                    if onPurge != nil { Button("Delete Forever", role: .destructive, action: onPurge!) }
                }
            } label: { HoverIcon { Image(systemName: "ellipsis").font(.system(size: 17)).padding(4) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().padding(.leading, 12).help("More actions")
        }.foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 14)
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Tags").font(.headline); Spacer(); Button("Done") { showTags.wrappedValue = false }.keyboardShortcut(.cancelAction) }
            ForEach(TagHierarchy.roots(in: store.data.tags), id: \.id) { root in
                tagPickerRow(tag: root, depth: 0)
            }
            Divider()
            TextField("New tag", text: tagName).textFieldStyle(.roundedBorder).focused($tagFocused).onSubmit(addTag)
            Button("Create & add", action: addTag).disabled(tagName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.padding(24).frame(width: 300).onAppear { tagFocused = true }
    }
    /// Indented tag toggle: hierarchy stays visible and assignable.
    /// `AnyView` breaks the recursion for the opaque return type.
    private func tagPickerRow(tag: TaskTag, depth: Int) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(get: { task.tagIDs.contains(tag.id) }, set: { enabled in var updated = task; if enabled { updated.tagIDs.append(tag.id) } else { updated.tagIDs.removeAll { $0 == tag.id } }; store.updateTask(updated) })) { Text("#" + tag.name).foregroundStyle(Color(hex: tag.color)) }.toggleStyle(.checkbox)
            ForEach(TagHierarchy.children(of: tag.id, in: store.data.tags)) { child in
                tagPickerRow(tag: child, depth: depth + 1)
            }
        }.padding(.leading, CGFloat(depth) * 16))
    }
    private func applyTemplate(_ template: TaskTemplate) {
        var updated = task
        updated.title = template.title; updated.body = template.body
        updated.richBody = template.richBody?.valid(for: template.body)
        // Checklist carries titles and checked state with fresh IDs (no
        // cross-task identity); a changed rule restarts the series at 1.
        updated.checklist = template.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }
        updated.customRecurrence = template.customRecurrence
        updated.restartCustomSeries(ruleChangedFrom: task.customRecurrence)
        updated.scheduledDuration = template.scheduledDuration
        updated.priority = template.priority; updated.tagIDs = template.tagIDs.filter { id in store.data.tags.contains { $0.id == id } }; updated.kind = template.kind
        store.updateTask(updated)
    }
    /// Rich-editor commit path: body and styles arrive together with mirrored
    /// text, so `updateTask` keeps them. No-op commits (uniform toggles that
    /// change nothing) skip the store to avoid timestamp churn and saves.
    private func updateBody(_ body: String, _ rich: RichBody?) {
        let valid = rich?.valid(for: body)
        let current = task.richBody?.valid(for: task.body)
        guard !RichBody.sameCodeUnits(body, task.body) || valid != current else { return }
        var updated = task
        updated.body = body
        updated.richBody = valid
        store.updateTask(updated)
    }
    private func addTag() {
        let name = tagName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines); guard !name.isEmpty else { return }
        let tagID = store.createTag(name: name, color: palette[0]); var updated = task
        if !updated.tagIDs.contains(tagID) { updated.tagIDs.append(tagID); store.updateTask(updated) }; tagName.wrappedValue = ""
    }
    private func addStep() {
        let title = newStep.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        var updated = task; updated.checklist.append(ChecklistItem(title: title)); store.updateTask(updated); newStep.wrappedValue = ""; stepFocused = true
    }
    private func addSubtask() {
        let title = newSubtask.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        if store.addSubtask(to: task.id, title: title) != nil { newSubtask.wrappedValue = "" }
        subtaskFocused = true
    }
    private func setReminder(_ date: Date) {
        guard let earliest = task.effectiveReminderDates.first else { return }
        var updated = task
        if earliest == task.endReminderDate { updated.endReminderEnabled = false }
        updated.reminderDates = task.reminderDates.filter { $0 != earliest } + [date]
        store.updateTask(updated)
    }
    private func dueHeaderText(_ due: Date) -> String {
        let cal = task.scheduleCalendar
        let timed = task.hasDueTime ? ", " + task.timeText(due) : ""
        return DueLabels.detailLabel(for: DueLabels.day(for: due, now: Date(), calendar: cal), dayText: task.dayText(due), timedSuffix: timed)
    }
    private func pastDue(_ due: Date) -> Bool {
        DueLabels.isOverdue(due: due, now: Date(), calendar: task.scheduleCalendar)
    }
    /// Planned-block suffix for the schedule button (" · 1h 30m", " · All day").
    private var durationSuffix: String {
        guard let window = task.scheduledDuration else { return "" }
        if window.isAllDay { return " · All day" }
        let minutes = Int(window.elapsed / 60)
        if minutes < 60 { return " · \(minutes)m" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? " · \(hours)h" : " · \(hours)h \(rest)m"
    }
}

struct EntityEditor: Identifiable {
    let id = UUID()
    var originalList: TaskList? = nil
    var entityID: UUID?
    var isTag: Bool
    var name = ""
    var color = palette[0]
    var kind: TaskKind = .task
    var symbol = ""
    /// Preselected folder for new lists, or the stored folder for edits.
    /// Edit call sites must pass the stored list's folder so unrelated edits
    /// never accidentally nil membership via a default-constructed editor.
    var folderID: UUID? = nil
    /// Trailing root placement for edits; carried through saves so an
    /// unrelated rename never resets a below-folders list to the top.
    var belowFolders = false
    /// Smart-list inclusion for lists; carried through saves like the folder.
    var showsInSmartLists = true
    /// Per-list center view; carried through saves so an unrelated rename
    /// never resets a Board list to List.
    var viewMode: TaskListViewMode = .list
    /// Preselected parent for new sub-tags, or the stored parent for edits.
    var parentTagID: UUID? = nil
    init(isTag: Bool, folderID: UUID? = nil, parentTagID: UUID? = nil) { self.isTag = isTag; self.folderID = folderID; self.parentTagID = parentTagID }
    init(list: TaskList) { originalList = list; entityID = list.id; isTag = false; name = list.name; color = list.color; kind = list.kind; symbol = list.symbol ?? ""; folderID = list.folderID; belowFolders = list.belowFolders; showsInSmartLists = list.showsInSmartLists; viewMode = list.viewMode }
    init(tag: TaskTag) { entityID = tag.id; isTag = true; name = tag.name; color = tag.color; parentTagID = tag.parentID }
}
struct EntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let editor: EntityEditor
    let folders: [ListFolder]
    let tags: [TaskTag]
    let save: (String, String, TaskKind, String?, UUID?, Bool, UUID?, Bool, TaskListViewMode) -> Bool
    @State private var saveFailed = false
    @State private var name: String
    @State private var color: String
    @State private var kind: TaskKind
    @State private var symbol: String
    @State private var folderID: UUID?
    @State private var showsInSmartLists: Bool
    @State private var viewMode: TaskListViewMode
    @State private var parentTagID: UUID?
    private let symbols = ["line.3.horizontal", "house", "briefcase", "book", "star", "cart", "heart", "folder", "list.bullet"]
    @FocusState private var focused: Bool
    init(editor: EntityEditor, folders: [ListFolder] = [], tags: [TaskTag] = [], save: @escaping (String, String, TaskKind, String?, UUID?, Bool, UUID?, Bool, TaskListViewMode) -> Bool) {
        self.editor = editor; self.folders = folders; self.tags = tags; self.save = save; _name = State(initialValue: editor.name); _color = State(initialValue: editor.color); _kind = State(initialValue: editor.kind); _symbol = State(initialValue: editor.symbol); _folderID = State(initialValue: editor.folderID); _showsInSmartLists = State(initialValue: editor.showsInSmartLists); _viewMode = State(initialValue: editor.viewMode); _parentTagID = State(initialValue: editor.parentTagID)
    }
    /// Cycle-safe parent options: the tag itself and its descendants can
    /// never be its parent.
    private var eligibleParents: [TaskTag] {
        guard let selfID = editor.entityID else { return tags }
        let forbidden = Set([selfID] + TagHierarchy.descendants(of: selfID, in: tags).map(\.id))
        return tags.filter { !forbidden.contains($0.id) }
    }
    var body: some View {
        Group {
            if editor.isTag {
                form
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        form
                        ListEditorPreview(name: name, symbol: symbol, tint: Color(hex: color),
                                          mode: viewMode, kind: kind)
                            .frame(width: 280)
                    }
                    form
                }
            }
        }.tint(accent).onAppear { focused = true }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text((editor.entityID == nil ? "New " : "Edit ") + (editor.isTag ? "Tag" : "List")).font(.system(size: 20, weight: .semibold))
            TextField(editor.isTag ? "Tag name" : "List name", text: $name).textFieldStyle(.roundedBorder).focused($focused).onSubmit(submit)
            HStack(spacing: 12) { ForEach(palette, id: \.self) { value in Button { color = value } label: { Circle().fill(Color(hex: value)).frame(width: 24, height: 24).overlay { if color == value { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) } } }.buttonStyle(.plain).accessibilityLabel("Color \(value)") } }
            if editor.isTag {
                Picker("Parent Tag", selection: $parentTagID) {
                    Text("None (top level)").tag(Optional<UUID>(nil))
                    ForEach(eligibleParents) { tag in Text(tag.name).tag(Optional(tag.id)) }
                }
                .help("Nest this tag under a parent")
                .accessibilityLabel("Parent Tag")
            } else {
                HStack(spacing: 8) {
                    ForEach(symbols, id: \.self) { value in
                        Button { symbol = value == "line.3.horizontal" ? "" : value } label: {
                            Image(systemName: value).frame(width: 27, height: 27)
                                .background((symbol == value || (symbol.isEmpty && value == "line.3.horizontal")) ? accent.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain).help(value == "line.3.horizontal" ? "Default list icon" : value)
                    }
                }
                TextField("Custom emoji", text: Binding(get: { symbols.contains(symbol) ? "" : symbol }, set: { symbol = String($0.prefix(1)) })).textFieldStyle(.roundedBorder)
                Picker("List type", selection: $kind) { Text("Tasks").tag(TaskKind.task); Text("Notes").tag(TaskKind.note) }.pickerStyle(.segmented)
                Picker("Folder", selection: $folderID) {
                    Text("No folder").tag(Optional<UUID>(nil))
                    ForEach(folders) { folder in Text(folder.name).tag(Optional(folder.id)) }
                }
                .help("Choose a folder for this list")
                .accessibilityLabel("Folder")
                Picker("Show in Smart List", selection: $showsInSmartLists) {
                    Text("All tasks").tag(true)
                    Text("Do not show").tag(false)
                }
                .help("Excluded lists hide from smart lists but keep reminders")
                .accessibilityLabel("Show in Smart List")
                Picker("View", selection: $viewMode) {
                    Text("List").tag(TaskListViewMode.list)
                    Text("Board").tag(TaskListViewMode.board)
                    Text("Timeline").tag(TaskListViewMode.timeline)
                }
                .pickerStyle(.segmented)
                .help("This list's center view: rows or a status-column Kanban board")
                .accessibilityLabel("List or board view")
            }
            if editor.entityID != nil && !editor.isTag { Text("List type sets the default for new items.").font(.caption).foregroundStyle(.secondary) }
            if saveFailed { Text("The list was not saved. Your draft is preserved. Check the workspace error, then retry or reopen the list if it changed.").font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true).accessibilityLabel("List save failed; draft preserved") }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button(editor.entityID == nil ? "Create" : "Save", action: submit).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 360)
    }
    private func submit() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let cleanedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedIcon = cleanedSymbol.isEmpty ? nil : cleanedSymbol
        let identity = editor.isTag ? (name: cleaned, symbol: selectedIcon) :
            ListIcon.resolvingName(cleaned, symbol: selectedIcon, previousName: editor.entityID == nil ? nil : editor.name)
        let saved = save(identity.name, color, kind, identity.symbol, folderID, folderID == nil ? editor.belowFolders : false,
             parentTagID, showsInSmartLists, viewMode)
        if saved { dismiss() } else { saveFailed = true }
    }
}

/// Name-only folder dialog (TickTick reference: text plus Cancel/Save).
struct FolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let initialName: String
    let save: (String) -> Void
    @State private var name: String
    @FocusState private var focused: Bool
    init(title: String, initialName: String = "", save: @escaping (String) -> Void) {
        self.title = title; self.initialName = initialName; self.save = save; _name = State(initialValue: initialName)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.system(size: 20, weight: .semibold))
            TextField("Folder name", text: $name).textFieldStyle(.roundedBorder).focused($focused).onSubmit(submit)
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Save", action: submit).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 320).tint(accent).onAppear { focused = true }
    }
    private func submit() { let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !cleaned.isEmpty else { return }; save(cleaned); dismiss() }
}
