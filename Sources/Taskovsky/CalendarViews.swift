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
    var complete: (CalendarEntry) -> Void
    var create: (Date, Date, Bool) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    var selectDay: (Date) -> Void
    var saveFoldedHours: (CalendarFoldedHours) -> Void
    var saveAllDayRows: (Int) -> Void
    @State private var expansion = CalendarHourlyWindow()
    @State private var timelineScale = CalendarTimelineScale.standard
    @Namespace private var allDayGrid
    @GestureState private var previewCutoffs: CalendarFoldedHours?
    @GestureState private var previewAllDayRows: Int?
    private var window: CalendarHourlyWindow { expansion.using(options.foldedHours) }
    private var hourHeight: CGFloat { timelineScale.pointsPerHour }
    private let allDayRowPitch: CGFloat = 18
    private let allDayPadding: CGFloat = 8
    private var zones: [CalendarTimeZone] { options.visibleTimeZones(primary: calendar.timeZone) }
    private var gutter: CGFloat { 56 + CGFloat(zones.count) * 54 }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = max(60, (geometry.size.width - gutter) / CGFloat(max(1, days.count)))
            let allDay = CalendarAllDayLayout.placements(entries: entries, days: days, calendar: calendar)
            let laneCount = (allDay.map(\.lane).max() ?? 0) + 1
            // Reserve space for date headers, fold controls, and the hourly grid.
            let rowLimit = min(TaskCalendarOptions.allDayRowRange.upperBound,
                               max(1, Int((geometry.size.height - 200 - allDayPadding) / allDayRowPitch)))
            let automaticHeight = min(125, stripHeight(for: min(rowLimit, laneCount)))
            let currentRows = options.allDayRows.map { min(rowLimit, $0) }
                ?? Int((automaticHeight - allDayPadding) / allDayRowPitch)
            let displayedRows = previewAllDayRows ?? currentRows
            let height = options.allDayRows == nil && previewAllDayRows == nil
                ? automaticHeight : stripHeight(for: displayedRows)
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
                    allDayStrip(columnWidth: columnWidth, height: height, placements: allDay, laneCount: laneCount)
                    allDayResizeGrip(rows: currentRows, displayed: displayedRows, limit: rowLimit)
                    timelineControls(viewportWidth: geometry.size.width)
                    hourlyTimeline(columnWidth: columnWidth, horizontalViewport: geometry.frame(in: .global))
                }.frame(width: gutter + columnWidth * CGFloat(days.count))
            }
        }
    }
    private func hourlyTimeline(columnWidth: CGFloat, horizontalViewport: CGRect) -> some View {
        let contentHeight = CGFloat(window.hours.count) * hourHeight
        return GeometryReader { viewport in
            let visible = viewport.frame(in: .global).intersection(horizontalViewport)
            ScrollView(.vertical) {
                GeometryReader { content in
                    HStack(alignment: .top, spacing: 0) {
                        hourRuler
                        ForEach(days, id: \.self) { day in
                            CalendarHourColumn(day: day, entries: entries, calendar: calendar, options: options,
                                window: window, hourHeight: hourHeight, open: open, complete: complete, create: create,
                                schedule: schedule, edit: edit, moveTarget: { point in
                                    let frame = content.frame(in: .global)
                                    let x = point.x - frame.minX - gutter
                                    let y = point.y - frame.minY
                                    guard visible.contains(point), x >= 0, x < columnWidth * CGFloat(days.count),
                                          y >= 0, y < contentHeight else { return nil }
                                    let day = days[Int(x / columnWidth)]
                                    let minute = window.minute(atOffset: Double(y / hourHeight * 60))
                                    return CalendarDates.instant(on: day, minute: min(window.endMinute - 15, minute), calendar: calendar)
                                })
                                .frame(width: columnWidth, height: contentHeight)
                        }
                    }
                    .background(CalendarTimelineZoomInput(scale: timelineScale) { timelineScale = $0 })
                }
                .frame(height: contentHeight)
            }
        }
    }
    private func timelineControls(viewportWidth: CGFloat) -> some View {
        let layout = viewportWidth >= 360
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        return layout {
            foldControls
            timelineZoomControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
    }
    private var foldControls: some View {
        HStack(spacing: 8) {
            ForEach(CalendarHourBand.allCases, id: \.self) { band in
                let expanded = window.isExpanded(band)
                let count = window.itemCount(in: band, entries: entries, days: days, calendar: calendar)
                Button {
                    expansion.toggle(band)
                } label: {
                    Label(expanded || count == 0 ? band.title : "\(band.title) (\(count))",
                          systemImage: expanded ? "chevron.up" : "chevron.down")
                }.accessibilityLabel((expanded ? "Hide " : "Show ") + band.title.lowercased())
                    .accessibilityValue(count == 1 ? "1 item" : "\(count) items")
                    .accessibilityIdentifier("calendarHourBand-" + band.rawValue)
            }
        }
    }
    private var timelineZoomControls: some View {
        HStack(spacing: 4) {
            Button { timelineScale = timelineScale.stepped(zoomingIn: false) } label: {
                Image(systemName: "minus.magnifyingglass")
            }.disabled(!timelineScale.canZoomOut)
                .accessibilityLabel("Zoom timeline out")
            Button("\(timelineScale.percentage)%") { timelineScale = .standard }
                .monospacedDigit()
                .disabled(timelineScale == .standard)
                .help("Reset timeline zoom")
                .accessibilityLabel("Reset timeline zoom")
                .accessibilityValue("\(timelineScale.percentage) percent")
                .accessibilityIdentifier("calendarTimelineZoom")
            Button { timelineScale = timelineScale.stepped(zoomingIn: true) } label: {
                Image(systemName: "plus.magnifyingglass")
            }.disabled(!timelineScale.canZoomIn)
                .accessibilityLabel("Zoom timeline in")
        }
    }
    private func stripHeight(for rows: Int) -> CGFloat {
        CGFloat(rows) * allDayRowPitch + allDayPadding
    }
    private func allDayResizeGrip(rows: Int, displayed: Int, limit: Int) -> some View {
        func resized(by delta: CGFloat) -> Int {
            let proposed = CGFloat(rows) + (delta / allDayRowPitch).rounded()
            return Int(min(CGFloat(limit), max(1, proposed)))
        }
        func save(_ updated: Int) {
            if updated != rows { saveAllDayRows(updated) }
        }
        return ZStack {
            Divider()
            Capsule().fill(.secondary).frame(width: 30, height: 3)
        }
        .frame(height: 14)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($previewAllDayRows) { value, state, _ in
                let proposed = resized(by: value.translation.height)
                state = proposed == rows ? nil : proposed
            }
            .onEnded { save(resized(by: $0.translation.height)) })
        .help("Drag to change how many all-day task rows are visible.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("All-day rows")
        .accessibilityValue("\(displayed)" + (options.allDayRows == nil && previewAllDayRows == nil ? ", automatic" : ""))
        .accessibilityIdentifier("calendarAllDayResize")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: save(min(limit, rows + 1))
            case .decrement: save(max(1, rows - 1))
            @unknown default: break
            }
        }
    }
    private func allDayStrip(columnWidth: CGFloat, height: CGFloat, placements: [CalendarAllDayPlacement],
                             laneCount: Int) -> some View {
        let resize = days.count > 1 ? CalendarAllDayResizeContext(space: allDayGrid, dateAt: { point in
            let x = point.x - gutter
            guard x >= 0, x < columnWidth * CGFloat(days.count) else { return nil }
            return days[Int(x / columnWidth)]
        }, schedule: schedule) : nil
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
            if placements.contains(where: { $0.dayCount > 1 || $0.continuesBefore || $0.continuesAfter }) {
                allDaySpanningStrip(placements, columnWidth: columnWidth, height: height, laneCount: laneCount, resize: resize)
            } else {
                ForEach(days, id: \.self) { day in
                    let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                    CalendarAllDayCell(day: day, entries: entries.filter { $0.isAllDay && $0.start < next && $0.end > day },
                        calendar: calendar, options: options, width: columnWidth, height: height, open: open, complete: complete,
                        create: create, schedule: schedule, edit: edit, resize: resize)
                }
            }
        }.frame(height: height).coordinateSpace(name: allDayGrid)
    }
    private func allDaySpanningStrip(_ placements: [CalendarAllDayPlacement], columnWidth: CGFloat,
                                     height: CGFloat, laneCount: Int, resize: CalendarAllDayResizeContext?) -> some View {
        let width = columnWidth * CGFloat(days.count)
        let contentHeight = max(height, stripHeight(for: laneCount))
        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        Color.clear.frame(width: columnWidth, height: contentHeight)
                            .modifier(CalendarAllDayActions(day: day, calendar: calendar, create: create))
                    }
                }
                ForEach(placements) { placement in
                    CalendarSpanningEntry(placement: placement, options: options, calendar: calendar,
                                          open: open, complete: complete, edit: edit, resize: resize)
                        .frame(width: columnWidth * CGFloat(placement.dayCount) - 6, height: 16)
                        .offset(x: columnWidth * CGFloat(placement.firstDay) + 3,
                                y: CGFloat(placement.lane) * allDayRowPitch + 6)
                }
            }
            .frame(width: width, height: contentHeight)
            .contentShape(Rectangle())
            .dropDestination(for: TaskDragPayload.self) { values, point in
                guard point.x >= 0, point.x < width,
                      let id = CalendarDrag.id(values) else { return false }
                schedule(id, .move(start: days[Int(point.x / columnWidth)], allDay: true))
                return true
            }
        }.frame(width: width, height: height)
    }
    private var hourRuler: some View {
        VStack(spacing: 0) {
            ForEach(window.hours, id: \.self) { hour in
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
        }.overlay(alignment: .topTrailing) {
            if window.canAdjustFolds {
                ForEach(CalendarHourBand.allCases, id: \.self) { cutoffMarker($0) }
            }
        }
    }

    private func cutoffMarker(_ band: CalendarHourBand) -> some View {
        let original = options.foldedHours
        let hour = (previewCutoffs ?? original).cutoff(band)
        let label = String(format: "%02d:00", hour)
        return Label(label, systemImage: "line.3.horizontal")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(CalendarAppearance.accent)
            .frame(width: 55, height: 30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
                .updating($previewCutoffs) { value, state, _ in
                    state = original.moving(band, by: value.translation.height / hourHeight)
                }
                .onEnded { value in
                    saveFoldedHours(original.moving(band, by: value.translation.height / hourHeight))
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(band.cutoffTitle)
            .accessibilityValue(label)
            .accessibilityIdentifier("calendarFoldCutoff-" + band.rawValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: saveFoldedHours(original.moving(band, to: hour + 1))
                case .decrement: saveFoldedHours(original.moving(band, to: hour - 1))
                @unknown default: break
                }
            }
            .offset(y: CGFloat(hour) * hourHeight - 15)
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
    var complete: (CalendarEntry) -> Void
    var create: (Date, Date, Bool) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    var resize: CalendarAllDayResizeContext?
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 2) {
                ForEach(entries) { entry in
                    HStack(spacing: 0) {
                        if let resize, entry.canResizeAllDayRange {
                            CalendarAllDayResizeHandle(entry: entry, edge: .start, calendar: calendar, context: resize, edit: edit)
                        }
                        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar,
                            showItemIcons: options.showsIcon(for: entry), compact: true, open: open, complete: complete, edit: edit)
                            .frame(height: 16).calendarDraggable(entry)
                        if let resize, entry.canResizeAllDayRange {
                            CalendarAllDayResizeHandle(entry: entry, edge: .end, calendar: calendar, context: resize, edit: edit)
                        }
                    }
                }
            }.padding(.horizontal, 3).padding(.top, 6).padding(.bottom, 4)
        }.frame(width: width, height: height)
            .modifier(CalendarAllDayActions(day: day, calendar: calendar, create: create))
            .dropDestination(for: TaskDragPayload.self) { values, _ in
                guard let id = CalendarDrag.id(values) else { return false }
                schedule(id, .move(start: day, allDay: true)); return true
            }
    }
}

private struct CalendarSpanningEntry: View {
    let placement: CalendarAllDayPlacement
    let options: TaskCalendarOptions
    let calendar: Calendar
    let open: (UUID) -> Void
    let complete: (CalendarEntry) -> Void
    let edit: (CalendarEntry) -> Void
    let resize: CalendarAllDayResizeContext?

    private var continuationHint: String {
        if placement.continuesBefore && placement.continuesAfter { return "Continues before and after this view" }
        if placement.continuesBefore { return "Continues before this view" }
        if placement.continuesAfter { return "Continues after this view" }
        return ""
    }

    var body: some View {
        let entry = placement.entry
        HStack(spacing: 0) {
            if let resize, entry.canResizeAllDayRange, !placement.continuesBefore {
                CalendarAllDayResizeHandle(entry: entry, edge: .start, calendar: calendar, context: resize, edit: edit)
            }
            CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar,
                              showItemIcons: options.showsIcon(for: entry), compact: true,
                              open: open, complete: complete, edit: edit)
                .accessibilityHint(continuationHint)
            if entry.canSchedule {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 16)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Drag " + entry.title)
                    .calendarDraggable(entry)
            }
            if let resize, entry.canResizeAllDayRange, !placement.continuesAfter {
                CalendarAllDayResizeHandle(entry: entry, edge: .end, calendar: calendar, context: resize, edit: edit)
            }
        }
    }
}

private struct CalendarAllDayResizeContext {
    let space: Namespace.ID
    let dateAt: (CGPoint) -> Date?
    let schedule: (UUID, CalendarScheduleOperation) -> Void
}

private struct CalendarAllDayResizeHandle: View {
    let entry: CalendarEntry
    let edge: CalendarRangeEdge
    let calendar: Calendar
    let context: CalendarAllDayResizeContext
    let edit: (CalendarEntry) -> Void
    @GestureState private var preview: Date?
    private var endpoint: String { edge == .start ? "start" : "end" }

    var body: some View {
        Button { edit(entry) } label: {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resize " + endpoint + " of " + entry.title)
        .help("Drag to change the \(endpoint) date, or click to open Schedule.")
        .highPriorityGesture(DragGesture(minimumDistance: 4, coordinateSpace: .named(context.space))
            .updating($preview) { value, state, _ in
                state = context.dateAt(value.location).flatMap { entry.allDayResizeTarget(on: $0, edge: edge, calendar: calendar) }
            }
            .onEnded { value in
                guard let day = context.dateAt(value.location),
                      let target = entry.allDayResizeTarget(on: day, edge: edge, calendar: calendar) else { return }
                context.schedule(entry.taskID, edge == .start ? .resizeStart(target) : .resizeEnd(target))
            })
        .overlay(alignment: .topTrailing) {
            if let preview {
                Text(CalendarText.date(preview, "MMM d", calendar: calendar))
                    .font(.caption2).fixedSize().padding(3).background(.regularMaterial, in: Capsule())
                    .offset(y: -17).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

private struct CalendarAllDayActions: ViewModifier {
    let day: Date
    let calendar: Calendar
    let create: (Date, Date, Bool) -> Void
    @State private var hovered = false
    @FocusState private var addFocused: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            Button { create(day, day, true) } label: {
                Image(systemName: "plus").font(.system(size: 9)).frame(width: 18, height: 18)
            }.buttonStyle(.plain).foregroundStyle(.secondary).focused($addFocused)
                .opacity(hovered || addFocused ? 1 : 0)
                .accessibilityLabel("Add all-day task " + CalendarText.date(day, "MMM d", calendar: calendar))
        }
        .contentShape(Rectangle()).onHover { hovered = $0 }
        .overlay(alignment: .leading) { CalendarDayBoundary() }
        .contextMenu { Button("Add all-day task") { create(day, day, true) } }
    }
}

private struct CalendarHourColumn: View {
    var day: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var window: CalendarHourlyWindow
    var hourHeight: CGFloat
    var open: (UUID) -> Void
    var complete: (CalendarEntry) -> Void
    var create: (Date, Date, Bool) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    var moveTarget: (CGPoint) -> Date?
    @GestureState private var selection: (Int, Int)?
    private var scale: CGFloat { hourHeight / 60 }
    private func minute(_ y: CGFloat) -> Int { window.minute(atOffset: Double(y / scale)) }
    private func offset(_ minute: Double) -> CGFloat { CGFloat(minute - Double(window.firstMinute)) * scale }
    private func instant(_ minute: Int) -> Date { CalendarDates.instant(on: day, minute: minute, calendar: calendar) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(nsColor: .textBackgroundColor)).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 5)
                        .updating($selection) { value, state, _ in state = (min(window.endMinute - 15, minute(value.startLocation.y)), minute(value.location.y)) }
                        .onEnded { value in
                            let first = min(window.endMinute - 15, minute(value.startLocation.y)), last = minute(value.location.y)
                            let start = min(first, last), end = max(start + 15, max(first, last))
                            create(instant(start), instant(min(window.endMinute, end)), false)
                        })
                    .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { value in
                        let start = min(window.endMinute - 15, minute(value.location.y))
                        create(instant(start), instant(min(window.endMinute, start + 30)), false)
                    })
                ForEach(window.hours, id: \.self) { hour in
                    let y = offset(Double(hour * 60))
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5).offset(y: y)
                    Rectangle().fill(Color.primary.opacity(0.025)).frame(height: 0.5).offset(y: y + hourHeight / 2)
                }.allowsHitTesting(false)
                CalendarDayBoundary()
                if let selection {
                    let start = min(selection.0, selection.1), end = max(start + 15, max(selection.0, selection.1))
                    RoundedRectangle(cornerRadius: 4).fill(CalendarAppearance.accent.opacity(0.2))
                        .frame(width: geometry.size.width - 4, height: CGFloat(end - start) * scale)
                        .offset(x: 2, y: offset(Double(start))).allowsHitTesting(false)
                }
                ForEach(CalendarTimedLayout.placements(entries: entries, day: day, calendar: calendar, window: window)) { placement in
                    let width = (geometry.size.width - 5) / CGFloat(placement.columnCount)
                    let cardWidth = max(18, width - 2)
                    CalendarTimedBlock(placement: placement, day: day, calendar: calendar, options: options, window: window, scale: scale,
                        width: cardWidth, open: open, complete: complete, schedule: schedule, edit: edit, moveTarget: moveTarget)
                        .frame(width: cardWidth)
                        .offset(x: 3 + CGFloat(placement.column) * width, y: offset(placement.startMinute))
                }
                if calendar.isDateInToday(day) {
                    let parts = calendar.dateComponents([.hour, .minute], from: Date())
                    let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                    if (window.firstMinute..<window.endMinute).contains(now) {
                        Rectangle().fill(Color.red).frame(height: 1).offset(y: offset(Double(now))).allowsHitTesting(false)
                    }
                }
            }.dropDestination(for: TaskDragPayload.self) { values, point in
                guard let id = CalendarDrag.id(values) else { return false }
                schedule(id, .move(start: instant(min(window.endMinute - 15, minute(point.y))), allDay: false)); return true
            }
        }
    }
}

private struct CalendarTimedBlock: View {
    var placement: CalendarTimedPlacement
    var day: Date
    var calendar: Calendar
    var options: TaskCalendarOptions
    var window: CalendarHourlyWindow
    var scale: CGFloat
    var width: CGFloat
    var open: (UUID) -> Void
    var complete: (CalendarEntry) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var edit: (CalendarEntry) -> Void
    var moveTarget: (CGPoint) -> Date?
    @GestureState private var resizeDelta: CGFloat = 0
    @GestureState private var startPreview: Date?
    @GestureState private var movePreview: Date?
    private var entry: CalendarEntry { placement.entry }
    private var canResizeStart: Bool { entry.canSchedule && entry.hasDuration && placement.startIsVisible }
    var body: some View {
        let available = CGFloat(Double(window.endMinute) - placement.startMinute) * scale
        let height = min(available, max(15, CGFloat(placement.endMinute - placement.startMinute) * scale + resizeDelta))
        let gripWidth = entry.canSchedule ? min(18, width / 3) : 0
        let resizeWidth = min(22, width - gripWidth)
        let resizeHeight = min(9, canResizeStart && placement.endIsVisible ? height / 2 : height)
        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, showItemIcons: options.showsIcon(for: entry), compact: height < 40,
            trailingInset: gripWidth, availableWidth: width, fillsAllocatedHeight: true, open: open, complete: complete, edit: edit)
            .frame(height: height, alignment: .top).clipped()
            .calendarDraggable(entry)
            .overlay(alignment: .bottom) {
                if entry.canSchedule && placement.endIsVisible {
                    Capsule().fill(Color(hex: entry.color).opacity(0.7))
                        .frame(width: resizeWidth, height: canResizeStart && height < 24 ? 2 : 3)
                        .frame(height: resizeHeight, alignment: canResizeStart ? .bottom : .center).contentShape(Rectangle())
                        .accessibilityLabel("Resize " + entry.title).help("Drag to resize in 15-minute steps, or use Schedule…")
                        .highPriorityGesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                            .updating($resizeDelta) { value, state, _ in state = value.translation.height }
                            .onEnded { value in
                                let target = placement.endResizeTarget(deltaMinutes: Double(value.translation.height / scale),
                                    day: day, calendar: calendar, window: window)
                                schedule(entry.taskID, .resizeEnd(target))
                            })
                        .padding(.trailing, gripWidth)
                }
            }
            .overlay(alignment: .top) {
                if canResizeStart {
                    startGrip(width: resizeWidth, height: resizeHeight).padding(.trailing, gripWidth)
                }
            }
            .overlay(alignment: .topTrailing) {
                if entry.canSchedule {
                    Button { edit(entry) } label: {
                        Image(systemName: "line.3.horizontal").font(.system(size: 8, weight: .semibold))
                            .frame(width: gripWidth, height: min(height, 15))
                            .clipped().contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Move " + entry.title)
                    .help("Drag to another time, or click to open Schedule.")
                    .highPriorityGesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
                        .updating($movePreview) { value, preview, _ in preview = moveTarget(value.location) }
                        .onEnded { value in
                            guard let date = moveTarget(value.location) else { return }
                            schedule(entry.taskID, .move(start: date, allDay: false))
                        })
                    .overlay(alignment: .topTrailing) {
                        if let movePreview {
                            Text(CalendarText.date(movePreview, "EEE HH:mm", calendar: calendar))
                                .font(.caption2).fixedSize().padding(3).background(.regularMaterial, in: Capsule())
                                .offset(y: -17).allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                }
            }
    }

    private func startGrip(width: CGFloat, height: CGFloat) -> some View {
        func target(_ delta: CGFloat) -> Date {
            placement.startResizeTarget(deltaMinutes: Double(delta / scale), day: day, calendar: calendar, window: window)
        }
        return Button { edit(entry) } label: {
            Capsule().fill(Color(hex: entry.color).opacity(0.7)).frame(width: width, height: min(2, height))
                .frame(height: height, alignment: .top).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resize start of " + entry.title)
        .help("Drag to adjust the start, or click to open Schedule.")
        .highPriorityGesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .updating($startPreview) { value, preview, _ in preview = target(value.translation.height) }
            .onEnded { value in
                let date = target(value.translation.height)
                guard date != entry.start else { return }
                schedule(entry.taskID, .resizeStart(date))
            })
        .overlay(alignment: .top) {
            if let startPreview {
                Text(CalendarText.time(startPreview, calendar: calendar)).font(.caption2).fixedSize()
                    .padding(3).background(.regularMaterial, in: Capsule())
                    .offset(y: -17).allowsHitTesting(false).accessibilityHidden(true)
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
    var complete: (CalendarEntry) -> Void
    var edit: (CalendarEntry) -> Void
    var create: (Date) -> Void
    var move: (UUID, Date, Bool) -> Void
    var schedule: (UUID, CalendarScheduleOperation) -> Void
    var createRange: (Date, Date, Bool) -> Void
    @Namespace private var monthGrid
    @GestureState private var selectedDays: ClosedRange<Int>?
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
                    LazyVStack(spacing: 0) {
                        ForEach(Array(stride(from: 0, to: days.count, by: 7)), id: \.self) { start in
                            week(Array(days.dropFirst(start).prefix(7)), firstIndex: start, width: width, height: height)
                        }
                    }.coordinateSpace(name: monthGrid)
                }.frame(width: width * 7)
            }
        }
    }
    private func week(_ dates: [Date], firstIndex: Int, width: CGFloat, height: CGFloat) -> some View {
        let capacity = max(1, Int((height - 55) / 23))
        let layout = CalendarMonthWeekLayout(entries: entries, dates: dates, capacity: capacity, calendar: calendar)
        let resize = CalendarAllDayResizeContext(space: monthGrid, dateAt: { point in
            dayIndex(at: point, width: width, height: height).map { days[$0] }
        }, schedule: schedule)
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(Array(dates.enumerated()), id: \.element) { index, day in
                    let dayIndex = firstIndex + index
                    CalendarMonthCell(day: day, focus: focus, layout: layout.days[index], calendar: calendar,
                                      options: options, height: height, open: open, complete: complete, edit: edit, create: create,
                                      selected: selectedDays?.contains(dayIndex) == true,
                                      selection: rangeGesture(from: dayIndex, width: width, height: height), resize: resize)
                        .frame(width: width)
                }
            }
            ForEach(layout.spans) { placement in
                CalendarSpanningEntry(placement: placement, options: options, calendar: calendar,
                                      open: open, complete: complete, edit: edit, resize: resize)
                    .frame(width: width * CGFloat(placement.dayCount) - 6, height: CalendarMonthCell.cardHeight)
                    .offset(x: width * CGFloat(placement.firstDay) + 3,
                            y: CalendarMonthCell.firstCardOffset + CGFloat(placement.lane) * CalendarMonthCell.cardPitch)
            }
        }
        .contentShape(Rectangle())
        .dropDestination(for: TaskDragPayload.self) { values, point in
            guard point.x >= 0, point.x < width * CGFloat(dates.count),
                  let id = CalendarDrag.id(values) else { return false }
            move(id, dates[Int(point.x / width)], false)
            return true
        }
    }

    private func dayIndex(at point: CGPoint, width: CGFloat, height: CGFloat) -> Int? {
        guard point.x >= 0, point.x < 7 * width, point.y >= 0,
              point.y < CGFloat((days.count + 6) / 7) * height else { return nil }
        let index = Int(point.y / height) * 7 + Int(point.x / width)
        return days.indices.contains(index) ? index : nil
    }

    private func rangeGesture(from first: Int, width: CGFloat, height: CGFloat) -> AnyGesture<DragGesture.Value> {
        func selection(at point: CGPoint) -> ClosedRange<Int>? {
            guard let last = dayIndex(at: point, width: width, height: height), first != last else { return nil }
            return min(first, last)...max(first, last)
        }
        return AnyGesture(DragGesture(minimumDistance: 5, coordinateSpace: .named(monthGrid))
            .updating($selectedDays) { value, state, _ in state = selection(at: value.location) }
            .onEnded { value in
                guard let range = selection(at: value.location) else { return }
                createRange(days[range.lowerBound], days[range.upperBound], true)
            })
    }
}

private struct CalendarMonthCell: View {
    var day: Date
    var focus: Date
    var layout: CalendarMonthWeekLayout.Day
    var calendar: Calendar
    var options: TaskCalendarOptions
    var height: CGFloat
    var open: (UUID) -> Void
    var complete: (CalendarEntry) -> Void
    var edit: (CalendarEntry) -> Void
    var create: (Date) -> Void
    var selected: Bool
    var selection: AnyGesture<DragGesture.Value>
    var resize: CalendarAllDayResizeContext
    @State private var more = false
    @State private var hovered = false
    @FocusState private var addFocused: Bool
    private static let spacing: CGFloat = 3
    private static let headerHeight: CGFloat = 24
    static let cardHeight: CGFloat = 17
    static var cardPitch: CGFloat { cardHeight + spacing }
    static var firstCardOffset: CGFloat { spacing + headerHeight + spacing }

    var body: some View {
        ZStack {
            let tint = selected ? 0.15 : calendar.isDateInToday(day) ? 0.04 : 0
            CalendarAppearance.accent.opacity(tint)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { create(day) }
                .gesture(selection)
            contents
        }.frame(height: height)
            .overlay { Rectangle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5).allowsHitTesting(false) }
            .onHover { hovered = $0 }
    }

    private var contents: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            HStack {
                if calendar.component(.day, from: day) == 1 && !calendar.isDateInToday(day) {
                    Text(CalendarText.date(day, "d MMM", calendar: calendar)).font(.system(size: 12))
                        .foregroundStyle(calendar.isDate(day, equalTo: focus, toGranularity: .month) ? Color.primary : Color.secondary)
                        .frame(height: Self.headerHeight).padding(.leading, 4)
                } else {
                    Text("\(calendar.component(.day, from: day))").font(.system(size: 12))
                        .foregroundStyle(calendar.isDateInToday(day) ? Color.white : calendar.isDate(day, equalTo: focus, toGranularity: .month) ? Color.primary : Color.secondary)
                        .frame(width: 24, height: Self.headerHeight)
                        .background(calendar.isDateInToday(day) ? CalendarAppearance.accent : .clear, in: Circle())
                }
                Spacer(minLength: 0)
                Button { create(day) } label: { Image(systemName: "plus").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .focused($addFocused).opacity(hovered || addFocused ? 1 : 0)
                    .accessibilityLabel("Add task " + CalendarText.date(day, "MMM d", calendar: calendar))
            }
            ForEach(layout.slots.indices, id: \.self) { index in
                if let entry = layout.slots[index] {
                    HStack(spacing: 0) {
                        if entry.canResizeAllDayRange {
                            CalendarAllDayResizeHandle(entry: entry, edge: .start, calendar: calendar, context: resize, edit: edit)
                        }
                        card(entry)
                        if entry.canResizeAllDayRange {
                            CalendarAllDayResizeHandle(entry: entry, edge: .end, calendar: calendar, context: resize, edit: edit)
                        }
                    }.frame(height: Self.cardHeight)
                } else {
                    Color.clear.frame(height: Self.cardHeight).allowsHitTesting(false)
                }
            }
            if layout.hiddenCount > 0 {
                Button("+\(layout.hiddenCount) more") { more = true }.buttonStyle(.plain)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .sheet(isPresented: $more) {
                        VStack(spacing: 12) {
                            HStack {
                                Text(CalendarText.date(day, "EEEE MMM d", calendar: calendar)).font(.headline)
                                Spacer()
                                Button("Done") { more = false }.keyboardShortcut(.cancelAction)
                            }
                            ScrollView { VStack(spacing: 5) { ForEach(layout.entries) { card($0) } } }
                        }.padding(16).frame(width: 300, height: min(420, CGFloat(layout.entries.count) * 30 + 80))
                    }
            }
            Spacer(minLength: 0)
        }.padding(Self.spacing).frame(maxWidth: .infinity)
    }
    private func card(_ entry: CalendarEntry) -> some View {
        CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, showItemIcons: options.showsIcon(for: entry), compact: true,
            open: open, complete: complete, edit: edit).calendarDraggable(entry)
    }
}

struct CalendarYearView: View {
    var focus: Date
    var entries: [CalendarEntry]
    var calendar: Calendar
    var style: CalendarYearStyle
    var selectMonth: (Date) -> Void
    var preview: (Date) -> Void
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
                            width: width, height: rowHeight, selectMonth: selectMonth, preview: preview, select: select)
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
    var preview: (Date) -> Void
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
                        .accessibilityAction(named: Text("Preview Scheduled Items")) { preview(day) }
                        .contextMenu { Button("Preview Scheduled Items") { preview(day) } }
                }
            }.padding(.horizontal, width * 0.063).padding(.top, height * 0.025)
            Spacer(minLength: 0)
        }.frame(height: height)
    }
}

struct CalendarYearDayPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let day: Date
    let projection: CalendarProjectionResult
    let listNames: [UUID: String]
    let calendar: Calendar
    let openWeek: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(CalendarText.date(day, "EEEE MMMM d y", calendar: calendar)).font(.headline)
            if projection.entries.isEmpty {
                Text("No scheduled items for this date").foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(projection.entries) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(Color(hex: entry.color)).frame(width: 7, height: 7).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title).strikethrough(entry.isCompleted)
                                    let details = CalendarEntryDetails(entry: entry, listNames: listNames, calendar: calendar)
                                    Text(details.text + (entry.isProjected ? " · Forecast" : ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.accessibilityElement(children: .combine)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: min(310, max(52, CGFloat(projection.entries.count) * 48)))
            }
            if !projection.truncatedTaskIDs.isEmpty {
                Text("Some repeat previews reach the preview limit.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Open Week") { dismiss(); openWeek() }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }.padding(18).frame(width: 365)
    }
}

struct CalendarAgendaView: View {
    var days: [Date]
    var entries: [CalendarEntry]
    var calendar: Calendar
    var options: TaskCalendarOptions
    var open: (UUID) -> Void
    var complete: (CalendarEntry) -> Void
    var edit: (CalendarEntry) -> Void
    var create: (Date) -> Void
    var canExtend: Bool
    var showMore: () -> Void
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
                                CalendarEntryView(entry: entry, style: options.itemStyle, calendar: calendar, showItemIcons: options.showsIcon(for: entry),
                                    open: open, complete: complete, edit: edit).fixedSize(horizontal: false, vertical: true).calendarDraggable(entry)
                            }
                        }
                    }
                }
                if let last = days.last {
                    HStack {
                        Text("Through " + CalendarText.date(last, "MMM d yyyy", calendar: calendar))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if canExtend { Button("Show more", action: showMore).accessibilityIdentifier("agendaShowMore") }
                    }
                }
            }.padding(22)
        }
    }
}
