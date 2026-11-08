import SwiftUI
import TaskovskyCore

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
    private let hourHeight: CGFloat = 60
    private var gutter: CGFloat { options.additionalTimeZoneID == nil ? 54 : 104 }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = max(118, (geometry.size.width - gutter) / CGFloat(max(1, days.count)))
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            if let id = options.additionalTimeZoneID, let zone = TimeZone(identifier: id) {
                                Text(zone.abbreviation(for: days.first ?? Date()) ?? id)
                                    .help(id + " · " + CalendarText.date(days.first ?? Date(), "MMM d", calendar: calendar))
                                    .frame(maxWidth: .infinity)
                            }
                            Text(calendar.timeZone.abbreviation(for: days.first ?? Date()) ?? calendar.timeZone.identifier)
                                .help(calendar.timeZone.identifier).frame(maxWidth: .infinity)
                        }.font(.system(size: 10)).foregroundStyle(.secondary).frame(width: gutter)
                        ForEach(days, id: \.self) { day in
                            Text(CalendarText.date(day, "EEE d", calendar: calendar))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : .primary)
                                .frame(width: columnWidth, height: 36)
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
        let stripHeight = min(125, max(35, CGFloat(maximum) * 26 + 22))
        return HStack(alignment: .top, spacing: 0) {
            Text("All day").font(.system(size: 10)).foregroundStyle(.secondary)
                .frame(width: gutter, height: 35)
            ForEach(days, id: \.self) { day in
                let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                ScrollView(.vertical) { VStack(spacing: 3) {
                    ForEach(entries.filter { $0.isAllDay && $0.start < next && $0.end > day }) { entry in
                        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, compact: true,
                            open: open, complete: complete, edit: edit).calendarDraggable(entry)
                    }
                    Button { create(day, day, true) } label: { Image(systemName: "plus").font(.system(size: 9)).frame(maxWidth: .infinity) }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Add all-day task " + CalendarText.date(day, "MMM d", calendar: calendar))
                }.padding(3) }.frame(width: columnWidth, height: stripHeight, alignment: .top)
                    .contentShape(Rectangle())
                    .overlay(alignment: .leading) { Divider() }
                    .dropDestination(for: String.self) { values, _ in
                        guard let id = values.compactMap(CalendarDrag.id).first else { return false }
                        schedule(id, .move(start: day, allDay: true)); return true
                    }
            }
        }.frame(height: stripHeight)
    }
    private var hourRuler: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 4) {
                    if let id = options.additionalTimeZoneID, let zone = TimeZone(identifier: id) {
                        var other = calendar
                        let _ = other.timeZone = zone
                        Text(CalendarText.time(CalendarDates.instant(on: days.first ?? Date(), minute: hour * 60, calendar: calendar), calendar: other))
                            .help(id).foregroundStyle(.tertiary)
                    }
                    Text(String(format: "%02d:00", hour)).foregroundStyle(.secondary)
                }.font(.system(size: 10)).frame(width: gutter - 8, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 8).id(hour)
            }
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
                    Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 0.5).offset(y: CGFloat(hour) * hourHeight)
                    Rectangle().fill(Color.primary.opacity(0.035)).frame(height: 0.5).offset(y: CGFloat(hour) * hourHeight + hourHeight / 2)
                }.allowsHitTesting(false)
                Rectangle().fill(Color.primary.opacity(0.09)).frame(width: 0.5).allowsHitTesting(false)
                if let selection {
                    let start = min(selection.0, selection.1), end = max(start + 15, max(selection.0, selection.1))
                    RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.2))
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
        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, compact: height < 40,
            open: open, complete: complete, edit: edit)
            .frame(height: height, alignment: .top).clipped()
            .calendarDraggable(entry)
            .overlay(alignment: .bottom) {
                if entry.canSchedule && finalSegment {
                    Capsule().fill(Color(hex: entry.color).opacity(0.7)).frame(width: 22, height: 3)
                        .frame(maxWidth: .infinity).frame(height: 9).contentShape(Rectangle())
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
            let height = max(115, (geometry.size.height - 26) / CGFloat(max(1, days.count / 7)))
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { index in
                            Text(calendar.shortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                                .font(.system(size: 11)).foregroundStyle(.secondary).frame(width: width, height: 26)
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
    private var items: [CalendarEntry] {
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return entries.filter { $0.start < end && $0.end > day }
    }
    private var capacity: Int { max(1, Int((height - 55) / 23)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(calendar.component(.day, from: day))").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(calendar.isDateInToday(day) ? Color.white : .primary)
                    .frame(width: 24, height: 24)
                    .background(calendar.isDateInToday(day) ? Color.accentColor : .clear, in: Circle())
                Spacer(minLength: 0)
                Button { create(day) } label: { Image(systemName: "plus").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
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
        }.padding(5).frame(maxWidth: .infinity).frame(height: height)
            .background(calendar.isDate(day, equalTo: focus, toGranularity: .month) ? Color.clear : Color.primary.opacity(0.025))
            .overlay { Rectangle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5).allowsHitTesting(false) }
            .contentShape(Rectangle()).onTapGesture(count: 2) { create(day) }
            .dropDestination(for: String.self) { values, _ in
                guard let id = values.compactMap(CalendarDrag.id).first else { return false }
                move(id, day, false); return true
            }
    }
    private func card(_ entry: CalendarEntry) -> some View {
        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, compact: true,
            open: open, complete: complete, edit: edit).calendarDraggable(entry)
    }
}

struct CalendarYearView: View {
    var focus: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var select: (Date) -> Void
    var body: some View {
        let start = calendar.dateInterval(of: .year, for: focus)?.start ?? focus
        let months = (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
        let days = CalendarDates.visibleDays(focus: focus, mode: .year, options: .init(), calendar: calendar)
        let counts = CalendarDayCounts.count(entries, days: days, calendar: calendar)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 290), spacing: 24, alignment: .top)], alignment: .leading, spacing: 26) {
                ForEach(months, id: \.self) { month in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(CalendarText.date(month, "MMMM", calendar: calendar)).font(.system(size: 15, weight: .semibold))
                        CalendarMiniMonth(month: month, counts: counts, heatmap: true, calendar: calendar, select: select)
                    }
                }
            }.padding(24)
            Text("Darker dates contain more visible items. Select a date to open it.")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 20)
        }
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
                                    .foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : .primary)
                                Spacer()
                                Button { create(day) } label: { Image(systemName: "plus") }
                                    .buttonStyle(.plain).accessibilityLabel("Add task " + CalendarText.date(day, "MMM d", calendar: calendar))
                            }
                            if items.isEmpty { Text("No scheduled tasks").font(.system(size: 12)).foregroundStyle(.secondary) }
                            ForEach(items) { entry in
                                CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar,
                                    open: open, complete: complete, edit: edit).fixedSize(horizontal: false, vertical: true).calendarDraggable(entry)
                            }
                        }
                    }
                }
            }.padding(22)
        }
    }
}
