import Foundation

public enum TaskCalendarMode: String, Codable, CaseIterable, Sendable {
    case day, week, month, year, agenda, multiDay, multiWeek
    public var title: String {
        switch self {
        case .day: "Day"; case .week: "Week"; case .month: "Month"; case .year: "Year"
        case .agenda: "Agenda"; case .multiDay: "Multi-Day"; case .multiWeek: "Multi-Week"
        }
    }
    public var isHourly: Bool { self == .day || self == .week || self == .multiDay }
}
public enum CalendarColorMode: String, Codable, CaseIterable, Sendable { case list, tag, priority }
public enum CalendarItemStyle: String, Codable, CaseIterable, Sendable { case filled, outline }

/// Local Calendar scope is independent of smart-list inclusion. Archived
/// lists stay hidden. Missing settings decode to the local defaults.
public struct TaskCalendarOptions: Codable, Equatable, Sendable {
    public var mode: TaskCalendarMode = .week
    public var multiDayCount = 5
    public var multiWeekCount = 2
    public var showSidebar = true
    public var showCompleted = true
    public var showRepeatCycles = true
    public var showChecklistItems = false
    public var colorBy: CalendarColorMode = .list
    public var itemStyle: CalendarItemStyle = .filled
    public var additionalTimeZoneID: String? = nil
    /// Nil = every active list; [] = none. Inbox is controlled separately.
    public var listIDs: [UUID]? = nil
    public var includeInbox = true
    /// Empty = no restriction; selected parent tags include descendants.
    public var tagIDs: [UUID] = []
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case mode, multiDayCount, multiWeekCount, showSidebar, showCompleted, showRepeatCycles,
             showChecklistItems, colorBy, itemStyle, additionalTimeZoneID, listIDs, includeInbox, tagIDs
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = (try? c.decode(TaskCalendarMode.self, forKey: .mode)) ?? mode
        multiDayCount = min(14, max(2, try c.decodeIfPresent(Int.self, forKey: .multiDayCount) ?? multiDayCount))
        multiWeekCount = min(6, max(2, try c.decodeIfPresent(Int.self, forKey: .multiWeekCount) ?? multiWeekCount))
        showSidebar = try c.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? showSidebar
        showCompleted = try c.decodeIfPresent(Bool.self, forKey: .showCompleted) ?? showCompleted
        showRepeatCycles = try c.decodeIfPresent(Bool.self, forKey: .showRepeatCycles) ?? showRepeatCycles
        showChecklistItems = try c.decodeIfPresent(Bool.self, forKey: .showChecklistItems) ?? showChecklistItems
        colorBy = (try? c.decode(CalendarColorMode.self, forKey: .colorBy)) ?? colorBy
        itemStyle = (try? c.decode(CalendarItemStyle.self, forKey: .itemStyle)) ?? itemStyle
        additionalTimeZoneID = try c.decodeIfPresent(String.self, forKey: .additionalTimeZoneID)
        if let id = additionalTimeZoneID, TimeZone(identifier: id) == nil { additionalTimeZoneID = nil }
        listIDs = try c.decodeIfPresent([UUID].self, forKey: .listIDs)
        includeInbox = try c.decodeIfPresent(Bool.self, forKey: .includeInbox) ?? includeInbox
        tagIDs = try c.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
    }
    public func includes(_ task: TaskItem, data: WorkspaceData) -> Bool {
        guard task.deletedAt == nil, !SmartListEligibility.isArchived(task, lists: data.lists) else { return false }
        if let id = task.listID {
            if let listIDs, !listIDs.contains(id) { return false }
        } else if !includeInbox { return false }
        return tagIDs.isEmpty || tagIDs.contains { SmartListEligibility.taskMatchesTag(task, tagID: $0, tags: data.tags) }
    }
}

public enum CalendarDates {
    public static func monthStart(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
    public static func weekStart(_ date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }
    public static func days(from start: Date, count: Int, calendar: Calendar) -> [Date] {
        (0..<max(0, count)).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: start)) }
    }
    public static func visibleDays(focus: Date, mode: TaskCalendarMode, options: TaskCalendarOptions, calendar: Calendar) -> [Date] {
        switch mode {
        case .day: return days(from: focus, count: 1, calendar: calendar)
        case .week: return days(from: weekStart(focus, calendar: calendar), count: 7, calendar: calendar)
        case .multiDay: return days(from: focus, count: min(14, max(2, options.multiDayCount)), calendar: calendar)
        case .multiWeek: return days(from: weekStart(focus, calendar: calendar), count: min(6, max(2, options.multiWeekCount)) * 7, calendar: calendar)
        case .agenda: return days(from: focus, count: 30, calendar: calendar)
        case .month:
            let month = monthStart(focus, calendar: calendar)
            let start = weekStart(month, calendar: calendar)
            let prefix = calendar.dateComponents([.day], from: start, to: month).day ?? 0
            let length = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
            return days(from: start, count: ((prefix + length + 6) / 7) * 7, calendar: calendar)
        case .year:
            let start = calendar.dateInterval(of: .year, for: focus)?.start ?? monthStart(focus, calendar: calendar)
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
            return days(from: start, count: calendar.dateComponents([.day], from: start, to: end).day ?? 365, calendar: calendar)
        }
    }
    public static func interval(for days: [Date], calendar: Calendar) -> DateInterval? {
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        return DateInterval(start: first, end: end)
    }
    public static func navigate(_ date: Date, direction: Int, mode: TaskCalendarMode, options: TaskCalendarOptions, calendar: Calendar) -> Date {
        let component: Calendar.Component
        let amount: Int
        switch mode {
        case .day: component = .day; amount = 1
        case .week: component = .day; amount = 7
        case .multiDay: component = .day; amount = min(14, max(2, options.multiDayCount))
        case .multiWeek: component = .day; amount = min(6, max(2, options.multiWeekCount)) * 7
        case .agenda: component = .day; amount = 30
        case .month: component = .month; amount = 1
        case .year: component = .year; amount = 1
        }
        let base = mode == .month ? monthStart(date, calendar: calendar) : date
        return calendar.date(byAdding: component, value: (direction < 0 ? -amount : amount), to: base) ?? date
    }
    public static func snappedMinute(_ value: Double, step: Int = 15) -> Int {
        guard value.isFinite else { return 0 }
        let step = max(1, step)
        return min(1_440, max(0, Int((min(1_440, max(0, value)) / Double(step)).rounded()) * step))
    }
    /// Wall-clock positions, not seconds since midnight on 23/25-hour days.
    public static func instant(on day: Date, minute: Int, calendar: Calendar) -> Date {
        let minute = min(1_440, max(0, minute))
        if minute == 1_440 { return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) ?? day }
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day,
                             matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) ?? day
    }
    /// All-day dates float by civil date between task and display zones.
    public static func civilDay(_ date: Date, from source: Calendar, to destination: Calendar) -> Date {
        destination.date(from: source.dateComponents([.era, .year, .month, .day], from: date)) ?? destination.startOfDay(for: date)
    }
}

public struct CalendarEntry: Identifiable, Equatable, Sendable {
    public var id: String
    public var taskID: UUID
    public var checklistID: UUID? = nil
    public var title: String
    public var start: Date
    /// Exclusive display end, including all-day spans.
    public var end: Date
    public var due: Date
    public var isAllDay: Bool
    public var isProjected: Bool
    public var isCompleted: Bool
    public var isNote: Bool
    public var hasDuration: Bool = false
    public var color: String
    public var listID: UUID?
    public var canSchedule: Bool { !isProjected && checklistID == nil }
    public func overlaps(_ interval: DateInterval) -> Bool { start < interval.end && end > interval.start }
}

public struct CalendarProjectionResult: Sendable {
    public var entries: [CalendarEntry]
    public var truncatedTaskIDs: Set<UUID>
}
