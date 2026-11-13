import SwiftUI
import TaskovskyCore

struct ScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var task: TaskItem
    let settings: AppSettings
    let save: (TaskItem, TaskItem) -> Bool
    @State private var saveFailed = false
    @State private var date: Date
    @State private var hasDate: Bool
    @State private var hasTime: Bool
    @State private var repeatDraft: RepeatDraft
    @State private var showCustomEditor = false
    @State private var hasDuration: Bool
    @State private var durationStart: Date
    @State private var durationEnd: Date
    @State private var durationAllDay: Bool
    @State private var endDate: Date
    @State private var hasEnd: Bool
    @State private var reminders: [Date]
    @State private var remindsAtEnd: Bool
    @State private var zoneSelection: ScheduleZoneSelection
    private var zoneID: String { zoneSelection.identifier }
    @State private var automaticReminder = true
    @State private var expanded: Row?
    private enum Row { case time, reminder, duration, repeatRule, end }
    private var calendar: Calendar { var cal = settings.calendar; cal.timeZone = TimeZone(identifier: zoneID) ?? .current; return cal }

    init(task: TaskItem, settings: AppSettings, save: @escaping (TaskItem, TaskItem) -> Bool) {
        _task = State(initialValue: task); self.settings = settings; self.save = save
        _zoneSelection = State(initialValue: ScheduleZoneSelection(storedIdentifier: task.timeZoneID,
            fallbackIdentifier: TimeZone.current.identifier))
        _date = State(initialValue: task.dueDate ?? Calendar.current.startOfDay(for: Date()))
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasTime = State(initialValue: task.hasDueTime)
        _repeatDraft = State(initialValue: RepeatDraft(repeatRule: task.recurrence, customRule: task.customRecurrence))
        _hasEnd = State(initialValue: task.recurrenceEndDate != nil)
        _endDate = State(initialValue: task.recurrenceEndDate ?? task.dueDate ?? Date())
        _reminders = State(initialValue: task.reminderDates)
        _remindsAtEnd = State(initialValue: task.endReminderEnabled)
        _automaticReminder = State(initialValue: TaskStore.usesDefaultReminder(task, settings: settings))
        // A stored window restores verbatim; a fresh one seeds the due date
        // (or today) with the default length so adding one is a single tap.
        let window = task.scheduledDuration
        let seedEnd = task.dueDate ?? Calendar.current.startOfDay(for: Date())
        let seedMinutes = max(settings.defaultDurationMinutes, 0)
        _hasDuration = State(initialValue: window != nil)
        _durationAllDay = State(initialValue: window?.isAllDay ?? false)
        _durationEnd = State(initialValue: window?.end ?? seedEnd)
        _durationStart = State(initialValue: window?.start ?? seedEnd.addingTimeInterval(-Double(min(seedMinutes > 0 ? seedMinutes : 60, 10_080)) * 60))
    }
    /// The draft window, or nil while it is invalid (OK stays disabled).
    private var draftDuration: TaskDurationRange? {
        guard hasDuration else { return nil }
        return TaskDurationRange(start: durationStart, end: durationEnd, isAllDay: durationAllDay).validated(in: calendar)
    }
    /// The staged range end, which IS the due date while duration is on.
    private var effectiveDate: Date { hasDuration ? durationEnd : date }
    /// The draft as a value, so day/time/zone decisions run through the
    /// tested `ScheduleDraft` helper instead of ad-hoc state math.
    private func staged() -> ScheduleDraft {
        ScheduleDraft(
            due: date, hasTime: hasTime,
            duration: hasDuration ? TaskDurationRange(start: durationStart, end: durationEnd, isAllDay: durationAllDay) : nil,
            timeZoneID: zoneID)
    }
    private func writeBack(_ draft: ScheduleDraft) {
        date = draft.due; hasTime = draft.hasTime; zoneSelection.identifier = draft.timeZoneID
        if let window = draft.duration {
            hasDuration = true
            durationStart = window.start; durationEnd = window.end; durationAllDay = window.isAllDay
        }
    }
    /// Grid days, shortcuts, and the Time row funnel through here: new days
    /// translate the whole interval, same-day writes adjust the end time.
    private func setDue(_ new: Date) {
        var draft = staged()
        draft.setDue(new, calendar: calendar)
        writeBack(draft)
        applyReminderDefault()
    }
    private func isOccurrence(_ day: Date) -> Bool {
        let start = calendar.startOfDay(for: effectiveDate), target = calendar.startOfDay(for: day)
        guard hasDate, target > start else { return false }
        if let rule = repeatDraft.customRule, rule.isValid {
            // The staged draft may have moved the due date or changed the
            // rule: the walk advances from the effective staged position,
            // mirroring what saving the draft would store.
            return rule.isOccurrence(on: target, seriesStart: effectiveDate, calendar: calendar,
                                     nominalStart: stagedNominal(draftDue: effectiveDate, draftRule: repeatDraft.customRule, task: task))
        }
        guard repeatDraft.repeatRule != .none,
              !hasEnd || target <= calendar.startOfDay(for: endDate) else { return false }
        let unchanged = task.dueDate == date && task.recurrence == repeatDraft.repeatRule
        let anchorDay = (unchanged ? task.recurrenceAnchorDay : nil) ?? calendar.component(.day, from: date)
        let anchorMonth = (unchanged ? task.recurrenceAnchorMonth : nil) ?? calendar.component(.month, from: date)
        switch repeatDraft.repeatRule {
        case .none: return false
        case .daily: return true
        case .weekdays: return (2...6).contains(calendar.component(.weekday, from: target))
        case .weekly:
            return (calendar.dateComponents([.day], from: start, to: target).day ?? 0) % 7 == 0
        case .monthly, .yearly:
            if repeatDraft.repeatRule == .yearly && calendar.component(.month, from: target) != anchorMonth { return false }
            guard let days = calendar.range(of: .day, in: .month, for: target) else { return false }
            return calendar.component(.day, from: target) == min(anchorDay, days.count)
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                shortcut("Today", symbol: "sun.max", days: 0)
                shortcut("Tomorrow", symbol: "sun.horizon", days: 1)
                shortcut("Next week", symbol: "calendar.badge.clock", days: 7)
                Button { setQuickDate(days: 0); setDue(calendar.date(bySettingHour: 18, minute: 0, second: 0, of: effectiveDate) ?? effectiveDate); hasTime = true } label: { Image(systemName: "moon.stars").frame(maxWidth: .infinity).frame(height: 30) }.help("This evening")
                Button { hasDate = false; hasTime = false; repeatDraft.repeatRule = .none; hasEnd = false; reminders = []; automaticReminder = true } label: { Image(systemName: "calendar.badge.minus").frame(maxWidth: .infinity).frame(height: 30) }.help("No date")
            }.buttonStyle(.plain).foregroundStyle(accent)
            CalendarGrid(date: dueBinding, calendar: calendar, showWeekNumbers: settings.showWeekNumbers, hasSelection: hasDate, isOccurrence: isOccurrence) { hasDate = true }
            Divider()
            row("Time", symbol: "clock", value: hasTime ? format(date, dateStyle: .none, timeStyle: .short) : "None", row: .time)
            if expanded == .time {
                HStack {
                    Button(hasTime ? "Remove time" : "Add time") { hasTime.toggle(); applyReminderDefault() }.buttonStyle(.borderless)
                    Spacer()
                    if hasTime { DatePicker("Time", selection: dueBinding, displayedComponents: .hourAndMinute).labelsHidden().fixedSize() }
                }.font(.system(size: 11)).padding(.horizontal, 8)
                if settings.enableTimeZone && hasTime {
                    Picker("Time Zone", selection: $zoneSelection.identifier) { ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) } }.font(.system(size: 11))
                }
            }
            row("Reminder", symbol: "bell", value: reminderLabel, row: .reminder).disabled(!hasDate)
            row("Duration", symbol: "hourglass", value: durationLabel, row: .duration).disabled(!hasDate)
            if expanded == .duration && hasDate {
                Toggle("All-day", isOn: durationAllDayBinding).font(.system(size: 11)).padding(.horizontal, 8)
                if durationAllDay {
                    DatePicker("Start", selection: rangeStartBinding, displayedComponents: .date).datePickerStyle(.field).font(.system(size: 11))
                    DatePicker("End", selection: rangeEndBinding, displayedComponents: .date).datePickerStyle(.field).font(.system(size: 11))
                } else {
                    DatePicker("Start", selection: rangeStartBinding, displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.field).font(.system(size: 11))
                    DatePicker("End", selection: rangeEndBinding, displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.field).font(.system(size: 11))
                }
                HStack {
                    Button(hasDuration ? "Remove Duration" : "Add Duration") { setHasDuration(!hasDuration) }.buttonStyle(.borderless)
                    Spacer()
                    if hasDuration && draftDuration == nil {
                        Text("End must not precede start.").font(.system(size: 11)).foregroundStyle(.orange)
                    }
                }.font(.system(size: 11)).padding(.horizontal, 8)
            }
            if expanded == .reminder && hasDate {
                if timedDurationEnd != nil {
                    Toggle("At the end", isOn: $remindsAtEnd)
                        .font(.system(size: 11)).padding(.horizontal, 8)
                        .accessibilityIdentifier("scheduleReminderAtEnd")
                }
                ForEach(Array(reminders.indices), id: \.self) { index in
                    HStack {
                        DatePicker("Reminder", selection: Binding(get: { reminders.indices.contains(index) ? reminders[index] : date }, set: { value in if reminders.indices.contains(index) { reminders[index] = value; automaticReminder = false } }), displayedComponents: [.date, .hourAndMinute]).labelsHidden().datePickerStyle(.field)
                        Button { reminders.remove(at: index); automaticReminder = false } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).help("Remove reminder")
                    }
                }
                HStack {
                    Button("Add reminder") { reminders.append(hasTime ? date : (calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date)); automaticReminder = false }.buttonStyle(.borderless)
                    Spacer()
                }.font(.system(size: 11)).padding(.horizontal, 8)
            }
            row("Repeat", symbol: "repeat", value: repeatLabel, row: .repeatRule).disabled(!hasDate)
            if expanded == .repeatRule && hasDate {
                if let rule = repeatDraft.customRule, rule.isValid {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rule.shortLabel(calendar: calendar)).font(.system(size: 11))
                        let preview = remainingOccurrences(rule: rule, current: effectiveDate, index: task.occurrenceIndex, calendar: calendar,
                                                                 nominal: stagedNominal(draftDue: effectiveDate, draftRule: repeatDraft.customRule, task: task))
                        ForEach(Array(preview.enumerated()), id: \.offset) { _, next in
                            Text("Then " + format(next, dateStyle: .medium, timeStyle: .none)).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        if let max = rule.maxOccurrences {
                            Text("Occurrence \(min(task.occurrenceIndex, max)) of \(max)").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("Edit Custom…") {
                                repeatDraft.openCustomSheet(seed: CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days))
                                showCustomEditor = true
                            }.buttonStyle(.borderless)
                            Button("Use Simple") { repeatDraft.dropCustom() }.buttonStyle(.borderless)
                        }.font(.system(size: 11))
                    }.padding(.horizontal, 8)
                } else {
                    Picker("Repeat", selection: $repeatDraft.repeatRule) { ForEach(RepeatRule.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden()
                        .onChange(of: repeatDraft.repeatRule) { _, value in if value != .none { repeatDraft.dropCustom() } }
                    Button("Custom…") {
                        // Opening stages a seed WITHOUT touching the
                        // committed draft: only Done commits. Cancel and
                        // dismissal leave the outer draft exactly as before.
                        let weekday = calendar.component(.weekday, from: date)
                        repeatDraft.openCustomSheet(seed: CustomRecurrence(anchor: .dueDate, interval: 1, unit: .weeks, weekdays: [weekday]))
                        showCustomEditor = true
                    }.buttonStyle(.borderless).font(.system(size: 11))
                }
            }
            if repeatDraft.repeatRule != .none && repeatDraft.customRule?.isValid != true && hasDate {
                row("End", symbol: "calendar.badge.clock", value: hasEnd ? format(endDate, dateStyle: .medium, timeStyle: .none) : "Endlessly", row: .end)
                if expanded == .end {
                    Picker("End", selection: $hasEnd) { Text("Endlessly").tag(false); Text("Until date").tag(true) }
                        .onChange(of: hasEnd) { _, enabled in if enabled && calendar.startOfDay(for: endDate) < calendar.startOfDay(for: date) { endDate = date } }
                    if hasEnd { DatePicker("Until", selection: $endDate, displayedComponents: .date).datePickerStyle(.field) }
                }
            }
            Divider()
            if saveFailed {
                Text("Could not save schedule. Your draft is kept. Retry, or reopen if the task changed.")
                    .font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("scheduleSaveError")
            }
            HStack {
                Button("Clear") { clear() }.buttonStyle(.plain)
                Spacer()
                Button("OK") { apply() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(hasDate && hasDuration && draftDuration == nil)
            }.font(.system(size: 12))
        }.padding(14).frame(width: 300).background(Color(nsColor: .textBackgroundColor))
            .sheet(isPresented: $showCustomEditor, onDismiss: {
                // All dismissal paths (Cancel, swipe-down) drop the staged
                // seed and preserve the committed draft. After Done/Clear
                // the staged value is already nil, so this is a safe no-op.
                repeatDraft.cancelCustom()
            }) {
                CustomRecurrenceEditor(rule: repeatDraft.stagedCustom ?? CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days), scheduledDate: date, calendar: calendar) { rule in
                    repeatDraft.commitCustom(rule)
                }
            }
            .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
            .onExitCommand { dismiss() }
            .onChange(of: hasTime) { _, _ in applyReminderDefault() }
            .onChange(of: hasDate) { _, _ in applyReminderDefault() }
            .onChange(of: date) { _, _ in applyReminderDefault() }
            .onChange(of: zoneID) { old, new in
                // Whole-interval wall-clock translation (due + both duration
                // endpoints) through the tested helper; the recurrence end
                // stays on its wall date.
                var draft = staged()
                draft.rezone(from: old, to: new, calendar: settings.calendar)
                writeBack(draft)
                var previous = settings.calendar; previous.timeZone = TimeZone(identifier: old) ?? .current
                let endParts = previous.dateComponents([.year, .month, .day], from: endDate)
                var next = settings.calendar; next.timeZone = TimeZone(identifier: new) ?? .current
                if let translatedEnd = next.date(from: endParts) { endDate = translatedEnd }
                applyReminderDefault()
            }
    }
    private var timedDurationEnd: Date? {
        guard hasDate, hasDuration, let window = draftDuration, !window.isAllDay else { return nil }
        return window.end
    }
    private var reminderLabel: String {
        var dates = Set(reminders)
        if remindsAtEnd, let end = timedDurationEnd { dates.insert(end) }
        guard let first = dates.first else { return "None" }
        if dates.count == 1 { return format(first, dateStyle: .medium, timeStyle: .short) }
        return "\(dates.count) reminders"
    }
    private var durationLabel: String {
        guard hasDuration else { return "None" }
        if durationAllDay {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: durationStart), to: calendar.startOfDay(for: durationEnd)).day ?? 0
            if days <= 0 { return "All day" }
            return "All day · \(days + 1) days"
        }
        let sameDay = calendar.isDate(durationStart, inSameDayAs: durationEnd)
        let startText = format(durationStart, dateStyle: sameDay ? .none : .short, timeStyle: .short)
        let endText = format(durationEnd, dateStyle: sameDay ? .none : .short, timeStyle: .short)
        return startText + " – " + endText
    }
    private var repeatLabel: String {
        if let rule = repeatDraft.customRule, rule.isValid {
            if let max = rule.maxOccurrences {
                return rule.shortLabel(calendar: calendar) + " (\(min(task.occurrenceIndex, max))/\(max))"
            }
            return rule.shortLabel(calendar: calendar)
        }
        if repeatDraft.repeatRule == .weekly { let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.setLocalizedDateFormatFromTemplate("EEEE"); return "Weekly on " + formatter.string(from: date) }
        return repeatDraft.repeatRule.label
    }
    private func row(_ title: String, symbol: String, value: String, row: Row) -> some View {
        Button {
            if row == .time, let seed = ScheduleTimeActivation.seed(hasDate: hasDate, now: Date(), calendar: calendar) {
                // Opening Time is itself an explicit date choice on an undated task.
                date = seed; hasDate = true; hasTime = true; hasDuration = false
                expanded = .time
                applyReminderDefault()
            } else {
                expanded = expanded == row ? nil : row
            }
        } label: {
            HStack { Image(systemName: symbol).frame(width: 18); Text(title); Spacer(); Text(value).foregroundStyle(.secondary).lineLimit(1); Image(systemName: expanded == row ? "chevron.up" : "chevron.right").font(.system(size: 9)) }.contentShape(Rectangle()).padding(.vertical, 5)
        }.buttonStyle(.plain).font(.system(size: 12))
    }
    private func shortcut(_ title: String, symbol: String, days: Int) -> some View {
        Button { setQuickDate(days: days) } label: { Image(systemName: symbol).frame(maxWidth: .infinity).frame(height: 30) }.help(title).accessibilityLabel(title)
    }
    /// Bindings route every staged write through `ScheduleDraft` so the range
    /// end stays the due date and day edits translate the whole interval.
    private var dueBinding: Binding<Date> {
        Binding(get: { hasDuration ? durationEnd : date }, set: { setDue($0) })
    }
    private var rangeStartBinding: Binding<Date> {
        Binding(get: { durationStart }, set: {
            var draft = staged()
            draft.setRangeStart($0, calendar: calendar)
            writeBack(draft)
            applyReminderDefault()
        })
    }
    private var rangeEndBinding: Binding<Date> {
        Binding(get: { durationEnd }, set: {
            var draft = staged()
            draft.setRangeEnd($0, calendar: calendar)
            writeBack(draft)
            applyReminderDefault()
        })
    }
    private var durationAllDayBinding: Binding<Bool> {
        Binding(get: { durationAllDay }, set: {
            var draft = staged()
            draft.setAllDay($0, calendar: calendar)
            writeBack(draft)
            applyReminderDefault()
        })
    }
    private func setHasDuration(_ enabled: Bool) {
        if enabled {
            var draft = staged()
            draft.enableDuration(defaultMinutes: max(settings.defaultDurationMinutes, 0), calendar: calendar)
            writeBack(draft)
        } else {
            var draft = staged()
            draft.removeDuration()
            // removeDuration keeps the end as the due date; duration states
            // below are now unused until re-enabled.
            date = draft.due
            hasDuration = false
        }
        applyReminderDefault()
    }
    private func setQuickDate(days: Int) {
        let day = days == 7 ? calendar.dateInterval(of: .weekOfYear, for: Date())!.end : calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date()))!
        let stamped = hasTime ? calendar.date(bySettingHour: calendar.component(.hour, from: effectiveDate), minute: calendar.component(.minute, from: effectiveDate), second: 0, of: day)! : day
        setDue(stamped)
        hasDate = true
    }
    private func clear() {
        var updated = task; updated.dueDate = nil; updated.hasDueTime = false; updated.reminderDates = []; updated.reminderFollowsSchedule = nil; updated.endReminderEnabled = false; updated.recurrence = .none; updated.recurrenceEndDate = nil; updated.recurrenceAnchorDay = nil; updated.recurrenceAnchorMonth = nil; updated.customRecurrence = nil; updated.occurrenceIndex = 1; updated.restartCustomSeries(ruleChangedFrom: task.customRecurrence); updated.scheduledDuration = nil; updated.timeZoneID = nil; submit(updated)
    }
    private func apply() {
        // Custom and legacy repeats stay mutually exclusive: a valid custom
        // rule clears the enum, a legacy pick clears the rule.
        let custom = hasDate ? repeatDraft.customRule.flatMap({ $0.isValid ? $0 : nil }) : nil
        var updated = task
        // Range end is the due date; a staged window decides timed/all-day.
        let timed = hasDate && (hasDuration ? !durationAllDay : hasTime)
        let end = hasDuration ? durationEnd : date
        updated.dueDate = hasDate ? (timed ? end : calendar.startOfDay(for: end)) : nil
        updated.hasDueTime = timed
        updated.recurrence = hasDate && custom == nil ? repeatDraft.repeatRule : .none
        updated.customRecurrence = custom
        // Plain date edits never restart the series; only a rule change
        // does (index back to 1, nominal back to the new series start).
        updated.restartCustomSeries(ruleChangedFrom: task.customRecurrence)
        updated.recurrenceEndDate = hasDate && custom == nil && repeatDraft.repeatRule != .none && hasEnd ? calendar.startOfDay(for: endDate) : nil
        updated.scheduledDuration = hasDate ? draftDuration : nil
        updated.reminderDates = hasDate ? reminders : []
        updated.endReminderEnabled = remindsAtEnd && timedDurationEnd != nil
        updated.reminderFollowsSchedule = hasDate ? automaticReminder : nil
        updated.timeZoneID = hasDate && (timed || settings.enableTimeZone || task.timeZoneID != nil) ? zoneSelection.storedIdentifier : nil
        if task.dueDate != updated.dueDate || task.recurrence != updated.recurrence { updated.recurrenceAnchorDay = nil; updated.recurrenceAnchorMonth = nil }
        submit(updated)
    }
    private func submit(_ candidate: TaskItem) {
        guard save(candidate, task) else { saveFailed = true; return }
        saveFailed = false
        dismiss()
    }
    private func format(_ value: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.dateStyle = dateStyle; formatter.timeStyle = timeStyle
        return formatter.string(from: value)
    }
    private func applyReminderDefault() {
        // Defaults follow the effective range endpoint (the due date), so a
        // duration end or an all-day switch re-anchors them; manual edits set
        // automaticReminder = false and stop this.
        guard hasDate, automaticReminder else { return }
        let timed = hasDuration ? !durationAllDay : hasTime
        reminders = TaskStore.defaultReminderDates(due: effectiveDate, hasTime: timed, settings: settings, calendar: calendar)
    }
}
