import Foundation

public enum TaskTimelineScope: Hashable, Sendable {
    case list(UUID), folder(UUID), filter(UUID)

    public init?(destination: TaskDestination, data: WorkspaceData) {
        switch destination {
        case .list(let id) where data.lists.contains(where: { $0.id == id && !$0.isArchived }): self = .list(id)
        case .folder(let id) where data.folders.contains(where: { $0.id == id }): self = .folder(id)
        case .filter(let id) where data.filters.contains(where: { $0.id == id }): self = .filter(id)
        default: return nil
        }
    }

    public func captureDestinations(in data: WorkspaceData) -> [TaskDestination] {
        switch self {
        case .list(let id):
            return data.lists.contains { $0.id == id && !$0.isArchived && $0.kind == .task } ? [.list(id)] : []
        case .folder(let id):
            guard data.folders.contains(where: { $0.id == id }) else { return [] }
            return data.lists.filter { $0.folderID == id && !$0.isArchived && $0.kind == .task }.map { .list($0.id) }
        case .filter(let id):
            return data.filters.contains { $0.id == id } ? [.filter(id)] : []
        }
    }

    fileprivate func tasks(in data: WorkspaceData, now: Date, calendar: Calendar) -> [TaskItem] {
        let destination: TaskDestination
        switch self {
        case .list(let id): destination = .list(id)
        case .folder(let id): destination = .folder(id)
        case .filter(let id): destination = .filter(id)
        }
        guard Self(destination: destination, data: data) != nil else { return [] }
        return destination.matchingTasks(in: data, now: now, calendar: calendar)
            .filter { !SmartListEligibility.isArchived($0, lists: data.lists) }
    }
}

public enum TaskTimelineScale: String, CaseIterable, Sendable {
    case day, week, month

    public var label: String { rawValue.capitalized }

    public func page(from focus: Date, direction: Int, calendar: Calendar) -> Date {
        let start = window(focus: focus, calendar: calendar).dates.first ?? focus
        switch self {
        case .day: return calendar.date(byAdding: .day, value: 14 * direction, to: start) ?? focus
        case .week: return calendar.date(byAdding: .day, value: 56 * direction, to: start) ?? focus
        case .month: return calendar.date(byAdding: .month, value: 6 * direction, to: start) ?? focus
        }
    }

    public func window(focus: Date, calendar: Calendar) -> TaskTimelineWindow {
        let first: Date
        let days: Int
        switch self {
        case .day:
            first = calendar.startOfDay(for: focus)
            days = 14
        case .week:
            first = CalendarDates.weekStart(focus, calendar: calendar)
            days = 56
        case .month:
            first = CalendarDates.monthStart(focus, calendar: calendar)
            let end = calendar.date(byAdding: .month, value: 6, to: first) ?? first
            days = calendar.dateComponents([.day], from: first, to: end).day ?? 0
        }
        let dates = CalendarDates.days(from: first, count: days, calendar: calendar)
        let marks = dates.enumerated().compactMap { index, date -> Date? in
            switch self {
            case .day: return date
            case .week: return index.isMultiple(of: 7) ? date : nil
            case .month: return calendar.component(.day, from: date) == 1 ? date : nil
            }
        }
        return TaskTimelineWindow(dates: dates, marks: marks, calendar: calendar)
    }
}

public struct TaskTimelineZoom: Equatable, Sendable {
    public static let standard = Self(factor: 1)
    public let factor: Double
    private static let range = 0.75...3.0

    private init(factor: Double) { self.factor = factor }

    public var percent: Int { Int((factor * 100).rounded()) }
    public var canZoomIn: Bool { factor < Self.range.upperBound }
    public var canZoomOut: Bool { factor > Self.range.lowerBound }

    public func scaled(by multiplier: Double) -> Self {
        guard multiplier.isFinite, multiplier > 0 else { return self }
        return Self(factor: min(Self.range.upperBound, max(Self.range.lowerBound, factor * multiplier)))
    }
}

public struct TaskTimelineZoomAnchor: Equatable, Sendable {
    private let dayOffset: Double
    private let viewportX: Double

    public init(contentX: Double, dayWidth: Double, viewportX: Double) {
        dayOffset = contentX / dayWidth
        self.viewportX = viewportX
    }

    public func viewportOrigin(contentStart: Double, dayWidth: Double) -> Double {
        contentStart + dayOffset * dayWidth - viewportX
    }
}

public struct TaskTimelineWindow: Equatable, Sendable {
    public let dates: [Date]
    public let marks: [Date]
    let calendar: Calendar
    public var interval: DateInterval? { CalendarDates.interval(for: dates, calendar: calendar) }

    /// Each civil day occupies one equal column. Fractions within a day
    /// use its real elapsed length so DST does not move a date boundary.
    public func offset(of instant: Date) -> Double {
        guard let interval else { return 0 }
        let clipped = min(interval.end, max(interval.start, instant))
        let day = calendar.startOfDay(for: clipped)
        let elapsedDays = calendar.dateComponents([.day], from: interval.start, to: day).day ?? 0
        guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else {
            return Double(elapsedDays)
        }
        return Double(elapsedDays) + clipped.timeIntervalSince(day) / next.timeIntervalSince(day)
    }

    public func date(at offset: Double) -> Date? {
        guard offset.isFinite, offset >= 0, offset <= Double(dates.count),
              let interval else { return nil }
        let index = Int(offset)
        guard index < dates.count else { return interval.end }
        let start = dates[index]
        let end = index + 1 < dates.count ? dates[index + 1] : interval.end
        return start.addingTimeInterval((offset - Double(index)) * end.timeIntervalSince(start))
    }

    public func captureDay(at offset: Double) -> Date? {
        guard offset.isFinite, offset >= 0, offset < Double(dates.count) else { return nil }
        return dates[Int(offset)]
    }

    public func arrange(at offset: Double, scale: TaskTimelineScale) -> CalendarScheduleOperation? {
        guard let day = captureDay(at: offset) else { return nil }
        if scale != .day { return .setPoint(date: day, allDay: true) }
        guard let instant = snappedQuarterHour(at: offset) else { return nil }
        return .setPoint(date: instant, allDay: false)
    }

    private func snappedQuarterHour(at offset: Double) -> Date? {
        guard let interval, let proposed = date(at: offset), proposed < interval.end else { return nil }
        let day = calendar.startOfDay(for: proposed)
        let quarterHour = proposed.timeIntervalSince(day) / 900
        let snapped = day.addingTimeInterval(quarterHour.rounded() * 900)
        return snapped < interval.end ? snapped : nil
    }

    public func adjust(_ adjustment: TaskTimelineAdjustment, entry: CalendarEntry, by displacement: Double,
                       scale: TaskTimelineScale) -> TaskTimelineScheduleChange? {
        guard entry.canSchedule, let interval, displacement.isFinite,
              abs(displacement) <= Double(dates.count),
              adjustment == .move || entry.hasDuration else { return nil }
        let anchor = adjustment == .move ? entry.start : entry.due
        guard anchor >= interval.start,
              anchor < interval.end || (adjustment == .resizeEnd && anchor == interval.end) else { return nil }
        let target: Date
        if entry.isAllDay || scale != .day {
            let days = Int(displacement.rounded())
            guard days != 0, let shifted = calendar.date(byAdding: .day, value: days, to: anchor),
                  shifted >= interval.start, shifted < interval.end else { return nil }
            target = shifted
        } else {
            guard let shifted = snappedQuarterHour(at: offset(of: anchor) + displacement) else { return nil }
            target = shifted
        }
        let end: Date
        switch adjustment {
        case .move:
            guard target != anchor else { return nil }
            return TaskTimelineScheduleChange(date: target, operation: .move(start: target, allDay: entry.isAllDay))
        case .resizeEnd:
            end = entry.isAllDay ? max(entry.start, target) : max(entry.start.addingTimeInterval(900), target)
            guard end != anchor else { return nil }
            return TaskTimelineScheduleChange(date: end, operation: .resizeEnd(end))
        }
    }
}

public enum TaskTimelineAdjustment: Sendable {
    case move, resizeEnd
}

public struct TaskTimelineScheduleChange: Sendable {
    public let date: Date
    public let operation: CalendarScheduleOperation
}

public struct TaskTimelineRow: Identifiable, Equatable, Sendable {
    public let entry: CalendarEntry
    public let start: Double
    public let end: Double
    public let isPoint: Bool
    public let continuesBefore: Bool
    public let continuesAfter: Bool
    public var id: UUID { entry.taskID }
}

public struct TaskTimelineGroup: Identifiable, Sendable {
    public enum ID: Hashable, Sendable {
        case inbox, unavailableList, list(UUID), section(list: UUID, section: UUID?)
    }

    public let id: ID
    public let title: String?
    public let rows: [TaskTimelineRow]

    static func project(_ rows: [TaskTimelineRow], scope: TaskTimelineScope, data: WorkspaceData) -> [Self] {
        let byList = Dictionary(grouping: rows, by: { $0.entry.listID })
        let tasks = Dictionary(data.tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let projected = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func groups(for list: TaskList, rows: [TaskTimelineRow], qualified: Bool) -> [Self] {
            if list.sections.isEmpty {
                return [Self(id: .list(list.id), title: qualified ? list.name : nil, rows: rows)]
            }
            let visible = rows.compactMap { tasks[$0.id] }
            return TaskSectionGroup.project(visible, for: list, in: data).compactMap { group in
                let items = group.tasks.compactMap { projected[$0.id] }
                guard !items.isEmpty else { return nil }
                let title = qualified ? list.name + " · " + group.title : group.title
                return Self(id: .section(list: list.id, section: group.id), title: title, rows: items)
            }
        }

        if case .list(let id) = scope {
            guard let list = data.lists.first(where: { $0.id == id }) else { return [] }
            return groups(for: list, rows: rows, qualified: false)
        }

        var result: [Self] = []
        if let inbox = byList[nil] { result.append(Self(id: .inbox, title: "Inbox", rows: inbox)) }
        let available = Set(data.lists.map(\.id))
        for list in data.lists {
            guard let listRows = byList[list.id] else { continue }
            result.append(contentsOf: groups(for: list, rows: listRows, qualified: true))
        }
        let unavailable = rows.filter { $0.entry.listID.map { !available.contains($0) } ?? false }
        if !unavailable.isEmpty {
            result.append(Self(id: .unavailableList, title: "Unavailable List", rows: unavailable))
        }
        return result
    }
}

public struct TaskTimelineProjection: Sendable {
    public let rows: [TaskTimelineRow]
    public let groups: [TaskTimelineGroup]
    public let undated: [TaskItem]
    public let firstScheduledDate: Date?

    public init(scope: TaskTimelineScope, data: WorkspaceData, window: TaskTimelineWindow,
                now: Date = Date(), colorBy: CalendarColorMode = .list) {
        let tasks = scope.tasks(in: data, now: now, calendar: window.calendar)
        undated = tasks.filter { $0.dueDate == nil && $0.completedAt == nil && $0.wontDoAt == nil }
        firstScheduledDate = tasks.compactMap(\.dueDate).min()
        guard let interval = window.interval else { rows = []; groups = []; return }
        var selected = data
        selected.tasks = tasks
        var options = TaskCalendarOptions()
        options.showRepeatCycles = false
        options.colorBy = colorBy
        let projected = TaskCalendarProjection.project(data: selected, range: interval, options: options, calendar: window.calendar)
        rows = projected.entries.compactMap { entry in
            let start = window.offset(of: entry.start)
            let end = entry.hasDuration ? window.offset(of: entry.isAllDay ? entry.end : entry.due) : start
            if !entry.hasDuration && (entry.start < interval.start || entry.start >= interval.end) { return nil }
            return TaskTimelineRow(entry: entry, start: start, end: end, isPoint: !entry.hasDuration || end == start,
                                   continuesBefore: entry.start < interval.start,
                                   continuesAfter: entry.hasDuration && (entry.isAllDay ? entry.end : entry.due) > interval.end)
        }
        groups = TaskTimelineGroup.project(rows, scope: scope, data: data)
    }
}
