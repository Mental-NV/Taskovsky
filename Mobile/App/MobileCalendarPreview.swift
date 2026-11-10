import SwiftUI
import UniformTypeIdentifiers
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneCalendarDrag: Codable, Transferable {
    let taskID: UUID
    let session: UUID
    let revision: WorkspaceRevision

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "local.taskovsky.calendar-drag"))
            .visibility(.ownProcess)
    }
}

enum PhoneCalendarDropTarget {
    case allDay(Date)
    case hour(Date)
    case day(Date)
}

struct PhoneCalendarControls {
    let drag: (CalendarEntry) -> PhoneCalendarDrag?
    let edit: (CalendarEntry, PhoneCalendarEditMode) -> Void
    let drop: (PhoneCalendarDrag, PhoneCalendarDropTarget) -> Bool
    let resize: (PhoneCalendarDrag, Date) -> Void
}

struct MobileCalendarPreview: View {
    let data: WorkspaceData
    let calendar: Calendar
    let today: Date
    @Binding var focus: Date
    let options: TaskCalendarOptions
    let controls: PhoneCalendarControls
    let select: (TaskCalendarMode, Date) -> Void
    let open: (UUID) -> Void
    var body: some View {
        let days = CalendarDates.visibleDays(focus: focus, mode: options.mode, options: options, calendar: calendar)
        let result = CalendarDates.interval(for: days, calendar: calendar).map {
            TaskCalendarProjection.project(data: data, range: $0, options: options, calendar: calendar).entries
        } ?? []
        return MobileCalendarContent(calendar: calendar, today: today, days: days, entries: result,
                                     focus: $focus, options: options, controls: controls, select: select, open: open)
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
    let options: TaskCalendarOptions
    let controls: PhoneCalendarControls
    let select: (TaskCalendarMode, Date) -> Void
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
    private func card(_ entry: CalendarEntry, fillsHeight: Bool = false) -> some View {
        let payload = controls.drag(entry)
        let color = cardColor(entry.color)
        return HStack(alignment: .top, spacing: 0) {
            cardButton(entry, color: color, canEdit: payload != nil, fillsHeight: fillsHeight)
            if let payload {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: fillsHeight ? 11 : 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: fillsHeight ? 28 : 16, height: fillsHeight ? 28 : 17)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Drag " + entry.title)
                    .draggable(payload)
            }
        }
        .frame(minHeight: 17, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(options.itemStyle == .filled ? color.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            if options.itemStyle == .outline {
                RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(0.7)).allowsHitTesting(false)
            }
        }
        .opacity(entry.isCompleted ? 0.58 : entry.isProjected ? 0.72 : 1)
    }

    private func cardColor(_ hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return .accentColor }
        return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    @ViewBuilder private func cardButton(_ entry: CalendarEntry, color: Color, canEdit: Bool, fillsHeight: Bool) -> some View {
        let button = Button { open(entry.taskID) } label: {
            HStack(spacing: 3) {
                Rectangle().fill(color).frame(width: 2)
                if options.showItemIcons {
                    Image(systemName: entry.isNote ? "doc.text" : entry.isCompleted ? "checkmark.square" :
                          entry.checklistID != nil ? "checklist" : "square")
                        .font(.system(size: 8)).foregroundStyle(color).accessibilityHidden(true)
                }
                Text(entry.title).font(.caption2).lineLimit(1).foregroundStyle(.primary)
                    .strikethrough(entry.isCompleted)
                Spacer(minLength: 0)
            }.frame(minHeight: 17, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading).contentShape(Rectangle())
        }
        .accessibilityLabel(entry.title + (entry.isProjected ? ", recurring preview" : ""))
        if canEdit {
            button
                .contextMenu {
                    Button("Edit Calendar Schedule", systemImage: "calendar") { controls.edit(entry, .schedule) }
                    Button("Move Schedule", systemImage: "arrow.up.and.down.and.arrow.left.and.right") { controls.edit(entry, .move) }
                    Button("Resize Schedule", systemImage: "arrow.up.and.down") { controls.edit(entry, .resize) }
                }
                .accessibilityAction(named: Text("Edit Calendar Schedule")) { controls.edit(entry, .schedule) }
                .accessibilityAction(named: Text("Move Schedule")) { controls.edit(entry, .move) }
                .accessibilityAction(named: Text("Resize Schedule")) { controls.edit(entry, .resize) }
        } else { button }
    }

    private var hourly: some View {
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0, entries(on: $0)) })
        let rowCount = byDay.values.map { $0.filter(\.isAllDay).count }.max() ?? 0
        let allDayHeight = max(36, Double(rowCount) * (allDayRowHeight + 2))
        let columnWidth: CGFloat = days.count == 1 ? 300 : 64
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                hourRulers(headerHeight: 52 + allDayHeight)
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 0) {
                        Button { select(.day, day) } label: {
                            VStack(spacing: 6) { Text(day.formatted(.dateTime.weekday(.narrow))).foregroundStyle(.secondary); Text("\(calendar.component(.day, from: day))").fontWeight(.semibold) }.font(.caption).frame(height: 52)
                        }.accessibilityLabel("Show " + day.formatted(date: .complete, time: .omitted) + " in Day view")
                        VStack(spacing: 2) {
                            ForEach((byDay[day] ?? []).filter(\.isAllDay)) { card($0).frame(height: allDayRowHeight) }
                        }.frame(height: allDayHeight, alignment: .top)
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .systemBackground))
                            .contentShape(Rectangle())
                            .dropDestination(for: PhoneCalendarDrag.self) { values, _ in
                                guard values.count == 1, let payload = values.first else { return false }
                                return controls.drop(payload, .allDay(day))
                            }
                        hourColumn(day, entries: byDay[day] ?? [], width: columnWidth)
                    }.frame(width: columnWidth).overlay(alignment: .leading) { Rectangle().fill(.primary.opacity(0.06)).frame(width: 0.5) }
                }
            }.padding(.bottom, 100)
        }.background(Color(uiColor: .systemBackground))
    }
    private func hourRulers(headerHeight: CGFloat) -> some View {
        let secondary = options.visibleTimeZones(primary: calendar.timeZone)
        let reference = days.first ?? focus
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(calendar.timeZone.abbreviation(for: reference) ?? calendar.timeZone.identifier)
                    .lineLimit(1).frame(width: 42, height: headerHeight)
                    .accessibilityLabel("Primary time zone " + calendar.timeZone.identifier)
                ForEach(0..<24) { hour in
                    Text(String(format: "%02d", hour)).frame(width: 42, height: 52, alignment: .top)
                }
            }
            ForEach(secondary) { ruler in
                if let zone = TimeZone(identifier: ruler.identifier) {
                    let formatter = Date.FormatStyle(date: .omitted, time: .shortened, calendar: calendar, timeZone: zone)
                    VStack(spacing: 0) {
                        Text(ruler.title(at: reference)).lineLimit(2).minimumScaleFactor(0.7)
                            .frame(width: 48, height: headerHeight)
                            .accessibilityLabel("Time zone " + ruler.title(at: reference) + ", " + ruler.identifier)
                            .accessibilityIdentifier("calendarRuler-" + ruler.identifier)
                        ForEach(0..<24) { hour in
                            let instant = CalendarDates.instant(on: reference, minute: hour * 60, calendar: calendar)
                            Text(instant.formatted(formatter)).lineLimit(1).minimumScaleFactor(0.7)
                                .frame(width: 48, height: 52, alignment: .top)
                        }
                    }
                }
            }
        }.font(.caption2).foregroundStyle(.secondary)
    }

    private func hourColumn(_ day: Date, entries: [CalendarEntry], width: CGFloat) -> some View {
        let hourHeight = 52.0
        let scale = hourHeight / 60
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<24) { _ in
                    Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5)
                    Color.clear.frame(height: hourHeight - 0.5)
                }
            }
            ForEach(CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar)) { placement in
                let lane = width / CGFloat(placement.columnCount)
                PhoneCalendarTimedSegment(placement: placement, day: day, calendar: calendar, scale: scale,
                                          payload: placement.entry.end <= next ? controls.drag(placement.entry) : nil,
                                          resize: controls.resize, content: card(placement.entry, fillsHeight: true))
                    .frame(width: max(1, lane - 2))
                    .offset(x: CGFloat(placement.column) * lane + 1, y: placement.startMinute * scale)
            }
        }
        .frame(height: 24 * hourHeight)
        .contentShape(Rectangle())
        .dropDestination(for: PhoneCalendarDrag.self) { values, point in
            guard values.count == 1, let payload = values.first else { return false }
            let minute = min(1425, CalendarDates.snappedMinute(point.y / scale))
            return controls.drop(payload, .hour(CalendarDates.instant(on: day, minute: minute, calendar: calendar)))
        }
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
                            Button("+\(items.count - 2)") { select(.day, day) }
                                .font(.caption2).frame(maxWidth: .infinity).frame(minHeight: 44)
                                .accessibilityLabel("\(items.count - 2) more items, open Day")
                        }
                        Spacer(minLength: 0)
                    }.padding(3).frame(minHeight: 84).frame(maxWidth: .infinity, alignment: .topLeading).background(Color(uiColor: .systemBackground))
                        .dropDestination(for: PhoneCalendarDrag.self) { values, _ in
                            guard values.count == 1, let payload = values.first else { return false }
                            return controls.drop(payload, .day(day))
                        }
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
                        Button { select(.month, first) } label: { Text(first.formatted(.dateTime.month(.abbreviated))).font(.subheadline.bold()).frame(minHeight: 44) }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
                            ForEach(CalendarDates.days(from: CalendarDates.weekStart(first, calendar: calendar), count: 42, calendar: calendar), id: \.self) { day in
                                Button { select(.week, day) } label: {
                                    yearDay(day, month: number)
                                }.accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", open Week")
                            }
                        }
                    }
                }
            }.padding(.horizontal, 16)
            Color.clear.frame(height: 100)
        }.accessibilityIdentifier(options.yearStyle == .heatmap ? "calendarYearHeatmap" : "calendarYearStandard")
    }
    private func yearDay(_ day: Date, month: Int) -> some View {
        let inMonth = calendar.component(.month, from: day) == month
        let count = inMonth ? entries(on: day).count : 0
        let heat = options.yearStyle == .heatmap && count > 0 ? Color.accentColor.opacity(min(0.7, 0.1 + Double(count) * 0.1)) : .clear
        return Text("\(calendar.component(.day, from: day))").font(.system(size: 9))
            .foregroundStyle(inMonth ? Color.primary : Color.secondary.opacity(0.4))
            .frame(maxWidth: .infinity, minHeight: 16)
            .background(heat, in: RoundedRectangle(cornerRadius: 2))
            .overlay(alignment: .bottom) {
                if options.yearStyle == .standard && count > 0 {
                    Circle().fill(Color.accentColor).frame(width: 3, height: 3)
                }
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


private struct PhoneCalendarTimedSegment<Content: View>: View {
    let placement: CalendarTimedPlacement
    let day: Date
    let calendar: Calendar
    let scale: Double
    let payload: PhoneCalendarDrag?
    let resize: (PhoneCalendarDrag, Date) -> Void
    let content: Content
    @GestureState private var delta: CGFloat = 0

    private var height: CGFloat { max(18, (placement.endMinute - placement.startMinute) * scale) }

    var body: some View {
        content.frame(height: max(18, height + delta), alignment: .top).clipped()
            .overlay(alignment: .bottom) {
                if let payload, height >= 44, placement.entry.hasDuration {
                    Capsule().fill(Color.blue.opacity(0.75)).frame(width: 22, height: 3)
                        .frame(maxWidth: .infinity).frame(height: 22).contentShape(Rectangle())
                        .accessibilityHidden(true)
                        // The handle moves as the preview grows. Measure the
                        // gesture outside that moving coordinate space.
                        .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .updating($delta) { value, state, _ in state = value.translation.height }
                            .onEnded { value in
                                let minute = CalendarDates.snappedMinute(placement.endMinute + value.translation.height / scale)
                                let end = CalendarDates.instant(on: day, minute: minute, calendar: calendar)
                                resize(payload, end)
                            })
                }
            }
    }
}
