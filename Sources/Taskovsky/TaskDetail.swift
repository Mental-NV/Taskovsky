import SwiftUI
import TaskovskyCore

/// Unsaved per-task detail drafts (subtask text, tag field, popover visibility).
/// Owned by the workspace and keyed by task so dock/drawer/pop-up transitions
/// never lose half-entered text. Title/body persist immediately via bindings.
final class DetailDrafts: ObservableObject {
    @Published var newStep: [UUID: String] = [:]
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

struct TaskDetail: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var drafts: DetailDrafts
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
    private var scheduling: Binding<Bool> { drafts.flag(id, \.scheduling) }
    private var newStep: Binding<String> { drafts.text(id, \.newStep) }
    private var tagName: Binding<String> { drafts.text(id, \.tagName) }
    private var showTags: Binding<Bool> { drafts.flag(id, \.shownTags) }
    private var showTemplates: Binding<Bool> { drafts.flag(id, \.shownTemplates) }
    @FocusState private var bodyFocused: Bool
    @FocusState private var stepFocused: Bool
    @FocusState private var tagFocused: Bool
    private var task: TaskItem { store.data.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "") }
    private var isDeleted: Bool { task.deletedAt != nil }
    private func field<Value>(_ keyPath: WritableKeyPath<TaskItem, Value>) -> Binding<Value> {
        Binding(get: { task[keyPath: keyPath] }, set: { value in var updated = task; updated[keyPath: keyPath] = value; store.updateTask(updated) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: compact ? 8 : 15) {
                if let onClose {
                    Button(action: onClose) { HoverIcon { Image(systemName: "xmark").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).padding(4) } }.buttonStyle(.plain).help("Close details").accessibilityLabel("Close details")
                }
                if task.kind == .task {
                    Button(action: onComplete) { HoverIcon { TaskCheckbox(state: task.wontDoAt != nil ? .wontDo : task.completedAt != nil ? .completed : .open, color: task.priority == .none ? Palette.taskOutline(colorScheme) : task.priority.color).padding(2).contentShape(Rectangle()) } }.buttonStyle(.plain).help(task.completedAt == nil && task.wontDoAt == nil ? "Complete task" : "Mark incomplete").accessibilityLabel("Toggle completion").disabled(isDeleted)
                    Divider().frame(height: 20)
                }
                Button { scheduling.wrappedValue = true } label: {
                    HoverIcon {
                        HStack(spacing: compact ? 4 : 6) {
                            Image(systemName: "calendar")
                            Text(task.dueDate.map { dueHeaderText($0) } ?? "Set date").lineLimit(1)
                            if task.recurrence != .none { Image(systemName: "repeat").font(.system(size: 11)) }
                        }.font(.system(size: 12)).foregroundStyle(task.dueDate.map { pastDue($0) ? .red : accent } ?? .secondary).padding(4)
                    }
                }.buttonStyle(.plain).help("Schedule, repeat, and reminders").disabled(isDeleted)
                    .popover(isPresented: scheduling, arrowEdge: .bottom) { ScheduleEditor(task: task, settings: store.settings) { updated in store.updateTask(updated, applyDefaultReminders: false) } }
                Spacer(minLength: 5)
                Menu {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Button { var updated = task; updated.priority = priority; store.updateTask(updated) } label: { Label(priority.label + (task.priority == priority ? " ✓" : ""), systemImage: "flag") }
                    }
                } label: { HoverIcon { Image(systemName: task.priority == .none ? "flag" : "flag.fill").font(.system(size: 16)).foregroundStyle(task.priority.color).padding(4) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(task.priority.color).fixedSize().help(task.priority.label).disabled(isDeleted)
            }.padding(.horizontal, compact ? 16 : 24).frame(height: standalonePopup ? 52 : 58)
            Divider()
            if isDeleted {
                HStack { Text("This item is in Trash.").font(.caption); Spacer(); Button("Restore") { onRestore?() ?? store.restoreTask(id: id) }.controlSize(.small) }.padding(14).background(.orange.opacity(0.07))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Title", text: field(\.title), axis: .vertical).font(.system(size: 20, weight: .semibold)).textFieldStyle(.plain).disabled(isDeleted).accessibilityLabel("Task title")
                    if task.completedAt != nil { Label("Completed " + task.completedAt!.formatted(date: .abbreviated, time: .shortened), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
                    if task.wontDoAt != nil { Label("Won't Do", systemImage: "xmark.square.fill").font(.caption).foregroundStyle(.secondary) }
                    if let reminder = task.reminderDates.first {
                        HStack(spacing: 8) {
                            Image(systemName: "bell")
                            Text((reminder <= Date() ? "Reminder due · " : "Remind me ") + task.dayText(reminder) + " at " + task.timeText(reminder) + (task.reminderDates.count > 1 ? " · \(task.reminderDates.count) reminders" : ""))
                            Spacer()
                            if reminder <= Date() && !isDeleted { Menu { Button("In 10 minutes") { setReminder(Date().addingTimeInterval(600)) }; Button("In 1 hour") { setReminder(Date().addingTimeInterval(3600)) }; Button("Tomorrow") { setReminder(Calendar.current.date(byAdding: .day, value: 1, to: Date())!) } } label: { Image(systemName: "clock.arrow.circlepath") }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().help("Snooze reminder") }
                            if !isDeleted { Button { var updated = task; updated.reminderDates = []; store.updateTask(updated) } label: { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain).help("Dismiss all reminders") }
                        }.font(.system(size: 11)).foregroundStyle(reminder <= Date() ? .orange : .secondary).padding(10).background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                    }
                    ZStack(alignment: .topLeading) {
                        // The hidden text gives the editor the height needed for wrapped plain text.
                        Text(task.body.isEmpty ? " " : task.body + "\n")
                            .font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 5).padding(.vertical, 4).hidden()
                        TextEditor(text: field(\.body)).font(.system(size: 14)).scrollContentBackground(.hidden)
                            .focused($bodyFocused).disabled(isDeleted).accessibilityLabel(task.kind == .note ? "Note content" : "Task description")
                        if task.body.isEmpty && !bodyFocused && !isDeleted {
                            HStack(spacing: 4) {
                                Button("Write something") { bodyFocused = true }.foregroundStyle(.tertiary)
                                Text("or").foregroundStyle(.tertiary)
                                Button("use a template") { showTemplates.wrappedValue = true }.foregroundStyle(accent)
                            }.buttonStyle(.plain).font(.system(size: 14)).padding(.top, 4).padding(.leading, 5)
                        }
                    }.frame(minHeight: task.kind == .note ? 120 : 60, alignment: .topLeading)
                        // Counteract the native TextEditor ~5pt text-container inset so the
                        // description and placeholder align with the title's left edge.
                        .padding(.leading, -5)
                        .sheet(isPresented: showTemplates) { TemplatePicker(store: store, onChoose: applyTemplate) }
                    HStack(spacing: 6) {
                        ForEach(store.data.tags.filter { task.tagIDs.contains($0.id) }) { tag in
                            Button { if !isDeleted { var updated = task; updated.tagIDs.removeAll { $0 == tag.id }; store.updateTask(updated) } } label: { Text("#" + tag.name).font(.system(size: 11)).foregroundStyle(Color(hex: tag.color)).padding(.horizontal, 8).padding(.vertical, 5).background(Color(hex: tag.color).opacity(0.08), in: Capsule()) }.buttonStyle(.plain).help("Remove tag \(tag.name)")
                        }
                        if !isDeleted { Button { showTags.wrappedValue.toggle() } label: { Image(systemName: "number").font(.system(size: 12)).foregroundStyle(.tertiary).padding(5) }.buttonStyle(.plain).help("Add tags").popover(isPresented: showTags, arrowEdge: .bottom) { tagPicker } }
                    }
                    if task.kind == .task {
                        Divider()
                        HStack { Text("Subtasks").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary); Spacer(); if !task.checklist.isEmpty { Text("\(task.checklist.filter(\.isCompleted).count) of \(task.checklist.count)").font(.system(size: 10)).foregroundStyle(.tertiary) } }
                        VStack(spacing: 8) {
                            ForEach(task.checklist) { step in
                                HStack(spacing: 10) {
                                    Button { var updated = task; if let i = updated.checklist.firstIndex(where: { $0.id == step.id }) { updated.checklist[i].isCompleted.toggle(); store.updateTask(updated) } } label: { TaskCheckbox(state: step.isCompleted ? .completed : .open, color: .secondary) }.buttonStyle(.plain).help("Toggle checklist item")
                                    TextField("Subtask", text: Binding(get: { task.checklist.first { $0.id == step.id }?.title ?? "" }, set: { text in var updated = task; if let i = updated.checklist.firstIndex(where: { $0.id == step.id }) { updated.checklist[i].title = text; store.updateTask(updated) } })).textFieldStyle(.plain).font(.system(size: 14)).strikethrough(step.isCompleted).foregroundStyle(step.isCompleted ? .secondary : .primary)
                                    Button { var updated = task; updated.checklist.removeAll { $0.id == step.id }; store.updateTask(updated) } label: { Image(systemName: "minus.circle").font(.system(size: 11)).foregroundStyle(.tertiary) }.buttonStyle(.plain).help("Remove checklist item")
                                }.disabled(isDeleted)
                            }
                            if !isDeleted {
                                HStack(spacing: 10) { Image(systemName: "plus").foregroundStyle(.tertiary); TextField("Add Subtask", text: newStep).textFieldStyle(.plain).font(.system(size: 14)).focused($stepFocused).onSubmit(addStep); if !newStep.wrappedValue.isEmpty { Button(action: addStep) { Image(systemName: "return") }.buttonStyle(.plain) } }
                            }
                        }
                    }
                    Spacer(minLength: 40)
                }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 24)
            }
            Divider()
            HStack {
                Menu {
                    Button("Inbox") { var updated = task; updated.listID = nil; store.updateTask(updated) }
                    ForEach(store.data.lists) { list in Button(list.name) { var updated = task; updated.listID = list.id; store.updateTask(updated) } }
                } label: { HoverIcon { Label(store.data.lists.first { $0.id == task.listID }?.name ?? "Inbox", systemImage: "tray").font(.system(size: 12)).foregroundStyle(.secondary).padding(4) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().disabled(isDeleted).help("Move to list")
                Spacer()
                Menu {
                    Text("Created " + task.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if !isDeleted {
                        if task.kind == .task && task.wontDoAt == nil { Button("Won't Do", action: onWontDo) }
                        if task.wontDoAt != nil { Button("Mark incomplete") { store.reopenTask(id: id) } }
                        Button("Save as Template") { _ = store.saveTemplate(from: id) }
                        Menu("Apply Template") {
                            ForEach(store.data.templates) { template in
                                Button(template.name) { applyTemplate(template) }
                            }
                        }
                        Button("Duplicate") { _ = store.duplicateTask(id: id) }
                        Button(task.kind == .task ? "Convert to Note" : "Convert to Task") { var updated = task; updated.kind = task.kind == .task ? .note : .task; updated.completedAt = nil; store.updateTask(updated) }
                        Divider()
                        Button("Move to Trash", role: .destructive, action: onTrash)
                    } else {
                        Button("Restore") { onRestore?() ?? store.restoreTask(id: id) }
                        if onPurge != nil { Button("Delete Forever", role: .destructive, action: onPurge!) }
                    }
                } label: { HoverIcon { Image(systemName: "ellipsis").font(.system(size: 17)).padding(4) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().padding(.leading, 12).help("More actions")
            }.foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 14)
        }
    }
    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Tags").font(.headline); Spacer(); Button("Done") { showTags.wrappedValue = false }.keyboardShortcut(.cancelAction) }
            ForEach(store.data.tags) { tag in
                Toggle(isOn: Binding(get: { task.tagIDs.contains(tag.id) }, set: { enabled in var updated = task; if enabled { updated.tagIDs.append(tag.id) } else { updated.tagIDs.removeAll { $0 == tag.id } }; store.updateTask(updated) })) { Text("#" + tag.name).foregroundStyle(Color(hex: tag.color)) }.toggleStyle(.checkbox)
            }
            Divider()
            TextField("New tag", text: tagName).textFieldStyle(.roundedBorder).focused($tagFocused).onSubmit(addTag)
            Button("Create & add", action: addTag).disabled(tagName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.padding(24).frame(width: 300).onAppear { tagFocused = true }
    }
    private func applyTemplate(_ template: TaskTemplate) {
        var updated = task
        updated.title = template.title; updated.body = template.body
        updated.checklist = template.checklist.map { ChecklistItem(title: $0.title) }
        updated.priority = template.priority; updated.tagIDs = template.tagIDs.filter { id in store.data.tags.contains { $0.id == id } }; updated.kind = template.kind
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
    private func setReminder(_ date: Date) { var updated = task; var dates = task.reminderDates; if !dates.isEmpty { dates.removeFirst() }; dates.append(date); updated.reminderDates = dates; store.updateTask(updated) }
    private func dueHeaderText(_ due: Date) -> String {
        let cal = task.scheduleCalendar
        let timed = task.hasDueTime ? ", " + task.timeText(due) : ""
        return DueLabels.detailLabel(for: DueLabels.day(for: due, now: Date(), calendar: cal), dayText: task.dayText(due), timedSuffix: timed)
    }
    private func pastDue(_ due: Date) -> Bool {
        DueLabels.isOverdue(due: due, now: Date(), calendar: task.scheduleCalendar)
    }
}

struct EntityEditor: Identifiable {
    let id = UUID()
    var entityID: UUID?
    var isTag: Bool
    var name = ""
    var color = palette[0]
    var kind: TaskKind = .task
    var symbol = ""
    init(isTag: Bool) { self.isTag = isTag }
    init(list: TaskList) { entityID = list.id; isTag = false; name = list.name; color = list.color; kind = list.kind; symbol = list.symbol ?? "" }
    init(tag: TaskTag) { entityID = tag.id; isTag = true; name = tag.name; color = tag.color }
}
struct EntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let editor: EntityEditor
    let save: (String, String, TaskKind, String?) -> Void
    @State private var name: String
    @State private var color: String
    @State private var kind: TaskKind
    @State private var symbol: String
    private let symbols = ["line.3.horizontal", "house", "briefcase", "book", "star", "cart", "heart", "folder", "list.bullet"]
    @FocusState private var focused: Bool
    init(editor: EntityEditor, save: @escaping (String, String, TaskKind, String?) -> Void) {
        self.editor = editor; self.save = save; _name = State(initialValue: editor.name); _color = State(initialValue: editor.color); _kind = State(initialValue: editor.kind); _symbol = State(initialValue: editor.symbol)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text((editor.entityID == nil ? "New " : "Edit ") + (editor.isTag ? "Tag" : "List")).font(.system(size: 20, weight: .semibold))
            TextField(editor.isTag ? "Tag name" : "List name", text: $name).textFieldStyle(.roundedBorder).focused($focused).onSubmit(submit)
            HStack(spacing: 12) { ForEach(palette, id: \.self) { value in Button { color = value } label: { Circle().fill(Color(hex: value)).frame(width: 24, height: 24).overlay { if color == value { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) } } }.buttonStyle(.plain).accessibilityLabel("Color \(value)") } }
            if !editor.isTag {
                HStack(spacing: 8) {
                    ForEach(symbols, id: \.self) { value in
                        Button { symbol = value } label: {
                            Image(systemName: value).frame(width: 27, height: 27)
                                .background((symbol == value || (symbol.isEmpty && value == "line.3.horizontal")) ? accent.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain).help(value)
                    }
                }
                TextField("Custom emoji", text: Binding(get: { symbols.contains(symbol) ? "" : symbol }, set: { symbol = String($0.prefix(1)) })).textFieldStyle(.roundedBorder)
                Picker("List type", selection: $kind) { Text("Tasks").tag(TaskKind.task); Text("Notes").tag(TaskKind.note) }.pickerStyle(.segmented)
            }
            if editor.entityID != nil && !editor.isTag { Text("List type sets the default for new items.").font(.caption).foregroundStyle(.secondary) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button(editor.entityID == nil ? "Create" : "Save", action: submit).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 360).tint(accent).onAppear { focused = true }
    }
    private func submit() { let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !cleaned.isEmpty else { return }; let cleanedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines); save(cleaned, color, kind, cleanedSymbol.isEmpty ? nil : cleanedSymbol); dismiss() }
}
