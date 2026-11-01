import SwiftUI
import TaskovskyCore

struct ScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    let settings: AppSettings
    let save: (TaskItem) -> Void
    @State private var date: Date
    @State private var hasDate: Bool
    @State private var hasTime: Bool
    @State private var repeatRule: RepeatRule
    @State private var endDate: Date
    @State private var hasEnd: Bool
    @State private var reminders: [Date]
    @State private var zoneID: String
    @State private var automaticReminder = true
    @State private var expanded: Row?
    private enum Row { case time, reminder, repeatRule, end }
    private var calendar: Calendar { var cal = settings.calendar; cal.timeZone = TimeZone(identifier: zoneID) ?? .current; return cal }

    init(task: TaskItem, settings: AppSettings, save: @escaping (TaskItem) -> Void) {
        self.task = task; self.settings = settings; self.save = save
        _zoneID = State(initialValue: task.timeZoneID ?? TimeZone.current.identifier)
        _date = State(initialValue: task.dueDate ?? Calendar.current.startOfDay(for: Date()))
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasTime = State(initialValue: task.hasDueTime)
        _repeatRule = State(initialValue: task.recurrence)
        _hasEnd = State(initialValue: task.recurrenceEndDate != nil)
        _endDate = State(initialValue: task.recurrenceEndDate ?? task.dueDate ?? Date())
        _reminders = State(initialValue: task.reminderDates)
        _automaticReminder = State(initialValue: TaskStore.usesDefaultReminder(task, settings: settings))
    }
    private func isOccurrence(_ day: Date) -> Bool {
        let start = calendar.startOfDay(for: date), target = calendar.startOfDay(for: day)
        guard hasDate, repeatRule != .none, target > start,
              !hasEnd || target <= calendar.startOfDay(for: endDate) else { return false }
        let unchanged = task.dueDate == date && task.recurrence == repeatRule
        let anchorDay = (unchanged ? task.recurrenceAnchorDay : nil) ?? calendar.component(.day, from: date)
        let anchorMonth = (unchanged ? task.recurrenceAnchorMonth : nil) ?? calendar.component(.month, from: date)
        switch repeatRule {
        case .none: return false
        case .daily: return true
        case .weekdays: return (2...6).contains(calendar.component(.weekday, from: target))
        case .weekly:
            return (calendar.dateComponents([.day], from: start, to: target).day ?? 0) % 7 == 0
        case .monthly, .yearly:
            if repeatRule == .yearly && calendar.component(.month, from: target) != anchorMonth { return false }
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
                Button { setQuickDate(days: 0); date = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date; hasTime = true } label: { Image(systemName: "moon.stars").frame(maxWidth: .infinity).frame(height: 30) }.help("This evening")
                Button { hasDate = false; hasTime = false; repeatRule = .none; hasEnd = false; reminders = []; automaticReminder = true } label: { Image(systemName: "calendar.badge.minus").frame(maxWidth: .infinity).frame(height: 30) }.help("No date")
            }.buttonStyle(.plain).foregroundStyle(accent)
            CalendarGrid(date: $date, calendar: calendar, showWeekNumbers: settings.showWeekNumbers, hasSelection: hasDate, isOccurrence: isOccurrence) { hasDate = true }
            Divider()
            row("Time", symbol: "clock", value: hasTime ? format(date, dateStyle: .none, timeStyle: .short) : "None", row: .time).disabled(!hasDate)
            if expanded == .time {
                HStack {
                    Button(hasTime ? "Remove time" : "Add time") { hasTime.toggle() }.buttonStyle(.borderless)
                    Spacer()
                    if hasTime { DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute).labelsHidden().fixedSize() }
                }.font(.system(size: 11)).padding(.horizontal, 8)
                if settings.enableTimeZone && hasTime {
                    Picker("Time Zone", selection: $zoneID) { ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) } }.font(.system(size: 11))
                }
            }
            row("Reminder", symbol: "bell", value: reminderLabel, row: .reminder).disabled(!hasDate)
            if expanded == .reminder && hasDate {
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
                Picker("Repeat", selection: $repeatRule) { ForEach(RepeatRule.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden()
            }
            if repeatRule != .none && hasDate {
                row("End", symbol: "calendar.badge.clock", value: hasEnd ? format(endDate, dateStyle: .medium, timeStyle: .none) : "Endlessly", row: .end)
                if expanded == .end {
                    Picker("End", selection: $hasEnd) { Text("Endlessly").tag(false); Text("Until date").tag(true) }
                        .onChange(of: hasEnd) { _, enabled in if enabled && calendar.startOfDay(for: endDate) < calendar.startOfDay(for: date) { endDate = date } }
                    if hasEnd { DatePicker("Until", selection: $endDate, displayedComponents: .date).datePickerStyle(.field) }
                }
            }
            Divider()
            HStack {
                Button("Clear") { clear() }.buttonStyle(.plain)
                Spacer()
                Button("OK") { apply() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }.font(.system(size: 12))
        }.padding(14).frame(width: 300).background(Color(nsColor: .textBackgroundColor))
            .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
            .onExitCommand { dismiss() }
            .onChange(of: hasTime) { _, _ in applyReminderDefault() }
            .onChange(of: hasDate) { _, _ in applyReminderDefault() }
            .onChange(of: date) { _, _ in applyReminderDefault() }
            .onChange(of: zoneID) { old, new in
                var previous = settings.calendar; previous.timeZone = TimeZone(identifier: old) ?? .current
                let parts = previous.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                let endParts = previous.dateComponents([.year, .month, .day], from: endDate)
                var next = settings.calendar; next.timeZone = TimeZone(identifier: new) ?? .current
                if let translated = next.date(from: parts) { date = translated }
                if let translatedEnd = next.date(from: endParts) { endDate = translatedEnd }
            }
    }
    private var reminderLabel: String {
        if reminders.isEmpty { return "None" }
        if reminders.count == 1 { return format(reminders[0], dateStyle: .medium, timeStyle: .short) }
        return "\(reminders.count) reminders"
    }
    private var repeatLabel: String {
        if repeatRule == .weekly { let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.setLocalizedDateFormatFromTemplate("EEEE"); return "Weekly on " + formatter.string(from: date) }
        return repeatRule.label
    }
    private func row(_ title: String, symbol: String, value: String, row: Row) -> some View {
        Button { expanded = expanded == row ? nil : row } label: {
            HStack { Image(systemName: symbol).frame(width: 18); Text(title); Spacer(); Text(value).foregroundStyle(.secondary).lineLimit(1); Image(systemName: expanded == row ? "chevron.up" : "chevron.right").font(.system(size: 9)) }.contentShape(Rectangle()).padding(.vertical, 5)
        }.buttonStyle(.plain).font(.system(size: 12))
    }
    private func shortcut(_ title: String, symbol: String, days: Int) -> some View {
        Button { setQuickDate(days: days) } label: { Image(systemName: symbol).frame(maxWidth: .infinity).frame(height: 30) }.help(title).accessibilityLabel(title)
    }
    private func setQuickDate(days: Int) {
        let day = days == 7 ? calendar.dateInterval(of: .weekOfYear, for: Date())!.end : calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date()))!
        date = hasTime ? calendar.date(bySettingHour: calendar.component(.hour, from: date), minute: calendar.component(.minute, from: date), second: 0, of: day)! : day
        hasDate = true
    }
    private func clear() {
        var updated = task; updated.dueDate = nil; updated.hasDueTime = false; updated.reminderDates = []; updated.reminderFollowsSchedule = nil; updated.recurrence = .none; updated.recurrenceEndDate = nil; updated.recurrenceAnchorDay = nil; updated.recurrenceAnchorMonth = nil; updated.timeZoneID = nil; save(updated); dismiss()
    }
    private func apply() {
        var updated = task
        updated.dueDate = hasDate ? (hasTime ? date : calendar.startOfDay(for: date)) : nil
        updated.hasDueTime = hasDate && hasTime
        updated.recurrence = hasDate ? repeatRule : .none
        updated.recurrenceEndDate = hasDate && repeatRule != .none && hasEnd ? calendar.startOfDay(for: endDate) : nil
        updated.reminderDates = hasDate ? reminders : []
        updated.reminderFollowsSchedule = hasDate ? automaticReminder : nil
        updated.timeZoneID = hasDate && (hasTime || settings.enableTimeZone || task.timeZoneID != nil) ? zoneID : nil
        if task.dueDate != updated.dueDate || task.recurrence != updated.recurrence { updated.recurrenceAnchorDay = nil; updated.recurrenceAnchorMonth = nil }
        save(updated); dismiss()
    }
    private func format(_ value: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.dateStyle = dateStyle; formatter.timeStyle = timeStyle
        return formatter.string(from: value)
    }
    private func applyReminderDefault() {
        guard hasDate, automaticReminder else { return }
        reminders = TaskStore.defaultReminderDates(due: date, hasTime: hasTime, settings: settings, calendar: calendar)
    }
}
