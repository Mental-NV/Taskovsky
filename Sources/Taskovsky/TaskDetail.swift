import SwiftUI
import TaskovskyCore

struct TaskDetail: View {
    @ObservedObject var store: TaskStore
    let id: UUID
    let onTrash: () -> Void
    let onComplete: () -> Void
    let onWontDo: () -> Void
    @State private var scheduling = false
    @State private var newStep = ""
    @State private var tagName = ""
    @State private var showTags = false
    @FocusState private var stepFocused: Bool
    @FocusState private var tagFocused: Bool
    private var task: TaskItem { store.data.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "") }
    private var isDeleted: Bool { task.deletedAt != nil }
    private func field<Value>(_ keyPath: WritableKeyPath<TaskItem, Value>) -> Binding<Value> {
        Binding(get: { task[keyPath: keyPath] }, set: { value in var updated = task; updated[keyPath: keyPath] = value; store.updateTask(updated) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 15) {
                if task.kind == .task {
                    Button(action: onComplete) { Image(systemName: task.wontDoAt != nil ? "xmark.square.fill" : task.completedAt == nil ? "square" : "checkmark.square.fill").font(.system(size: 16, weight: .light)).foregroundStyle(task.completedAt == nil && task.wontDoAt == nil ? task.priority.color : .secondary) }.buttonStyle(.plain).help(task.completedAt == nil && task.wontDoAt == nil ? "Complete task" : "Mark incomplete").accessibilityLabel("Toggle completion").disabled(isDeleted)
                    Divider().frame(height: 20)
                }
                Button { scheduling = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(task.dueDate.map { task.dayText($0) + (task.hasDueTime ? ", " + task.timeText($0) : "") } ?? "Set date")
                        if task.recurrence != .none { Image(systemName: "repeat").font(.system(size: 11)) }
                    }.font(.system(size: 12)).foregroundStyle(task.dueDate == nil ? .secondary : accent)
                }.buttonStyle(.plain).help("Schedule, repeat, and reminders").disabled(isDeleted)
                    .popover(isPresented: $scheduling, arrowEdge: .bottom) { ScheduleEditor(task: task, settings: store.settings) { updated in store.updateTask(updated, applyDefaultReminders: false) } }
                Spacer(minLength: 5)
                Menu {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Button { var updated = task; updated.priority = priority; store.updateTask(updated) } label: { Label(priority.label + (task.priority == priority ? " ✓" : ""), systemImage: "flag") }
                    }
                } label: { Image(systemName: task.priority == .none ? "flag" : "flag.fill").font(.system(size: 16)).foregroundStyle(task.priority.color) }.menuStyle(.borderlessButton).fixedSize().help(task.priority.label).disabled(isDeleted)
            }.padding(.horizontal, 24).frame(height: 58)
            Divider()
            if isDeleted {
                HStack { Text("This item is in Trash.").font(.caption); Spacer(); Button("Restore") { store.restoreTask(id: id) }.controlSize(.small) }.padding(14).background(.orange.opacity(0.07))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Title", text: field(\.title), axis: .vertical).font(.system(size: 20, weight: .semibold)).textFieldStyle(.plain).disabled(isDeleted).accessibilityLabel("Task title")
                    if task.completedAt != nil { Label("Completed " + task.completedAt!.formatted(date: .abbreviated, time: .shortened), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
                    if task.wontDoAt != nil { Label("Won't Do", systemImage: "xmark.square.fill").font(.caption).foregroundStyle(.secondary) }
                    if let reminder = task.reminderDate {
                        HStack(spacing: 8) {
                            Image(systemName: "bell")
                            Text((reminder <= Date() ? "Reminder due · " : "Remind me ") + task.dayText(reminder) + " at " + task.timeText(reminder))
                            Spacer()
                            if reminder <= Date() && !isDeleted { Menu { Button("In 10 minutes") { setReminder(Date().addingTimeInterval(600)) }; Button("In 1 hour") { setReminder(Date().addingTimeInterval(3600)) }; Button("Tomorrow") { setReminder(Calendar.current.date(byAdding: .day, value: 1, to: Date())!) } } label: { Image(systemName: "clock.arrow.circlepath") }.menuStyle(.borderlessButton).fixedSize().help("Snooze reminder") }
                            if !isDeleted { Button { var updated = task; updated.reminderDate = nil; store.updateTask(updated) } label: { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain).help("Dismiss reminder") }
                        }.font(.system(size: 11)).foregroundStyle(reminder <= Date() ? .orange : .secondary).padding(10).background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                    }
                        ZStack(alignment: .topLeading) {
                            if task.body.isEmpty { Text(task.kind == .note ? "Start writing…" : "Description").font(.system(size: 16)).foregroundStyle(.tertiary).padding(.top, 1).padding(.leading, 4).allowsHitTesting(false) }
                            TextEditor(text: field(\.body)).font(.system(size: 16)).scrollContentBackground(.hidden).frame(minHeight: task.kind == .note ? 300 : 150).disabled(isDeleted).accessibilityLabel(task.kind == .note ? "Note content" : "Task description")
                        }
                    HStack(spacing: 6) {
                        ForEach(store.data.tags.filter { task.tagIDs.contains($0.id) }) { tag in
                            Button { if !isDeleted { var updated = task; updated.tagIDs.removeAll { $0 == tag.id }; store.updateTask(updated) } } label: { Text("#" + tag.name).font(.system(size: 11)).foregroundStyle(Color(hex: tag.color)).padding(.horizontal, 8).padding(.vertical, 5).background(Color(hex: tag.color).opacity(0.08), in: Capsule()) }.buttonStyle(.plain).help("Remove tag \(tag.name)")
                        }
                        if !isDeleted { Button { showTags.toggle() } label: { Image(systemName: "number").font(.system(size: 12)).foregroundStyle(.tertiary).padding(5) }.buttonStyle(.plain).help("Add tags").sheet(isPresented: $showTags) { tagPicker } }
                    }
                    if task.kind == .task {
                        Divider()
                        HStack { Text("Checklist").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary); Spacer(); if !task.checklist.isEmpty { Text("\(task.checklist.filter(\.isCompleted).count) of \(task.checklist.count)").font(.system(size: 10)).foregroundStyle(.tertiary) } }
                        VStack(spacing: 12) {
                            ForEach(task.checklist) { step in
                                HStack(spacing: 10) {
                                    Button { var updated = task; if let i = updated.checklist.firstIndex(where: { $0.id == step.id }) { updated.checklist[i].isCompleted.toggle(); store.updateTask(updated) } } label: { Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle").foregroundStyle(step.isCompleted ? accent : .secondary) }.buttonStyle(.plain).help("Toggle checklist item")
                                    TextField("Checklist item", text: Binding(get: { task.checklist.first { $0.id == step.id }?.title ?? "" }, set: { text in var updated = task; if let i = updated.checklist.firstIndex(where: { $0.id == step.id }) { updated.checklist[i].title = text; store.updateTask(updated) } })).textFieldStyle(.plain).font(.system(size: 12)).strikethrough(step.isCompleted).foregroundStyle(step.isCompleted ? .secondary : .primary)
                                    Button { var updated = task; updated.checklist.removeAll { $0.id == step.id }; store.updateTask(updated) } label: { Image(systemName: "minus.circle").font(.system(size: 11)).foregroundStyle(.tertiary) }.buttonStyle(.plain).help("Remove checklist item")
                                }.disabled(isDeleted)
                            }
                            if !isDeleted {
                                HStack(spacing: 10) { Image(systemName: "plus").foregroundStyle(.tertiary); TextField("Add checklist item", text: $newStep).textFieldStyle(.plain).font(.system(size: 12)).focused($stepFocused).onSubmit(addStep); if !newStep.isEmpty { Button(action: addStep) { Image(systemName: "return") }.buttonStyle(.plain) } }
                            }
                        }
                    }
                    Spacer(minLength: 40)
                }.padding(24)
            }
            Divider()
            HStack {
                Menu {
                    Button("Inbox") { var updated = task; updated.listID = nil; store.updateTask(updated) }
                    ForEach(store.data.lists) { list in Button(list.name) { var updated = task; updated.listID = list.id; store.updateTask(updated) } }
                } label: { Label(store.data.lists.first { $0.id == task.listID }?.name ?? "Inbox", systemImage: "tray").font(.system(size: 12)).foregroundStyle(.secondary) }.menuStyle(.borderlessButton).fixedSize().disabled(isDeleted).help("Move to list")
                Spacer()
                Menu {
                    Text("Created " + task.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if !isDeleted {
                        if task.kind == .task && task.wontDoAt == nil { Button("Won't Do", action: onWontDo) }
                        if task.wontDoAt != nil { Button("Mark incomplete") { store.reopenTask(id: id) } }
                        Button("Save as Template") { _ = store.saveTemplate(from: id) }
                        Menu("Apply Template") {
                            ForEach(store.data.templates) { template in
                                Button(template.name) { var updated = task; updated.title = template.title; updated.body = template.body; updated.checklist = template.checklist.map { ChecklistItem(title: $0.title) }; updated.priority = template.priority; updated.tagIDs = template.tagIDs; updated.kind = template.kind; store.updateTask(updated) }
                            }
                        }
                        Button("Duplicate") { _ = store.duplicateTask(id: id) }
                        Button(task.kind == .task ? "Convert to Note" : "Convert to Task") { var updated = task; updated.kind = task.kind == .task ? .note : .task; updated.completedAt = nil; store.updateTask(updated) }
                        Divider()
                        Button("Move to Trash", role: .destructive, action: onTrash)
                    } else { Button("Restore") { store.restoreTask(id: id) } }
                } label: { Image(systemName: "ellipsis").font(.system(size: 17)) }.menuStyle(.borderlessButton).fixedSize().padding(.leading, 12).help("More actions")
            }.foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 14)
        }
    }
    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Tags").font(.headline); Spacer(); Button("Done") { showTags = false }.keyboardShortcut(.cancelAction) }
            ForEach(store.data.tags) { tag in
                Toggle(isOn: Binding(get: { task.tagIDs.contains(tag.id) }, set: { enabled in var updated = task; if enabled { updated.tagIDs.append(tag.id) } else { updated.tagIDs.removeAll { $0 == tag.id } }; store.updateTask(updated) })) { Text("#" + tag.name).foregroundStyle(Color(hex: tag.color)) }.toggleStyle(.checkbox)
            }
            Divider()
            TextField("New tag", text: $tagName).textFieldStyle(.roundedBorder).focused($tagFocused).onSubmit(addTag)
            Button("Create & add", action: addTag).disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.padding(24).frame(width: 300).onAppear { tagFocused = true }
    }
    private func addTag() {
        let name = tagName.trimmingCharacters(in: .whitespacesAndNewlines); guard !name.isEmpty else { return }
        let tagID = store.createTag(name: name, color: palette[0]); var updated = task
        if !updated.tagIDs.contains(tagID) { updated.tagIDs.append(tagID); store.updateTask(updated) }; tagName = ""
    }
    private func addStep() {
        let title = newStep.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        var updated = task; updated.checklist.append(ChecklistItem(title: title)); store.updateTask(updated); newStep = ""; stepFocused = true
    }
    private func setReminder(_ date: Date) { var updated = task; updated.reminderDate = date; store.updateTask(updated) }
}

struct ScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    let settings: AppSettings
    let save: (TaskItem) -> Void
    @State private var date: Date
    @State private var hasDate: Bool
    @State private var hasTime: Bool
    @State private var repeatRule: RepeatRule
    @State private var hasReminder: Bool
    @State private var reminder: Date
    @State private var zoneID: String
    @State private var automaticReminder = true
    private var calendar: Calendar { var cal = settings.calendar; cal.timeZone = TimeZone(identifier: zoneID) ?? .current; return cal }
    init(task: TaskItem, settings: AppSettings, save: @escaping (TaskItem) -> Void) {
        self.task = task; self.settings = settings; self.save = save
        _zoneID = State(initialValue: task.timeZoneID ?? TimeZone.current.identifier)
        _date = State(initialValue: task.dueDate ?? Calendar.current.startOfDay(for: Date()))
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasTime = State(initialValue: task.hasDueTime)
        _repeatRule = State(initialValue: task.recurrence)
        _hasReminder = State(initialValue: task.reminderDate != nil)
        _reminder = State(initialValue: task.reminderDate ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: task.dueDate ?? Date())!)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Schedule").font(.headline)
            HStack(spacing: 8) {
                quickDate("Today", symbol: "sun.max", days: 0)
                quickDate("Tomorrow", symbol: "sun.horizon", days: 1)
                quickDate("Next week", symbol: "calendar", days: 7)
            }
            Toggle("Due date", isOn: $hasDate).toggleStyle(.checkbox)
            CalendarGrid(date: $date, calendar: calendar, showWeekNumbers: settings.showWeekNumbers).disabled(!hasDate)
            HStack { Toggle("Time", isOn: $hasTime).toggleStyle(.checkbox); Spacer(); if hasTime { DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute).labelsHidden().fixedSize() } }.disabled(!hasDate)
            if settings.enableTimeZone && hasTime {
                Picker("Time Zone", selection: $zoneID) { ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) } }.font(.system(size: 11))
            }
            Divider()
            HStack { Label("Repeat", systemImage: "repeat").font(.system(size: 12)); Spacer(); Picker("Repeat", selection: $repeatRule) { ForEach(RepeatRule.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden().frame(width: 155) }.disabled(!hasDate)
            Divider()
            Toggle(isOn: $hasReminder) { Label("Reminder", systemImage: "bell").font(.system(size: 12)) }.toggleStyle(.checkbox)
            if hasReminder {
                DatePicker("Remind me", selection: Binding(get: { reminder }, set: { reminder = $0; automaticReminder = false }), displayedComponents: [.date, .hourAndMinute]).labelsHidden().datePickerStyle(.field)
                HStack {
                    Button("On due date, 9am") { reminder = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!; automaticReminder = true }.disabled(!hasDate)
                    Button("10 min before") { reminder = date.addingTimeInterval(-600); automaticReminder = true }.disabled(!hasDate || !hasTime)
                }.font(.system(size: 10)).buttonStyle(.borderless)
                Text("Shown in the app. No system notifications.").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Divider()
            HStack {
                Button("Clear") { var updated = task; updated.dueDate = nil; updated.hasDueTime = false; updated.reminderDate = nil; updated.recurrence = .none; updated.recurrenceAnchorDay = nil; updated.recurrenceAnchorMonth = nil; save(updated); dismiss() }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { apply() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 320)
            .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
            .onChange(of: hasTime) { _, _ in applyReminderDefault() }
            .onChange(of: hasDate) { _, _ in applyReminderDefault() }
            .onChange(of: date) { old, new in if hasReminder && automaticReminder { reminder = reminder.addingTimeInterval(new.timeIntervalSince(old)) } }
            .onChange(of: zoneID) { old, new in
                var previous = settings.calendar; previous.timeZone = TimeZone(identifier: old) ?? .current
                let parts = previous.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                var next = settings.calendar; next.timeZone = TimeZone(identifier: new) ?? .current
                if let translated = next.date(from: parts) { date = translated }
            }
    }
    private func quickDate(_ title: String, symbol: String, days: Int) -> some View {
        Button {
            let cal = calendar
            let day = days == 7 ? cal.dateInterval(of: .weekOfYear, for: Date())!.end : cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date()))!
            date = hasTime ? cal.date(bySettingHour: cal.component(.hour, from: date), minute: cal.component(.minute, from: date), second: 0, of: day)! : day
            hasDate = true
        } label: { VStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 16)); Text(title).font(.system(size: 9)) }.frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.borderless).foregroundStyle(accent).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
    private func apply() {
        var updated = task
        updated.dueDate = hasDate ? (hasTime ? date : calendar.startOfDay(for: date)) : nil
        updated.hasDueTime = hasDate && hasTime
        updated.recurrence = hasDate ? repeatRule : .none
        updated.reminderDate = hasReminder ? reminder : nil
        updated.timeZoneID = hasDate && hasTime ? zoneID : nil
        if task.dueDate != updated.dueDate || task.recurrence != updated.recurrence { updated.recurrenceAnchorDay = nil; updated.recurrenceAnchorMonth = nil }
        save(updated); dismiss()
    }
    private func applyReminderDefault() {
        guard hasDate else { return }
        automaticReminder = true
        if hasTime, let offset = settings.defaultReminder.offset { reminder = date.addingTimeInterval(offset); hasReminder = true }
        else if !hasTime && settings.allDayReminder != .none {
            let day = settings.allDayReminder == .dayBefore9 ? calendar.date(byAdding: .day, value: -1, to: date)! : date
            reminder = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!; hasReminder = true
        } else if task.reminderDate == nil { hasReminder = false }
    }
}

struct EntityEditor: Identifiable {
    let id = UUID()
    var entityID: UUID?
    var isTag: Bool
    var name = ""
    var color = palette[0]
    var kind: TaskKind = .task
    init(isTag: Bool) { self.isTag = isTag }
    init(list: TaskList) { entityID = list.id; isTag = false; name = list.name; color = list.color; kind = list.kind }
    init(tag: TaskTag) { entityID = tag.id; isTag = true; name = tag.name; color = tag.color }
}
struct EntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let editor: EntityEditor
    let save: (String, String, TaskKind) -> Void
    @State private var name: String
    @State private var color: String
    @State private var kind: TaskKind
    @FocusState private var focused: Bool
    init(editor: EntityEditor, save: @escaping (String, String, TaskKind) -> Void) {
        self.editor = editor; self.save = save; _name = State(initialValue: editor.name); _color = State(initialValue: editor.color); _kind = State(initialValue: editor.kind)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text((editor.entityID == nil ? "New " : "Edit ") + (editor.isTag ? "Tag" : "List")).font(.system(size: 20, weight: .semibold))
            TextField(editor.isTag ? "Tag name" : "List name", text: $name).textFieldStyle(.roundedBorder).focused($focused).onSubmit(submit)
            HStack(spacing: 12) { ForEach(palette, id: \.self) { value in Button { color = value } label: { Circle().fill(Color(hex: value)).frame(width: 24, height: 24).overlay { if color == value { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) } } }.buttonStyle(.plain).accessibilityLabel("Color \(value)") } }
            if !editor.isTag { Picker("List type", selection: $kind) { Text("Tasks").tag(TaskKind.task); Text("Notes").tag(TaskKind.note) }.pickerStyle(.segmented) }
            if editor.entityID != nil && !editor.isTag { Text("List type sets the default for new items.").font(.caption).foregroundStyle(.secondary) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button(editor.entityID == nil ? "Create" : "Save", action: submit).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 360).tint(accent).onAppear { focused = true }
    }
    private func submit() { let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !cleaned.isEmpty else { return }; save(cleaned, color, kind); dismiss() }
}
