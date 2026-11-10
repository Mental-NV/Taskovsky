import SwiftUI
import UIKit
import UniformTypeIdentifiers
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneCalendarDrag: Codable, Transferable {
    let taskID: UUID
    let session: UUID
    let revision: WorkspaceRevision

    static let contentType = UTType(exportedAs: "local.taskovsky.calendar-drag")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: contentType)
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
    let resize: (PhoneCalendarDrag, CalendarScheduleOperation) -> Void
    let saveFoldedHours: (CalendarFoldedHours) -> Void
    let createRange: ((ClosedRange<Date>) -> Void)?
}

struct PhoneCalendarDateJump: View {
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    let calendar: Calendar
    let go: (Date) -> Void

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
                .navigationTitle("Jump to Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") { go(calendar.startOfDay(for: date)); dismiss() }
                    }
                }
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .presentationDetents([.medium, .large])
    }
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
    @State private var agendaWindow = CalendarAgendaWindow()
    @State private var monthZoom = CalendarMonthZoom.full
    var body: some View {
        let days = CalendarDates.visibleDays(focus: focus, mode: options.mode, options: options, calendar: calendar,
                                            agendaWindow: agendaWindow, monthZoom: monthZoom)
        let result = CalendarDates.interval(for: days, calendar: calendar).map {
            TaskCalendarProjection.project(data: data, range: $0, options: options, calendar: calendar).entries
        } ?? []
        return MobileCalendarContent(calendar: calendar, today: today, days: days, entries: result,
                                     focus: $focus, options: options, monthZoom: $monthZoom, controls: controls, select: select, open: open,
                                     canExtendAgenda: agendaWindow.canExtend, showMoreAgenda: { agendaWindow.extend() },
                                     resetAgenda: { agendaWindow = CalendarAgendaWindow() })
            .onChange(of: focus) { _, _ in agendaWindow = CalendarAgendaWindow() }
            .onChange(of: options.mode) { _, _ in
                agendaWindow = CalendarAgendaWindow()
                monthZoom = .full
            }
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
    @Binding var monthZoom: CalendarMonthZoom
    let controls: PhoneCalendarControls
    let select: (TaskCalendarMode, Date) -> Void
    let open: (UUID) -> Void
    let canExtendAgenda: Bool
    let showMoreAgenda: () -> Void
    let resetAgenda: () -> Void
    @ScaledMetric(relativeTo: .caption2) private var allDayRowHeight = 17.0
    @ScaledMetric(relativeTo: .caption) private var monthDateHeight = 17.0
    @State private var expansion = CalendarHourlyWindow()
    @GestureState private var previewCutoffs: CalendarFoldedHours?
    @State private var monthWeekFrames: [Date: CGRect] = [:]
    @State private var monthSelection: ClosedRange<Date>?
    private let hourHeight: CGFloat = 52
    private var hourWindow: CalendarHourlyWindow { expansion.using(options.foldedHours) }
    private func entries(on day: Date) -> [CalendarEntry] {
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        return entries.filter { $0.start < next && ($0.end > day || calendar.isDate($0.start, inSameDayAs: day)) }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { focus = CalendarDates.navigate(focus, direction: -1, mode: options.mode, options: options, calendar: calendar, monthZoom: monthZoom) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous Calendar period")
                Spacer(); Text(options.mode.title).font(.subheadline)
                Button("Today") { resetAgenda(); focus = today }.frame(minHeight: 44)
                Spacer()
                Button { focus = CalendarDates.navigate(focus, direction: 1, mode: options.mode, options: options, calendar: calendar, monthZoom: monthZoom) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Next Calendar period")
            }.padding(.horizontal, 16)
            if options.mode.isHourly {
                hourFoldControls
                hourly
            }
            else if options.mode == .year { year }
            else if options.mode == .agenda { agenda.id(calendar.startOfDay(for: focus)) }
            else if options.mode == .month {
                monthZoomControls
                zoomableMonth.id(monthZoom)
            }
            else {
                ScrollView {
                    monthGrid(days, zoom: .full)
                    Color.clear.frame(height: 100)
                }
            }
        }.buttonStyle(.plain)
            .onChange(of: options.mode) { old, new in
                if old.isHourly && !new.isHourly { expansion = CalendarHourlyWindow() }
            }
    }
    private func card(_ entry: CalendarEntry, fillsHeight: Bool = false,
                      resizeStartDay: ((DragGesture.Value) -> Date?)? = nil,
                      compactResize: Bool = false,
                      resizeDay: ((DragGesture.Value) -> Date?)? = nil) -> some View {
        let payload = controls.drag(entry)
        let color = cardColor(entry.color)
        let usesCompactGrips = compactResize && entry.canResizeAllDayRange && (resizeStartDay != nil || resizeDay != nil)
        return HStack(alignment: .top, spacing: 0) {
            if let payload, let resizeStartDay, entry.canResizeAllDayRange {
                PhoneAllDayResizeHandle(entry: entry, edge: .start, calendar: calendar, dateAt: resizeStartDay,
                                        width: usesCompactGrips ? 12 : 15,
                                        save: { controls.resize(payload, .resizeStart($0)) },
                                        edit: { controls.edit(entry, .resizeStart) })
            }
            cardButton(entry, color: color, canEdit: payload != nil, fillsHeight: fillsHeight, compact: usesCompactGrips)
            if let payload {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: fillsHeight ? 11 : 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: fillsHeight ? 28 : usesCompactGrips ? 12 : 16,
                           height: fillsHeight ? 28 : 17)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Drag " + entry.title)
                    .draggable(payload)
                if let resizeDay, entry.canResizeAllDayRange {
                    PhoneAllDayResizeHandle(entry: entry, edge: .end, calendar: calendar, dateAt: resizeDay,
                                            width: usesCompactGrips ? 12 : 18,
                                            save: { controls.resize(payload, .resizeEnd($0)) },
                                            edit: { controls.edit(entry, .resize) })
                }
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

    @ViewBuilder private func cardButton(_ entry: CalendarEntry, color: Color, canEdit: Bool,
                                         fillsHeight: Bool, compact: Bool) -> some View {
        let button = Button { open(entry.taskID) } label: {
            HStack(spacing: 3) {
                Rectangle().fill(color).frame(width: 2)
                if options.showsIcon(for: entry) {
                    Image(systemName: entry.isNote ? "doc.text" : entry.isCompleted ? "checkmark.square" :
                          entry.checklistID != nil ? "checklist" : "square")
                        .font(.system(size: 8)).foregroundStyle(color).accessibilityHidden(true)
                }
                Text(entry.title).font(.caption2).lineLimit(1).foregroundStyle(.primary)
                    .strikethrough(entry.isCompleted)
                Spacer(minLength: 0)
            }
            .frame(minWidth: compact ? 0 : nil, maxWidth: compact ? .infinity : nil, minHeight: 17,
                   maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
        }
        .accessibilityLabel(entry.title + (entry.isProjected ? ", recurring preview" : ""))
        if canEdit {
            button
                .contextMenu {
                    Button("Edit Calendar Schedule", systemImage: "calendar") { controls.edit(entry, .schedule) }
                    Button("Move Schedule", systemImage: "arrow.up.and.down.and.arrow.left.and.right") { controls.edit(entry, .move) }
                    if entry.hasDuration {
                        Button("Resize Start", systemImage: entry.isAllDay ? "arrow.left.to.line" : "arrow.up.to.line") {
                            controls.edit(entry, .resizeStart)
                        }
                    }
                    Button("Resize Schedule", systemImage: "arrow.up.and.down") { controls.edit(entry, .resize) }
                }
                .accessibilityAction(named: Text("Edit Calendar Schedule")) { controls.edit(entry, .schedule) }
                .accessibilityAction(named: Text("Move Schedule")) { controls.edit(entry, .move) }
                .accessibilityAction(named: Text("Resize Schedule")) { controls.edit(entry, .resize) }
                .accessibilityActions {
                    if entry.hasDuration {
                        Button("Resize Start") { controls.edit(entry, .resizeStart) }
                    }
                }
        } else { button }
    }

    private var hourFoldControls: some View {
        HStack(spacing: 8) {
            ForEach(CalendarHourBand.allCases, id: \.self) { band in
                let expanded = hourWindow.isExpanded(band)
                let count = hourWindow.itemCount(in: band, entries: entries, days: days, calendar: calendar)
                Button {
                    expansion.toggle(band)
                } label: {
                    Label(expanded || count == 0 ? band.title : "\(band.title) (\(count))",
                          systemImage: expanded ? "chevron.up" : "chevron.down")
                        .frame(minHeight: 32)
                }.buttonStyle(.bordered).accessibilityLabel((expanded ? "Hide " : "Show ") + band.title.lowercased())
                    .accessibilityValue(count == 1 ? "1 item" : "\(count) items")
                    .accessibilityIdentifier("calendarHourBand-" + band.rawValue)
            }
        }.font(.caption).padding(.horizontal, 16)
    }

    private var hourly: some View {
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0, entries(on: $0)) })
        let placements = CalendarAllDayLayout.placements(entries: entries, days: days, calendar: calendar)
        let rowCount = (placements.map(\.lane).max() ?? -1) + 1
        let allDayHeight = options.allDayRows.map { Double($0) * (allDayRowHeight + 2) - 2 }
            ?? max(36, Double(rowCount) * (allDayRowHeight + 2))
        let columnWidth: CGFloat = days.count == 1 ? 300 : 64
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                hourRulers(headerHeight: 52 + allDayHeight)
                if placements.contains(where: { $0.dayCount > 1 || $0.continuesBefore || $0.continuesAfter }) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(days, id: \.self) { day in
                                hourlyDayHeader(day).frame(width: columnWidth)
                                    .overlay(alignment: .leading) { hourlyDayBoundary }
                            }
                        }
                        spanningAllDayCards(placements, columnWidth: columnWidth, height: allDayHeight, rowCount: rowCount)
                        HStack(spacing: 0) {
                            ForEach(days, id: \.self) { day in
                                hourColumn(day, entries: byDay[day] ?? [], width: columnWidth)
                                    .frame(width: columnWidth)
                                    .overlay(alignment: .leading) { hourlyDayBoundary }
                            }
                        }
                    }
                } else {
                    ForEach(Array(days.enumerated()), id: \.element) { index, day in
                        VStack(spacing: 0) {
                            hourlyDayHeader(day)
                            allDayCards((byDay[day] ?? []).filter(\.isAllDay),
                                        index: index, columnWidth: columnWidth)
                                .frame(height: allDayHeight, alignment: .top)
                                .frame(maxWidth: .infinity)
                                .background(Color(uiColor: .systemBackground))
                                .contentShape(Rectangle())
                                .dropDestination(for: PhoneCalendarDrag.self) { values, _ in
                                    guard values.count == 1, let payload = values.first else { return false }
                                    return controls.drop(payload, .allDay(day))
                                }
                            hourColumn(day, entries: byDay[day] ?? [], width: columnWidth)
                        }.frame(width: columnWidth).overlay(alignment: .leading) { hourlyDayBoundary }
                    }
                }
            }.padding(.bottom, 100)
        }
        .background(Color(uiColor: .systemBackground))
        .overlay {
            if options.mode == .week {
                HStack(spacing: 0) {
                    PhoneCalendarWeekEdge(direction: -1, page: pageWeek)
                    Spacer(minLength: 0)
                    PhoneCalendarWeekEdge(direction: 1, page: pageWeek)
                }
            }
        }
        .accessibilityIdentifier("calendarHourlyGrid")
    }

    private func pageWeek(_ direction: Int) {
        focus = CalendarDates.navigate(focus, direction: direction, mode: .week, options: options, calendar: calendar)
    }

    private func hourlyDayHeader(_ day: Date) -> some View {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let identifier = "calendarDay-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        return Button { select(.day, day) } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.narrow))).foregroundStyle(.secondary)
                Text("\(calendar.component(.day, from: day))").fontWeight(.semibold)
            }.font(.caption).frame(height: 52)
        }.accessibilityLabel("Show " + day.formatted(date: .complete, time: .omitted) + " in Day view")
            .accessibilityIdentifier(identifier)
    }

    private var hourlyDayBoundary: some View {
        Rectangle().fill(.primary.opacity(0.06)).frame(width: 0.5)
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    @ViewBuilder private func spanningAllDayCards(_ placements: [CalendarAllDayPlacement],
                                                  columnWidth: CGFloat, height: CGFloat, rowCount: Int) -> some View {
        let pitch = allDayRowHeight + 2
        let width = columnWidth * CGFloat(days.count)
        let contentHeight = max(height, CGFloat(rowCount) * pitch - 2)
        let content = ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { _ in
                    Color.clear.frame(width: columnWidth, height: contentHeight)
                        .overlay(alignment: .leading) { hourlyDayBoundary }
                }
            }
            ForEach(placements) { placement in
                card(placement.entry,
                     resizeStartDay: placement.continuesBefore ? nil :
                        hourlyResizeDay(placement.firstDay, width: columnWidth, edge: .start),
                     compactResize: placement.dayCount == 1,
                     resizeDay: placement.continuesAfter ? nil :
                        hourlyResizeDay(placement.firstDay + placement.dayCount - 1, width: columnWidth))
                    .frame(width: columnWidth * CGFloat(placement.dayCount) - 2, height: allDayRowHeight)
                    .offset(x: columnWidth * CGFloat(placement.firstDay) + 1, y: CGFloat(placement.lane) * pitch)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .contentShape(Rectangle())
        .dropDestination(for: PhoneCalendarDrag.self) { values, point in
            guard values.count == 1, let payload = values.first, point.x >= 0, point.x < width else { return false }
            return controls.drop(payload, .allDay(days[Int(point.x / columnWidth)]))
        }
        if contentHeight > height {
            ScrollView { content }
                .frame(height: height)
                .accessibilityLabel("All-day tasks")
                .accessibilityIdentifier("calendarAllDayOverflow")
        } else {
            content
        }
    }

    private func hourlyResizeDay(_ index: Int, width: CGFloat,
                                 edge: CalendarRangeEdge = .end) -> ((DragGesture.Value) -> Date?)? {
        guard days.count > 1 else { return nil }
        let gripCenter: CGFloat = edge == .start ? 8 : width - 10
        return { value in
            let column = index + Int(floor((value.translation.width + gripCenter) / width))
            return days.indices.contains(column) ? days[column] : nil
        }
    }

    @ViewBuilder private func allDayCards(_ entries: [CalendarEntry], index: Int, columnWidth: CGFloat) -> some View {
        let cards = VStack(spacing: 2) {
            ForEach(entries) {
                card($0, resizeStartDay: hourlyResizeDay(index, width: columnWidth, edge: .start),
                     compactResize: true, resizeDay: hourlyResizeDay(index, width: columnWidth))
                    .frame(height: allDayRowHeight)
            }
        }
        if let rows = options.allDayRows, entries.count > rows {
            ScrollView { cards }
                .accessibilityLabel("All-day tasks")
                .accessibilityIdentifier("calendarAllDayOverflow")
        } else {
            cards
        }
    }
    private func hourRulers(headerHeight: CGFloat) -> some View {
        let secondary = options.visibleTimeZones(primary: calendar.timeZone)
        let reference = days.first ?? focus
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(calendar.timeZone.abbreviation(for: reference) ?? calendar.timeZone.identifier)
                    .lineLimit(1).frame(width: 42, height: headerHeight)
                    .accessibilityLabel("Primary time zone " + calendar.timeZone.identifier)
                ForEach(hourWindow.hours, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).frame(width: 42, height: hourHeight, alignment: .top)
                }
            }.overlay(alignment: .top) {
                if hourWindow.canAdjustFolds {
                    ForEach(CalendarHourBand.allCases, id: \.self) { cutoffMarker($0, headerHeight: headerHeight) }
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
                        ForEach(hourWindow.hours, id: \.self) { hour in
                            let instant = CalendarDates.instant(on: reference, minute: hour * 60, calendar: calendar)
                            Text(instant.formatted(formatter)).lineLimit(1).minimumScaleFactor(0.7)
                                .frame(width: 48, height: hourHeight, alignment: .top)
                        }
                    }
                }
            }
        }.font(.caption2).foregroundStyle(.secondary)
    }

    private func cutoffMarker(_ band: CalendarHourBand, headerHeight: CGFloat) -> some View {
        let original = options.foldedHours
        let hour = (previewCutoffs ?? original).cutoff(band)
        let label = String(format: "%02d:00", hour)
        return VStack(spacing: 1) {
            Image(systemName: "line.3.horizontal")
            Text(label)
        }.font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .frame(width: 42, height: 44)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
                .updating($previewCutoffs) { value, state, _ in
                    state = original.moving(band, by: value.translation.height / hourHeight)
                }
                .onEnded { value in
                    controls.saveFoldedHours(original.moving(band, by: value.translation.height / hourHeight))
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(band.cutoffTitle)
            .accessibilityValue(label)
            .accessibilityIdentifier("calendarFoldCutoff-" + band.rawValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: controls.saveFoldedHours(original.moving(band, to: hour + 1))
                case .decrement: controls.saveFoldedHours(original.moving(band, to: hour - 1))
                @unknown default: break
                }
            }
            .offset(y: headerHeight + CGFloat(hour) * hourHeight - 22)
    }

    private func hourColumn(_ day: Date, entries: [CalendarEntry], width: CGFloat) -> some View {
        let scale = hourHeight / 60
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(hourWindow.hours, id: \.self) { _ in
                    Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5)
                    Color.clear.frame(height: hourHeight - 0.5)
                }
            }
            ForEach(CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar, window: hourWindow)) { placement in
                let lane = width / CGFloat(placement.columnCount)
                let cardWidth = max(1, lane - 2)
                PhoneCalendarTimedSegment(placement: placement, day: day, calendar: calendar, scale: scale,
                                          hourWindow: hourWindow, width: cardWidth,
                                          payload: controls.drag(placement.entry), resize: controls.resize,
                                          edit: { controls.edit(placement.entry, $0) },
                                          content: card(placement.entry, fillsHeight: true))
                    .frame(width: cardWidth)
                    .offset(x: CGFloat(placement.column) * lane + 1, y: (placement.startMinute - Double(hourWindow.firstMinute)) * scale)
            }
        }
        .frame(height: Double(hourWindow.hours.count) * hourHeight)
        .contentShape(Rectangle())
        .dropDestination(for: PhoneCalendarDrag.self) { values, point in
            guard values.count == 1, let payload = values.first else { return false }
            let minute = min(hourWindow.endMinute - 15, hourWindow.minute(atOffset: point.y / scale))
            return controls.drop(payload, .hour(CalendarDates.instant(on: day, minute: minute, calendar: calendar)))
        }
    }

    private var monthZoomControls: some View {
        HStack(spacing: 12) {
            Button { monthZoom = monthZoom.adjusted(zoomingIn: false) } label: {
                Image(systemName: "minus.magnifyingglass").frame(width: 44, height: 44).contentShape(Rectangle())
            }.disabled(monthZoom == .full).accessibilityLabel("Zoom Month out")
            Text(monthZoom.title).font(.caption).accessibilityIdentifier("calendarMonthZoomLevel")
            Button { monthZoom = monthZoom.adjusted(zoomingIn: true) } label: {
                Image(systemName: "plus.magnifyingglass").frame(width: 44, height: 44).contentShape(Rectangle())
            }.disabled(monthZoom == .oneWeek).accessibilityLabel("Zoom Month in")
        }
    }

    private var zoomableMonth: some View {
        ScrollView {
            monthGrid(days, zoom: monthZoom)
                .contentShape(Rectangle())
                .simultaneousGesture(MagnifyGesture().onEnded { gesture in
                    monthZoom = monthZoom.adjusted(magnification: gesture.magnification)
                })
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("calendarMonthDays")
            Color.clear.frame(height: 100)
        }
        .accessibilityIdentifier("calendarMonthGrid")
    }

    private func monthGrid(_ visible: [Date], zoom: CalendarMonthZoom) -> some View {
        let cellHeight: CGFloat = switch zoom {
        case .full: 84
        case .threeWeeks: 112
        case .twoWeeks: 144
        case .oneWeek: 186
        }
        return LazyVStack(spacing: 1) {
            ForEach(Array(stride(from: 0, to: visible.count, by: 7)), id: \.self) { start in
                monthWeek(Array(visible.dropFirst(start).prefix(7)), capacity: zoom.itemLimit, cellHeight: cellHeight)
            }
        }
        .onPreferenceChange(PhoneMonthWeekFrames.self) { monthWeekFrames = $0 }
        .padding(.horizontal, 8)
    }

    private func monthWeek(_ dates: [Date], capacity: Int, cellHeight: CGFloat) -> some View {
        let layout = CalendarMonthWeekLayout(entries: entries, dates: dates, capacity: capacity, calendar: calendar)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
            ForEach(Array(dates.enumerated()), id: \.element) { index, day in
                monthCell(day, layout: layout.days[index], height: cellHeight)
            }
        }
        .background {
            GeometryReader { geometry in
                if let first = dates.first {
                    Color.clear.preference(key: PhoneMonthWeekFrames.self,
                                           value: [first: geometry.frame(in: .global)])
                }
            }
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geometry in
                let width = (geometry.size.width - 6) / 7
                let pitch = width + 1
                ForEach(layout.spans) { placement in
                    card(placement.entry,
                         resizeStartDay: placement.continuesBefore ? nil : monthResizeDay,
                         compactResize: placement.dayCount == 1,
                         resizeDay: placement.continuesAfter ? nil : monthResizeDay)
                        .frame(width: pitch * CGFloat(placement.dayCount) - 7, height: allDayRowHeight)
                        .contentShape(Rectangle())
                        .dropDestination(for: PhoneCalendarDrag.self) { values, point in
                            guard values.count == 1, let payload = values.first, point.x >= 0, pitch > 0 else { return false }
                            let index = placement.firstDay + min(placement.dayCount - 1, Int((point.x + 3) / pitch))
                            return controls.drop(payload, .day(dates[index]))
                        }
                        .offset(x: pitch * CGFloat(placement.firstDay) + 3,
                                y: monthDateHeight + 8 + CGFloat(placement.lane) * (allDayRowHeight + 2))
                }
            }
        }
    }

    private func monthCell(_ day: Date, layout: CalendarMonthWeekLayout.Day, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(calendar.component(.day, from: day))").font(.caption)
                .frame(height: monthDateHeight).padding(.bottom, 3)
            ForEach(layout.slots.indices, id: \.self) { index in
                if let entry = layout.slots[index] {
                    card(entry, resizeStartDay: monthResizeDay, compactResize: true, resizeDay: monthResizeDay)
                        .frame(height: allDayRowHeight)
                } else {
                    Color.clear.frame(height: allDayRowHeight).allowsHitTesting(false)
                }
            }
            if layout.hiddenCount > 0 {
                Button { select(.day, day) } label: {
                    Text("+\(layout.hiddenCount)")
                        .font(.caption2).frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }.accessibilityLabel("\(layout.hiddenCount) more items, open Day")
            }
            Spacer(minLength: 0)
        }.padding(3).frame(minHeight: height).frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                let selected = monthSelection?.contains(day) == true
                ZStack {
                    Color(uiColor: .systemBackground)
                        .overlay(selected ? Color.accentColor.opacity(0.16) : .clear)
                    if let createRange = controls.createRange {
                        PhoneMonthRangeTarget { point, finished in
                            let dates = point.flatMap { monthRange(from: day, to: $0) }
                            monthSelection = finished ? nil : dates
                            if finished, let dates, dates.lowerBound != dates.upperBound {
                                createRange(dates)
                            }
                        }.accessibilityHidden(true)
                    }
                }
            }
            .dropDestination(for: PhoneCalendarDrag.self) { values, _ in
                guard values.count == 1, let payload = values.first else { return false }
                return controls.drop(payload, .day(day))
            }
    }

    private func monthDate(at point: CGPoint) -> Date? {
        guard let (first, frame) = monthWeekFrames.first(where: { $0.value.contains(point) }) else { return nil }
        let column = min(6, Int((point.x - frame.minX) / ((frame.width + 1) / 7)))
        guard let end = calendar.date(byAdding: .day, value: column, to: first), days.contains(end) else { return nil }
        return end
    }

    private func monthRange(from start: Date, to point: CGPoint) -> ClosedRange<Date>? {
        guard let end = monthDate(at: point) else { return nil }
        return min(start, end)...max(start, end)
    }

    private func monthResizeDay(_ value: DragGesture.Value) -> Date? {
        monthDate(at: value.location)
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
                if entries.isEmpty { Text("No scheduled tasks").foregroundStyle(.secondary) }
                ForEach(days, id: \.self) { day in
                    let items = entries(on: day)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.headline)
                            ForEach(items) { card($0).frame(minHeight: 44) }
                        }.padding(12).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let last = days.last {
                    let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)
                    HStack {
                        Text("Through " + last.formatted(dateStyle)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if canExtendAgenda {
                            Button("Show more", action: showMoreAgenda)
                                .buttonStyle(.bordered).frame(minHeight: 44).accessibilityIdentifier("agendaShowMore")
                        }
                    }
                }
            }.padding(.horizontal, 16)
            Color.clear.frame(height: 100)
        }
    }
}


/// A long press on the empty cell defers to a normal scroll until it
/// recognizes. The continuous UIKit gesture then tracks the selected dates.
private struct PhoneMonthRangeTarget: UIViewRepresentable {
    let update: (CGPoint?, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(update: update) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.track))
        press.minimumPressDuration = 0.35
        view.addGestureRecognizer(press)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.update = update
    }

    final class Coordinator: NSObject {
        var update: (CGPoint?, Bool) -> Void
        init(update: @escaping (CGPoint?, Bool) -> Void) { self.update = update }

        @objc func track(_ press: UILongPressGestureRecognizer) {
            switch press.state {
            case .began, .changed:
                update(press.location(in: press.view?.window), false)
            case .ended:
                update(press.location(in: press.view?.window), true)
            case .cancelled, .failed:
                update(nil, false)
            default:
                break
            }
        }
    }
}

private struct PhoneMonthWeekFrames: PreferenceKey {
    static let defaultValue: [Date: CGRect] = [:]
    static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// A local Calendar drag pages once per entry. Releasing on the
/// navigation edge itself leaves the schedule untouched.
private struct PhoneCalendarWeekEdge: View {
    let direction: Int
    let page: (Int) -> Void
    @State private var targeted = false

    var body: some View {
        PhoneCalendarWeekEdgeTarget(targeted: { targeted = $0 }, page: { page(direction) })
            .frame(width: 22)
            .overlay {
                if targeted {
                    Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22, height: 42)
                        .background(.regularMaterial, in: Capsule())
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct PhoneCalendarWeekEdgeTarget: UIViewRepresentable {
    let targeted: (Bool) -> Void
    let page: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(targeted: targeted, page: page) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.addInteraction(UIDropInteraction(delegate: context.coordinator))
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.targeted = targeted
        context.coordinator.page = page
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.cancel()
    }

    @MainActor final class Coordinator: NSObject, UIDropInteractionDelegate {
        var targeted: (Bool) -> Void
        var page: () -> Void
        private var dwell: Task<Void, Never>?

        init(targeted: @escaping (Bool) -> Void, page: @escaping () -> Void) {
            self.targeted = targeted
            self.page = page
        }

        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            session.localDragSession != nil &&
                session.hasItemsConforming(toTypeIdentifiers: [PhoneCalendarDrag.contentType.identifier])
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
            guard dwell == nil else { return }
            targeted(true)
            dwell = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(700)) }
                catch { return }
                guard !Task.isCancelled else { return }
                self?.page()
            }
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: .copy)
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
            cancel()
        }

        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            cancel()
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
            cancel()
        }

        func cancel() {
            guard let dwell else { return }
            dwell.cancel()
            self.dwell = nil
            targeted(false)
        }
    }
}

private struct PhoneAllDayResizeHandle: View {
    let entry: CalendarEntry
    let edge: CalendarRangeEdge
    let calendar: Calendar
    let dateAt: (DragGesture.Value) -> Date?
    let width: CGFloat
    let save: (Date) -> Void
    let edit: () -> Void
    @GestureState private var preview: Date?
    private var endpoint: String { edge == .start ? "start" : "end" }

    var body: some View {
        Button(action: edit) {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: width, height: 17)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resize " + endpoint + " of " + entry.title)
        .accessibilityIdentifier("calendarAllDay" + endpoint.capitalized + "Handle-" + entry.taskID.uuidString)
        .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($preview) { value, state, _ in
                state = dateAt(value).flatMap { entry.allDayResizeTarget(on: $0, edge: edge, calendar: calendar) }
            }
            .onEnded { value in
                guard let day = dateAt(value),
                      let target = entry.allDayResizeTarget(on: day, edge: edge, calendar: calendar) else { return }
                save(target)
            })
        .overlay(alignment: .topTrailing) {
            if let preview {
                Text(preview.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)))
                    .font(.caption2).fixedSize().padding(3).background(.regularMaterial, in: Capsule())
                    .offset(y: -19).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

private struct PhoneCalendarTimedSegment<Content: View>: View {
    let placement: CalendarTimedPlacement
    let day: Date
    let calendar: Calendar
    let scale: Double
    let hourWindow: CalendarHourlyWindow
    let width: CGFloat
    let payload: PhoneCalendarDrag?
    let resize: (PhoneCalendarDrag, CalendarScheduleOperation) -> Void
    let edit: (PhoneCalendarEditMode) -> Void
    let content: Content
    @GestureState private var delta: CGFloat = 0
    @GestureState private var startPreview: Date?

    private var height: CGFloat { max(18, (placement.endMinute - placement.startMinute) * scale) }

    var body: some View {
        let available = (Double(hourWindow.endMinute) - placement.startMinute) * scale
        content.frame(height: min(available, max(18, height + delta)), alignment: .top).clipped()
            .overlay(alignment: .bottom) {
                if let payload, height >= 44, placement.entry.hasDuration, placement.endIsVisible {
                    Button { edit(.resize) } label: {
                        Capsule().fill(Color.blue.opacity(0.75)).frame(width: 22, height: 3)
                            .frame(maxWidth: .infinity).frame(height: 22).contentShape(Rectangle())
                    }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Resize " + placement.entry.title)
                        .accessibilityIdentifier("calendarResizeHandle-" + placement.entry.taskID.uuidString)
                        // The handle moves as the preview grows. Measure the
                        // gesture outside that moving coordinate space.
                        .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .updating($delta) { value, state, _ in state = value.translation.height }
                            .onEnded { value in
                                let minute = hourWindow.snappedMinute(placement.resizeMinute + value.translation.height / scale)
                                let end = CalendarDates.instant(on: day, minute: minute, calendar: calendar)
                                resize(payload, .resizeEnd(end))
                            })
                }
            }
            .overlay(alignment: .topLeading) {
                if let payload, height >= 44, placement.entry.hasDuration, placement.startIsVisible {
                    startGrip(for: payload)
                }
            }
    }

    private func startGrip(for payload: PhoneCalendarDrag) -> some View {
        func target(_ delta: CGFloat) -> Date {
            placement.startResizeTarget(deltaMinutes: delta / scale, day: day, calendar: calendar, window: hourWindow)
        }
        return Button { edit(.resizeStart) } label: {
            Capsule().fill(Color.blue.opacity(0.75)).frame(width: 22, height: 3)
                .frame(width: min(44, max(1, width - 28)), height: 22).clipped().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resize start of " + placement.entry.title)
        .accessibilityIdentifier("calendarResizeStartHandle-" + placement.entry.taskID.uuidString)
        .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($startPreview) { value, preview, _ in preview = target(value.translation.height) }
            .onEnded { value in
                let date = target(value.translation.height)
                guard date != placement.entry.start else { return }
                resize(payload, .resizeStart(date))
            })
        .overlay(alignment: .topLeading) {
            if let startPreview {
                Text(startPreview.formatted(Date.FormatStyle(date: .omitted, time: .shortened,
                                                             calendar: calendar, timeZone: calendar.timeZone)))
                    .font(.caption2).fixedSize().padding(3).background(.regularMaterial, in: Capsule())
                    .offset(y: -20).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}
