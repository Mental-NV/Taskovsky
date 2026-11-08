import SwiftUI
import TaskovskyCore

/// Native editor for `CustomRecurrence`: anchor, cadence, weekday/month/year
/// selectors, specific dates, and ending — with a live occurrence preview and
/// the invalid-rule reason inline. Returns a valid rule (or nil when the user
/// clears it) through `save`; selectors follow engine precedence (an "On the"
/// ordinal beats "Each" day lists, workday beats both when set).
struct CustomRecurrenceEditor: View {
    @Environment(\.dismiss) private var dismiss
    let scheduledDate: Date
    let calendar: Calendar
    let save: (CustomRecurrence?) -> Void
    @State private var anchor: RecurrenceAnchor
    @State private var unit: RecurrenceUnit
    @State private var interval: Int
    @State private var weekdays: Set<Int>
    @State private var monthMode: MonthMode
    @State private var monthDaysText: String
    @State private var includesLastDay: Bool
    @State private var ordinalSlot: Int // 0 = none, 1...5 = nth, 6 = last
    @State private var ordinalWeekday: Int
    @State private var workday: WorkdayPosition?
    @State private var yearMonth: Int? // nil = scheduled month
    @State private var yearMonthDayText: String
    @State private var skipWeekends: Bool
    @State private var specificDates: [Date]
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var hasMaxCount: Bool
    @State private var maxCount: Int
    @State private var newSpecificDate = Date()
    private enum MonthMode { case each, onThe, workday }

    init(rule: CustomRecurrence, scheduledDate: Date, calendar: Calendar, save: @escaping (CustomRecurrence?) -> Void) {
        self.scheduledDate = scheduledDate; self.calendar = calendar; self.save = save
        _anchor = State(initialValue: rule.anchor)
        _unit = State(initialValue: rule.unit)
        _interval = State(initialValue: min(max(rule.interval, 1), 999))
        _weekdays = State(initialValue: Set((rule.weekdays ?? []).filter { (1...7).contains($0) }))
        let hasOrdinal = rule.ordinalWeekday?.isValid == true
        _monthMode = State(initialValue: rule.workday != nil ? .workday : hasOrdinal ? .onThe : .each)
        _monthDaysText = State(initialValue: (rule.monthDays ?? []).filter { (1...31).contains($0) }.sorted().map(String.init).joined(separator: ", "))
        _includesLastDay = State(initialValue: rule.includesLastDayOfMonth)
        _ordinalSlot = State(initialValue: rule.ordinalWeekday.map { $0.ordinal == -1 ? 6 : $0.ordinal } ?? 0)
        _ordinalWeekday = State(initialValue: rule.ordinalWeekday?.weekday ?? calendar.component(.weekday, from: scheduledDate))
        _workday = State(initialValue: rule.workday)
        _yearMonth = State(initialValue: rule.yearMonth)
        _yearMonthDayText = State(initialValue: rule.yearMonthDay.map(String.init) ?? "")
        _skipWeekends = State(initialValue: rule.skipWeekends)
        _specificDates = State(initialValue: (rule.specificDates ?? []).sorted())
        _hasEndDate = State(initialValue: rule.endDate != nil)
        _endDate = State(initialValue: rule.endDate ?? scheduledDate)
        _hasMaxCount = State(initialValue: rule.maxOccurrences != nil)
        _maxCount = State(initialValue: min(max(rule.maxOccurrences ?? 10, 2), 999))
    }

    /// The draft as a rule, or nil while it is malformed (Done stays disabled).
    private var draft: CustomRecurrence? {
        // Strict parse lives in TaskovskyCore (tested): bogus tokens
        // invalidate the draft instead of being silently dropped.
        guard let monthDays = parseMonthDayList(monthDaysText) else { return nil }
        let yearDay = yearMonthDayText.trimmingCharacters(in: .whitespaces)
        let yearMonthDay: Int? = yearDay.isEmpty ? nil : Int(yearDay)
        if !yearDay.isEmpty, yearMonthDay.map({ (1...31).contains($0) }) != true { return nil }
        var rule = CustomRecurrence(
            anchor: anchor, interval: min(max(interval, 1), CustomRecurrence.maximumInterval), unit: unit,
            weekdays: unit == .weeks ? weekdays.sorted() : nil,
            monthDays: unit == .months && monthMode == .each && !monthDays.isEmpty ? monthDays : nil,
            includesLastDayOfMonth: unit == .months && monthMode == .each && includesLastDay,
            ordinalWeekday: (unit == .months && monthMode == .onThe) || unit == .years ? ordinalValue : nil,
            workday: unit == .months && monthMode == .workday ? (workday ?? .first) : nil,
            yearMonth: unit == .years ? yearMonth : nil,
            yearMonthDay: unit == .years ? yearMonthDay : nil,
            skipWeekends: skipWeekends,
            specificDates: specificDates.isEmpty ? nil : specificDates,
            endDate: hasEndDate ? calendar.startOfDay(for: endDate) : nil,
            maxOccurrences: hasMaxCount ? min(max(maxCount, 2), 999_999) : nil)
        // Bare monthly falls back to the scheduled day, so an empty "Each"
        // list is still a valid rule.
        if rule.unit == .months, rule.monthDays == nil, !rule.includesLastDayOfMonth, rule.ordinalWeekday == nil, rule.workday == nil {
            rule.monthDays = nil
        }
        return rule.isValid ? rule : nil
    }

    private var ordinalValue: OrdinalWeekday? {
        guard ordinalSlot != 0 else { return nil }
        let ordinal = ordinalSlot == 6 ? -1 : ordinalSlot
        let value = OrdinalWeekday(ordinal: ordinal, weekday: ordinalWeekday)
        return value.isValid ? value : nil
    }

    private var weekdaySymbols: [String] {
        // Sunday == 1 through Saturday == 7, matching engine numbering.
        (1...7).map { calendar.shortWeekdaySymbols[$0 - 1] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom Repeat").font(.headline)
            Picker("Anchor", selection: $anchor) {
                Text("By due dates").tag(RecurrenceAnchor.dueDate)
                Text("By completion date").tag(RecurrenceAnchor.completionDate)
            }.pickerStyle(.segmented)
            .accessibilityLabel("Repeat anchor")
            HStack {
                Picker("Unit", selection: $unit) {
                    Text("Day").tag(RecurrenceUnit.days); Text("Week").tag(RecurrenceUnit.weeks)
                    Text("Month").tag(RecurrenceUnit.months); Text("Year").tag(RecurrenceUnit.years)
                }.pickerStyle(.segmented).labelsHidden()
                Stepper("Every \(interval)", value: $interval, in: 1...999)
                    .font(.system(size: 11)).frame(width: 120)
            }.accessibilityElement(children: .contain)
            if unit == .weeks {
                weekdayChips
            }
            if unit == .months {
                Picker("Month pattern", selection: $monthMode) {
                    Text("Each").tag(MonthMode.each); Text("On the").tag(MonthMode.onThe); Text("Workday").tag(MonthMode.workday)
                }.pickerStyle(.segmented)
                .accessibilityLabel("Month pattern")
                if monthMode == .each {
                    TextField("Days, e.g. 1, 15 (blank = scheduled day)", text: $monthDaysText)
                        .textFieldStyle(.roundedBorder).font(.system(size: 11))
                    Toggle("Include last day of month", isOn: $includesLastDay).font(.system(size: 11))
                } else if monthMode == .onThe {
                    ordinalPickers
                    Text("A 5th weekday that does not exist is skipped that month.").font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                    Picker("Workday", selection: Binding(get: { workday ?? .first }, set: { workday = $0 })) {
                        Text("First").tag(WorkdayPosition.first); Text("Last").tag(WorkdayPosition.last)
                    }.pickerStyle(.segmented)
                    .accessibilityLabel("Workday position")
                }
            }
            if unit == .years {
                HStack {
                    Picker("Month", selection: $yearMonth) {
                        Text("Scheduled month").tag(nil as Int?)
                        ForEach(1...12, id: \.self) { month in Text(calendar.shortMonthSymbols[month - 1]).tag(month as Int?) }
                    }.frame(width: 150)
                    TextField("Day (blank = scheduled)", text: $yearMonthDayText).textFieldStyle(.roundedBorder).font(.system(size: 11)).frame(width: 150)
                }.font(.system(size: 11))
                ordinalPickers
                Text("“On the” beats the day above when both are set.").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Toggle("Skip weekends (roll to Monday)", isOn: $skipWeekends).font(.system(size: 11))
            Divider()
            specificDatesSection
            Divider()
            endingSection
            Divider()
            previewSection
            HStack {
                Button("Clear Rule", role: .destructive) { save(nil); dismiss() }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Done") { if let rule = draft { save(rule); dismiss() } }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(draft == nil)
            }.font(.system(size: 12))
        }.padding(16).frame(width: 380)
    }

    private var weekdayChips: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { day in
                weekdayChip(day)
            }
        }.accessibilityElement(children: .contain).accessibilityLabel("Weekdays")
    }

    private func weekdayChip(_ day: Int) -> some View {
        let name = weekdaySymbols[day - 1]
        let selected = weekdays.contains(day)
        return Button(name) {
            if selected { weekdays.remove(day) } else { weekdays.insert(day) }
        }
        .buttonStyle(.plain).font(.system(size: 11))
        .frame(width: 34, height: 24)
        .background(selected ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
        .accessibilityLabel(selected ? name + ", selected" : name)
    }

    private var ordinalPickers: some View {
        HStack {
            Picker("Ordinal", selection: $ordinalSlot) {
                Text("None").tag(0); Text("1st").tag(1); Text("2nd").tag(2); Text("3rd").tag(3)
                Text("4th").tag(4); Text("5th").tag(5); Text("Last").tag(6)
            }.frame(width: 110)
            Picker("Weekday", selection: $ordinalWeekday) {
                ForEach(1...7, id: \.self) { day in Text(weekdaySymbols[day - 1]).tag(day) }
            }.frame(width: 130)
        }.font(.system(size: 11))
    }

    private var specificDatesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Specific Dates").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if !specificDates.isEmpty {
                Text("Cadence above is ignored while dates are listed.").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            ForEach(Array(specificDates.enumerated()), id: \.offset) { index, date in
                HStack {
                    Text(date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11))
                    Spacer()
                    Button { specificDates.remove(at: index) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).help("Remove date")
                }
            }
            HStack {
                DatePicker("Add date", selection: $newSpecificDate, displayedComponents: [.date, .hourAndMinute]).labelsHidden().datePickerStyle(.field)
                Button("Add") {
                    if !specificDates.contains(newSpecificDate) { specificDates.append(newSpecificDate); specificDates.sort() }
                }.buttonStyle(.borderless).font(.system(size: 11))
                Spacer()
            }
        }
    }

    private var endingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ending").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Toggle("End by date", isOn: $hasEndDate).font(.system(size: 11))
            if hasEndDate {
                DatePicker("Until", selection: $endDate, displayedComponents: .date).datePickerStyle(.field).font(.system(size: 11))
            }
            Toggle("End after a count", isOn: $hasMaxCount).font(.system(size: 11))
            if hasMaxCount {
                Stepper("After \(maxCount) occurrences", value: $maxCount, in: 2...999_999).font(.system(size: 11))
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if let rule = draft {
                let dates = rule.occurrences(from: scheduledDate, limit: 6, calendar: calendar)
                if dates.isEmpty {
                    Text("No upcoming occurrences.").font(.system(size: 11)).foregroundStyle(.orange)
                } else {
                    ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                        Text("\(index + 1). " + date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11))
                    }
                }
            } else {
                Text("Pick at least one weekday for a weekly rule.").font(.system(size: 11)).foregroundStyle(.orange)
            }
        }.frame(minHeight: 60)
    }
}
