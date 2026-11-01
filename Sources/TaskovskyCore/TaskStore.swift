import Foundation
import Combine

@MainActor
public final class TaskStore: ObservableObject {
    @Published public private(set) var data: WorkspaceData
    @Published public private(set) var storageError: String?
    @Published public var settings: AppSettings { didSet { saveSettings() } }
    public let fileURL: URL
    private var settingsLoadFailed = false
    private var settingsSaveError: String?
    private var completionSnapshots: [UUID: TaskItem] = [:]
    public var settingsURL: URL { fileURL.deletingLastPathComponent().appendingPathComponent("settings.json") }
    private var blockedByLoadFailure = false
    public var needsRecovery: Bool { blockedByLoadFailure }

    public init(fileURL: URL? = nil, seed: Bool = true) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        let settingsURL = self.fileURL.deletingLastPathComponent().appendingPathComponent("settings.json")
        var settingsError: String?
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            do { self.settings = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: settingsURL)) }
            catch { self.settings = AppSettings(); self.settingsLoadFailed = true; settingsError = "Could not load settings: \(error.localizedDescription). The original file is preserved." }
        } else { self.settings = AppSettings() }
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do {
                self.data = try JSONDecoder().decode(WorkspaceData.self, from: Data(contentsOf: self.fileURL))
                self.storageError = nil
            } catch {
                // Never overwrite a file that failed to load, even after in-memory edits.
                self.data = WorkspaceData()
                self.blockedByLoadFailure = true
                self.storageError = "Could not load workspace: \(error.localizedDescription). Changes are not being saved; the original file is preserved."
            }
        } else {
            self.data = seed ? Self.starterData() : WorkspaceData()
            self.storageError = nil
            if seed { save() }
        }
        if let settingsError { self.storageError = settingsError }
        if seed && !blockedByLoadFailure && !settingsLoadFailed && !settings.hasInstalledBuiltInTemplates {
            let existingNames = Set(data.templates.map { $0.name.lowercased() })
            data.templates.append(contentsOf: TaskTemplate.builtIns.filter { !existingNames.contains($0.name.lowercased()) })
            save()
            // Do not record migration until the workspace has been written successfully.
            if storageError == nil { settings.hasInstalledBuiltInTemplates = true; saveSettings() }
        }
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        do { return try AppMigration.workspaceURL(in: base) }
        catch {
            // Keep using the original data if moving it fails; never start an empty workspace.
            return base.appendingPathComponent(AppMigration.legacyName, isDirectory: true).appendingPathComponent("workspace.json")
        }
    }

    public func save() {
        guard !blockedByLoadFailure else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
            if !settingsLoadFailed { storageError = settingsSaveError }
        } catch { storageError = "Could not save workspace: \(error.localizedDescription)" }
    }

    private func saveSettings() {
        guard !settingsLoadFailed else { return }
        do {
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(settings).write(to: settingsURL, options: .atomic)
            settingsSaveError = nil
        } catch { settingsSaveError = "Could not save settings: \(error.localizedDescription)"; storageError = settingsSaveError }
    }

    /// Backs up an unreadable workspace before saving the current in-memory data.
    /// Returns the backup URL, or nil if recovery could not be performed.
    @discardableResult public func recoverUnreadableWorkspace() -> URL? {
        guard blockedByLoadFailure else { return nil }
        let backup = fileURL.appendingPathExtension("unreadable-\(UUID().uuidString).bak")
        do {
            try FileManager.default.copyItem(at: fileURL, to: backup)
        } catch {
            storageError = "Could not back up the unreadable workspace: \(error.localizedDescription). Changes are not being saved; the original file is preserved."
            return nil
        }
        blockedByLoadFailure = false
        save()
        return backup
    }

    public func updateTask(_ task: TaskItem, applyDefaultReminders: Bool = true) {
        guard let index = data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var task = task
        let old = data.tasks[index]
        if old.dueDate != task.dueDate || old.recurrence != task.recurrence {
            task.recurrenceAnchorDay = nil; task.recurrenceAnchorMonth = nil
        }
        if applyDefaultReminders, task.reminderDates != old.reminderDates, task.reminderFollowsSchedule == old.reminderFollowsSchedule {
            task.reminderFollowsSchedule = false
        }
        if applyDefaultReminders, task.reminderDates == old.reminderDates,
           (old.dueDate != task.dueDate || old.hasDueTime != task.hasDueTime || old.timeZoneID != task.timeZoneID),
           Self.usesDefaultReminder(old, settings: settings), task.reminderFollowsSchedule != false {
            var calendar = settings.calendar
            if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { calendar.timeZone = zone }
            task.reminderDates = task.dueDate.map { Self.defaultReminderDates(due: $0, hasTime: task.hasDueTime, settings: settings, calendar: calendar) } ?? []
            task.reminderFollowsSchedule = true
        }
        task.updatedAt = Date()
        data.tasks[index] = task
        save()
    }

    @discardableResult public func createTask(title: String, listID: UUID? = nil, kind: TaskKind = .task, dueDate: Date? = nil, useDefaultList: Bool = true, preferRecognizedDate: Bool = false, recognizeDates: Bool = true, body: String = "") -> UUID {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = settings.calendar
        var taskDue = dueDate
        var hasDueTime = false
        if (taskDue == nil || preferRecognizedDate) && settings.dateRecognition && recognizeDates, let recognized = Self.recognizeDate(in: text, calendar: calendar) {
            taskDue = recognized.date; hasDueTime = recognized.hasTime
            if settings.removeDateText { text.removeSubrange(recognized.range) }
        }
        if taskDue == nil && dueDate == nil {
            switch settings.defaultDate { case .none: break; case .today: taskDue = calendar.startOfDay(for: Date()); case .tomorrow: taskDue = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())); case .dayAfterTomorrow: taskDue = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date())); case .nextWeek: taskDue = calendar.dateInterval(of: .weekOfYear, for: Date())?.end }
        }
        var tags: [UUID] = []
        if let id = settings.defaultTagID, data.tags.contains(where: { $0.id == id }) { tags.append(id) }
        let regex = try? NSRegularExpression(pattern: "(?<!\\S)#(?:\"[^\"\\r\\n]+\"|[\\p{L}\\p{N}_-]+)")
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let name = String(text[range].dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let tagID: UUID
            if let tag = data.tags.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) { tagID = tag.id }
            else { let tag = TaskTag(name: name, color: "#7C6CF2"); data.tags.append(tag); tagID = tag.id }
            if !tags.contains(tagID) { tags.append(tagID) }
            if settings.removeTagText { text.removeSubrange(range) }
        }
        let resolvedList = listID ?? (useDefaultList ? settings.defaultListID.flatMap { id in data.lists.contains(where: { $0.id == id }) ? id : nil } : nil)
        let reminders = taskDue.map { Self.defaultReminderDates(due: $0, hasTime: hasDueTime, settings: settings, calendar: calendar) } ?? []
        var task = TaskItem(title: text.trimmingCharacters(in: .whitespacesAndNewlines), body: body, listID: resolvedList, tagIDs: tags, kind: kind, dueDate: taskDue, hasDueTime: hasDueTime, priority: settings.defaultPriority, reminderFollowsSchedule: reminders.isEmpty ? nil : true, timeZoneID: settings.enableTimeZone && taskDue != nil ? calendar.timeZone.identifier : nil)
        task.reminderDates = reminders
        if settings.defaultAddTo == .top { data.tasks.insert(task, at: 0) } else { data.tasks.append(task) }; save(); if settings.urlParsing { resolveURLTitle(for: task.id) }; return task.id
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

    public func toggleComplete(id: UUID) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt == nil else { return }
        let now = Date()
        if data.tasks[index].completedAt != nil {
            undoCompletion(id: id); return
        } else {
            data.tasks[index].wontDoAt = nil
            data.tasks[index].completedAt = now
            let original = data.tasks[index]
            var recurrenceCalendar = settings.calendar
            if let zoneID = original.timeZoneID, let zone = TimeZone(identifier: zoneID) { recurrenceCalendar.timeZone = zone }
            if original.recurrence != .none, !data.tasks.contains(where: { $0.recurrenceSourceID == original.id }),
               let due = original.dueDate,
               let next = Self.nextDate(after: due, rule: original.recurrence,
                                        anchorDay: original.recurrenceAnchorDay,
                                        anchorMonth: original.recurrenceAnchorMonth, calendar: recurrenceCalendar),
               original.recurrenceEndDate.map({ recurrenceCalendar.startOfDay(for: next) <= recurrenceCalendar.startOfDay(for: $0) }) ?? true {
                var copy = original
                copy.id = UUID(); copy.dueDate = next; copy.completedAt = nil; copy.deletedAt = nil
                copy.reminderDates = original.reminderDates.map { reminder in
                    guard !original.hasDueTime else { return next.addingTimeInterval(reminder.timeIntervalSince(due)) }
                    let dayOffset = recurrenceCalendar.dateComponents([.day], from: recurrenceCalendar.startOfDay(for: due), to: recurrenceCalendar.startOfDay(for: reminder)).day ?? 0
                    let reminderDay = recurrenceCalendar.date(byAdding: .day, value: dayOffset, to: recurrenceCalendar.startOfDay(for: next)) ?? next
                    let parts = recurrenceCalendar.dateComponents([.hour, .minute, .second], from: reminder)
                    return recurrenceCalendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: parts.second ?? 0, of: reminderDay) ?? reminderDay
                }
                copy.createdAt = now; copy.updatedAt = now
                copy.recurrenceSourceID = original.id
                copy.recurrenceAnchorDay = original.recurrenceAnchorDay ?? recurrenceCalendar.component(.day, from: due)
                copy.recurrenceAnchorMonth = original.recurrenceAnchorMonth ?? recurrenceCalendar.component(.month, from: due)
                copy.checklist = original.checklist.map { ChecklistItem(title: $0.title) }
                data.tasks.append(copy)
                completionSnapshots[id] = copy
            }
        }
        data.tasks[index].updatedAt = now; save()
    }

    public func undoCompletion(id: UUID) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].completedAt != nil else { return }
        data.tasks[index].completedAt = nil; data.tasks[index].updatedAt = Date()
        if let snapshot = completionSnapshots.removeValue(forKey: id), let successor = data.tasks.firstIndex(where: { $0.id == snapshot.id && $0 == snapshot }) { data.tasks.remove(at: successor) }
        save()
    }
    public func markWontDo(id: UUID) { mutateTask(id: id) { $0.wontDoAt = Date(); $0.completedAt = nil } }
    public func reopenTask(id: UUID) {
        if data.tasks.first(where: { $0.id == id })?.completedAt != nil { undoCompletion(id: id) }
        mutateTask(id: id) { $0.wontDoAt = nil; $0.completedAt = nil }
    }
    @discardableResult public func createFilter(_ filter: TaskFilter) -> UUID { data.filters.append(filter); save(); return filter.id }
    public func updateFilter(_ filter: TaskFilter) { guard let i = data.filters.firstIndex(where: { $0.id == filter.id }) else { return }; data.filters[i] = filter; save() }
    public func deleteFilter(id: UUID) { data.filters.removeAll { $0.id == id }; save() }
    @discardableResult public func saveTemplate(from id: UUID, name: String? = nil) -> UUID? {
        guard let task = data.tasks.first(where: { $0.id == id }) else { return nil }
        let template = TaskTemplate(name: name ?? task.title, title: task.title, body: task.body, checklist: task.checklist, priority: task.priority, tagIDs: task.tagIDs, kind: task.kind)
        data.templates.append(template); save(); return template.id
    }
    public func updateTemplate(_ template: TaskTemplate) { if let i = data.templates.firstIndex(where: { $0.id == template.id }) { data.templates[i] = template } else { data.templates.append(template) }; save() }
    public func deleteTemplate(id: UUID) { data.templates.removeAll { $0.id == id }; save() }
    @discardableResult public func createTaskFromTemplate(id: UUID, listID: UUID? = nil, dueDate: Date? = nil, useDefaultList: Bool = true) -> UUID? {
        guard let template = data.templates.first(where: { $0.id == id }) else { return nil }
        let resolvedList = listID ?? (useDefaultList ? settings.defaultListID.flatMap { id in data.lists.contains(where: { $0.id == id }) ? id : nil } : nil)
        let task = TaskItem(title: template.title, body: template.body, listID: resolvedList, tagIDs: template.tagIDs.filter { id in data.tags.contains { $0.id == id } }, kind: template.kind, dueDate: dueDate, priority: template.priority, checklist: template.checklist.map { ChecklistItem(title: $0.title) })
        if settings.defaultAddTo == .top { data.tasks.insert(task, at: 0) } else { data.tasks.append(task) }; save(); return task.id
    }
    public func trashTask(id: UUID) { mutateTask(id: id) { $0.deletedAt = Date() } }
    public func restoreTask(id: UUID) { mutateTask(id: id) { $0.deletedAt = nil } }
    private func mutateTask(id: UUID, _ change: (inout TaskItem) -> Void) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&data.tasks[index]); data.tasks[index].updatedAt = Date(); save()
    }
    @discardableResult public func duplicateTask(id: UUID) -> UUID? {
        guard var copy = data.tasks.first(where: { $0.id == id }) else { return nil }
        let now = Date(); copy.id = UUID(); copy.completedAt = nil; copy.deletedAt = nil
        copy.createdAt = now; copy.updatedAt = now; copy.recurrenceSourceID = nil
        copy.checklist = copy.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }
        data.tasks.append(copy); save(); return copy.id
    }
    @discardableResult public func createList(name: String, color: String, kind: TaskKind = .task, symbol: String? = nil) -> UUID {
        let list = TaskList(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color, kind: kind, symbol: symbol); data.lists.append(list); save(); return list.id
    }
    public func updateList(_ list: TaskList) {
        guard let index = data.lists.firstIndex(where: { $0.id == list.id }) else { return }
        data.lists[index] = list; save()
    }
    public func deleteList(id: UUID) {
        data.lists.removeAll { $0.id == id }
        for i in data.tasks.indices where data.tasks[i].listID == id { data.tasks[i].listID = nil; data.tasks[i].updatedAt = Date() }
        save()
    }
    @discardableResult public func createTag(name: String, color: String) -> UUID {
        let normalized = Self.normalizedTagName(name)
        if let existing = data.tags.first(where: { Self.normalizedTagName($0.name).localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            return existing.id
        }
        let tag = TaskTag(name: normalized, color: color); data.tags.append(tag); save(); return tag.id
    }
    private static func normalizedTagName(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("#") { result.removeFirst(); result = result.trimmingCharacters(in: .whitespacesAndNewlines) }
        return result
    }
    public func updateTag(_ tag: TaskTag) {
        guard let index = data.tags.firstIndex(where: { $0.id == tag.id }) else { return }
        data.tags[index] = tag; save()
    }
    public func deleteTag(id: UUID) {
        data.tags.removeAll { $0.id == id }
        for i in data.tasks.indices where data.tasks[i].tagIDs.contains(id) {
            data.tasks[i].tagIDs.removeAll { $0 == id }; data.tasks[i].updatedAt = Date()
        }
        save()
    }

    nonisolated public static func defaultReminderDates(due: Date, hasTime: Bool, settings: AppSettings, calendar: Calendar) -> [Date] {
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

    nonisolated public static func defaultReminderDate(due: Date, hasTime: Bool, settings: AppSettings, calendar: Calendar) -> Date? {
        defaultReminderDates(due: due, hasTime: hasTime, settings: settings, calendar: calendar).first
    }

    nonisolated public static func usesDefaultReminder(_ task: TaskItem, settings: AppSettings) -> Bool {
        if let follows = task.reminderFollowsSchedule { return follows }
        guard !task.reminderDates.isEmpty else { return true }
        guard let due = task.dueDate else { return false }
        var calendar = settings.calendar
        if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { calendar.timeZone = zone }
        let expected = defaultReminderDates(due: due, hasTime: task.hasDueTime, settings: settings, calendar: calendar)
        return expected.count == task.reminderDates.count && zip(expected, task.reminderDates).allSatisfy { pair in abs(pair.0.timeIntervalSince(pair.1)) < 1 }
    }

    nonisolated public static func nextDate(after date: Date, rule: RepeatRule, anchorDay: Int? = nil, anchorMonth: Int? = nil, calendar: Calendar = .current) -> Date? {
        switch rule {
        case .none: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays:
            guard var next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            while calendar.component(.weekday, from: next) == 1 || calendar.component(.weekday, from: next) == 7 {
                guard let following = calendar.date(byAdding: .day, value: 1, to: next) else { return nil }; next = following
            }
            return next
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly, .yearly:
            // Move from the first of the month, then clamp the original day to its length.
            var components = calendar.dateComponents([.era, .year, .month, .hour, .minute, .second, .nanosecond], from: date)
            let day = anchorDay ?? calendar.component(.day, from: date)
            components.day = 1
            guard let first = calendar.date(from: components),
                  let advanced = calendar.date(byAdding: rule == .monthly ? .month : .year, value: 1, to: first) else { return nil }
            var target = calendar.dateComponents([.era, .year, .month, .hour, .minute, .second, .nanosecond], from: advanced)
            if rule == .yearly, let anchorMonth { target.month = anchorMonth }
            target.day = 1
            guard let targetFirst = calendar.date(from: target), let days = calendar.range(of: .day, in: .month, for: targetFirst) else { return nil }
            target.day = min(max(day, 1), days.count)
            return calendar.date(from: target)
        }
    }

    private static func starterData() -> WorkspaceData {
        let personal = TaskList(name: "Personal", color: "#7C6CF2")
        let work = TaskList(name: "Work", color: "#45A8A0")
        let idea = TaskTag(name: "Idea", color: "#D99250")
        return WorkspaceData(tasks: [
            TaskItem(title: "Plan your week", listID: personal.id, dueDate: Calendar.current.startOfDay(for: Date()), priority: .medium,
                     checklist: [ChecklistItem(title: "Choose your priorities"), ChecklistItem(title: "Make time for what matters")]),
            TaskItem(title: "Add your first task"),
            TaskItem(title: "Capture a new idea", body: "Your notes and tasks live together here.", listID: work.id, tagIDs: [idea.id], kind: .note)
        ], lists: [personal, work], tags: [idea], templates: TaskTemplate.builtIns)
    }
}
