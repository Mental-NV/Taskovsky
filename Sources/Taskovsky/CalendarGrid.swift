import SwiftUI

struct CalendarGrid: View {
    @Binding var date: Date
    var calendar: Calendar
    var showWeekNumbers: Bool
    var hasSelection: Bool
    var isOccurrence: (Date) -> Bool
    var onSelect: () -> Void
    @State private var displayedMonth: Date

    init(date: Binding<Date>, calendar: Calendar, showWeekNumbers: Bool, hasSelection: Bool = true, isOccurrence: @escaping (Date) -> Bool = { _ in false }, onSelect: @escaping () -> Void = {}) {
        _date = date
        self.calendar = calendar
        self.showWeekNumbers = showWeekNumbers
        self.hasSelection = hasSelection; self.isOccurrence = isOccurrence; self.onSelect = onSelect
        _displayedMonth = State(initialValue: calendar.date(from: calendar.dateComponents([.era, .year, .month], from: date.wrappedValue)) ?? date.wrappedValue)
    }
    private var monthStart: Date { calendar.date(from: calendar.dateComponents([.era, .year, .month], from: displayedMonth)) ?? displayedMonth }
    private var firstGridDay: Date {
        let weekday = calendar.component(.weekday, from: monthStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: monthStart) ?? monthStart
    }
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain).accessibilityLabel("Previous month")
                Spacer()
                Text(format(monthStart, template: "MMMM y")).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain).accessibilityLabel("Next month")
            }.padding(.horizontal, 5).padding(.bottom, 3)
            HStack(spacing: 2) {
                if showWeekNumbers { Text("#").frame(width: 24, height: 22).accessibilityLabel("Week number") }
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in Text(symbol).frame(width: 28, height: 22) }
            }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 2) {
                    if showWeekNumbers {
                        let weekDate = day(at: row * 7)
                        Text("\(calendar.component(.weekOfYear, from: weekDate))").font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 24, height: 26)
                            .accessibilityLabel("Week \(calendar.component(.weekOfYear, from: weekDate))")
                    }
                    ForEach(0..<7, id: \.self) { column in dayButton(day(at: row * 7 + column)) }
                }
            }
        }.padding(10).frame(width: showWeekNumbers ? 260 : 234)
            .onChange(of: date) { _, new in
                displayedMonth = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: new)) ?? new
            }
    }
    private func day(at offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: firstGridDay) ?? firstGridDay }
    private func dayButton(_ day: Date) -> some View {
        let selected = hasSelection && calendar.isDate(day, inSameDayAs: date)
        let today = calendar.isDateInToday(day)
        let currentMonth = calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
        return Button { select(day) } label: {
            Text("\(calendar.component(.day, from: day))").font(.system(size: 12))
                .foregroundStyle(selected ? Color.white : currentMonth ? Color.primary : Color.secondary)
                .frame(width: 28, height: 26)
                .background { if selected { Circle().fill(Color.accentColor).frame(width: 25, height: 25) } else if isOccurrence(day) { Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 25, height: 25) } }
                .overlay { if today && !selected { Circle().stroke(Color.accentColor, lineWidth: 1).frame(width: 25, height: 25) } }
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(format(day, template: "EEEE d MMMM y"))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template); return formatter.string(from: date)
    }
    private func moveMonth(_ amount: Int) { displayedMonth = calendar.date(byAdding: .month, value: amount, to: monthStart) ?? monthStart }
    private func select(_ day: Date) {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let start = calendar.startOfDay(for: day)
        date = calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: components.second ?? 0, of: start) ?? start
        displayedMonth = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: day)) ?? day
        onSelect()
    }
}
