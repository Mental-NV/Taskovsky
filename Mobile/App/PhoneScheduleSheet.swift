import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneScheduleRequest: Identifiable {
    var id: UUID { task.id }
    let task: TaskItem
    let document: WorkspaceDocument
    let calendar: Calendar
    let now: Date

    static func summary(for task: TaskItem, calendar: Calendar) -> String {
        guard let due = task.dueDate else { return "Schedule" }
        var calendar = calendar
        if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { calendar.timeZone = zone }
        let date = Date.FormatStyle(date: .abbreviated, time: task.hasDueTime ? .shortened : .omitted,
                                    calendar: calendar, timeZone: calendar.timeZone)
        if let range = task.scheduledDuration { return "\(range.start.formatted(date)) – \(range.end.formatted(date))" }
        return due.formatted(date)
    }
}

struct PhoneScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneScheduleRequest
    @State private var edit: TaskScheduleEdit
    @State private var error: String?
    @State private var showZones = false
    @State private var showCustom = false
    @State private var showReplace = false

    private var settings: AppSettings { request.document.snapshot.settings }
    private var due: Date { edit.schedule.effectiveDue }
    private var calendar: Calendar { edit.calendar }

    init(model: PhoneWorkspaceModel, request: PhoneScheduleRequest) {
        self.model = model
        self.request = request
        _edit = State(initialValue: TaskScheduleEdit(task: request.task, settings: request.document.snapshot.settings,
                                                    calendar: request.calendar, now: request.now))
    }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                if edit.hasDate {
                    Section("Time Zone") {
                        Button {
                            showZones = true
                        } label: {
                            LabeledContent("Time zone", value: edit.zoneID.map(Self.zoneLabel) ?? "Device time zone")
                        }
                        .accessibilityIdentifier("scheduleZone")
                        if !edit.hasKnownZone {
                            Text("This time zone is unavailable. Choose a supported zone before saving changes.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    reminderSection
                    repeatSection
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial)
                        .accessibilityIdentifier("scheduleError")
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("scheduleCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            error = await model.saveSchedule(edit, expected: request.document.revision)
                            if error == nil { dismiss() }
                        }
                    }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("scheduleDone")
                }
            }
            .disabled(model.isBusy)
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .interactiveDismissDisabled(model.isBusy)
        .sheet(isPresented: $showZones) {
            PhoneScheduleZoneSheet(current: edit.zoneID) { edit.setZone($0) }
        }
        .sheet(isPresented: $showCustom) {
            let seed = edit.customRule ?? customSeed
            PhoneCustomRepeatSheet(rule: seed, task: request.task, due: due, timed: edit.schedule.effectiveHasTime) {
                edit.selectCustomRepeat($0)
            }
        }
        .confirmationDialog("Replace custom repeat?", isPresented: $showReplace, titleVisibility: .visible) {
            Button("Remove custom repeat", role: .destructive) { edit.selectSimpleRepeat(.none) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the custom rule and its series position when you save. You can then choose a simple repeat.")
        }
    }

    private var dateSection: some View {
        Section {
            if edit.hasDate {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        shortcut("Today", offset: 0)
                        shortcut("Tomorrow", offset: 1)
                        shortcut("Next week", offset: 7)
                    }.buttonStyle(.bordered)
                }
                DatePicker("Date", selection: Binding(get: { due }, set: { edit.chooseDay($0) }), displayedComponents: .date)
                Toggle("Time", isOn: Binding(get: { edit.schedule.effectiveHasTime }, set: { edit.setTime($0) }))
                    .accessibilityIdentifier("scheduleTime")
                Toggle("Duration", isOn: Binding(get: { edit.schedule.duration != nil },
                                                  set: { edit.setDuration($0, defaultMinutes: settings.defaultDurationMinutes) }))
                    .accessibilityIdentifier("scheduleDuration")
                if let range = edit.schedule.duration {
                    let components: DatePickerComponents = range.isAllDay ? .date : [.date, .hourAndMinute]
                    DatePicker("Start", selection: Binding(get: { edit.schedule.duration?.start ?? range.start },
                                                            set: { edit.setStart($0) }), displayedComponents: components)
                    DatePicker("End", selection: Binding(get: { due }, set: { edit.setEnd($0) }), displayedComponents: components)
                    if range.validated(in: calendar) == nil {
                        Text("The end must be on or after the start.").font(.footnote).foregroundStyle(.red)
                    }
                } else if edit.schedule.effectiveHasTime {
                    DatePicker("Due time", selection: Binding(get: { due }, set: { edit.setEnd($0) }),
                               displayedComponents: .hourAndMinute)
                }
                Button("Remove schedule", role: .destructive) { edit.hasDate = false }
                    .accessibilityIdentifier("scheduleRemove")
            } else {
                Button("Add date") { edit.hasDate = true }.accessibilityIdentifier("scheduleAddDate")
                if request.task.dueDate != nil { Text("Schedule removal is staged until you tap Done.").font(.footnote) }
            }
        } header: { Text("Date") }
    }

    private func shortcut(_ label: String, offset: Int) -> some View {
        Button(label) {
            let day = calendar.startOfDay(for: request.now)
            edit.chooseDay(calendar.date(byAdding: .day, value: offset, to: day) ?? day)
        }
        .accessibilityIdentifier("scheduleDay-\(offset)")
    }

    private var reminderSection: some View {
        Section("Reminders") {
            Toggle("Use default reminders", isOn: $edit.usesAutomaticReminders)
                .accessibilityIdentifier("scheduleAutomaticReminders")
            if edit.usesAutomaticReminders {
                let dates = edit.automaticReminders(settings: settings)
                if dates.isEmpty { Text("No default reminder").foregroundStyle(.secondary) }
                ForEach(dates, id: \.self) { date in
                    Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened,
                                                         calendar: calendar, timeZone: calendar.timeZone)))
                }
            } else {
                ForEach(edit.manualReminders.indices, id: \.self) { index in
                    DatePicker("Reminder \(index + 1)", selection: Binding(
                        get: { edit.manualReminders.indices.contains(index) ? edit.manualReminders[index] : due },
                        set: { if edit.manualReminders.indices.contains(index) { edit.manualReminders[index] = $0 } }))
                }
                .onDelete { edit.manualReminders.remove(atOffsets: $0) }
                Button("Add reminder") {
                    let latest = edit.manualReminders.max() ?? due.addingTimeInterval(-900)
                    edit.manualReminders.append(latest.addingTimeInterval(900))
                }
                .accessibilityIdentifier("scheduleAddReminder")
                if !edit.manualReminders.isEmpty {
                    Button("Remove all reminders", role: .destructive) { edit.manualReminders.removeAll() }
                }
            }
        }
    }

    private var repeatSection: some View {
        Section("Repeat") {
            if let custom = edit.customRule {
                Text(custom.isValid ? custom.shortLabel(calendar: calendar) : "Invalid custom repeat")
                    .accessibilityIdentifier("scheduleCustomRule")
                Button("Edit custom repeat") { showCustom = true }.accessibilityIdentifier("scheduleCustom")
                Button("Replace with simple repeat") { showReplace = true }
            } else {
                Picker("Repeat", selection: Binding(get: { edit.repeatRule }, set: { edit.selectSimpleRepeat($0) })) {
                    ForEach(RepeatRule.allCases, id: \.self) { rule in
                        Text(rule == .none ? "None" : rule.rawValue.capitalized).tag(rule)
                    }
                }
                .accessibilityIdentifier("scheduleSimpleRepeat")
                if edit.repeatRule != .none {
                    Toggle("End by date", isOn: Binding(get: { edit.repeatEnd != nil }, set: { edit.repeatEnd = $0 ? calendar.startOfDay(for: due) : nil }))
                    if edit.repeatEnd != nil {
                        DatePicker("Last day", selection: Binding(get: { edit.repeatEnd ?? due }, set: { edit.repeatEnd = calendar.startOfDay(for: $0) }),
                                   displayedComponents: .date)
                    }
                }
                Button("Custom repeat") { showCustom = true }.accessibilityIdentifier("scheduleCustom")
            }
        }
    }

    private var customSeed: CustomRecurrence {
        var rule = CustomRecurrence(legacyRawValue: edit.repeatRule.rawValue) ?? CustomRecurrence()
        if rule.unit == .weeks { rule.weekdays = [calendar.component(.weekday, from: due)] }
        rule.endDate = edit.repeatEnd
        return rule
    }

    fileprivate static func zoneLabel(_ id: String) -> String { id.replacingOccurrences(of: "_", with: " ") }
}

struct PhoneScheduleZoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: String?
    var excluded: Set<String> = []
    var showsDevice = true
    let choose: (String?) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if showsDevice && query.isEmpty { option("Device time zone", id: nil) }
                ForEach(TimeZone.knownTimeZoneIdentifiers.filter(matches), id: \.self) { id in
                    option(PhoneScheduleSheet.zoneLabel(id), id: id)
                }
            }
            .searchable(text: $query, prompt: "Search time zones")
            .navigationTitle("Time Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func matches(_ id: String) -> Bool {
        !excluded.contains(id) && (query.isEmpty ||
            PhoneScheduleSheet.zoneLabel(id).localizedCaseInsensitiveContains(PhoneScheduleSheet.zoneLabel(query)))
    }

    private func option(_ title: String, id: String?) -> some View {
        Button {
            choose(id)
            dismiss()
        } label: {
            HStack {
                Text(title)
                Spacer()
                if current == id { Image(systemName: "checkmark") }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(current == id ? .isSelected : [])
    }
}

private struct PhoneCustomRepeatSheet: View {
    private enum Pattern: String, CaseIterable { case cadence = "Cadence", dates = "Specific dates" }
    private enum MonthPattern: String, CaseIterable { case days = "Days", ordinal = "Weekday", workday = "Workday" }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    let task: TaskItem
    let due: Date
    let timed: Bool
    let commit: (CustomRecurrence) -> Void
    @State private var rule: CustomRecurrence
    @State private var pattern: Pattern
    @State private var monthDays: String
    @State private var dates: [Date]

    init(rule: CustomRecurrence, task: TaskItem, due: Date, timed: Bool,
         commit: @escaping (CustomRecurrence) -> Void) {
        self.task = task
        self.due = due
        self.timed = timed
        self.commit = commit
        _rule = State(initialValue: rule)
        _pattern = State(initialValue: rule.specificDates?.isEmpty == false ? .dates : .cadence)
        _monthDays = State(initialValue: (rule.monthDays ?? []).map(String.init).joined(separator: ", "))
        _dates = State(initialValue: rule.specificDates ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pattern", selection: $pattern) {
                        ForEach(Pattern.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    if pattern == .cadence { cadence } else { specificDates }
                }
                limits
                if task.customRecurrence != nil, candidate != task.customRecurrence {
                    Section { Text("Saving a changed rule restarts the series from the scheduled date.").font(.footnote) }
                }
                if let candidate, candidate.isValid {
                    let dates = preview(candidate)
                    Section("Next occurrences") {
                        if dates.isEmpty { Text("No further occurrences").foregroundStyle(.secondary) }
                        ForEach(dates, id: \.self) { date in
                            Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: timed ? .shortened : .omitted,
                                                                 calendar: calendar, timeZone: calendar.timeZone)))
                        }
                    }
                } else {
                    Section { Text("Enter a valid repeat pattern.").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Custom Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("customRepeatCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard let candidate, candidate.isValid else { return }
                        commit(candidate)
                        dismiss()
                    }
                    .disabled(candidate?.isValid != true)
                    .accessibilityIdentifier("customRepeatDone")
                }
            }
        }
    }

    private var candidate: CustomRecurrence? {
        var value = rule
        if pattern == .dates {
            guard !dates.isEmpty else { return nil }
            if dates != rule.specificDates { value.specificDates = dates }
        } else {
            if value.specificDates?.isEmpty == false { value.specificDates = nil }
            if rule.unit == .months && monthPattern == .days {
                guard let parsed = parseMonthDayList(monthDays) else { return nil }
                if parsed != (rule.monthDays ?? []) { value.monthDays = parsed.isEmpty ? nil : parsed }
            }
        }
        return value
    }

    private func preview(_ candidate: CustomRecurrence) -> [Date] {
        let index = candidate == task.customRecurrence ? task.occurrenceIndex : 1
        guard index < Int.max - 5 else { return [] }
        return remainingOccurrences(rule: candidate, current: due, index: index,
                             calendar: calendar, extraLimit: 5,
                             nominal: stagedNominal(draftDue: due, draftRule: candidate, task: task))
    }

    @ViewBuilder private var cadence: some View {
        Picker("Anchor", selection: $rule.anchor) {
            Text("By due dates").tag(RecurrenceAnchor.dueDate)
            Text("By completion date").tag(RecurrenceAnchor.completionDate)
        }
        Picker("Unit", selection: Binding(get: { rule.unit }, set: setUnit)) {
            ForEach(RecurrenceUnit.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        Stepper("Every \(rule.interval) \(rule.unit.rawValue)", value: $rule.interval, in: 1...CustomRecurrence.maximumInterval)
            .accessibilityIdentifier("customRepeatInterval")
        switch rule.unit {
        case .days: EmptyView()
        case .weeks:
            ForEach(1...7, id: \.self) { weekday in
                Toggle(calendar.weekdaySymbols[weekday - 1], isOn: Binding(
                    get: { rule.weekdays?.contains(weekday) == true },
                    set: { selected in
                        var weekdays = Set(rule.weekdays ?? [])
                        if selected { weekdays.insert(weekday) } else { weekdays.remove(weekday) }
                        rule.weekdays = weekdays.sorted()
                    }))
            }
        case .months:
            Picker("Monthly pattern", selection: Binding(get: { monthPattern }, set: setMonthPattern)) {
                ForEach(MonthPattern.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            switch monthPattern {
            case .days:
                TextField("Days, e.g. 1, 15, 31", text: $monthDays).keyboardType(.numbersAndPunctuation)
                Toggle("Last day of month", isOn: $rule.includesLastDayOfMonth)
            case .ordinal:
                ordinalPickers
            case .workday:
                Picker("Workday", selection: Binding(get: { rule.workday ?? .first }, set: { rule.workday = $0 })) {
                    Text("First").tag(WorkdayPosition.first)
                    Text("Last").tag(WorkdayPosition.last)
                }
            }
        case .years:
            Picker("Month", selection: $rule.yearMonth) {
                Text("Scheduled month").tag(Int?.none)
                ForEach(1...12, id: \.self) { Text(calendar.monthSymbols[$0 - 1]).tag(Optional($0)) }
            }
            Toggle("On a weekday", isOn: Binding(get: { rule.ordinalWeekday != nil }, set: {
                rule.ordinalWeekday = $0 ? initialOrdinal : nil
                if $0 { rule.yearMonthDay = nil }
            }))
            if rule.ordinalWeekday != nil {
                ordinalPickers
            } else {
                Picker("Day", selection: $rule.yearMonthDay) {
                    Text("Scheduled day").tag(Int?.none)
                    ForEach(1...31, id: \.self) { Text(String($0)).tag(Optional($0)) }
                }
            }
        }
        Toggle("Skip weekends", isOn: $rule.skipWeekends)
    }

    private var monthPattern: MonthPattern {
        if rule.workday != nil { return .workday }
        return rule.ordinalWeekday != nil ? .ordinal : .days
    }

    private var initialOrdinal: OrdinalWeekday {
        OrdinalWeekday(ordinal: 1, weekday: calendar.component(.weekday, from: due))
    }

    private func setMonthPattern(_ pattern: MonthPattern) {
        rule.ordinalWeekday = pattern == .ordinal ? initialOrdinal : nil
        rule.workday = pattern == .workday ? .first : nil
        if pattern != .days {
            rule.includesLastDayOfMonth = false
            rule.monthDays = nil
            monthDays = ""
        }
    }

    private func setUnit(_ unit: RecurrenceUnit) {
        guard unit != rule.unit else { return }
        rule.unit = unit
        rule.weekdays = unit == .weeks ? [calendar.component(.weekday, from: due)] : nil
        rule.monthDays = nil
        monthDays = ""
        rule.includesLastDayOfMonth = false
        rule.ordinalWeekday = nil
        rule.workday = nil
        rule.yearMonth = nil
        rule.yearMonthDay = nil
        rule.anchorDayOfMonth = nil
        rule.anchorMonth = nil
    }

    private var ordinalPickers: some View {
        Group {
            Picker("Position", selection: Binding(get: { rule.ordinalWeekday?.ordinal ?? 1 }, set: {
                rule.ordinalWeekday = OrdinalWeekday(ordinal: $0, weekday: rule.ordinalWeekday?.weekday ?? initialOrdinal.weekday)
            })) {
                ForEach(1...5, id: \.self) { Text(String($0)).tag($0) }
                Text("Last").tag(-1)
            }
            Picker("Weekday", selection: Binding(get: { rule.ordinalWeekday?.weekday ?? initialOrdinal.weekday }, set: {
                rule.ordinalWeekday = OrdinalWeekday(ordinal: rule.ordinalWeekday?.ordinal ?? 1, weekday: $0)
            })) {
                ForEach(1...7, id: \.self) { Text(calendar.weekdaySymbols[$0 - 1]).tag($0) }
            }
        }
    }

    private var specificDates: some View {
        Group {
            ForEach(dates.indices, id: \.self) { index in
                DatePicker("Occurrence \(index + 1)", selection: Binding(
                    get: { dates.indices.contains(index) ? dates[index] : due },
                    set: { if dates.indices.contains(index) { dates[index] = $0 } }),
                    displayedComponents: timed ? [.date, .hourAndMinute] : .date)
            }
            .onDelete { dates.remove(atOffsets: $0) }
            Button("Add date") {
                let last = dates.max() ?? due
                dates.append(calendar.date(byAdding: .day, value: 1, to: last) ?? last)
            }
        }
    }

    private var limits: some View {
        Section("End Repeat") {
            Toggle("End by date", isOn: Binding(get: { rule.endDate != nil }, set: { rule.endDate = $0 ? calendar.startOfDay(for: due) : nil }))
            if rule.endDate != nil {
                DatePicker("Last day", selection: Binding(get: { rule.endDate ?? due }, set: { rule.endDate = calendar.startOfDay(for: $0) }),
                           displayedComponents: .date)
            }
            Toggle("End by count", isOn: Binding(get: { rule.maxOccurrences != nil }, set: { rule.maxOccurrences = $0 ? 10 : nil }))
            if let count = rule.maxOccurrences {
                Stepper("Total occurrences: \(count)", value: Binding(get: { rule.maxOccurrences ?? 10 }, set: { rule.maxOccurrences = $0 }),
                        in: 1...999_999)
            }
        }
    }
}
