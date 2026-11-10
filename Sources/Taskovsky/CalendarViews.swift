import SwiftUI
import TaskovskyCore

private struct CalendarDayBoundary: View {
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        Rectangle().fill(Color.primary.opacity(0.06))
            .frame(width: 1 / max(1, displayScale))
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct CalendarHourlyView: View {
    var days: [Date]
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var create: (Date, Date, Bool) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    var selectDay: (Date) -> Void
    private let hourHeight: CGFloat = 52
    private var zones: [CalendarTimeZone] { options.visibleTimeZones(primary: calendar.timeZone) }
    private var gutter: CGFloat { 56 + CGFloat(zones.count) * 54 }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = max(60, (geometry.size.width - gutter) / CGFloat(max(1, days.count)))
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: gutter, height: 32)
                        ForEach(days, id: \.self) { day in
                            Text(CalendarText.date(day, "EEE", calendar: calendar))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                .frame(width: columnWidth, height: 32)
                        }
                    }
                    HStack(spacing: 0) {
                        Color.clear.frame(width: gutter, height: 28)
                        ForEach(days, id: \.self) { day in
                            Button { selectDay(day) } label: {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(calendar.isDateInToday(day) ? Color.white : Color.primary)
                                    .frame(width: 24, height: 24)
                                    .background(calendar.isDateInToday(day) ? CalendarAppearance.accent : .clear, in: Circle())
                                    .padding(.leading, 4)
                                    .frame(width: columnWidth, height: 28, alignment: .bottomLeading)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .overlay(alignment: .leading) { CalendarDayBoundary() }
                                .accessibilityLabel("Show " + CalendarText.date(day, "EEEE d MMMM y", calendar: calendar) + " in Day view")
                        }
                    }
                    allDayStrip(columnWidth: columnWidth)
                    Divider()
                    ScrollViewReader { reader in
                        ScrollView(.vertical) {
                            HStack(alignment: .top, spacing: 0) {
                                hourRuler
                                ForEach(days, id: \.self) { day in
                                    CalendarHourColumn(day: day, entries: entries, calendar: calendar, options: options,
                                        hourHeight: hourHeight, open: open, complete: complete, create: create,
                                        schedule: schedule, edit: edit)
                                        .frame(width: columnWidth, height: 24 * hourHeight)
                                }
                            }
                        }.onAppear { reader.scrollTo(7, anchor: .top) }
                    }
                }.frame(width: gutter + columnWidth * CGFloat(days.count))
            }
        }
    }
    private func allDayStrip(columnWidth: CGFloat) -> some View {
        let maximum = days.map { day in
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return entries.filter { $0.isAllDay && $0.start < end && $0.end > day }.count
        }.max() ?? 0
        let stripHeight = min(125, max(26, CGFloat(maximum) * 18 + 8))
        return HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(zones) { zone in
                    Text(zone.title(at: days.first ?? Date())).lineLimit(1).frame(width: 50)
                        .help(zone.identifier + " · Ruler for " + CalendarText.date(days.first ?? Date(), "MMM d", calendar: calendar))
                        .accessibilityLabel("Time zone " + zone.title(at: days.first ?? Date()) + ", " + zone.identifier)
                }
                Text(calendar.timeZone.abbreviation(for: days.first ?? Date()) ?? calendar.timeZone.identifier)
                    .help(calendar.timeZone.identifier).frame(maxWidth: .infinity)
            }.font(.system(size: 10)).foregroundStyle(.secondary).frame(width: gutter).padding(.bottom, 3)
            ForEach(days, id: \.self) { day in
                let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                CalendarAllDayCell(day: day, entries: entries.filter { $0.isAllDay && $0.start < next && $0.end > day },
                    calendar: calendar, options: options, width: columnWidth, height: stripHeight, open: open, complete: complete,
                    create: create, schedule: schedule, edit: edit)
            }
        }.frame(height: stripHeight)
    }
    private var hourRuler: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 4) {
                    ForEach(zones) { ruler in
                        var other = calendar
                        let _ = other.timeZone = TimeZone(identifier: ruler.identifier) ?? calendar.timeZone
                        let instant = CalendarDates.instant(on: days.first ?? Date(), minute: hour * 60, calendar: calendar)
                        Text(CalendarText.time(instant, calendar: other))
                            .frame(width: 50, alignment: .trailing)
                            .help(ruler.identifier + " · " + CalendarText.date(instant, "EEE MMM d HHmm", calendar: other))
                            .foregroundStyle(.tertiary)
                    }
                    Text(String(format: "%02d:00", hour)).foregroundStyle(.secondary)
                }.font(.system(size: 10)).frame(width: gutter - 8, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 8).id(hour)
            }
        }
    }
}

private struct CalendarAllDayCell: View {
    var day: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var width: CGFloat
    var height: CGFloat
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var create: (Date, Date, Bool) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    @State private var hovered = false
    @FocusState private var addFocused: Bool
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 2) {
                ForEach(entries) { entry in
                    CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar,
                        showItemIcons: options.showItemIcons, compact: true, open: open, complete: complete, edit: edit)
                        .frame(height: 16).calendarDraggable(entry)
                }
            }.padding(.horizontal, 3).padding(.top, 6).padding(.bottom, 4)
        }.frame(width: width, height: height)
        .overlay(alignment: .bottomTrailing) {
            Button { create(day, day, true) } label: {
                Image(systemName: "plus").font(.system(size: 9)).frame(width: 18, height: 18)
            }.buttonStyle(.plain).foregroundStyle(.secondary).focused($addFocused)
                .opacity(hovered || addFocused ? 1 : 0)
                .accessibilityLabel("Add all-day task " + CalendarText.date(day, "MMM d", calendar: calendar))
        }
        .contentShape(Rectangle()).onHover { hovered = $0 }
        .overlay(alignment: .leading) { CalendarDayBoundary() }
        .contextMenu { Button("Add all-day task") { create(day, day, true) } }
        .dropDestination(for: String.self) { values, _ in
            guard let id = values.compactMap(CalendarDrag.id).first else { return false }
            schedule(id, .move(start: day, allDay: true)); return true
        }
    }
}

private struct CalendarHourColumn: View {
    var day: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var hourHeight: CGFloat
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var create: (Date, Date, Bool) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    @GestureState private var selection: (Int, Int)?
    private var scale: CGFloat { hourHeight / 60 }
    private func minute(_ y: CGFloat) -> Int { CalendarDates.snappedMinute(Double(y / scale)) }
    private func instant(_ minute: Int) -> Date { CalendarDates.instant(on: day, minute: minute, calendar: calendar) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(nsColor: .textBackgroundColor)).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 5)
                        .updating($selection) { value, state, _ in state = (min(1425, minute(value.startLocation.y)), minute(value.location.y)) }
                        .onEnded { value in
                            let first = min(1425, minute(value.startLocation.y)), last = minute(value.location.y)
                            let start = min(first, last), end = max(start + 15, max(first, last))
                            create(instant(start), instant(min(1440, end)), false)
                        })
                    .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { value in
                        let start = min(1425, minute(value.location.y))
                        create(instant(start), instant(min(1440, start + 30)), false)
                    })
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5).offset(y: CGFloat(hour) * hourHeight)
                    Rectangle().fill(Color.primary.opacity(0.025)).frame(height: 0.5).offset(y: CGFloat(hour) * hourHeight + hourHeight / 2)
                }.allowsHitTesting(false)
                CalendarDayBoundary()
                if let selection {
                    let start = min(selection.0, selection.1), end = max(start + 15, max(selection.0, selection.1))
                    RoundedRectangle(cornerRadius: 4).fill(CalendarAppearance.accent.opacity(0.2))
                        .frame(width: geometry.size.width - 4, height: CGFloat(end - start) * scale)
                        .offset(x: 2, y: CGFloat(start) * scale).allowsHitTesting(false)
                }
                ForEach(CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar)) { placement in
                    let width = (geometry.size.width - 5) / CGFloat(placement.columnCount)
                    CalendarTimedBlock(placement: placement, day: day, calendar: calendar, options: options, scale: scale,
                        open: open, complete: complete, schedule: schedule, edit: edit)
                        .frame(width: max(18, width - 2))
                        .offset(x: 3 + CGFloat(placement.column) * width, y: CGFloat(placement.startMinute) * scale)
                }
                if calendar.isDateInToday(day) {
                    let parts = calendar.dateComponents([.hour, .minute], from: Date())
                    Rectangle().fill(Color.red).frame(height: 1)
                        .offset(y: CGFloat((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) * scale).allowsHitTesting(false)
                }
            }.dropDestination(for: String.self) { values, point in
                guard let id = values.compactMap(CalendarDrag.id).first else { return false }
                schedule(id, .move(start: instant(min(1425, minute(point.y))), allDay: false)); return true
            }
        }
    }
}

private struct CalendarTimedBlock: View {
    var placement: CalendarTimedPlacement
    var day: Date
    var calendar: Calendar
    var options: TaskCalendarOptions
    var scale: CGFloat
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    @GestureState private var resizeDelta: CGFloat = 0
    private var entry: CalendarEntry { placement.entry }
    private var finalSegment: Bool {
        entry.end <= (calendar.date(byAdding: .day, value: 1, to: day) ?? day)
    }
    var body: some View {
        let height = max(15, CGFloat(placement.endMinute - placement.startMinute) * scale + resizeDelta)
        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, showItemIcons: options.showItemIcons, compact: height < 40,
            open: open, complete: complete, edit: edit)
            .frame(height: height, alignment: .top).clipped()
            .calendarDraggable(entry)
            .overlay(alignment: .bottom) {
                if entry.canSchedule && finalSegment {
                    Capsule().fill(Color(hex: entry.color).opacity(0.7)).frame(width: 22, height: 3)
                        .frame(height: 9).contentShape(Rectangle())
                        .accessibilityLabel("Resize " + entry.title).help("Drag to resize in 15-minute steps, or use Schedule…")
                        .highPriorityGesture(DragGesture(minimumDistance: 3)
                            .updating($resizeDelta) { value, state, _ in state = value.translation.height }
                            .onEnded { value in
                                let minute = CalendarDates.snappedMinute(placement.endMinute + Double(value.translation.height / scale))
                                schedule(entry.taskID, .resizeEnd(CalendarDates.instant(on: day, minute: minute, calendar: calendar)))
                            })
                }
            }
    }
}

struct CalendarMonthView: View {
    var days: [Date]
    var focus: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var edit: (CalendarEntry) -> Void
    var create: (Date) -> Void
    var move: (UUID, Date, Bool) -> Void
    var body: some View {
        GeometryReader { geometry in
            let width = max(96, geometry.size.width / 7)
            let height = max(90, (geometry.size.height - 32) / CGFloat(max(1, days.count / 7)))
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { index in
                            Text(calendar.shortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                                .font(.system(size: 12)).foregroundStyle(.secondary).frame(width: width, height: 32)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: 0), count: 7), spacing: 0) {
                        ForEach(days, id: \.self) { day in
                            CalendarMonthCell(day: day, focus: focus, entries: entries, calendar: calendar, options: options,
                                height: height, open: open, complete: complete, edit: edit, create: create, move: move)
                        }
                    }
                }.frame(width: width * 7)
            }
        }
    }
}

private struct CalendarMonthCell: View {
    var day: Date
    var focus: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var height: CGFloat
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var edit: (CalendarEntry) -> Void
    var create: (Date) -> Void
    var move: (UUID, Date, Bool) -> Void
    @State private var more = false
    @State private var hovered = false
    @FocusState private var addFocused: Bool
    private var items: [CalendarEntry] {
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return entries.filter { $0.start < end && $0.end > day }
    }
    private var capacity: Int { max(1, Int((height - 55) / 23)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                if calendar.component(.day, from: day) == 1 && !calendar.isDateInToday(day) {
                    Text(CalendarText.date(day, "d MMM", calendar: calendar)).font(.system(size: 12))
                        .foregroundStyle(calendar.isDate(day, equalTo: focus, toGranularity: .month) ? Color.primary : Color.secondary)
                        .frame(height: 24).padding(.leading, 4)
                } else {
                    Text("\(calendar.component(.day, from: day))").font(.system(size: 12))
                        .foregroundStyle(calendar.isDateInToday(day) ? Color.white : calendar.isDate(day, equalTo: focus, toGranularity: .month) ? Color.primary : Color.secondary)
                        .frame(width: 24, height: 24)
                        .background(calendar.isDateInToday(day) ? CalendarAppearance.accent : .clear, in: Circle())
                }
                Spacer(minLength: 0)
                Button { create(day) } label: { Image(systemName: "plus").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .focused($addFocused).opacity(hovered || addFocused ? 1 : 0)
                    .accessibilityLabel("Add task " + CalendarText.date(day, "MMM d", calendar: calendar))
            }
            ForEach(Array(items.prefix(capacity))) { entry in card(entry) }
            if items.count > capacity {
                Button("+\(items.count - capacity) more") { more = true }.buttonStyle(.plain)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .sheet(isPresented: $more) {
                        VStack(spacing: 12) {
                            HStack {
                                Text(CalendarText.date(day, "EEEE MMM d", calendar: calendar)).font(.headline)
                                Spacer()
                                Button("Done") { more = false }.keyboardShortcut(.cancelAction)
                            }
                            ScrollView { VStack(spacing: 5) { ForEach(items) { card($0) } } }
                        }.padding(16).frame(width: 300, height: min(420, CGFloat(items.count) * 30 + 80))
                    }
            }
            Spacer(minLength: 0)
        }.padding(3).frame(maxWidth: .infinity).frame(height: height)
            .background(calendar.isDateInToday(day) ? CalendarAppearance.accent.opacity(0.04) : Color.clear)
            .overlay { Rectangle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5).allowsHitTesting(false) }
            .contentShape(Rectangle()).onHover { hovered = $0 }.onTapGesture(count: 2) { create(day) }
            .dropDestination(for: String.self) { values, _ in
                guard let id = values.compactMap(CalendarDrag.id).first else { return false }
                move(id, day, false); return true
            }
    }
    private func card(_ entry: CalendarEntry) -> some View {
        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, showItemIcons: options.showItemIcons, compact: true,
            open: open, complete: complete, edit: edit).calendarDraggable(entry)
    }
}

struct CalendarYearView: View {
    var focus: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var style: CalendarYearStyle
    var selectMonth: (Date) -> Void
    var select: (Date) -> Void
    var body: some View {
        GeometryReader { geometry in
            let start = calendar.dateInterval(of: .year, for: focus)?.start ?? focus
            let months = (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
            let days = CalendarDates.visibleDays(focus: focus, mode: .year, options: .init(), calendar: calendar)
            let counts = CalendarDayCounts.count(entries, days: days, calendar: calendar)
            let ideal = Int(sqrt(12 * geometry.size.width / max(1, geometry.size.height)).rounded())
            let columns = max(1, min(4, ideal, max(1, Int(geometry.size.width / 150))))
            let rows = (12 + columns - 1) / columns
            let rowHeight = max(150, geometry.size.height / CGFloat(rows))
            let outerPadding = geometry.size.width * 0.015
            let width = (geometry.size.width - outerPadding * 2) / CGFloat(columns)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columns), spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        CalendarYearMonth(month: month, counts: counts, calendar: calendar, style: style,
                            width: width, height: rowHeight, selectMonth: selectMonth, select: select)
                    }
                }.padding(.horizontal, outerPadding)
            }.accessibilityLabel(style == .heatmap ? "Year heatmap. Darker dates contain more visible items." : "Year calendar. Dots mark dates with visible items.")
        }
    }
}

private struct CalendarYearMonth: View {
    var month: Date
    var counts: [Date: Int]
    var calendar: Calendar
    var style: CalendarYearStyle
    var width: CGFloat
    var height: CGFloat
    var selectMonth: (Date) -> Void
    var select: (Date) -> Void
    private var days: [Date] {
        CalendarDates.days(from: CalendarDates.weekStart(month, calendar: calendar), count: 42, calendar: calendar)
    }
    private var dateFont: CGFloat { max(9, min(14, height * 0.042)) }
    var body: some View {
        VStack(spacing: 0) {
            Button { selectMonth(month) } label: { Text(CalendarText.date(month, "MMMM", calendar: calendar))
                .font(.system(size: max(11, min(20, height * 0.06)), weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, width * 0.1)
                .frame(height: height * 0.16).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("Show " + CalendarText.date(month, "MMMM y", calendar: calendar) + " in Month view")
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + offset) % 7])
                        .font(.system(size: dateFont)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }.frame(height: height * 0.12).padding(.horizontal, width * 0.063)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let today = calendar.isDateInToday(day)
                    let count = counts[day, default: 0]
                    Button { select(day) } label: {
                        ZStack(alignment: .bottom) {
                            Text("\(calendar.component(.day, from: day))").font(.system(size: dateFont))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            if style == .standard && count > 0 && !today {
                                Circle().fill(CalendarAppearance.accent).frame(width: 3, height: 3).padding(.bottom, 1)
                            }
                        }.frame(height: height * 0.096)
                            .foregroundStyle(today ? Color.white : calendar.isDate(day, equalTo: month, toGranularity: .month) ? Color.primary : Color.secondary.opacity(0.5))
                            .background {
                                if today { CalendarAppearance.accent }
                                else if style == .heatmap && count > 0 { CalendarAppearance.accent.opacity(min(0.7, 0.1 + Double(count) * 0.1)) }
                            }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(CalendarText.date(day, "EEEE d MMMM y", calendar: calendar) + ", \(count) items")
                }
            }.padding(.horizontal, width * 0.063).padding(.top, height * 0.025)
            Spacer(minLength: 0)
        }.frame(height: height)
    }
}

struct CalendarAgendaView: View {
    var days: [Date]
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var open: (UUID) -> Void
    var complete: (UUID) -> Void
    var edit: (CalendarEntry) -> Void
    var create: (Date) -> Void
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(days, id: \.self) { day in
                    let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                    let items = entries.filter { $0.start < end && $0.end > day }
                    if !items.isEmpty || day == days.first {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(CalendarText.date(day, "EEEE MMMM d", calendar: calendar)).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(calendar.isDateInToday(day) ? CalendarAppearance.accent : .primary)
                                Spacer()
                                Button { create(day) } label: { Image(systemName: "plus") }
                                    .buttonStyle(.plain).accessibilityLabel("Add task " + CalendarText.date(day, "MMM d", calendar: calendar))
                            }
                            if items.isEmpty { Text("No scheduled tasks").font(.system(size: 12)).foregroundStyle(.secondary) }
                            ForEach(items) { entry in
                                CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, showItemIcons: options.showItemIcons,
                                    open: open, complete: complete, edit: edit).fixedSize(horizontal: false, vertical: true).calendarDraggable(entry)
                            }
                        }
                    }
                }
            }.padding(22)
        }
    }
}
