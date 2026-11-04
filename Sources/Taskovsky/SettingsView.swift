import SwiftUI
import TaskovskyCore

/// Settings-only flat switch: 26x16 track, 14pt white knob, flat accent when on
/// and measured gray when off. Interaction and accessibility come from a real
/// Button plus a native-Toggle accessibility representation, so keyboard
/// focus, Space toggling, and VoiceOver keep working.
struct FlatSwitchStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        // Labels-hidden only: the row title already shows the text, so render
        // just the 26x16 track. The label still reaches assistive tech through
        // the native-styled representation below (explicit style so it can
        // never reenter this custom style).
        Button { configuration.isOn.toggle() } label: { track(isOn: configuration.isOn) }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch) }
    }
    private func track(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isOn ? accent : colorScheme == .dark ? Color(nsColor: .separatorColor) : Color(hex: "#D9D9D9"))
                .frame(width: 26, height: 16)
            Circle().fill(.white).frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                .padding(1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isOn)
    }
}

/// Settings-only flat checkbox: 14x14 rounded 2-3, flat accent with a white
/// check when on, measured gray outline on the card when off. Same Button +
/// native-Toggle accessibility arrangement as the switch.
struct FlatCheckboxStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack {
                    if configuration.isOn {
                        RoundedRectangle(cornerRadius: 2.5).fill(accent)
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(colorScheme == .dark ? Color.clear : Palette.card(colorScheme))
                            .strokeBorder(colorScheme == .dark ? Color.secondary : Color(hex: "#CCCCCC"), lineWidth: 1)
                    }
                }.frame(width: 14, height: 14)
                // The off state is an outline only (transparent fill in dark
                // mode), so give the box an explicit rectangular hit shape.
                .contentShape(Rectangle())
                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.checkbox) }
    }
}

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: TaskStore
    @State private var section: Section = .smartLists
    @State private var editingTemplate: TemplateDraft?

    private enum Section: String, CaseIterable {
        case smartLists = "Smart Lists", dateTime = "Date & Time", more = "More", about = "About"
        var symbol: String {
            switch self { case .smartLists: "line.3.horizontal.decrease"; case .dateTime: "clock"; case .more: "switch.2"; case .about: "info.circle" }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").font(.system(size: 16, weight: .bold)).padding(.horizontal, 16).padding(.bottom, 24)
                ForEach(Section.allCases, id: \.self) { item in
                    Button { section = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).frame(width: 20)
                            Text(item.rawValue)
                            Spacer()
                        }.font(.system(size: 14)).padding(.horizontal, 12).padding(.vertical, 10)
                            .foregroundStyle(.primary)
                            .background(section == item ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(.horizontal, 16).padding(.top, 32).frame(width: 220).frame(maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if section != .more {
                        Text(section == .smartLists ? "Smart List" : section.rawValue).font(.system(size: 16, weight: .bold))
                    }
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
            .background(WindowChrome()).ignoresSafeArea(.container, edges: .top)
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
            smartListIcon(key).frame(width: 20).foregroundStyle(.primary)
            Text(title); Spacer(minLength: 16)
            valueMenu(selection: Binding(get: { store.settings.smartListVisibility[key] ?? .show }, set: { store.settings.smartListVisibility[key] = $0 }), options: key == .summary ? [("Hidden", .hidden), ("Show", .show)] : [
                ("Hidden", .hidden), ("Show", .show), ("Show if not empty", .showIfNotEmpty)
            ], title: title)
        }.font(.system(size: 14)).frame(minHeight: 40).padding(.horizontal, 18)
    }
    @ViewBuilder private func smartListIcon(_ key: SmartListKey) -> some View {
        switch key {
        case .today: CalendarSymbol(text: String(Calendar.current.component(.day, from: Date())))
        case .week: CalendarSymbol(text: String(Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1].prefix(2)))
        default: Image(systemName: smartListSymbol(key)).font(.system(size: 17))
        }
    }
    private func smartListSymbol(_ key: SmartListKey) -> String {
        switch key { case .all: "tray.full"; case .today: "calendar"; case .tomorrow: "sun.horizon"; case .week: "calendar.badge.clock"; case .inbox: "tray"; case .summary: "doc.text"; case .tags: "tag"; case .filters: "line.3.horizontal.decrease"; case .completed: "checkmark.square"; case .wontDo: "xmark.square"; case .trash: "trash" }
    }
    private var dateTime: some View {
        VStack(alignment: .leading, spacing: 20) {
            group {
                row("Start Week on") {
                    valueMenu(selection: $store.settings.startWeekOn, options: (1...7).map { (Calendar.current.weekdaySymbols[$0 - 1], $0) })
                }
            }
            group { toggleRow("Show Week Numbers(W)", $store.settings.showWeekNumbers) }
            group {
                toggleRow("Time Zone", $store.settings.enableTimeZone)
                explanation("If enabled, you can select the time zone when setting time for tasks.")
            }
        }
    }
    private var more: some View {
        VStack(alignment: .leading, spacing: 24) {
            titled("Smart Recognition") {
                group {
                    toggleRow("Date Recognition", $store.settings.dateRecognition)
                    explanation("When adding tasks, recognize date and time information and automatically set reminders.")
                    checkboxRow("Remove text in tasks", $store.settings.removeDateText)
                        .disabled(!store.settings.dateRecognition)
                    row("Tag Recognition") { EmptyView() }
                    explanation("You can select to keep or remove tags from task name.")
                    checkboxRow("Remove tags from task name", $store.settings.removeTagText)
                    toggleRow("URL Parsing", $store.settings.urlParsing)
                    explanation("When the task name is a URL, it will be parsed as the URL title.")
                }
            }
            titled("Task Default") {
                VStack(spacing: 12) {
                    group {
                        row("Default Date") { valueMenu(selection: $store.settings.defaultDate, options: [("None", .none), ("Today", .today), ("Tomorrow", .tomorrow), ("Day after tomorrow", .dayAfterTomorrow), ("Next week", .nextWeek)]) }
                        row("Default Reminders (Due time task)") {
                            ReferenceReminderMenu(selection: Binding(get: { store.settings.effectiveTimedReminderDefaults }, set: { values in
                                store.settings.timedReminderDefaults = values; store.settings.defaultReminder = values.first ?? .none
                            }), options: [("On time", .onTime), ("5 minutes early", .fiveMinutesBefore), ("15 minutes early", .fifteenMinutesBefore), ("30 minutes early", .thirtyMinutesBefore), ("1 hour early", .oneHourBefore), ("1 day early", .oneDayBefore)])
                        }
                        row("Default Reminders (All day task)") {
                            ReferenceReminderMenu(selection: Binding(get: { store.settings.effectiveAllDayReminderDefaults }, set: { values in
                                store.settings.allDayReminderDefaults = values; store.settings.allDayReminder = values.first ?? .none
                            }), options: [("On the day (09:00)", .onDay9), ("1 day early (09:00)", .dayBefore9), ("2 days early (09:00)", .twoDaysBefore9), ("3 days early (09:00)", .threeDaysBefore9), ("1 week early (09:00)", .weekBefore9)])
                        }
                    }
                    group {
                        row("Default Priority") { valueMenu(selection: $store.settings.defaultPriority, options: TaskPriority.allCases.map { ($0.label, $0) }) }
                        row("Default Tag") { valueMenu(selection: $store.settings.defaultTagID, options: [("None", nil)] + store.data.tags.map { ($0.name, Optional($0.id)) }) }
                        row("Default List") { valueMenu(selection: $store.settings.defaultListID, options: [("Inbox", nil)] + store.data.lists.map { ($0.name, Optional($0.id)) }) }
                    }
                    group {
                        positionRow("Default Add to", $store.settings.defaultAddTo)
                        positionRow("Overdue Section shows at", $store.settings.overduePosition)
                    }
                    HStack { Button("Reset Default", action: resetDefaults).buttonStyle(.plain).foregroundStyle(accent); Spacer() }
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
                                            ForEach(Array(template.checklist.prefix(5))) { item in
                                                HStack(alignment: .top, spacing: 5) { Image(systemName: "square"); Text(item.title).lineLimit(1) }.font(.system(size: 12)).foregroundStyle(Palette.explanatory(colorScheme))
                                            }
                                        } else if !template.body.isEmpty {
                                            Text(template.body).font(.system(size: 12)).foregroundStyle(Palette.explanatory(colorScheme)).lineLimit(4)
                                        } else {
                                            Text(template.title).font(.system(size: 12)).foregroundStyle(Palette.explanatory(colorScheme)).lineLimit(4)
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
            Text("A quiet place for your tasks.").foregroundStyle(Palette.explanatory(colorScheme))
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }
    private var cardBackground: Color { Palette.card(colorScheme) }
    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content).background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }
    private func titled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.system(size: 15, weight: .semibold)); content() }
    }
    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack { Text(title).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 16); content() }.font(.system(size: 14)).frame(minHeight: 40).padding(.horizontal, 18)
    }
    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        row(title) { Toggle(title, isOn: binding).labelsHidden().toggleStyle(FlatSwitchStyle()) }
    }
    private func checkboxRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        HStack { Toggle(title, isOn: binding).toggleStyle(FlatCheckboxStyle()); Spacer() }.font(.system(size: 13)).frame(minHeight: 44).padding(.horizontal, 18)
    }
    private func explanation(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Palette.explanatory(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 10)
    }
    private func valueMenu<Value: Equatable>(selection: Binding<Value>, options: [(String, Value)], title: String = "") -> some View {
        ReferenceValueMenu(selection: selection, options: options, title: title)
    }

    private func positionRow(_ title: String, _ binding: Binding<TaskPosition>) -> some View {
        row(title) { valueMenu(selection: binding, options: [("Top of List", .top), ("Bottom of List", .bottom)]) }
    }
    private func resetDefaults() {
        let defaults = AppSettings()
        store.settings.defaultDate = defaults.defaultDate; store.settings.defaultReminder = defaults.defaultReminder
        store.settings.allDayReminder = defaults.allDayReminder; store.settings.timedReminderDefaults = nil; store.settings.allDayReminderDefaults = nil
        store.settings.defaultPriority = defaults.defaultPriority
        store.settings.defaultTagID = defaults.defaultTagID; store.settings.defaultListID = defaults.defaultListID
        store.settings.defaultAddTo = defaults.defaultAddTo; store.settings.overduePosition = defaults.overduePosition
    }
}

private struct ReferenceReminderMenu<Value: Equatable>: View {
    @Binding var selection: [Value]
    let options: [(String, Value)]
    @State private var draft: [Value] = []
    @State private var open = false
    private var label: String {
        if selection.isEmpty { return "None" }
        if selection.count == 1 { return options.first { $0.1 == selection[0] }?.0 ?? "1 reminder" }
        return "\(selection.count) reminders"
    }
    var body: some View {
        Button { draft = selection; open = true } label: {
            HStack(spacing: 6) {
                Text(label).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
            }.foregroundStyle(.secondary).frame(maxWidth: 190, alignment: .trailing).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .popover(isPresented: $open, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                        Button {
                            if draft.contains(option.1) { draft.removeAll { $0 == option.1 } }
                            else { draft.append(option.1) }
                        } label: {
                            HStack(spacing: 20) {
                                Text(option.0); Spacer(minLength: 0)
                                Image(systemName: "checkmark").opacity(draft.contains(option.1) ? 1 : 0)
                            }.foregroundStyle(draft.contains(option.1) ? accent : .primary)
                                .padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    Divider().padding(.vertical, 5)
                    HStack {
                        Spacer()
                        Button("Cancel") { open = false }
                        Button("OK") {
                            selection = options.compactMap { option in draft.contains(option.1) ? option.1 : nil }
                            open = false
                        }.keyboardShortcut(.defaultAction)
                    }.padding(.horizontal, 8).padding(.bottom, 6)
                }.font(.system(size: 14)).padding(5).fixedSize(horizontal: true, vertical: true)
                    .onExitCommand { open = false }
            }
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
