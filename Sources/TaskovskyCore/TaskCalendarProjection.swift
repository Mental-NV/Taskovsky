import Foundation

public enum TaskCalendarProjection {
    public static func taskCalendar(_ task: TaskItem, fallback: Calendar) -> Calendar {
        var result = fallback
        if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { result.timeZone = zone }
        return result
    }
    public static func color(for task: TaskItem, data: WorkspaceData, by mode: CalendarColorMode,
                             overrides: CalendarColorSource.Overrides = .init()) -> String {
        switch mode {
        case .priority:
            switch task.priority {
            case .high: return "#E65757"; case .medium: return "#E6A53A"
            case .low: return "#5B8DEF"; case .none: return "#7C6CF2"
            }
        case .tag:
            if let tag = task.tagIDs.compactMap({ id in data.tags.first { $0.id == id } }).first {
                return overrides[.tag(tag.id)] ?? tag.color
            }
            fallthrough
        case .list:
            if let list = task.listID.flatMap({ id in data.lists.first { $0.id == id } }) {
                return overrides[.list(list.id)] ?? list.color
            }
            return overrides[.inbox] ?? "#7C6CF2"
        }
    }
    /// Projection never creates records or completes a task. Repeat previews
    /// use the recurrence engine's nominal cursor and remaining series count.
    /// Completion-anchored previews assume completion at the scheduled time.
    public static func project(data: WorkspaceData, range: DateInterval, options: TaskCalendarOptions,
                               calendar: Calendar, traversalLimit: Int = 5_000) -> CalendarProjectionResult {
        var entries: [CalendarEntry] = []
        var truncated = Set<UUID>()
        let limit = min(5_000, max(1, traversalLimit))
        let predecessors = Set(data.tasks.compactMap(\.recurrenceSourceID))
        for original in data.tasks where options.includes(original, data: data) {
            let recurrence = original.recurrenceSchedule
            guard original.dueDate != nil, let initialDue = recurrence.dueDate,
                  options.showCompleted || (original.completedAt == nil && original.wontDoAt == nil) else { continue }
            var cursor = recurrence
            let local = taskCalendar(original, fallback: calendar)
            for index in 0..<limit {
                guard let due = cursor.dueDate else { break }
                var entry = makeEntry(index == 0 ? original : cursor, originalID: original.id, projected: index > 0,
                                      data: data, options: options, calendar: calendar)
                // A current occurrence can land on the exact instant of a forecast.
                if index > 0, due == original.dueDate { entry.id += ":forecast" }
                if entry.overlaps(range) {
                    entries.append(entry)
                    if options.showChecklistItems {
                        for item in original.checklist {
                            let completed = entry.isProjected ? false : item.isCompleted
                            guard options.showCompleted || !completed else { continue }
                            var child = entry
                            child.id += ":check:\(item.id)"; child.checklistID = item.id
                            child.title = item.title; child.isCompleted = completed
                            entries.append(child)
                        }
                    }
                }
                guard options.showRepeatCycles, original.isRepeating,
                      original.completedAt == nil, original.wontDoAt == nil,
                      !predecessors.contains(original.id),
                      forecastCanContinue(from: cursor, displayed: entry, original: original,
                                          before: range.end, data: data, options: options, calendar: calendar) else { break }
                let next: Date
                if let rule = cursor.customRecurrence, rule.isValid {
                    if rule.anchor == .completionDate {
                        guard let candidate = rule.nextOccurrence(after: due, completedAt: due, calendar: local, occurrenceIndex: cursor.occurrenceIndex) else { break }
                        next = candidate; cursor.recurrenceNominalDate = nil
                    } else {
                        guard let step = rule.nextDueDateStep(after: due, nominalBase: cursor.recurrenceNominalDate, calendar: local, occurrenceIndex: cursor.occurrenceIndex) else { break }
                        next = step.adjusted; cursor.recurrenceNominalDate = step.nominal
                    }
                    cursor.occurrenceIndex += 1
                } else {
                    guard let candidate = LegacyRecurrence.nextDate(after: due, rule: cursor.recurrence,
                        anchorDay: cursor.recurrenceAnchorDay ?? local.component(.day, from: initialDue),
                        anchorMonth: cursor.recurrenceAnchorMonth ?? local.component(.month, from: initialDue), calendar: local) else { break }
                    next = candidate
                }
                guard next > due,
                      cursor.recurrenceEndDate.map({ local.startOfDay(for: next) <= local.startOfDay(for: $0) }) ?? true else { break }
                cursor.dueDate = next
                if let window = recurrence.scheduledDuration?.validated(in: local) {
                    cursor.scheduledDuration = window.anchoredEnd(at: next, calendar: local)
                }
                if index == limit - 1,
                   makeEntry(cursor, originalID: original.id, projected: true, data: data, options: options, calendar: calendar).start < range.end {
                    truncated.insert(original.id)
                }
            }
        }
        entries.sort {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.end != $1.end { return $0.end > $1.end }
            return $0.id < $1.id
        }
        return CalendarProjectionResult(entries: entries, truncatedTaskIDs: truncated)
    }

    private static func forecastCanContinue(from cursor: TaskItem, displayed: CalendarEntry, original: TaskItem,
                                            before end: Date, data: WorkspaceData, options: TaskCalendarOptions,
                                            calendar: Calendar) -> Bool {
        if displayed.isProjected || original.originalOccurrenceSchedule == nil { return displayed.start < end }
        let cadence = makeEntry(cursor, originalID: original.id, projected: false, data: data, options: options, calendar: calendar)
        return cadence.start < end
    }
    private static func makeEntry(_ task: TaskItem, originalID: UUID, projected: Bool, data: WorkspaceData,
                                  options: TaskCalendarOptions, calendar: Calendar) -> CalendarEntry {
        let due = task.dueDate!
        let local = taskCalendar(task, fallback: calendar)
        let window = task.scheduledDuration?.validated(in: local)
        let allDay = window?.isAllDay ?? !task.hasDueTime
        let start: Date
        let end: Date
        if allDay {
            start = CalendarDates.civilDay(window?.start ?? due, from: local, to: calendar)
            let inclusiveEnd = CalendarDates.civilDay(window?.end ?? due, from: local, to: calendar)
            end = calendar.date(byAdding: .day, value: 1, to: inclusiveEnd) ?? inclusiveEnd.addingTimeInterval(86_400)
        } else {
            start = window?.start ?? due
            // Point tasks have a visible hit area, not an invented stored duration.
            if let window, window.end > start { end = window.end }
            else {
                let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)) ?? start.addingTimeInterval(86_400)
                end = min(midnight, start.addingTimeInterval(15 * 60))
            }
        }
        return CalendarEntry(id: "\(originalID):\(due.timeIntervalSinceReferenceDate)", taskID: originalID,
            title: task.title, start: start, end: end, due: due, isAllDay: allDay, isProjected: projected,
            isCompleted: task.completedAt != nil || task.wontDoAt != nil, isNote: task.kind == .note,
            hasDuration: window != nil,
            color: color(for: task, data: data, by: options.colorBy, overrides: options.sourceColors), listID: task.listID)
    }
    public static func arrangementTasks(data: WorkspaceData, options: TaskCalendarOptions, overdue: Bool = false,
                                        now: Date = Date(), calendar: Calendar,
                                        selection: CalendarArrangeSelection = .calendar) -> [TaskItem] {
        var scope = options
        switch selection {
        case .calendar: break
        case .inbox: scope.listIDs = []; scope.includeInbox = true; scope.tagIDs = []
        case .list(let id): scope.listIDs = [id]; scope.includeInbox = false; scope.tagIDs = []
        }
        return data.tasks.filter { task in
            guard scope.includes(task, data: data), task.completedAt == nil, task.wontDoAt == nil else { return false }
            if selection != .calendar && !options.tagIDs.isEmpty && !options.matchesSelectedTags(task, data: data) { return false }
            if let due = task.dueDate {
                let local = taskCalendar(task, fallback: calendar)
                let allDay = task.scheduledDuration?.validated(in: local)?.isAllDay ?? !task.hasDueTime
                let displayedDue = allDay ? CalendarDates.civilDay(due, from: local, to: calendar) : due
                return overdue && displayedDue < calendar.startOfDay(for: now)
            }
            return true
        }
    }

    public static func arrangementGroups(_ tasks: [TaskItem], data: WorkspaceData,
                                         grouping: CalendarColorMode) -> [(name: String, tasks: [TaskItem])] {
        let groups = Dictionary(grouping: tasks) { task in
            switch grouping {
            case .list: task.listID.flatMap { id in data.lists.first { $0.id == id }?.name } ?? "Inbox"
            case .tag: task.tagIDs.first.flatMap { id in data.tags.first { $0.id == id }?.name } ?? "No Tags"
            case .priority: task.priority.rawValue.capitalized
            }
        }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

}

public struct CalendarDayPreview: Identifiable, Sendable {
    public let day: Date
    public var id: Date { day }

    public init(_ date: Date, calendar: Calendar) {
        day = calendar.startOfDay(for: date)
    }

    public func project(data: WorkspaceData, options: TaskCalendarOptions, calendar: Calendar) -> CalendarProjectionResult {
        guard let range = calendar.dateInterval(of: .day, for: day) else {
            return CalendarProjectionResult(entries: [], truncatedTaskIDs: [])
        }
        return TaskCalendarProjection.project(data: data, range: range, options: options, calendar: calendar)
    }
}

public struct CalendarAllDayPlacement: Identifiable, Equatable, Sendable {
    public let entry: CalendarEntry
    public let firstDay: Int
    public let dayCount: Int
    public let lane: Int
    public let continuesBefore: Bool
    public let continuesAfter: Bool
    public var id: String { entry.id }
}

public enum CalendarAllDayLayout {
    /// Projects one visible run of consecutive civil days. Month passes
    /// one week at a time so a range continues on the following row.
    public static func placements(entries: [CalendarEntry], days: [Date], calendar: Calendar) -> [CalendarAllDayPlacement] {
        let starts = days.map { calendar.startOfDay(for: $0) }
        guard let first = starts.first, let last = starts.last,
              let rangeEnd = calendar.date(byAdding: .day, value: 1, to: last) else { return [] }
        let boundaries = starts + [rangeEnd]
        let visible = entries.filter { $0.isAllDay && $0.start < rangeEnd && $0.end > first && $0.start < $0.end }
            .sorted {
                if $0.start != $1.start { return $0.start < $1.start }
                if $0.end != $1.end { return $0.end > $1.end }
                return $0.id < $1.id
            }
        var occupiedUntil: [Int] = []
        var result: [CalendarAllDayPlacement] = []
        for entry in visible {
            guard let start = starts.indices.first(where: { entry.start < boundaries[$0 + 1] }),
                  let end = starts.indices.last(where: { entry.end > boundaries[$0] }),
                  start <= end else { continue }
            let lane = occupiedUntil.firstIndex(where: { $0 <= start }) ?? occupiedUntil.count
            if lane == occupiedUntil.count { occupiedUntil.append(end + 1) }
            else { occupiedUntil[lane] = end + 1 }
            result.append(CalendarAllDayPlacement(entry: entry, firstDay: start, dayCount: end - start + 1,
                                                 lane: lane, continuesBefore: entry.start < first,
                                                 continuesAfter: entry.end > rangeEnd))
        }
        return result
    }
}

/// Packs one month row. Continuous all-day ranges reserve the same lane
/// across their dates. Other cards fill the remaining slots in each date.
public struct CalendarMonthWeekLayout: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public let entries: [CalendarEntry]
        /// Empty slots align local cards with the week’s spanning bars.
        public let slots: [CalendarEntry?]
        public let hiddenCount: Int
    }

    public let spans: [CalendarAllDayPlacement]
    public let days: [Day]

    public init(entries: [CalendarEntry], dates: [Date], capacity: Int, calendar: Calendar) {
        let capacity = max(0, capacity)
        let ranges = entries.filter { entry in
            guard entry.isAllDay, let next = calendar.date(byAdding: .day, value: 1,
                                                           to: calendar.startOfDay(for: entry.start)) else { return false }
            return entry.end > next
        }
        let placements = CalendarAllDayLayout.placements(entries: ranges, days: dates, calendar: calendar)
        spans = placements.filter { $0.lane < capacity }
        let visibleSpans = spans
        let spanningIDs = Set(placements.map(\.id))
        days = dates.enumerated().map { index, date in
            let next = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let items = entries.filter { $0.start < next && $0.end > date }
            let reserved = Set(visibleSpans.filter {
                index >= $0.firstDay && index < $0.firstDay + $0.dayCount
            }.map(\.lane))
            let local = items.lazy.filter { !spanningIDs.contains($0.id) }
            var remaining = local.makeIterator()
            var slots: [CalendarEntry?] = []
            var localCount = 0
            for lane in 0..<capacity {
                if reserved.contains(lane) {
                    slots.append(nil)
                } else if let item = remaining.next() {
                    slots.append(item)
                    localCount += 1
                } else if reserved.contains(where: { $0 > lane }) {
                    slots.append(nil)
                } else {
                    break
                }
            }
            return Day(entries: items, slots: slots, hiddenCount: items.count - reserved.count - localCount)
        }
    }
}

public struct CalendarTimedPlacement: Identifiable, Equatable, Sendable {
    public var entry: CalendarEntry
    public var startMinute: Double
    public var endMinute: Double
    public var column: Int
    public var columnCount: Int
    public var startIsVisible: Bool
    public var endIsVisible: Bool
    public var resizeMinute: Double
    public var id: String { entry.id }

    public func startResizeTarget(deltaMinutes: Double, day: Date, calendar: Calendar, window: CalendarHourlyWindow) -> Date {
        guard deltaMinutes != 0 else { return entry.start }
        let minute = window.snappedMinute(startMinute + deltaMinutes)
        let proposed = CalendarDates.instant(on: day, minute: minute, calendar: calendar)
        return CalendarScheduling.timedResizeStart(proposed, start: entry.start, end: entry.due)
    }
}
public enum CalendarTimedLayout {
    /// Interval coloring per connected overlap cluster. Adjacent events can
    /// reuse a lane. Midnight boundaries are exclusive; DST uses wall hours.
    public static func placements(entries: [CalendarEntry], day: Date, calendar: Calendar,
                                  window: CalendarHourlyWindow = .full) -> [CalendarTimedPlacement] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let visibleStart = window.firstMinute == 0 ? start : CalendarDates.instant(on: day, minute: window.firstMinute, calendar: calendar)
        let visibleEnd = window.endMinute == 1440 ? end : CalendarDates.instant(on: day, minute: window.endMinute, calendar: calendar)
        func minute(_ date: Date) -> Double {
            if date <= start { return 0 }; if date >= end { return 1_440 }
            let c = calendar.dateComponents([.hour, .minute, .second], from: date)
            return Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        }
        let sorted = entries.filter { !$0.isAllDay && $0.start < visibleEnd && $0.end > visibleStart }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.end != $1.end { return $0.end > $1.end }
            return $0.id < $1.id
        }
        var result: [CalendarTimedPlacement] = [], cluster: [CalendarTimedPlacement] = []
        var laneEnds: [Double] = [], clusterEnd = -1.0
        func flush() {
            let count = max(1, laneEnds.count)
            for var item in cluster { item.columnCount = count; result.append(item) }
            cluster = []; laneEnds = []; clusterEnd = -1
        }
        for entry in sorted {
            let rawStart = minute(entry.start), rawEnd = minute(entry.end)
            let a = max(Double(window.firstMinute), rawStart)
            let b = min(Double(window.endMinute), max(rawStart + 15, rawEnd))
            guard a < b else { continue }
            if a >= clusterEnd { flush() }
            let lane = laneEnds.firstIndex { $0 <= a } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(b) } else { laneEnds[lane] = b }
            cluster.append(CalendarTimedPlacement(entry: entry, startMinute: a, endMinute: b, column: lane,
                                                  columnCount: 1, startIsVisible: entry.start >= visibleStart,
                                                  endIsVisible: entry.end <= visibleEnd,
                                                  resizeMinute: entry.hasDuration ? rawEnd : b))
            clusterEnd = max(clusterEnd, b)
        }
        flush()
        return result
    }
}
