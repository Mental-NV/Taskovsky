import SwiftUI
import TaskovskyDomain

struct MobileCalendarPreview: View {
    let data: WorkspaceData
    let calendar: Calendar
    let today: Date
    @Binding var focus: Date
    @Binding var options: TaskCalendarOptions
    let open: (UUID) -> Void
    var body: some View {
        let days = CalendarDates.visibleDays(focus: focus, mode: options.mode, options: options, calendar: calendar)
        let result = CalendarDates.interval(for: days, calendar: calendar).map {
            TaskCalendarProjection.project(data: data, range: $0, options: options, calendar: calendar).entries
        } ?? []
        return MobileCalendarContent(calendar: calendar, today: today, days: days, entries: result,
                                     focus: $focus, options: $options, open: open)
    }
}

/// Projection is computed once per body update, rather than cached from a
/// Binding in init (which can remain stale when only that binding changes).
private struct MobileCalendarContent: View {
    let calendar: Calendar
    let today: Date
    let days: [Date]
    let entries: [CalendarEntry]
    @Binding var focus: Date
    @Binding var options: TaskCalendarOptions
    let open: (UUID) -> Void
    @ScaledMetric(relativeTo: .caption2) private var allDayRowHeight = 17.0
    private func entries(on day: Date) -> [CalendarEntry] {
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        return entries.filter { $0.start < next && ($0.end > day || calendar.isDate($0.start, inSameDayAs: day)) }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { focus = CalendarDates.navigate(focus, direction: -1, mode: options.mode, options: options, calendar: calendar) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous Calendar period")
                Spacer(); Text(options.mode.title).font(.subheadline)
                Button("Today") { focus = today }.frame(minHeight: 44)
                Spacer()
                Button { focus = CalendarDates.navigate(focus, direction: 1, mode: options.mode, options: options, calendar: calendar) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Next Calendar period")
            }.padding(.horizontal, 16)
            if options.mode.isHourly { hourly }
            else if options.mode == .year { year }
            else if options.mode == .agenda { agenda }
            else { month(days) }
        }.buttonStyle(.plain)
    }
    private func card(_ entry: CalendarEntry) -> some View {
        Button { open(entry.taskID) } label: {
            HStack(spacing: 3) {
                Rectangle().fill(Color.blue).frame(width: 2)
                Text(entry.title).font(.caption2).lineLimit(1).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }.frame(minHeight: 17).background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
        }.accessibilityLabel(entry.title + (entry.isProjected ? ", recurring preview" : ""))
    }
    private var hourly: some View {
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0, entries(on: $0)) })
        let rowCount = byDay.values.map { $0.filter(\.isAllDay).count }.max() ?? 0
        let allDayHeight = max(36, Double(rowCount) * (allDayRowHeight + 2))
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Text(calendar.timeZone.abbreviation() ?? "").font(.caption2).frame(height: 52 + allDayHeight)
                    ForEach(0..<24) { hour in Text(String(format: "%02d", hour)).font(.caption2).foregroundStyle(.secondary).frame(width: 42, height: 52, alignment: .top) }
                }
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 0) {
                        Button { focus = day; options.mode = .day } label: {
                            VStack(spacing: 6) { Text(day.formatted(.dateTime.weekday(.narrow))).foregroundStyle(.secondary); Text("\(calendar.component(.day, from: day))").fontWeight(.semibold) }.font(.caption).frame(height: 52)
                        }.accessibilityLabel("Show " + day.formatted(date: .complete, time: .omitted) + " in Day view")
                        VStack(spacing: 2) {
                            ForEach((byDay[day] ?? []).filter(\.isAllDay)) { card($0).frame(height: allDayRowHeight) }
                        }.frame(height: allDayHeight, alignment: .top)
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) { ForEach(0..<24) { _ in Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5); Color.clear.frame(height: 51.5) } }
                            ForEach((byDay[day] ?? []).filter { !$0.isAllDay }) { entry in
                                let minute = entry.start < day ? 0 : Double(calendar.component(.hour, from: entry.start) * 60 + calendar.component(.minute, from: entry.start))
                                card(entry).frame(height: max(18, min(entry.end.timeIntervalSince(entry.start) / 60, 1_440 - minute) / 60 * 52)).offset(y: minute / 60 * 52)
                            }
                        }.frame(height: 1_248)
                    }.frame(width: days.count == 1 ? 300 : 64).overlay(alignment: .leading) { Rectangle().fill(.primary.opacity(0.06)).frame(width: 0.5) }
                }
            }.padding(.bottom, 100)
        }.background(Color(uiColor: .systemBackground))
    }
    private func month(_ visible: [Date]) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(visible, id: \.self) { day in
                    let items = entries(on: day)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(calendar.component(.day, from: day))").font(.caption).padding(.bottom, 3)
                        ForEach(items.prefix(2)) { card($0) }
                        if items.count > 2 {
                            Button("+\(items.count - 2)") { focus = day; options.mode = .day }
                                .font(.caption2).frame(maxWidth: .infinity).frame(minHeight: 44)
                                .accessibilityLabel("\(items.count - 2) more items, open Day")
                        }
                        Spacer(minLength: 0)
                    }.padding(3).frame(minHeight: 84).frame(maxWidth: .infinity, alignment: .topLeading).background(Color(uiColor: .systemBackground))
                }
            }.padding(.horizontal, 8)
            Color.clear.frame(height: 100)
        }
    }
    private var year: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 20) {
                ForEach(1...12, id: \.self) { number in
                    let first = calendar.date(from: DateComponents(year: calendar.component(.year, from: focus), month: number, day: 1))!
                    VStack(spacing: 5) {
                        Button { focus = first; options.mode = .month } label: { Text(first.formatted(.dateTime.month(.abbreviated))).font(.subheadline.bold()).frame(minHeight: 44) }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
                            ForEach(CalendarDates.days(from: CalendarDates.weekStart(first, calendar: calendar), count: 42, calendar: calendar), id: \.self) { day in
                                Button { focus = day; options.mode = .week } label: {
                                    Text("\(calendar.component(.day, from: day))").font(.system(size: 9)).foregroundStyle(calendar.component(.month, from: day) == number ? Color.primary : Color.secondary.opacity(0.4)).frame(minHeight: 16).background(entries(on: day).isEmpty ? Color.clear : Color.blue.opacity(0.17), in: RoundedRectangle(cornerRadius: 2))
                                }.accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", open Week")
                            }
                        }
                    }
                }
            }.padding(.horizontal, 16)
            Color.clear.frame(height: 100)
        }
    }
    private var agenda: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(days, id: \.self) { day in
                    let items = entries(on: day)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.headline)
                            ForEach(items) { card($0).frame(minHeight: 44) }
                        }.padding(12).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }.padding(.horizontal, 16)
            Color.clear.frame(height: 100)
        }
    }
}
