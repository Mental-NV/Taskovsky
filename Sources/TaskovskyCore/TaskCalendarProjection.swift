import Foundation

public enum TaskCalendarProjection {
    public static func taskCalendar(_ task: TaskItem, fallback: Calendar) -> Calendar {
        var result = fallback
        if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { result.timeZone = zone }
        return result
    }
    public static func color(for task: TaskItem, data: WorkspaceData, by mode: CalendarColorMode) -> String {
        switch mode {
        case .priority:
            switch task.priority {
            case .high: return "#E65757"; case .medium: return "#E6A53A"
            case .low: return "#5B8DEF"; case .none: return "#7C6CF2"
            }
        case .tag:
            if let tag = task.tagIDs.compactMap({ id in data.tags.first { $0.id == id } }).first { return tag.color }
            fallthrough
        case .list: return task.listID.flatMap { id in data.lists.first { $0.id == id }?.color } ?? "#7C6CF2"
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
        for original in data.tasks where options.includes(original, data: data) {
            guard let initialDue = original.dueDate,
                  options.showCompleted || (original.completedAt == nil && original.wontDoAt == nil) else { continue }
            var cursor = original
            let local = taskCalendar(original, fallback: calendar)
            for index in 0..<limit {
                guard let due = cursor.dueDate else { break }
                let entry = makeEntry(cursor, originalID: original.id, projected: index > 0, data: data, options: options, calendar: calendar)
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
                      entry.start < range.end else { break }
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
                if let window = original.scheduledDuration?.validated(in: local) {
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
            color: color(for: task, data: data, by: options.colorBy), listID: task.listID)
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

public struct CalendarTimedPlacement: Identifiable, Equatable, Sendable {
    public var entry: CalendarEntry
    public var startMinute: Double
    public var endMinute: Double
    public var column: Int
    public var columnCount: Int
    public var id: String { entry.id }
}
public enum CalendarTimedLayout {
    /// Interval coloring per connected overlap cluster. Adjacent events can
    /// reuse a lane. Midnight boundaries are exclusive; DST uses wall hours.
    public static func placements(entries: [CalendarEntry], day: Date, calendar: Calendar) -> [CalendarTimedPlacement] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        func minute(_ date: Date) -> Double {
            if date <= start { return 0 }; if date >= end { return 1_440 }
            let c = calendar.dateComponents([.hour, .minute, .second], from: date)
            return Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        }
        let sorted = entries.filter { !$0.isAllDay && $0.start < end && $0.end > start }.sorted {
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
            let a = minute(entry.start), b = min(1_440, max(a + 15, minute(entry.end)))
            if a >= clusterEnd { flush() }
            let lane = laneEnds.firstIndex { $0 <= a } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(b) } else { laneEnds[lane] = b }
            cluster.append(CalendarTimedPlacement(entry: entry, startMinute: a, endMinute: b, column: lane, columnCount: 1))
            clusterEnd = max(clusterEnd, b)
        }
        flush()
        return result
    }
}
