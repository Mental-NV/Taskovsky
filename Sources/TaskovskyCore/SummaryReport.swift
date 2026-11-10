import Foundation

public struct SummaryReportOptions: Equatable, Sendable {
    public enum Period: String, CaseIterable, Sendable {
        case thisWeek = "This Week", lastWeek = "Last Week", thisMonth = "This Month", today = "Today", custom = "Custom"
    }
    public enum Grouping: String, CaseIterable, Sendable {
        case status = "By Completion Status", list = "By List", date = "By Date"
    }
    public enum Field: String, CaseIterable, Sendable {
        case date = "Date", list = "List", description = "Description", tags = "Tags", priority = "Priority"
    }

    public var period: Period
    public var customStart: Date
    public var customEnd: Date
    public var listIDs: Set<UUID>
    public var status: FilterStatus
    public var grouping: Grouping
    public var fields: Set<Field>
    public var nextPeriod: Bool

    public init(period: Period = .thisWeek, customStart: Date, customEnd: Date, listIDs: Set<UUID> = [],
                status: FilterStatus = .all, grouping: Grouping = .status,
                fields: Set<Field> = [.date, .list, .description], nextPeriod: Bool = false) {
        self.period = period
        self.customStart = customStart
        self.customEnd = customEnd
        self.listIDs = listIDs
        self.status = status
        self.grouping = grouping
        self.fields = fields
        self.nextPeriod = nextPeriod
    }

    public func interval(now: Date, calendar: Calendar) -> DateInterval {
        let fallback = DateInterval(start: now, duration: 0)
        switch period {
        case .today: return calendar.dateInterval(of: .day, for: now) ?? fallback
        case .thisWeek: return calendar.dateInterval(of: .weekOfYear, for: now) ?? fallback
        case .lastWeek:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: now),
                  let start = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start) else { return fallback }
            return DateInterval(start: start, end: week.start)
        case .thisMonth: return calendar.dateInterval(of: .month, for: now) ?? fallback
        case .custom:
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            let last = calendar.startOfDay(for: max(customStart, customEnd))
            guard let end = calendar.date(byAdding: .day, value: 1, to: last) else { return fallback }
            return DateInterval(start: start, end: end)
        }
    }

    fileprivate func nextEnd(after interval: DateInterval, calendar: Calendar) -> Date {
        let component: Calendar.Component
        let count: Int
        switch period {
        case .today: component = .day; count = 1
        case .thisWeek, .lastWeek: component = .weekOfYear; count = 1
        case .thisMonth: component = .month; count = 1
        case .custom:
            component = .day
            count = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
        }
        return calendar.date(byAdding: component, value: count, to: interval.end) ?? interval.end
    }
}

public struct SummaryReport: Sendable {
    public let range: String
    public let text: String
    public var noteTitle: String { "Summary " + range }

    public static func rangeLabel(for interval: DateInterval, calendar: Calendar) -> String {
        let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(dayHeading(interval.start, calendar: calendar)) – \(dayHeading(last, calendar: calendar))"
    }

    public static func generate(from data: WorkspaceData, options: SummaryReportOptions, now: Date,
                                calendar: Calendar) -> Self {
        let interval = options.interval(now: now, calendar: calendar)
        let range = rangeLabel(for: interval, calendar: calendar)
        func listName(_ task: TaskItem) -> String { data.lists.first { $0.id == task.listID }?.name ?? "Inbox" }
        func inPeriod(_ date: Date?) -> Bool { date.map { $0 >= interval.start && $0 < interval.end } ?? false }
        func statusMatches(_ task: TaskItem) -> Bool {
            switch options.status {
            case .all: true
            case .active: task.completedAt == nil && task.wontDoAt == nil
            case .completed: task.completedAt != nil
            case .wontDo: task.wontDoAt != nil
            }
        }
        func taskLine(_ task: TaskItem) -> String {
            var fields: [String] = []
            if options.fields.contains(.date), let due = task.dueDate { fields.append(dueLabel(task, date: due, calendar: calendar)) }
            if options.fields.contains(.list) { fields.append(listName(task)) }
            if options.fields.contains(.tags) {
                let names = data.tags.filter { task.tagIDs.contains($0.id) }.map { "#" + $0.name }
                if !names.isEmpty { fields.append(names.joined(separator: " ")) }
            }
            if options.fields.contains(.priority), task.priority != .none {
                fields.append(task.priority.rawValue.capitalized + " priority")
            }
            var line = "- " + task.title + (fields.isEmpty ? "" : " (" + fields.joined(separator: " · ") + ")")
            if options.fields.contains(.description), !task.body.isEmpty {
                line += "\n  " + task.body.replacingOccurrences(of: "\n", with: "\n  ")
            }
            return line
        }

        let eligible = data.tasks.filter { task in
            let selected = options.listIDs.contains(task.listID ?? TaskFilter.inboxListID)
            return task.deletedAt == nil && task.kind == .task && (options.listIDs.isEmpty || selected) &&
                statusMatches(task) && (selected || !SmartListEligibility.isExcludedFromSmart(task, lists: data.lists))
        }
        let current = eligible.filter { inPeriod($0.dueDate) || inPeriod($0.completedAt) || inPeriod($0.wontDoAt) }
        let sections: [(String, [TaskItem])]
        switch options.grouping {
        case .status:
            sections = [("Undone", current.filter { $0.completedAt == nil && $0.wontDoAt == nil }),
                        ("Completed", current.filter { $0.completedAt != nil }),
                        ("Won't Do", current.filter { $0.wontDoAt != nil })]
        case .list:
            sections = Set(current.map(listName)).sorted().map { name in (name, current.filter { listName($0) == name }) }
        case .date:
            func date(_ task: TaskItem) -> Date { task.dueDate ?? task.completedAt ?? task.wontDoAt ?? interval.start }
            let days = Set(current.map { calendar.startOfDay(for: date($0)) }).sorted()
            sections = days.map { day in
                (dayHeading(day, calendar: calendar), current.filter { calendar.isDate(date($0), inSameDayAs: day) })
            }
        }
        var lines = ["Summary · " + range]
        for (name, tasks) in sections where !tasks.isEmpty {
            lines.append("\n" + name + "\n" + tasks.map(taskLine).joined(separator: "\n"))
        }
        if options.nextPeriod {
            let nextEnd = options.nextEnd(after: interval, calendar: calendar)
            let upcoming = eligible.filter { task in
                task.completedAt == nil && task.wontDoAt == nil &&
                    task.dueDate.map { $0 >= interval.end && $0 < nextEnd } == true
            }
            if !upcoming.isEmpty {
                lines.append("\nNext Period Tasks\n" + upcoming.map(taskLine).joined(separator: "\n"))
            }
        }
        return Self(range: range, text: lines.joined(separator: "\n"))
    }

    private static func dayHeading(_ date: Date, calendar: Calendar) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                        calendar: calendar, timeZone: calendar.timeZone))
    }

    private static func dueLabel(_ task: TaskItem, date: Date, calendar: Calendar) -> String {
        let zone = TaskCalendarProjection.taskCalendar(task, fallback: calendar).timeZone
        let day = DateFormatter()
        day.timeZone = zone
        day.setLocalizedDateFormatFromTemplate("d MMM")
        let label = day.string(from: date)
        guard task.hasDueTime else { return label }
        let time = DateFormatter()
        time.timeZone = zone
        time.timeStyle = .short
        let suffix = zone.identifier == calendar.timeZone.identifier ? "" : " " + (zone.abbreviation(for: date) ?? zone.identifier)
        return label + " " + time.string(from: date) + suffix
    }
}
