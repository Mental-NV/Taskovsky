import SwiftUI
import TaskovskyCore

struct SettingsView: View {
    @ObservedObject var store: TaskStore
    @State private var section: Section = .smartLists
    @State private var editingTemplate: TemplateDraft?

    private enum Section: String, CaseIterable {
        case smartLists = "Smart Lists", dateTime = "Date & Time", more = "More", about = "About"
        var symbol: String {
            switch self { case .smartLists: "list.bullet.rectangle"; case .dateTime: "calendar"; case .more: "slider.horizontal.3"; case .about: "info.circle" }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").font(.system(size: 20, weight: .bold)).padding(.horizontal, 16).padding(.bottom, 24)
                ForEach(Section.allCases, id: \.self) { item in
                    Button { section = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).frame(width: 20)
                            Text(item.rawValue)
                            Spacer()
                        }.font(.system(size: 14)).padding(.horizontal, 12).padding(.vertical, 10)
                            .foregroundStyle(section == item ? accent : .primary)
                            .background(section == item ? accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(.horizontal, 16).padding(.top, 32).frame(width: 220).frame(maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(section.rawValue).font(.system(size: 20, weight: .bold))
                    switch section {
                    case .smartLists: smartLists
                    case .dateTime: dateTime
                    case .more: more
                    case .about: about
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 40).padding(.vertical, 32)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .textBackgroundColor))
        }.frame(minWidth: 800, minHeight: 680).tint(accent)
            .sheet(item: $editingTemplate) { draft in TemplateEditor(draft: draft) { store.updateTemplate($0) } }
    }

    private var smartLists: some View {
        VStack(spacing: 20) {
            group {
                visibilityRow("All", .all); visibilityRow("Today", .today); visibilityRow("Tomorrow", .tomorrow)
                visibilityRow("Next 7 Days", .week); visibilityRow("Inbox", .inbox); visibilityRow("Summary", .summary)
            }
            group { visibilityRow("Tags", .tags); visibilityRow("Filters", .filters) }
            group { visibilityRow("Completed", .completed); visibilityRow("Won't Do", .wontDo); visibilityRow("Trash", .trash) }
        }
    }
    private func visibilityRow(_ title: String, _ key: SmartListKey) -> some View {
        HStack {
            Image(systemName: smartListSymbol(key)).frame(width: 20).foregroundStyle(.secondary)
            Text(title); Spacer(minLength: 16)
            Picker(title, selection: Binding(get: { store.settings.smartListVisibility[key] ?? .show }, set: { store.settings.smartListVisibility[key] = $0 })) {
                Text("Hidden").tag(SmartListVisibility.hidden); Text("Show").tag(SmartListVisibility.show); Text("Show if not empty").tag(SmartListVisibility.showIfNotEmpty)
            }.labelsHidden().frame(width: 160)
        }.font(.system(size: 14)).frame(minHeight: 40).padding(.horizontal, 18)
    }
    private func smartListSymbol(_ key: SmartListKey) -> String {
        switch key { case .all: "tray.full"; case .today: "calendar"; case .tomorrow: "sun.horizon"; case .week: "calendar.badge.clock"; case .inbox: "tray"; case .summary: "chart.bar"; case .tags: "number"; case .filters: "line.3.horizontal.decrease.circle"; case .completed: "checkmark.circle"; case .wontDo: "minus.circle"; case .trash: "trash" }
    }
    private var dateTime: some View {
        VStack(alignment: .leading, spacing: 20) {
            group {
                row("Start Week On") {
                    Picker("Start Week On", selection: $store.settings.startWeekOn) {
                        ForEach(1...7, id: \.self) { day in Text(Calendar.current.weekdaySymbols[day - 1]).tag(day) }
                    }.labelsHidden().frame(width: 160)
                }
                toggleRow("Show Week Numbers", $store.settings.showWeekNumbers)
            }
            group {
                toggleRow("Time Zone", $store.settings.enableTimeZone)
                Text("Set a time zone for tasks and keep their scheduled time when you travel.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 15)
            }
        }
    }
    private var more: some View {
        VStack(alignment: .leading, spacing: 24) {
            titled("Smart Recognition") {
                group {
                    toggleRow("Date Recognition", $store.settings.dateRecognition)
                    Text("Automatically recognize dates in task names.").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 8)
                    checkboxRow("Remove recognized date text from task title", $store.settings.removeDateText)
                        .disabled(!store.settings.dateRecognition)
                }
            }
            titled("Tag Recognition") { group { checkboxRow("Remove recognized tag text from task title", $store.settings.removeTagText) } }
            titled("URL Parsing") { group { toggleRow("URL Parsing", $store.settings.urlParsing); Text("When the task name is a URL, it will be parsed as the URL title.").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 14) } }
            titled("Task Default") {
                group {
                    row("Default Date") { Picker("Default Date", selection: $store.settings.defaultDate) { Text("None").tag(DefaultDate.none); Text("Today").tag(DefaultDate.today); Text("Tomorrow").tag(DefaultDate.tomorrow); Text("Day after tomorrow").tag(DefaultDate.dayAfterTomorrow); Text("Next week").tag(DefaultDate.nextWeek) }.labelsHidden().frame(width: 160) }
                    row("Default Reminders (Due time task)") { Picker("Reminder for Timed Tasks", selection: $store.settings.defaultReminder) {
                        Text("None").tag(DueReminder.none); Text("On time").tag(DueReminder.onTime); Text("5 minutes before").tag(DueReminder.fiveMinutesBefore); Text("15 minutes before").tag(DueReminder.fifteenMinutesBefore); Text("30 minutes before").tag(DueReminder.thirtyMinutesBefore); Text("1 hour before").tag(DueReminder.oneHourBefore); Text("1 day before").tag(DueReminder.oneDayBefore)
                    }.labelsHidden().frame(width: 160) }
                    row("Default Reminders (All day task)") { Picker("Reminder for All-day Tasks", selection: $store.settings.allDayReminder) { Text("None").tag(AllDayReminder.none); Text("On day at 9:00 AM").tag(AllDayReminder.onDay9); Text("Day before at 9:00 AM").tag(AllDayReminder.dayBefore9) }.labelsHidden().frame(width: 160) }
                    row("Default Priority") { Picker("Default Priority", selection: $store.settings.defaultPriority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden().frame(width: 160) }
                    row("Default Tag") { Picker("Default Tag", selection: $store.settings.defaultTagID) { Text("None").tag(nil as UUID?); ForEach(store.data.tags) { Text($0.name).tag(Optional($0.id)) } }.labelsHidden().frame(width: 160) }
                    row("Default List") { Picker("Default List", selection: $store.settings.defaultListID) { Text("Inbox").tag(nil as UUID?); ForEach(store.data.lists) { Text($0.name).tag(Optional($0.id)) } }.labelsHidden().frame(width: 160) }
                    positionRow("Default Add to", $store.settings.defaultAddTo)
                    positionRow("Overdue Section shows at", $store.settings.overduePosition)
                    HStack { Spacer(); Button("Reset Default", action: resetDefaults) }.padding(14)
                }
            }
            titled("Task Template") {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 145), spacing: 10), count: 3), spacing: 10) {
                        ForEach(store.data.templates) { template in
                            ZStack(alignment: .topTrailing) {
                                Button { editingTemplate = TemplateDraft(template) } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(template.name).font(.system(size: 14, weight: .semibold)).lineLimit(2).padding(.trailing, 20)
                                        if !template.checklist.isEmpty {
                                            ForEach(Array(template.checklist.prefix(4))) { item in
                                                HStack(alignment: .top, spacing: 5) { Image(systemName: "square"); Text(item.title).lineLimit(1) }.font(.system(size: 12)).foregroundStyle(.secondary)
                                            }
                                        } else if !template.body.isEmpty {
                                            Text(template.body).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(4)
                                        } else {
                                            Text(template.title).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(4)
                                        }
                                        Spacer(minLength: 0)
                                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(14).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Menu {
                                    Button("Edit") { editingTemplate = TemplateDraft(template) }
                                    Button("Delete", role: .destructive) { store.deleteTemplate(id: template.id) }
                                } label: { Image(systemName: "ellipsis").frame(width: 25, height: 25).contentShape(Rectangle()) }
                                    .menuStyle(.borderlessButton).fixedSize().padding(8).help("Template options")
                            }.frame(height: 170).background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Button { editingTemplate = TemplateDraft() } label: { Label("New Template", systemImage: "plus") }
                }
            }
        }
    }
    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Taskovsky Pre-Alpha").font(.system(size: 17, weight: .semibold))
            Text("A quiet place for your tasks.").foregroundStyle(.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }
    private var cardBackground: Color { Color.primary.opacity(0.025) }
    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content).background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }
    private func titled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.system(size: 15, weight: .semibold)); content() }
    }
    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack { Text(title); Spacer(minLength: 16); content() }.font(.system(size: 14)).frame(minHeight: 40).padding(.horizontal, 18)
    }
    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        row(title) { Toggle(title, isOn: binding).labelsHidden().toggleStyle(.switch).controlSize(.small) }
    }
    private func checkboxRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        HStack { Toggle(title, isOn: binding).toggleStyle(.checkbox); Spacer() }.font(.system(size: 13)).frame(minHeight: 44).padding(.horizontal, 18)
    }
    private func positionRow(_ title: String, _ binding: Binding<TaskPosition>) -> some View {
        row(title) { Picker(title, selection: binding) { Text("Top of List").tag(TaskPosition.top); Text("Bottom of List").tag(TaskPosition.bottom) }.labelsHidden().frame(width: 160) }
    }
    private func resetDefaults() {
        let defaults = AppSettings()
        store.settings.defaultDate = defaults.defaultDate; store.settings.defaultReminder = defaults.defaultReminder
        store.settings.allDayReminder = defaults.allDayReminder; store.settings.defaultPriority = defaults.defaultPriority
        store.settings.defaultTagID = defaults.defaultTagID; store.settings.defaultListID = defaults.defaultListID
        store.settings.defaultAddTo = defaults.defaultAddTo; store.settings.overduePosition = defaults.overduePosition
    }
}

private struct TemplateDraft: Identifiable {
    var id: UUID
    var original: TaskTemplate?
    init(_ template: TaskTemplate? = nil) { id = template?.id ?? UUID(); original = template }
}

private struct TemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    let draft: TemplateDraft
    let save: (TaskTemplate) -> Void
    @State private var name: String
    @State private var title: String
    @State private var bodyText: String
    @State private var checklist: String
    @State private var priority: TaskPriority
    init(draft: TemplateDraft, save: @escaping (TaskTemplate) -> Void) {
        self.draft = draft; self.save = save
        _name = State(initialValue: draft.original?.name ?? ""); _title = State(initialValue: draft.original?.title ?? "")
        _bodyText = State(initialValue: draft.original?.body ?? ""); _checklist = State(initialValue: draft.original?.checklist.map(\.title).joined(separator: "\n") ?? "")
        _priority = State(initialValue: draft.original?.priority ?? .none)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.original == nil ? "New Template" : "Edit Template").font(.system(size: 18, weight: .bold))
            TextField("Template name", text: $name)
            TextField("Task title", text: $title)
            Text("Description").font(.system(size: 13, weight: .medium))
            TextEditor(text: $bodyText).frame(height: 90).border(Color.secondary.opacity(0.25))
            Text("Checklist (one item per line)").font(.system(size: 13, weight: .medium))
            TextEditor(text: $checklist).frame(height: 90).border(Color.secondary.opacity(0.25))
            Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Save") {
                let lines = checklist.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                let template = TaskTemplate(id: draft.id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: bodyText, checklist: lines.map { ChecklistItem(title: $0) }, priority: priority, tagIDs: draft.original?.tagIDs ?? [], kind: draft.original?.kind ?? .task)
                save(template); dismiss()
            }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 480).tint(accent)
    }
}
