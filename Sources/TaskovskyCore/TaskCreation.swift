import Foundation

public struct TaskCreationResult: Sendable {
    public let task: TaskItem
    public let addedTags: [TaskTag]
}

/// Shared Mac capture pipeline. No persistence or network side effects.
public enum TaskCreation {
    public static func make(workspace: WorkspaceData, settings: AppSettings, title: String, listID: UUID? = nil, kind: TaskKind = .task, dueDate: Date? = nil, useDefaultList: Bool = true, preferRecognizedDate: Bool = false, recognizeDates: Bool = true, body: String = "", duration: TaskDurationRange? = nil, now: Date = Date(), id: UUID = UUID(), calendar suppliedCalendar: Calendar? = nil, recognizeTags: Bool = true, createMissingTags: Bool = true, hasDueTime suppliedHasTime: Bool = false, useDefaultDate: Bool = true, ignoredRecognizedTags: Set<UUID> = []) -> TaskCreationResult {
        var data = workspace
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = suppliedCalendar ?? settings.calendar
        var taskDue = dueDate
        var hasDueTime = suppliedHasTime
        if (taskDue == nil || preferRecognizedDate) && settings.dateRecognition && recognizeDates, let recognized = Self.recognizeDate(in: text, calendar: calendar, now: now) {
            taskDue = recognized.date; hasDueTime = recognized.hasTime
            if settings.removeDateText { text.removeSubrange(recognized.range) }
        }
        if taskDue == nil && dueDate == nil && useDefaultDate {
            switch settings.defaultDate { case .none: break; case .today: taskDue = calendar.startOfDay(for: now); case .tomorrow: taskDue = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)); case .dayAfterTomorrow: taskDue = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)); case .nextWeek: taskDue = calendar.dateInterval(of: .weekOfYear, for: now)?.end }
        }
        var tags: [UUID] = []
        if let id = settings.defaultTagID, data.tags.contains(where: { $0.id == id }) { tags.append(id) }
        let matches = recognizeTags ? tagMatches(in: text) : []
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let name = String(text[range].dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let tagID: UUID
            if let tag = data.tags.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) { tagID = tag.id }
            else if createMissingTags { let tag = TaskTag(name: name, color: "#7C6CF2"); data.tags.append(tag); tagID = tag.id }
            else { continue }
            if ignoredRecognizedTags.contains(tagID) { continue }
            if !tags.contains(tagID) { tags.append(tagID) }
            if settings.removeTagText { text.removeSubrange(range) }
        }
        let resolvedList = listID ?? (useDefaultList ? settings.defaultListID.flatMap { id in data.lists.contains(where: { $0.id == id }) ? id : nil } : nil)
        // Never create into an archived list: archived content is read-only,
        // so creation falls back to Inbox. Unknown lists pass through untouched
        // (fail-open: a corrupt reference never drops data).
        let resolvedActive = resolvedList.flatMap { id in data.lists.first(where: { $0.id == id }).map { $0.isArchived ? nil : $0.id } ?? id }
        // Explicit durations win; timed dues otherwise inherit the default
        // block ending at the due instant. All-day dues never gain times
        // silently, and hostile windows (end before start) store as none.
        let minutes = min(max(settings.defaultDurationMinutes, 0), 10_080)
        let defaulted: TaskDurationRange? = {
            guard duration == nil, hasDueTime, minutes > 0, let due = taskDue else { return nil }
            return TaskDurationRange(start: due.addingTimeInterval(-Double(minutes) * 60), end: due)
        }()
        // Duration coherence: an explicit window anchors the due date at
        // its end (a record is never undated with an absolute window, and
        // a mismatched due endpoint loses to the window); without one the
        // recognized/default due stands untouched.
        let schedule = TaskSchedulePolicy.coherentSchedule(dueDate: taskDue, hasDueTime: hasDueTime, window: duration ?? defaulted, calendar: calendar)
        let reminders = schedule.dueDate.map { TaskSchedulePolicy.defaultReminderDates(due: $0, hasTime: schedule.hasDueTime, settings: settings, calendar: calendar) } ?? []
        var task = TaskItem(title: text.trimmingCharacters(in: .whitespacesAndNewlines), body: body, listID: resolvedActive, tagIDs: tags, kind: kind, dueDate: schedule.dueDate, hasDueTime: schedule.hasDueTime, priority: settings.defaultPriority, reminderFollowsSchedule: reminders.isEmpty ? nil : true, timeZoneID: settings.enableTimeZone && schedule.dueDate != nil ? calendar.timeZone.identifier : nil, scheduledDuration: schedule.window)
        task.reminderDates = reminders
        task.id = id; task.createdAt = now; task.updatedAt = now
        return TaskCreationResult(task: task, addedTags: Array(data.tags.dropFirst(workspace.tags.count)))
    }

    private static let tagRegex = try? NSRegularExpression(pattern: "(?<!\\S)#(?:\"[^\"\\r\\n]+\"|[\\p{L}\\p{N}_-]+)")
    private static func tagMatches(in text: String) -> [NSTextCheckingResult] {
        tagRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    }
    public static func existingTagCandidates(in text: String, tags: [TaskTag]) -> [TaskTag] {
        var seen = Set<UUID>()
        return tagMatches(in: text).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let name = String(text[range].dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard let tag = tags.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }), seen.insert(tag.id).inserted else { return nil }
            return tag
        }
    }

    public static func recognizeDate(in text: String, calendar: Calendar, now: Date = Date()) -> (date: Date, hasTime: Bool, range: Range<String.Index>)? {
        let pattern = "(?i)\\b(day after tomorrow|next week|today|tomorrow|in [0-9]+ days?|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\\s+(?:at\\s+)?([0-9]{1,2})(?::([0-9]{2}))?(?:\\s*(am|pm))?)?\\b"
        if let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range, in: text), let phraseRange = Range(match.range(at: 1), in: text) {
            let phrase = text[phraseRange].lowercased(); let start = calendar.startOfDay(for: now)
            let days: Int
            switch phrase { case "today": days = 0; case "tomorrow": days = 1; case "day after tomorrow": days = 2; case "next week": days = calendar.dateInterval(of: .weekOfYear, for: now).map { calendar.dateComponents([.day], from: start, to: $0.end).day ?? 7 } ?? 7; default:
                if phrase.hasPrefix("in ") { days = Int(phrase.split(separator: " ")[1]) ?? 0 }
                else { let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]; let target = (names.firstIndex(of: phrase) ?? 0) + 1; let delta = (target - calendar.component(.weekday, from: now) + 7) % 7; days = delta == 0 ? 7 : delta }
            }
            guard var date = calendar.date(byAdding: .day, value: days, to: start) else { return nil }
            var hasTime = false
            if let hourRange = Range(match.range(at: 2), in: text), let hour = Int(text[hourRange]) {
                let minute = Range(match.range(at: 3), in: text).flatMap { Int(text[$0]) } ?? 0
                let meridiem = Range(match.range(at: 4), in: text).map { text[$0].lowercased() }
                let validHour = meridiem == nil ? (0...23).contains(hour) : (1...12).contains(hour)
                let resolvedHour = meridiem.map { hour % 12 + ($0 == "pm" ? 12 : 0) } ?? hour
                if validHour, minute < 60, let timed = calendar.date(bySettingHour: resolvedHour, minute: minute, second: 0, of: date) { date = timed; hasTime = true }
            }
            var recognizedRange = range
            if !hasTime {
                let prefix = String(text[..<range.lowerBound])
                let timePattern = "(?i)(?:\\bat\\s+([0-9]{1,2})(?::([0-9]{2}))?\\s*(am|pm)?|\\b([0-9]{1,2})(?::([0-9]{2}))\\s*(am|pm)?|\\b([0-9]{1,2})\\s*(am|pm))\\s+$"
                if let timeRegex = try? NSRegularExpression(pattern: timePattern), let timeMatch = timeRegex.firstMatch(in: prefix, range: NSRange(prefix.startIndex..., in: prefix)), let prefixRange = Range(timeMatch.range, in: text) {
                    func part(_ index: Int) -> String? { Range(timeMatch.range(at: index), in: text).map { String(text[$0]).lowercased() } }
                    if let hourString = part(1) ?? part(4) ?? part(7), let hour = Int(hourString) {
                        let minute = Int(part(2) ?? part(5) ?? "0") ?? 0
                        let meridiem = part(3) ?? part(6) ?? part(8)
                        let valid = meridiem == nil ? (0...23).contains(hour) : (1...12).contains(hour)
                        let resolved = meridiem.map { hour % 12 + ($0 == "pm" ? 12 : 0) } ?? hour
                        if valid, minute < 60, let timed = calendar.date(bySettingHour: resolved, minute: minute, second: 0, of: date) {
                            date = timed; hasTime = true; recognizedRange = prefixRange.lowerBound..<range.upperBound
                        }
                    }
                }
            }
            return (date, hasTime, recognizedRange)
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue), let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let date = match.date, let range = Range(match.range, in: text) {
            let hasTime = text[range].range(of: "(?i)\\b[0-9]{1,2}(:[0-9]{2}|\\s*(am|pm))", options: .regularExpression) != nil
            return (hasTime ? date : calendar.startOfDay(for: date), hasTime, range)
        }
        return nil
    }

    public static func fromTemplate(workspace data: WorkspaceData, settings: AppSettings, id: UUID, listID: UUID? = nil, dueDate: Date? = nil, useDefaultList: Bool = true, now: Date = Date(), taskID: UUID = UUID(), calendar suppliedCalendar: Calendar? = nil) -> TaskItem? {
        let calendar = suppliedCalendar ?? settings.calendar
        guard let template = data.templates.first(where: { $0.id == id }) else { return nil }
        let resolvedList = listID ?? (useDefaultList ? settings.defaultListID.flatMap { id in data.lists.contains(where: { $0.id == id }) ? id : nil } : nil)
        // Never instantiate into an archived list: archived content is read-only.
        // Unknown lists pass through untouched (fail-open).
        let resolvedActive = resolvedList.flatMap { id in data.lists.first(where: { $0.id == id }).map { $0.isArchived ? nil : $0.id } ?? id }
        // Duration coherence: onto a due date the template shape re-anchors
        // its end at that date (never `moved(to:)`, which anchors the
        // start); without one an absolute template window still brings its
        // own due, so the record is never undated with an absolute window.
        let window: TaskDurationRange? = {
            guard let shape = template.scheduledDuration?.validated(in: calendar) else { return nil }
            if let due = dueDate { return shape.anchoredEnd(at: due, calendar: calendar) }
            return shape
        }()
        var task = TaskItem(title: template.title, body: template.body, listID: resolvedActive, tagIDs: template.tagIDs.filter { id in data.tags.contains { $0.id == id } }, kind: template.kind, dueDate: dueDate ?? window?.end, hasDueTime: window.map { !$0.isAllDay } ?? false, priority: template.priority, checklist: template.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }, customRecurrence: template.customRecurrence, scheduledDuration: window, richBody: template.richBody?.valid(for: template.body))
        task.id = taskID; task.createdAt = now; task.updatedAt = now
        return task
    }
}

public enum TaskSchedulePolicy {
    public static func defaultReminderDates(due: Date, hasTime: Bool, settings: AppSettings, calendar: Calendar) -> [Date] {
        let dates: [Date]
        if hasTime {
            dates = settings.effectiveTimedReminderDefaults.compactMap { $0.offset.map { due.addingTimeInterval($0) } }
        } else {
            dates = settings.effectiveAllDayReminderDefaults.compactMap { choice in
                let days: Int
                switch choice {
                case .none: return nil
                case .onDay9: days = 0
                case .dayBefore9: days = -1
                case .twoDaysBefore9: days = -2
                case .threeDaysBefore9: days = -3
                case .weekBefore9: days = -7
                }
                guard let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: due)) else { return nil }
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
            }
        }
        return Array(Set(dates)).sorted()
    }

    public static func coherentSchedule(dueDate: Date?, hasDueTime: Bool, window: TaskDurationRange?, calendar: Calendar) -> (dueDate: Date?, hasDueTime: Bool, window: TaskDurationRange?) {
        guard let valid = window?.validated(in: calendar) else { return (dueDate, hasDueTime, nil) }
        return (valid.end, !valid.isAllDay, valid)
    }

}

public enum TaskCaptureValidation: Error, Equatable, Sendable { case emptyTitle, target, tag, template }

/// Editable creation input only; no workspace copy or persistent side effects.
public struct TaskCaptureInput: Codable, Equatable, Sendable {
    public var title = ""
    public var body = ""
    public var kind: TaskKind = .task
    public var listID: UUID?
    public var dueDate: Date?
    public var hasDueTime = false
    public var priority: TaskPriority = .none
    public var tagIDs: [UUID] = []
    public var recognizeDates = true
    public var recognizeTags = true
    public var ignoredRecognizedTagIDs: [UUID] = []
    public private(set) var template: TaskTemplate?
    public private(set) var contextDate: Date?
    public private(set) var dateWasChosen = false
    public private(set) var preserveTemplateDuration = true

    public static func summaryNote(title: String, body: String) -> Self {
        var value = Self()
        value.title = title
        value.body = body
        value.kind = .note
        value.recognizeDates = false
        value.recognizeTags = false
        return value
    }

    public static func start(destination: TaskDestination, calendarDate: Date? = nil, workspace: WorkspaceData,
                             settings: AppSettings, now: Date, calendar: Calendar) -> Self {
        var value = Self()
        let list: TaskList? = { if case .list(let id) = destination { return workspace.lists.first { $0.id == id } }; return nil }()
        value.kind = destination == .notes ? .note : list?.kind ?? .task
        let day = calendar.startOfDay(for: now)
        let contextual = calendarDate.map { calendar.startOfDay(for: $0) } ?? (destination == .today || destination == .week ? day : destination == .tomorrow ? calendar.date(byAdding: .day, value: 1, to: day) : nil)
        value.contextDate = value.kind == .task ? contextual : nil
        let result = TaskCreation.make(workspace: workspace, settings: settings, title: "", listID: list?.id,
                                       kind: value.kind, dueDate: value.contextDate,
                                       useDefaultList: destination != .inbox && list == nil, recognizeDates: false,
                                       now: now, calendar: calendar)
        value.listID = result.task.listID; value.dueDate = result.task.dueDate
        value.hasDueTime = result.task.hasDueTime; value.priority = result.task.priority; value.tagIDs = result.task.tagIDs
        if case .tag(let id) = destination, workspace.tags.contains(where: { $0.id == id }), !value.tagIDs.contains(id) { value.tagIDs.append(id) }
        return value
    }
    public mutating func chooseDate(_ date: Date?, hasTime: Bool = false) {
        dueDate = date; hasDueTime = date != nil && hasTime; dateWasChosen = true; recognizeDates = false
        if date == nil { preserveTemplateDuration = false }
    }
    public mutating func applyTemplate(_ seed: TaskTemplate) {
        var copy = seed; copy.checklist = seed.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }
        template = copy; title = seed.title; body = seed.body; kind = seed.kind; priority = seed.priority; tagIDs = seed.tagIDs
        recognizeDates = false; recognizeTags = false; ignoredRecognizedTagIDs = []; preserveTemplateDuration = true
        if !dateWasChosen { dueDate = contextDate; hasDueTime = false }
    }
    public var protectsBody: Bool { template?.richBody != nil }
    public func task(id: UUID, now: Date, workspace: WorkspaceData, settings: AppSettings, calendar: Calendar, requireTitle: Bool = true) throws -> TaskItem {
        if let listID, !workspace.lists.contains(where: { $0.id == listID && !$0.isArchived }) { throw TaskCaptureValidation.target }
        guard Set(tagIDs).count == tagIDs.count, tagIDs.allSatisfy({ id in workspace.tags.contains { $0.id == id } }) else { throw TaskCaptureValidation.tag }
        var result: TaskItem
        if let seed = template {
            guard seed.richBody == nil || (seed.richBody?.valid(for: seed.body) != nil && body.utf16.elementsEqual(seed.body.utf16)),
                  seed.customRecurrence == nil || seed.customRecurrence?.isValid == true,
                  seed.scheduledDuration == nil || seed.scheduledDuration?.validated(in: calendar) == seed.scheduledDuration else { throw TaskCaptureValidation.template }
            var source = workspace; source.templates = [seed]
            // Template instantiation intentionally does not add quick-entry
            // default reminders/tags or recognize tokens in template content.
            result = TaskCreation.fromTemplate(workspace: source, settings: settings, id: seed.id, listID: listID,
                                               dueDate: dueDate, useDefaultList: false, now: now, taskID: id, calendar: calendar)!
            result.checklist = seed.checklist
            result.title = title.trimmingCharacters(in: .whitespacesAndNewlines); result.body = body
            if dateWasChosen && !preserveTemplateDuration { result.scheduledDuration = nil; result.dueDate = dueDate; result.hasDueTime = hasDueTime }
            else if result.scheduledDuration == nil { result.hasDueTime = hasDueTime }
        } else {
            var config = settings; config.defaultTagID = nil
            let made = TaskCreation.make(workspace: workspace, settings: config, title: title, listID: listID, kind: kind,
                                         dueDate: dueDate, useDefaultList: false, preferRecognizedDate: true,
                                         recognizeDates: recognizeDates, body: body, now: now, id: id, calendar: calendar,
                                         recognizeTags: recognizeTags, createMissingTags: false, hasDueTime: hasDueTime, useDefaultDate: false, ignoredRecognizedTags: Set(ignoredRecognizedTagIDs))
            result = made.task
        }
        result.kind = kind; result.priority = priority
        for tag in tagIDs where !result.tagIDs.contains(tag) { result.tagIDs.append(tag) }
        if template != nil { result.tagIDs = tagIDs }
        guard !requireTitle || !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TaskCaptureValidation.emptyTitle }
        return result
    }
}
