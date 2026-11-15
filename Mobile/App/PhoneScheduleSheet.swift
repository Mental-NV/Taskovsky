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

struct PhoneScheduleFeedback: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let surface: PhoneScheduleSurface

    var body: some View {
        if let notice = model.scheduleNotice(in: surface) {
            HStack {
                Text(notice).font(.footnote)
                    .accessibilityIdentifier(surface == .calendar ? "calendarScheduleNotice" : "taskScheduleNotice")
                if model.canUndoSchedule(in: surface) {
                    Button("Undo") { Task { await model.undoSchedule(in: surface) } }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier(surface == .calendar ? "undoCalendarSchedule" : "undoTaskSchedule")
                }
            }
        }
    }
}

struct PhoneOccurrenceSkipStage: View {
    var explainsSavedSchedule = false
    let keepEditing: () -> Void

    var body: some View {
        Section {
            Text("Done moves this open task to its next scheduled occurrence.")
            if explainsSavedSchedule {
                Text("Skipping uses the saved schedule. Keep editing returns to your date and repeat changes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Keep editing", action: keepEditing)
        }
    }
}

struct PhoneScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneScheduleRequest
    @State private var edit: TaskScheduleEdit
    @State private var error: String?
    @State private var skipOccurrence = false
    @State private var showZones = false
    @State private var showCustom = false
    @State private var showReplace = false
    @State private var showTimePopover = false
    @State private var showCustomReminder = false

    private var settings: AppSettings { request.document.snapshot.settings }
    private var due: Date { edit.schedule.effectiveDue }
    private var calendar: Calendar { edit.calendar }
    private var canSkipOccurrence: Bool {
        CalendarScheduling.canSkipCurrentOccurrence(request.task, in: request.document.snapshot.workspace.tasks,
                                                    calendar: request.calendar)
    }

    init(model: PhoneWorkspaceModel, request: PhoneScheduleRequest) {
        self.model = model
        self.request = request
        _edit = State(initialValue: TaskScheduleEdit(task: request.task, settings: request.document.snapshot.settings,
                                                    calendar: request.calendar, now: request.now))
    }

    var body: some View {
        NavigationStack {
            Form {
                if skipOccurrence {
                    PhoneOccurrenceSkipStage(explainsSavedSchedule: true) { skipOccurrence = false; error = nil }
                } else {
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
                        Section {
                            NavigationLink {
                                Form { reminderSection }
                                    .navigationTitle("Reminder").navigationBarTitleDisplayMode(.inline)
                            } label: { LabeledContent("Reminder", value: reminderSummary) }
                                .accessibilityIdentifier("scheduleReminderOptions").accessibilityValue(reminderSummary)
                            NavigationLink {
                                Form { repeatSection }
                                    .navigationTitle("Repeat").navigationBarTitleDisplayMode(.inline)
                            } label: { LabeledContent("Repeat", value: repeatSummary) }
                                .accessibilityIdentifier("scheduleRepeatOptions").accessibilityValue(repeatSummary)
                        }
                        if canSkipOccurrence {
                            Section {
                                Button("Skip this occurrence") { skipOccurrence = true; error = nil }
                                    .accessibilityIdentifier("scheduleSkipOccurrence")
                            }
                        }
                    }
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
                            if skipOccurrence {
                                error = await model.skipTaskOccurrence(taskID: request.task.id, expected: request.document.revision)
                            } else {
                                error = await model.saveSchedule(edit, expected: request.document.revision)
                            }
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
                Picker("Schedule type", selection: Binding(
                    get: { edit.schedule.duration != nil },
                    set: { edit.setDuration($0, defaultMinutes: settings.defaultDurationMinutes) })) {
                        Text("Date").tag(false)
                        Text("Duration").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("scheduleType")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        shortcut("Today", offset: 0)
                        shortcut("Tomorrow", offset: 1)
                        shortcut("Next week", offset: 7)
                    }.buttonStyle(.bordered)
                }
                if edit.schedule.duration == nil {
                    DatePicker("Date", selection: Binding(get: { due }, set: { edit.chooseDay($0) }), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accessibilityIdentifier("scheduleDateGrid")
                } else {
                    DisclosureGroup("Move duration to another date") {
                        DatePicker("Date", selection: Binding(get: { due }, set: { edit.chooseDay($0) }), displayedComponents: .date)
                            .accessibilityIdentifier("scheduleMoveDurationDate")
                    }
                }
                if let range = edit.schedule.duration {
                    Toggle("Time", isOn: Binding(get: { edit.schedule.effectiveHasTime }, set: { edit.setTime($0) }))
                        .accessibilityIdentifier("scheduleTime")
                    let components: DatePickerComponents = range.isAllDay ? .date : [.date, .hourAndMinute]
                    DatePicker("Start", selection: Binding(get: { edit.schedule.duration?.start ?? range.start },
                                                            set: { edit.setStart($0) }), displayedComponents: components)
                        .accessibilityIdentifier("scheduleRangeStart")
                    DatePicker("End", selection: Binding(get: { due }, set: { edit.setEnd($0) }), displayedComponents: components)
                        .accessibilityIdentifier("scheduleRangeEnd")
                    if range.validated(in: calendar) == nil {
                        Text("The end must be on or after the start.").font(.footnote).foregroundStyle(.red)
                    }
                } else {
                    Button {
                        if !edit.schedule.effectiveHasTime { edit.setTime(true) }
                        showTimePopover = true
                    } label: {
                        LabeledContent("Time", value: edit.schedule.effectiveHasTime
                            ? Self.timeLabel(due, calendar: calendar) : "None")
                    }
                    .accessibilityIdentifier("scheduleTime")
                    .accessibilityValue(edit.schedule.effectiveHasTime
                        ? Self.timeLabel(due, calendar: calendar) : "None")
                    .popover(isPresented: $showTimePopover) {
                        PhoneScheduleTimePopover(edit: $edit)
                            .presentationCompactAdaptation(.popover)
                    }
                    if edit.schedule.effectiveHasTime {
                        Button("Remove time", role: .destructive) { edit.setTime(false) }
                            .accessibilityIdentifier("scheduleTimeRemove")
                    }
                }
                Button("Remove schedule", role: .destructive) { edit.hasDate = false }
                    .accessibilityIdentifier("scheduleRemove")
            } else {
                Button("Add date") { edit.hasDate = true }.accessibilityIdentifier("scheduleAddDate")
                if request.task.dueDate != nil { Text("Schedule removal is staged until you tap Done.").font(.footnote) }
            }
        } header: { Text(edit.schedule.duration == nil ? "Date" : "Duration") }
    }

    private func shortcut(_ label: String, offset: Int) -> some View {
        Button(label) {
            let day = calendar.startOfDay(for: request.now)
            edit.chooseDay(calendar.date(byAdding: .day, value: offset, to: day) ?? day)
        }
        .accessibilityIdentifier("scheduleDay-\(offset)")
    }

    private var reminderSummary: String {
        var dates = edit.usesAutomaticReminders ? edit.automaticReminders(settings: settings) : edit.manualReminders
        if edit.remindsAtEnd, let end = edit.timedDurationEnd { dates.append(end) }
        let count = Set(dates).count
        if count == 0 { return edit.usesAutomaticReminders ? "Default (none)" : "None" }
        return edit.usesAutomaticReminders ? "Default · \(count)" : "\(count) reminder\(count == 1 ? "" : "s")"
    }

    private var repeatSummary: String {
        if let custom = edit.customRule { return custom.isValid ? custom.shortLabel(calendar: calendar) : "Invalid custom repeat" }
        return edit.repeatRule == .none ? "None" : edit.repeatRule.rawValue.capitalized
    }

    private var reminderSection: some View {
        Section("Reminders") {
            if let end = edit.timedDurationEnd {
                Toggle("At the end", isOn: $edit.remindsAtEnd)
                    .accessibilityIdentifier("scheduleReminderAtEnd")
                if edit.remindsAtEnd {
                    Text(end.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened,
                                                       calendar: calendar, timeZone: calendar.timeZone)))
                        .accessibilityIdentifier("scheduleEndReminderDate")
                }
            }
            if edit.schedule.duration == nil && !edit.schedule.effectiveHasTime {
                Button("Custom") { showCustomReminder = true }
                    .accessibilityIdentifier("scheduleCustomReminder")
                    .popover(isPresented: $showCustomReminder) {
                        PhoneAllDayReminderDialog(due: due, calendar: calendar, clock: { model.now }) { date in
                            edit.addManualReminder(date, settings: settings)
                        }.presentationCompactAdaptation(.popover)
                    }
            }
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
                        .accessibilityIdentifier("scheduleManualReminder-" + String(index))
                        .accessibilityValue(edit.manualReminders[index].formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, calendar: calendar, timeZone: calendar.timeZone)))
                }
                .onDelete { edit.manualReminders.remove(atOffsets: $0) }
                Button("Add reminder") {
                    let latest = edit.manualReminders.max() ?? due.addingTimeInterval(-900)
                    edit.manualReminders.append(latest.addingTimeInterval(900))
                }
                .accessibilityIdentifier("scheduleAddReminder")
                if !edit.manualReminders.isEmpty || edit.remindsAtEnd {
                    Button("Remove all reminders", role: .destructive) {
                        edit.manualReminders.removeAll()
                        edit.remindsAtEnd = false
                    }
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

    fileprivate static func timeLabel(_ date: Date, calendar: Calendar) -> String {
        date.formatted(Date.FormatStyle(time: .shortened, calendar: calendar, timeZone: calendar.timeZone))
    }
}

/// D09 compact Time popup for Date-mode schedules: hour/minute wheels with the
/// staged time zone shown below. Opening stages a time through
/// `TaskScheduleEdit.setTime`; closing the popup keeps the staged value and
/// the outer Cancel/Done transaction is unchanged. Zone changes stay on the
/// existing Time Zone row to avoid stacked presentations.
private struct PhoneScheduleTimePopover: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var edit: TaskScheduleEdit

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Time",
                       selection: Binding(get: { edit.schedule.effectiveDue },
                                          set: { edit.setEnd($0) }),
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .accessibilityIdentifier("scheduleTimeWheels")
                .padding(.horizontal)
            Divider()
            LabeledContent("Time zone",
                           value: edit.zoneID.map(PhoneScheduleSheet.zoneLabel) ?? "Device time zone")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
                .accessibilityIdentifier("scheduleTimeZone")
                .accessibilityValue(edit.zoneID.map(PhoneScheduleSheet.zoneLabel) ?? "Device time zone")
            Button { dismiss() } label: {
                Text("Done").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityIdentifier("scheduleTimePopoverDone")
            .padding(.bottom)
        }
    }
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
    @State private var exactIntervalText: String

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
        _exactIntervalText = State(initialValue: String(rule.interval))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Menu {
                        repeatTypeChoice("By Due Dates", id: "due", selected: pattern == .cadence && rule.anchor == .dueDate) {
                            pattern = .cadence; rule.anchor = .dueDate
                        }
                        repeatTypeChoice("By Completion Date", id: "completion", selected: pattern == .cadence && rule.anchor == .completionDate) {
                            pattern = .cadence; rule.anchor = .completionDate
                        }
                        repeatTypeChoice("By Specific Dates", id: "dates", selected: pattern == .dates) { pattern = .dates }
                    } label: {
                        HStack { Text("Repeat Type"); Spacer(); Text(repeatTypeLabel).foregroundStyle(.secondary); Image(systemName: "chevron.up.chevron.down").font(.caption) }
                    }.accessibilityIdentifier("customRepeatType").accessibilityValue(repeatTypeLabel)
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
            guard let interval = Int(exactIntervalText), (1...CustomRecurrence.maximumInterval).contains(interval) else { return nil }
            value.interval = interval
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

    private var repeatTypeLabel: String {
        if pattern == .dates { return "By Specific Dates" }
        return rule.anchor == .completionDate ? "By Completion Date" : "By Due Dates"
    }

    private func repeatTypeChoice(_ title: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
        }.accessibilityIdentifier("customRepeatType-" + id)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // A huge wheel makes native accessibility snapshots unresponsive. Preserve the
    // complete model range through Exact interval and include an existing large value.
    private var intervalChoices: [Int] {
        let common = Array(1...100)
        return rule.interval > 100 ? common + [rule.interval] : common
    }

    @ViewBuilder private var cadence: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 0) {
                Picker("Interval", selection: $rule.interval) {
                    ForEach(intervalChoices, id: \.self) { Text(String($0)).tag($0) }
                }.accessibilityIdentifier("customRepeatInterval")
                Picker("Unit", selection: Binding(get: { rule.unit }, set: setUnit)) {
                    ForEach(RecurrenceUnit.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }.accessibilityIdentifier("customRepeatUnit")
            }.pickerStyle(.wheel).frame(height: 150)
                .onChange(of: rule.interval) { _, value in exactIntervalText = String(value) }
            DisclosureGroup("Exact interval") {
                TextField("1–\(CustomRecurrence.maximumInterval)", text: $exactIntervalText)
                    .onChange(of: exactIntervalText) { _, value in
                        if let interval = Int(value), (1...CustomRecurrence.maximumInterval).contains(interval) { rule.interval = interval }
                    }
                    .keyboardType(.numberPad).accessibilityIdentifier("customRepeatExactInterval")
            }
            Text(candidate?.shortLabel(calendar: calendar) ?? "Enter a valid repeat pattern.")
                .font(.footnote).accessibilityIdentifier("customRepeatSummary")
        }
        switch rule.unit {
        case .days: EmptyView()
        case .weeks:
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { offset in
                    let weekday = ((calendar.firstWeekday - 1 + offset) % 7) + 1
                    let selected = rule.weekdays?.contains(weekday) == true
                    Button {
                        var weekdays = Set(rule.weekdays ?? [])
                        if selected { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                        rule.weekdays = weekdays.sorted()
                    } label: {
                        Text(calendar.veryShortStandaloneWeekdaySymbols[weekday - 1])
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08), in: Capsule())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
                        .accessibilityValue(selected ? "Selected" : "Not selected")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("customRepeatWeekday-\(weekday)")
                }
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
                    .accessibilityIdentifier("customRepeatDate-\(index)")
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


private struct PhoneAllDayReminderDialog: View {
    @Environment(\.dismiss) private var dismiss
    let due: Date
    let calendar: Calendar
    let clock: () -> Date
    @State private var expiredOnAdd = false
    let add: (Date) -> Void
    @State private var weeks = false
    @State private var offset = 0
    @State private var hour = 9
    @State private var minute = 0
    private var candidate: Date? {
        AllDayReminderOffset.date(due: due, weeks: weeks, offset: offset, hour: hour, minute: minute, calendar: calendar)
    }
    var body: some View {
        VStack(spacing: 12) {
            Text("Custom Reminder").font(.headline)
            Picker("Unit", selection: $weeks) { Text("Day").tag(false); Text("Week").tag(true) }
                .pickerStyle(.segmented).accessibilityIdentifier("customReminderUnit")
            HStack(spacing: 0) {
                Picker("Offset", selection: $offset) { ForEach(0...52, id: \.self) { Text(String($0)).tag($0) } }
                    .accessibilityIdentifier("customReminderOffset")
                Picker("Hour", selection: $hour) { ForEach(0...23, id: \.self) { Text(String(format: "%02d", $0)).tag($0) } }
                    .accessibilityIdentifier("customReminderHour")
                Picker("Minute", selection: $minute) { ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0)).tag($0) } }
                    .accessibilityIdentifier("customReminderMinute")
            }.pickerStyle(.wheel).frame(height: 150)
            Text("Before the scheduled date · " + calendar.timeZone.identifier).font(.caption).foregroundStyle(.secondary)
            if let candidate {
                Text(candidate.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, calendar: calendar, timeZone: calendar.timeZone)))
                    .font(.footnote).accessibilityIdentifier("customReminderPreview")
                if candidate <= clock() || expiredOnAdd { Text("This reminder has expired.").foregroundStyle(.red).accessibilityIdentifier("customReminderExpired") }
            } else {
                Text("This time does not exist in the selected time zone.").foregroundStyle(.red)
            }
            HStack {
                Button { dismiss() } label: { Text("Cancel").frame(minWidth: 44, minHeight: 44) }.accessibilityIdentifier("customReminderCancel")
                Spacer()
                Button {
                    guard let candidate, candidate > clock() else { expiredOnAdd = true; return }
                    add(candidate); dismiss()
                } label: { Text("Add").frame(minWidth: 44, minHeight: 44) }
                    .disabled(candidate == nil || candidate! <= clock())
                    .accessibilityIdentifier("customReminderAdd")
            }
        }.padding(16).frame(width: 310)
            .onChange(of: candidate) { _, _ in expiredOnAdd = false }
    }
}
