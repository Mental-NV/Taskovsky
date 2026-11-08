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
    /// Pristine recurrence spawns per completed record (direct successor plus
    /// subtree clones), keyed by the completed record. In-memory only: a
    /// user edit breaks the byte-equality link and the spawned records stay.
    /// Cascade reopen ledgers are persisted separately in `WorkspaceData`.
    private var completionSnapshots: [UUID: [TaskItem]] = [:]
    /// Stored (not computed): an explicit `--settings` override must be the
    /// actual persisted path for reads AND writes.
    public let settingsURL: URL
    private var blockedByLoadFailure = false
    public var needsRecovery: Bool { blockedByLoadFailure }

    /// `settingsURL` overrides the adjacent `settings.json` (used by the
    /// isolated `--workspace` launch); nil keeps the file next to `fileURL`.
    public init(fileURL: URL? = nil, settingsURL: URL? = nil, seed: Bool = true) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.settingsURL = settingsURL ?? self.fileURL.deletingLastPathComponent().appendingPathComponent("settings.json")
        let settingsURL = self.settingsURL
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
        // Archived lists are read-only at the store layer: content, status,
        // schedule, tags, and links freeze. Moving the record out to a live
        // list (or Inbox) stays allowed and lifts the freeze for this save.
        let oldArchived = old.listID.flatMap { id in data.lists.first { $0.id == id } }?.isArchived ?? false
        let newListArchived = task.listID.flatMap { id in data.lists.first { $0.id == id } }?.isArchived ?? false
        let movesOut = task.listID != old.listID && !newListArchived
        if oldArchived && !movesOut { return }
        // The plain body is authoritative: when it was replaced independently
        // (template apply writes both, the rich editor writes both), styles
        // whose mirrored text no longer matches are stale and clear instead
        // of silently applying to different text.
        let bodyChanged = !RichBody.sameCodeUnits(task.body, old.body)
        let stylesMatch = task.richBody.map { RichBody.sameCodeUnits($0.text, task.body) } ?? true
        if bodyChanged, !stylesMatch {
            task.richBody = nil
        }
        // Direct record edits use the same graph-aware policy as moves: a
        // list change carries the subtree and detaches from a staying parent
        // in another list; an archived target refuses the list change.
        if task.listID != old.listID {
            if newListArchived {
                task.listID = old.listID
            } else {
                let now = Date()
                for descendant in TaskHierarchy.descendants(of: task.id, in: data.tasks) {
                    if let i = data.tasks.firstIndex(where: { $0.id == descendant.id }) {
                        data.tasks[i].listID = task.listID; data.tasks[i].updatedAt = now
                    }
                }
                if let parentID = task.parentID,
                   let parent = data.tasks.first(where: { $0.id == parentID }),
                   parent.listID != task.listID {
                    task.parentID = nil
                }
            }
        }
        // Direct parent-link edits route through the same validation as
        // `setTaskParent`; refused links revert to the stored parent.
        if task.parentID != old.parentID {
            switch Self.resolveParentLink(childID: task.id, parentID: task.parentID, tasks: data.tasks, lists: data.lists) {
            case .keep: break
            case .relocateSubtree(let listID):
                task.listID = listID
                let now = Date()
                for descendant in TaskHierarchy.descendants(of: task.id, in: data.tasks) {
                    if let i = data.tasks.firstIndex(where: { $0.id == descendant.id }) {
                        data.tasks[i].listID = listID; data.tasks[i].updatedAt = now
                    }
                }
            case .refuse: task.parentID = old.parentID
            }
        }
        // Schedule coherence on every save: a staged window must be valid
        // with due == end and hasDueTime matching the shape. Invalid windows
        // drop; a record is never left undated with an absolute window.
        // (ScheduleEditor stages this too; the store is the backstop for
        // every other writer.)
        do {
            // Normalize in the RECORD's zone: all-day `startOfDay` at the
            // host/settings midnight shifts absolute endpoints for tasks
            // carrying another zone. Unknown IDs fall back to the settings
            // calendar, exactly like the reminder block below.
            var scheduleCalendar = settings.calendar
            if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { scheduleCalendar.timeZone = zone }
            let schedule = Self.coherentSchedule(dueDate: task.dueDate, hasDueTime: task.hasDueTime, window: task.scheduledDuration, calendar: scheduleCalendar)
            task.dueDate = schedule.dueDate; task.hasDueTime = schedule.hasDueTime; task.scheduledDuration = schedule.window
        }
        if old.dueDate != task.dueDate || old.recurrence != task.recurrence {
            task.recurrenceAnchorDay = nil; task.recurrenceAnchorMonth = nil
        }
        // Series position follows manual schedule edits at the store
        // boundary: rule changes restart, date edits rebase the nominal so
        // the next completion advances from the new due. No-op saves keep
        // the stored nominal (including rolled tasks).
        task.normalizeSeriesPosition(old: old)
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

    @discardableResult public func createTask(title: String, listID: UUID? = nil, kind: TaskKind = .task, dueDate: Date? = nil, useDefaultList: Bool = true, preferRecognizedDate: Bool = false, recognizeDates: Bool = true, body: String = "", duration: TaskDurationRange? = nil) -> UUID {
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
        let schedule = Self.coherentSchedule(dueDate: taskDue, hasDueTime: hasDueTime, window: duration ?? defaulted, calendar: calendar)
        let reminders = schedule.dueDate.map { Self.defaultReminderDates(due: $0, hasTime: schedule.hasDueTime, settings: settings, calendar: calendar) } ?? []
        var task = TaskItem(title: text.trimmingCharacters(in: .whitespacesAndNewlines), body: body, listID: resolvedActive, tagIDs: tags, kind: kind, dueDate: schedule.dueDate, hasDueTime: schedule.hasDueTime, priority: settings.defaultPriority, reminderFollowsSchedule: reminders.isEmpty ? nil : true, timeZoneID: settings.enableTimeZone && schedule.dueDate != nil ? calendar.timeZone.identifier : nil, scheduledDuration: schedule.window)
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

    /// True when the task sits in an archived list (read-only content).
    private func isInArchivedList(_ task: TaskItem) -> Bool {
        task.listID.flatMap { id in data.lists.first { $0.id == id } }?.isArchived ?? false
    }

    public func toggleComplete(id: UUID) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }),
              data.tasks[index].deletedAt == nil,
              !isInArchivedList(data.tasks[index]) else { return }
        if data.tasks[index].completedAt != nil {
            undoCompletion(id: id); return
        }
        completeSubtree(rootID: id, now: Date())
        save()
    }

    /// Completes a task and its whole active subtree in one instant.
    /// Already-completed and Won't Do descendants are preserved, never
    /// restamped. Every descendant completed by the cascade is recorded
    /// with its exact stamp in the persisted ledger, so undo (even after a
    /// reload) reopens only those — never independent prior completions or
    /// later user changes.
    ///
    /// Recurring-parent policy: when the parent itself spawns a recurrence
    /// successor, the whole live subtree clones under that successor once
    /// (fresh IDs, states reset, series links rewritten per member) and the
    /// old descendants complete WITHOUT their own spawns — no second
    /// successor tree, no child successor dangling off the old parent. When
    /// the parent spawns nothing, a repeating descendant keeps its own
    /// series with a single spawn that retains the old parent link.
    private func completeSubtree(rootID: UUID, now: Date) {
        guard let rootIndex = data.tasks.firstIndex(where: { $0.id == rootID }) else { return }
        let original = data.tasks[rootIndex]
        data.tasks[rootIndex].wontDoAt = nil
        data.tasks[rootIndex].completedAt = now
        data.tasks[rootIndex].updatedAt = now
        var calendar = settings.calendar
        if let zoneID = original.timeZoneID, let zone = TimeZone(identifier: zoneID) { calendar.timeZone = zone }
        let hasLiveSubtree = TaskHierarchy.descendants(of: rootID, in: data.tasks).contains { $0.deletedAt == nil }
        if let successor = Self.spawnSuccessor(of: original, now: now, calendar: calendar, in: data.tasks) {
            data.tasks.append(successor)
            completionSnapshots[rootID] = [successor]
            if hasLiveSubtree {
                // Cloning needs both dues (guaranteed by the spawn, which
                // requires a due date and always sets the next one); the
                // cascade below runs regardless.
                if let parentDue = original.dueDate, let successorDue = successor.dueDate {
                    let clones = cloneSubtreeIntoSuccessor(originalRootID: rootID, newParentID: successor.id, parentDue: parentDue, successorDue: successorDue, now: now, calendar: calendar)
                    completionSnapshots[rootID]?.append(contentsOf: clones)
                }
                cascadeCompleteDescendants(of: rootID, now: now, spawning: false, calendar: calendar)
            }
        } else {
            cascadeCompleteDescendants(of: rootID, now: now, spawning: true, calendar: calendar)
        }
        // The in-memory successor snapshots never outlive records the user
        // edited; `undoCompletion` removes only byte-pristine spawns.
        if let index = data.tasks.firstIndex(where: { $0.id == rootID }) {
            data.tasks[index].updatedAt = now
        }
    }

    /// Marks every open non-trashed descendant completed at `now`, recording
    /// each in the persisted cascade ledger. With `spawning`, a repeating
    /// descendant also spawns its own successor (single-task semantics).
    private func cascadeCompleteDescendants(of rootID: UUID, now: Date, spawning: Bool, calendar: Calendar) {
        var cascaded: [TaskCompletionCascade.ChildCompletion] = []
        for child in TaskHierarchy.descendants(of: rootID, in: data.tasks) {
            guard child.deletedAt == nil, child.completedAt == nil, child.wontDoAt == nil,
                  let index = data.tasks.firstIndex(where: { $0.id == child.id }) else { continue }
            data.tasks[index].wontDoAt = nil
            data.tasks[index].completedAt = now
            data.tasks[index].updatedAt = now
            cascaded.append(.init(id: child.id, completedAt: now))
            if spawning, let successor = Self.spawnSuccessor(of: child, now: now, calendar: calendar, in: data.tasks) {
                data.tasks.append(successor)
                completionSnapshots[child.id, default: []].append(successor)
            }
        }
        if !cascaded.isEmpty {
            data.completionCascades.removeAll { $0.parentID == rootID }
            data.completionCascades.append(.init(parentID: rootID, completedAt: now, children: cascaded))
        }
    }

    /// Conservative recurring-tree clone: every live (non-trashed) OPEN
    /// descendant copies under the successor with a fresh ID, reset states
    /// (open, untrashed, unchecked checklist), a remapped parent link, and
    /// `recurrenceSourceID` pointing at its original member so each member's
    /// own series continues from the clone. Previously-completed/Won't Do
    /// descendants are finished work and do not clone into the new series.
    ///
    /// Offset policy: dates never strand on the previous overdue occurrence.
    /// The subtree keeps its relative structure around the new occurrence:
    /// timed members (dues and reminders) shift by the exact elapsed delta
    /// between the old and new parent dues; all-day members shift whole
    /// calendar days, preserving day spans across DST. The parent's day
    /// displacement (`dayDelta`, measured in the root calendar) applies to
    /// every member, but all-day dues, reminders, and duration windows shift
    /// in the APPLICABLE MEMBER zone (its own record zone when set,
    /// otherwise the root calendar), so a 09:00 reminder keeps its
    /// wall-clock time across a DST transition in the member's zone instead
    /// of inheriting the root's. Duration windows re-anchor their end at
    /// the shifted due date. Members without dues keep none — except an
    /// undated member holding an absolute window, which anchors its due at
    /// the window end (records are never undated with absolute windows).
    /// Returns the clones (for pristine tracking).
    private func cloneSubtreeIntoSuccessor(originalRootID: UUID, newParentID: UUID, parentDue: Date, successorDue: Date, now: Date, calendar: Calendar) -> [TaskItem] {
        let members = TaskHierarchy.descendants(of: originalRootID, in: data.tasks).filter { $0.deletedAt == nil && $0.completedAt == nil && $0.wontDoAt == nil }
        guard !members.isEmpty else { return [] }
        let elapsedDelta = successorDue.timeIntervalSince(parentDue)
        let dayDelta = calendar.dateComponents([.day], from: calendar.startOfDay(for: parentDue), to: calendar.startOfDay(for: successorDue)).day ?? 0
        func calendarFor(_ member: TaskItem) -> Calendar {
            guard let id = member.timeZoneID, let zone = TimeZone(identifier: id) else { return calendar }
            var memberCalendar = calendar
            memberCalendar.timeZone = zone
            return memberCalendar
        }
        func shift(_ date: Date, timed: Bool, in memberCalendar: Calendar) -> Date {
            if timed { return date.addingTimeInterval(elapsedDelta) }
            return memberCalendar.date(byAdding: .day, value: dayDelta, to: memberCalendar.startOfDay(for: date)) ?? date
        }
        /// Reminder instants shift like the member's due date (elapsed for
        /// timed members, whole calendar days for all-day ones) but keep
        /// their own wall-clock time in the member zone: an all-day
        /// member's 09:00 reminder is day-shifted from its own instant —
        /// never via startOfDay, which would reset it to midnight and
        /// collapse distinct reminders.
        func shiftReminder(_ reminder: Date, memberDue: Date, cloneDue: Date, timed: Bool, in memberCalendar: Calendar) -> Date {
            if timed { return reminder.addingTimeInterval(elapsedDelta) }
            let dayOffset = memberCalendar.dateComponents([.day], from: memberCalendar.startOfDay(for: memberDue), to: memberCalendar.startOfDay(for: reminder)).day ?? 0
            let reminderDay = memberCalendar.date(byAdding: .day, value: dayOffset, to: memberCalendar.startOfDay(for: cloneDue)) ?? cloneDue
            let parts = memberCalendar.dateComponents([.hour, .minute, .second], from: reminder)
            return memberCalendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: parts.second ?? 0, of: reminderDay) ?? reminderDay
        }
        var idMap: [UUID: UUID] = [:]
        for member in members { idMap[member.id] = UUID() }
        var clones: [TaskItem] = []
        for member in members {
            var clone = member
            clone.id = idMap[member.id]!
            clone.completedAt = nil; clone.wontDoAt = nil; clone.deletedAt = nil
            clone.createdAt = now; clone.updatedAt = now
            clone.recurrenceSourceID = member.id
            if member.isCustomRepeating { clone.occurrenceIndex = member.occurrenceIndex + 1 }
            clone.checklist = member.checklist.map { ChecklistItem(title: $0.title) }
            let memberCalendar = calendarFor(member)
            if let memberDue = member.dueDate {
                let newDue = shift(memberDue, timed: member.hasDueTime, in: memberCalendar)
                clone.dueDate = newDue
                clone.reminderDates = member.reminderDates.map { shiftReminder($0, memberDue: memberDue, cloneDue: newDue, timed: member.hasDueTime, in: memberCalendar) }
                // The clone continues the member's series from the same
                // nominal offset: shifting the nominal by the same delta
                // keeps the nominal<->due relationship the clone's future
                // completions advance from.
                if let nominal = member.recurrenceNominalDate {
                    clone.recurrenceNominalDate = shift(nominal, timed: member.hasDueTime, in: memberCalendar)
                }
                if let window = member.scheduledDuration?.validated(in: memberCalendar) {
                    clone.scheduledDuration = window.anchoredEnd(at: newDue, calendar: memberCalendar)
                } else if member.scheduledDuration != nil {
                    clone.scheduledDuration = nil
                }
            } else if let window = member.scheduledDuration?.validated(in: memberCalendar) {
                clone.scheduledDuration = window
                clone.dueDate = window.end
                clone.hasDueTime = !window.isAllDay
            } else if member.scheduledDuration != nil {
                clone.scheduledDuration = nil
            }
            if let parent = member.parentID {
                clone.parentID = parent == originalRootID ? newParentID : idMap[parent] ?? parent
            }
            data.tasks.append(clone)
            clones.append(clone)
        }
        return clones
    }

    /// Duration coherence (pure): when a scheduled window is present it must
    /// be valid, and the due date must equal the window end with
    /// `hasDueTime == !isAllDay`. Invalid windows (end before start) drop —
    /// they can never anchor a due date — and a record is never left
    /// undated holding an absolute window (the end becomes the due date).
    /// Dateless *templates* may still store a bare shape; this applies to
    /// live task records (create, save/update, instantiate, successors).
    nonisolated static func coherentSchedule(dueDate: Date?, hasDueTime: Bool, window: TaskDurationRange?, calendar: Calendar) -> (dueDate: Date?, hasDueTime: Bool, window: TaskDurationRange?) {
        guard let valid = window?.validated(in: calendar) else { return (dueDate, hasDueTime, nil) }
        return (valid.end, !valid.isAllDay, valid)
    }

    /// Builds the recurrence successor for one record without appending it.
    /// Nil when the series ends, already has a successor, or has no due
    /// date. A valid custom rule supersedes the legacy enum; both honor the
    /// legacy end date.
    private static func spawnSuccessor(of original: TaskItem, now: Date, calendar: Calendar, in tasks: [TaskItem]) -> TaskItem? {
        guard let (next, customIndex) = Self.nextRecurrenceDate(for: original, now: now, calendar: calendar),
              !tasks.contains(where: { $0.recurrenceSourceID == original.id }),
              let due = original.dueDate else { return nil }
        var copy = original
        copy.id = UUID(); copy.dueDate = next; copy.completedAt = nil; copy.deletedAt = nil; copy.wontDoAt = nil
        copy.occurrenceIndex = customIndex ?? original.occurrenceIndex
        // Weekend-rolling custom series record the unadjusted nominal
        // alongside the displayed (possibly rolled) due date, so the next
        // completion advances from the nominal and interval alignment
        // survives month-boundary rolls. Recomputed from the same inputs
        // (pure step), so it always matches the date above. Completion
        // anchor and legacy successors carry no nominal.
        copy.recurrenceNominalDate = original.isCustomRepeating
            ? Self.nextCustomStep(for: original, now: now, calendar: calendar)?.nominal
            : nil
        copy.reminderDates = original.reminderDates.map { reminder in
            guard !original.hasDueTime else { return next.addingTimeInterval(reminder.timeIntervalSince(due)) }
            let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: calendar.startOfDay(for: reminder)).day ?? 0
            let reminderDay = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: next)) ?? next
            let parts = calendar.dateComponents([.hour, .minute, .second], from: reminder)
            return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: parts.second ?? 0, of: reminderDay) ?? reminderDay
        }
        copy.createdAt = now; copy.updatedAt = now
        copy.recurrenceSourceID = original.id
        // End-anchored (never `moved(to:)`, which anchors the start), then
        // re-cohered: the successor's window must end exactly at its due
        // date and the shape decides `hasDueTime`, even when the anchor
        // calendar rounds an all-day successor onto its day.
        if let window = original.scheduledDuration?.validated(in: calendar) {
            let anchored = window.anchoredEnd(at: next, calendar: calendar)
            let schedule = Self.coherentSchedule(dueDate: next, hasDueTime: original.hasDueTime, window: anchored, calendar: calendar)
            copy.dueDate = schedule.dueDate
            copy.hasDueTime = schedule.hasDueTime
            copy.scheduledDuration = schedule.window
        } else {
            copy.scheduledDuration = nil
        }
        copy.recurrenceAnchorDay = original.recurrenceAnchorDay ?? calendar.component(.day, from: due)
        copy.recurrenceAnchorMonth = original.recurrenceAnchorMonth ?? calendar.component(.month, from: due)
        copy.checklist = original.checklist.map { ChecklistItem(title: $0.title) }
        return copy
    }

    public func undoCompletion(id: UUID) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].completedAt != nil else { return }
        guard !isInArchivedList(data.tasks[index]) else { return }
        data.tasks[index].completedAt = nil; data.tasks[index].updatedAt = Date()
        // Spawned successors (and subtree clones) leave only while pristine:
        // a user edit breaks the link and the records stay (never delete
        // user data on undo).
        if let snapshots = completionSnapshots.removeValue(forKey: id) {
            removePristineSpawns(snapshots)
        }
        // Reopen only cascaded descendants whose stamp is untouched: prior
        // completions and later user changes carry different stamps (or no
        // stamp) and stay. The ledger is consumed even when empty of
        // matches, so a second undo cannot reopen later work.
        if let cascadeIndex = data.completionCascades.firstIndex(where: { $0.parentID == id }) {
            let cascade = data.completionCascades[cascadeIndex]
            for child in cascade.children {
                if let i = data.tasks.firstIndex(where: { $0.id == child.id }),
                   data.tasks[i].completedAt == child.completedAt,
                   data.tasks[i].deletedAt == nil {
                    data.tasks[i].completedAt = nil; data.tasks[i].updatedAt = Date()
                    // A reopened cascade step must not leave its own pristine
                    // spawn behind as a duplicate occurrence (non-repeating
                    // parents spawn per-child successors keyed at the child).
                    if let childSnapshots = completionSnapshots.removeValue(forKey: child.id) {
                        removePristineSpawns(childSnapshots)
                    }
                }
            }
            data.completionCascades.remove(at: cascadeIndex)
        }
        save()
    }

    /// Removes pristine spawned records, retaining any that anchor surviving
    /// content: a pristine spawn with an edited descendant — or a user-added
    /// descendant — stays as their required ancestor instead of leaving a
    /// dangling parent link. Retention propagates upward (an ancestor of a
    /// retained record is itself retained). Never deletes user data; records
    /// that cannot be proven pristine (e.g. after a reload, which drops the
    /// in-memory snapshots) are retained.
    private func removePristineSpawns(_ snapshots: [TaskItem]) {
        guard !snapshots.isEmpty else { return }
        var removable: Set<UUID> = []
        for snapshot in snapshots {
            if data.tasks.contains(where: { $0.id == snapshot.id && $0 == snapshot }) {
                removable.insert(snapshot.id)
            }
        }
        guard !removable.isEmpty else { return }
        // Everything not slated for removal must survive; ancestors of those
        // survivors (walked cycle-safe) can never be removed.
        var byID: [UUID: TaskItem] = [:]
        for task in data.tasks { byID[task.id] = task }
        var anchored: Set<UUID> = []
        for id in Set(data.tasks.map(\.id)).subtracting(removable) {
            var seen = Set<UUID>([id])
            var cursor = byID[id]?.parentID
            while let current = cursor, seen.insert(current).inserted {
                anchored.insert(current)
                cursor = byID[current]?.parentID
            }
        }
        let doomed = removable.subtracting(anchored)
        guard !doomed.isEmpty else { return }
        data.tasks.removeAll { doomed.contains($0.id) }
    }
    public func markWontDo(id: UUID) {
        guard let task = data.tasks.first(where: { $0.id == id }),
              task.deletedAt == nil, !isInArchivedList(task) else { return }
        mutateTask(id: id) { $0.wontDoAt = Date(); $0.completedAt = nil }
    }
    public func reopenTask(id: UUID) {
        guard let task = data.tasks.first(where: { $0.id == id }),
              task.deletedAt == nil, !isInArchivedList(task) else { return }
        if task.completedAt != nil { undoCompletion(id: id) }
        mutateTask(id: id) { $0.wontDoAt = nil; $0.completedAt = nil }
    }
    /// Pins or unpins a task. Completed, Won't Do, and trashed records refuse
    /// (returning false with no mutation) so they can never become pinned
    /// active rows; the stored flag survives status changes so reopening or
    /// restoring brings the pin back.
    @discardableResult public func setPinned(id: UUID, pinned: Bool) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }),
              data.tasks[index].deletedAt == nil,
              data.tasks[index].completedAt == nil,
              data.tasks[index].wontDoAt == nil,
              !isInArchivedList(data.tasks[index]) else { return false }
        guard data.tasks[index].isPinned != pinned else { return true }
        data.tasks[index].isPinned = pinned
        data.tasks[index].updatedAt = Date()
        save()
        return true
    }
    @discardableResult public func createFilter(_ filter: TaskFilter) -> UUID { data.filters.append(filter); save(); return filter.id }
    public func updateFilter(_ filter: TaskFilter) { guard let i = data.filters.firstIndex(where: { $0.id == filter.id }) else { return }; data.filters[i] = filter; save() }
    public func deleteFilter(id: UUID) { data.filters.removeAll { $0.id == id }; save() }
    @discardableResult public func saveTemplate(from id: UUID, name: String? = nil) -> UUID? {
        guard let task = data.tasks.first(where: { $0.id == id }) else { return nil }
        let template = TaskTemplate(name: name ?? task.title, title: task.title, body: task.body, checklist: task.checklist, priority: task.priority, tagIDs: task.tagIDs, kind: task.kind, richBody: task.richBody?.valid(for: task.body), customRecurrence: task.customRecurrence, scheduledDuration: task.scheduledDuration)
        data.templates.append(template); save(); return template.id
    }
    public func updateTemplate(_ template: TaskTemplate) { if let i = data.templates.firstIndex(where: { $0.id == template.id }) { data.templates[i] = template } else { data.templates.append(template) }; save() }
    public func deleteTemplate(id: UUID) { data.templates.removeAll { $0.id == id }; save() }
    @discardableResult public func createTaskFromTemplate(id: UUID, listID: UUID? = nil, dueDate: Date? = nil, useDefaultList: Bool = true) -> UUID? {
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
            guard let shape = template.scheduledDuration?.validated(in: settings.calendar) else { return nil }
            if let due = dueDate { return shape.anchoredEnd(at: due, calendar: settings.calendar) }
            return shape
        }()
        let task = TaskItem(title: template.title, body: template.body, listID: resolvedActive, tagIDs: template.tagIDs.filter { id in data.tags.contains { $0.id == id } }, kind: template.kind, dueDate: dueDate ?? window?.end, hasDueTime: window.map { !$0.isAllDay } ?? false, priority: template.priority, checklist: template.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }, customRecurrence: template.customRecurrence, scheduledDuration: window, richBody: template.richBody?.valid(for: template.body))
        if settings.defaultAddTo == .top { data.tasks.insert(task, at: 0) } else { data.tasks.append(task) }; save(); return task.id
    }
    /// Trashes a task and its whole non-trashed subtree in one instant,
    /// recording each cascaded child with its exact stamp in the persisted
    /// ledger. Restore revives only children whose stamp is untouched, so
    /// separately trashed children (different stamps) stay in Trash.
    public func trashTask(id: UUID) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt == nil else { return }
        let now = Date()
        data.tasks[index].deletedAt = now; data.tasks[index].updatedAt = now
        var trashed: [TaskTrashCascade.ChildTrash] = []
        for child in TaskHierarchy.descendants(of: id, in: data.tasks) where child.deletedAt == nil {
            if let i = data.tasks.firstIndex(where: { $0.id == child.id }) {
                data.tasks[i].deletedAt = now; data.tasks[i].updatedAt = now
                trashed.append(.init(id: child.id, deletedAt: now))
            }
        }
        if !trashed.isEmpty {
            data.trashCascades.removeAll { $0.parentID == id }
            data.trashCascades.append(.init(parentID: id, deletedAt: now, children: trashed))
        }
        save()
    }
    /// Restores a trashed task and the descendants trashed with it (same
    /// stamp). Separately trashed children keep their own stamps and stay.
    public func restoreTask(id: UUID) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt != nil else { return }
        data.tasks[index].deletedAt = nil; data.tasks[index].updatedAt = Date()
        if let cascadeIndex = data.trashCascades.firstIndex(where: { $0.parentID == id }) {
            let cascade = data.trashCascades[cascadeIndex]
            for child in cascade.children {
                if let i = data.tasks.firstIndex(where: { $0.id == child.id }),
                   data.tasks[i].deletedAt == child.deletedAt {
                    data.tasks[i].deletedAt = nil; data.tasks[i].updatedAt = Date()
                }
            }
            data.trashCascades.remove(at: cascadeIndex)
        }
        save()
    }
    /// Permanently removes one trashed record. Refuses missing IDs and active
    /// items. Surviving children (trashed or restored) detach to top level
    /// instead of dangling, and cascade ledgers naming the record are
    /// dropped. Never touches lists, tags, or templates.
    @discardableResult public func purgeTask(id: UUID) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt != nil else { return false }
        data.tasks.remove(at: index)
        let now = Date()
        for i in data.tasks.indices where data.tasks[i].parentID == id {
            data.tasks[i].parentID = nil; data.tasks[i].updatedAt = now
        }
        pruneCascades(naming: id)
        completionSnapshots.removeValue(forKey: id)
        for key in completionSnapshots.keys {
            completionSnapshots[key]?.removeAll { $0.id == id }
        }
        save(); return true
    }

    /// Drops cascade ledger entries that name a removed record: entries
    /// parented at it go away, and child references to it shed.
    private func pruneCascades(naming id: UUID) {
        data.completionCascades.removeAll { $0.parentID == id }
        for i in data.completionCascades.indices {
            data.completionCascades[i].children.removeAll { $0.id == id }
        }
        data.trashCascades.removeAll { $0.parentID == id }
        for i in data.trashCascades.indices {
            data.trashCascades[i].children.removeAll { $0.id == id }
        }
    }
    private func mutateTask(id: UUID, _ change: (inout TaskItem) -> Void) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&data.tasks[index]); data.tasks[index].updatedAt = Date(); save()
    }
    /// Duplicates a task with its whole non-deleted subtree. Every copied
    /// record takes a fresh ID (and fresh checklist IDs); descendant links
    /// remap into the copy, while the copy itself keeps the original's
    /// parent slot (duplicating a child keeps it a sibling under the same
    /// parent). The root resets to open (completed/Won't Do/trashed clear,
    /// new custom series at position 1); descendants keep their statuses,
    /// bodies, rich styles, priorities, dates, checklist behavior, and
    /// custom-rule/duration state. Recurrence links cut on every copy so the
    /// duplicate never chains to the original.
    @discardableResult public func duplicateTask(id: UUID) -> UUID? {
        guard data.tasks.contains(where: { $0.id == id }) else { return nil }
        let now = Date()
        let members = [id] + TaskHierarchy.descendants(of: id, in: data.tasks)
            .filter { $0.deletedAt == nil }.map(\.id)
        var idMap: [UUID: UUID] = [:]
        for member in members { idMap[member] = UUID() }
        let newRootID = idMap[id]!
        for member in members {
            guard var copy = data.tasks.first(where: { $0.id == member }) else { continue }
            copy.id = idMap[member]!
            if member == id {
                copy.completedAt = nil; copy.deletedAt = nil; copy.wontDoAt = nil
                // The duplicate restarts the series at position 1 with the
                // nominal back at the copy's due date (the new series start);
                // the rule itself carries over. Clearing the rule drops it.
                copy.occurrenceIndex = 1
                copy.restartCustomSeries(ruleChangedFrom: nil)
            }
            copy.recurrenceSourceID = nil
            // Links inside the copied subtree remap; the root keeps its
            // original parent slot (outside the copy by construction).
            if let parent = copy.parentID, let remapped = idMap[parent] { copy.parentID = remapped }
            copy.checklist = copy.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }
            copy.createdAt = now; copy.updatedAt = now
            data.tasks.append(copy)
        }
        save(); return newRootID
    }
    @discardableResult public func createList(name: String, color: String, kind: TaskKind = .task, symbol: String? = nil, folderID: UUID? = nil, showsInSmartLists: Bool = true) -> UUID {
        let folder = folderID.flatMap { id in data.folders.contains(where: { $0.id == id }) ? id : nil }
        let list = TaskList(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color, kind: kind, symbol: symbol, folderID: folder, showsInSmartLists: showsInSmartLists); data.lists.append(list); save(); return list.id
    }

    /// Archives or unarchives a list. Archive hides its tasks from smart
    /// destinations and suppresses their reminders; the list keeps its order
    /// and folder slot, and unarchiving restores it exactly.
    @discardableResult public func setListArchived(id: UUID, archived: Bool) -> Bool {
        guard let index = data.lists.firstIndex(where: { $0.id == id }) else { return false }
        guard data.lists[index].isArchived != archived else { return true }
        data.lists[index].isArchived = archived; save(); return true
    }

    /// Smart-list inclusion ("Show in Smart List"). `false` hides the list's
    /// tasks from smart destinations while reminders keep firing.
    @discardableResult public func setListSmartInclusion(id: UUID, shows: Bool) -> Bool {
        guard let index = data.lists.firstIndex(where: { $0.id == id }) else { return false }
        guard data.lists[index].showsInSmartLists != shows else { return true }
        data.lists[index].showsInSmartLists = shows; save(); return true
    }

    @discardableResult public func setListPinned(id: UUID, pinned: Bool) -> Bool {
        guard let index = data.lists.firstIndex(where: { $0.id == id }) else { return false }
        guard data.lists[index].isPinned != pinned else { return true }
        data.lists[index].isPinned = pinned; save(); return true
    }

    @discardableResult public func setFolderPinned(id: UUID, pinned: Bool) -> Bool {
        guard let index = data.folders.firstIndex(where: { $0.id == id }) else { return false }
        guard data.folders[index].isPinned != pinned else { return true }
        data.folders[index].isPinned = pinned; save(); return true
    }

    @discardableResult public func setTagPinned(id: UUID, pinned: Bool) -> Bool {
        guard let index = data.tags.firstIndex(where: { $0.id == id }) else { return false }
        guard data.tags[index].isPinned != pinned else { return true }
        data.tags[index].isPinned = pinned; save(); return true
    }

    @discardableResult public func setFilterPinned(id: UUID, pinned: Bool) -> Bool {
        guard let index = data.filters.firstIndex(where: { $0.id == id }) else { return false }
        guard data.filters[index].isPinned != pinned else { return true }
        data.filters[index].isPinned = pinned; save(); return true
    }

    /// Duplicates a list with all its non-deleted tasks. The copy takes a
    /// fresh ID ("<name> copy"), keeps kind/symbol/folder/order and smart-list
    /// inclusion, and is never archived or pinned. Tasks copy with new IDs
    /// and checklist IDs, preserving bodies, rich text, scheduling, reminders
    /// (relative offsets preserved via whole-record copy), tags, and status;
    /// recurrence links are cut so the copy never chains to the original.
    /// Tasks keep their relative order, appended after existing records.
    @discardableResult public func duplicateList(id: UUID) -> UUID? {
        guard let source = data.lists.first(where: { $0.id == id }) else { return nil }
        var copy = source
        copy.id = UUID(); copy.name = source.name + " copy"
        copy.isArchived = false; copy.isPinned = false
        // View mode travels with the duplicate (a Board list copies as Board).
        data.lists.append(copy)
        let now = Date()
        let members = data.tasks.filter { $0.listID == id && $0.deletedAt == nil }
        var idMap: [UUID: UUID] = [:]
        for member in members { idMap[member.id] = UUID() }
        for task in members {
            var duplicate = task
            duplicate.id = idMap[task.id]!
            duplicate.listID = copy.id
            // Subtree links remap into the copy. A parent outside the copied
            // set (original list, another list, trashed) clears to top
            // level: the copy must never stay silently linked across lists.
            duplicate.parentID = task.parentID.flatMap { idMap[$0] }
            duplicate.checklist = task.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }
            duplicate.recurrenceSourceID = nil
            duplicate.createdAt = now; duplicate.updatedAt = now
            data.tasks.append(duplicate)
        }
        save(); return copy.id
    }
    public func updateList(_ list: TaskList) {
        guard let index = data.lists.firstIndex(where: { $0.id == list.id }) else { return }
        var list = list
        // Membership and trailing placement travel on the record itself:
        // callers must carry the stored folderID and belowFolders
        // (EntityEditor(list:) does) or the save resets them. Unknown folder
        // IDs always clear to top root.
        if let folder = list.folderID, !data.folders.contains(where: { $0.id == folder }) { list.folderID = nil; list.belowFolders = false }
        data.lists[index] = list; save()
    }
    public func deleteList(id: UUID) {
        data.lists.removeAll { $0.id == id }
        for i in data.tasks.indices where data.tasks[i].listID == id { data.tasks[i].listID = nil; data.tasks[i].updatedAt = Date() }
        // Dead list IDs persist in saved-filter criteria as no-match (they
        // can never equal a task's list, and tasks were just repointed to
        // Inbox): stripping them would broaden a filter whose only
        // selection was deleted from "nothing" to "everything". The editor
        // surfaces them as unavailable so the user can deliberately clear or
        // replace them. Rule-tree conditions are never rewritten either.
        save()
    }
    @discardableResult public func createTag(name: String, color: String, parentID: UUID? = nil) -> UUID {
        let normalized = Self.normalizedTagName(name)
        if let existing = data.tags.first(where: { Self.normalizedTagName($0.name).localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            return existing.id
        }
        // Unknown parents clear to top level, matching the load policy.
        let parent = parentID.flatMap { id in data.tags.contains(where: { $0.id == id }) ? id : nil }
        let tag = TaskTag(name: normalized, color: color, parentID: parent); data.tags.append(tag); save(); return tag.id
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
    /// Deletes a tag and cleans every referencing place: tasks, templates,
    /// saved filters, and the default tag. Surviving children are promoted
    /// to the deleted tag's parent (top level when it had none); promotion
    /// that would recreate a cycle falls back to top level.
    public func deleteTag(id: UUID) {
        guard let deleted = data.tags.first(where: { $0.id == id }) else { return }
        let parent = deleted.parentID
        let parentCycles = parent.map { TagHierarchy.isDescendant($0, of: id, in: data.tags) } ?? false
        data.tags.removeAll { $0.id == id }
        for i in data.tags.indices where data.tags[i].parentID == id {
            data.tags[i].parentID = parentCycles ? nil : parent
        }
        for i in data.tasks.indices where data.tasks[i].tagIDs.contains(id) {
            data.tasks[i].tagIDs.removeAll { $0 == id }; data.tasks[i].updatedAt = Date()
        }
        for i in data.templates.indices {
            data.templates[i].tagIDs.removeAll { $0 == id }
        }
        // Dead tag IDs persist in saved-filter criteria as no-match (no
        // task can carry them after the sweep above): pruning them would
        // broaden a filter whose only selection was deleted. The editor
        // surfaces them as unavailable for deliberate clearing.
        if settings.defaultTagID == id { settings.defaultTagID = nil }
        save()
    }

    /// Sets a tag's parent. Rejects unknown IDs, self-parenting, and parents
    /// that would create a cycle (a descendant of the tag). Nil clears to top
    /// level. Exactly one save per accepted change.
    @discardableResult public func setTagParent(id: UUID, parentID: UUID?) -> Bool {
        guard let index = data.tags.firstIndex(where: { $0.id == id }) else { return false }
        if let parentID {
            guard data.tags.contains(where: { $0.id == parentID }), parentID != id,
                  !TagHierarchy.isDescendant(parentID, of: id, in: data.tags) else { return false }
        }
        guard data.tags[index].parentID != parentID else { return true }
        data.tags[index].parentID = parentID
        data.tags = WorkspaceData.sanitizedTagParents(data.tags)
        save(); return true
    }

    @discardableResult public func setTagCollapsed(id: UUID, collapsed: Bool) -> Bool {
        guard let index = data.tags.firstIndex(where: { $0.id == id }) else { return false }
        guard data.tags[index].isCollapsed != collapsed else { return true }
        data.tags[index].isCollapsed = collapsed; save(); return true
    }

    /// Parent-link validation shared by `setTaskParent` and direct record
    /// edits (`updateTask`): unknown IDs, self-parenting, and descendants
    /// (cycles) refuse, as do note, trashed, and archived parents — and
    /// archived or trashed children. A cross-list link normalizes by
    /// relocating the child's subtree into the parent's list instead of
    /// leaving a relationship that spans lists.
    enum ParentLinkResolution: Equatable {
        case keep
        case relocateSubtree(toList: UUID?)
        case refuse
    }

    static func resolveParentLink(childID: UUID, parentID: UUID?, tasks: [TaskItem], lists: [TaskList]) -> ParentLinkResolution {
        guard let parentID else { return .keep }
        guard let child = tasks.first(where: { $0.id == childID }),
              child.deletedAt == nil,
              !(child.listID.flatMap { id in lists.first { $0.id == id } }?.isArchived ?? false) else { return .refuse }
        guard parentID != childID,
              let parent = tasks.first(where: { $0.id == parentID }),
              parent.deletedAt == nil,
              parent.kind == .task,
              !(parent.listID.flatMap { id in lists.first { $0.id == id } }?.isArchived ?? false),
              !TaskHierarchy.isDescendant(parentID, of: childID, in: tasks) else { return .refuse }
        if parent.listID != child.listID { return .relocateSubtree(toList: parent.listID) }
        return .keep
    }

    /// Parents `id` under `parentID` (nil unparents to top level). Refuses
    /// unknown IDs, self-parenting, descendants (cycles), note/trashed/
    /// archived parents, and archived/trashed children. A cross-list link
    /// relocates the child's subtree into the parent's list. Nil clears to
    /// top level. Exactly one save per accepted change.
    @discardableResult public func setTaskParent(id: UUID, parentID: UUID?) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return false }
        var relocated = false
        switch Self.resolveParentLink(childID: id, parentID: parentID, tasks: data.tasks, lists: data.lists) {
        case .refuse: return false
        case .keep: break
        case .relocateSubtree(let listID):
            relocated = true
            let now = Date()
            data.tasks[index].listID = listID
            for descendant in TaskHierarchy.descendants(of: id, in: data.tasks) {
                if let i = data.tasks.firstIndex(where: { $0.id == descendant.id }) {
                    data.tasks[i].listID = listID; data.tasks[i].updatedAt = now
                }
            }
        }
        guard data.tasks[index].parentID != parentID || relocated else { return true }
        data.tasks[index].parentID = parentID
        data.tasks = WorkspaceData.sanitizedTaskParents(data.tasks)
        save(); return true
    }

    /// Creates a subtask under `parentID`, inheriting its list. Refuses
    /// unknown, trashed, archived, or note parents: notes never take
    /// children and archived content never gains new records. The child
    /// starts open, unpinned, and uncompleted at the default add position.
    @discardableResult public func addSubtask(to parentID: UUID, title: String) -> UUID? {
        guard let parent = data.tasks.first(where: { $0.id == parentID }),
              parent.deletedAt == nil,
              parent.kind == .task,
              !isInArchivedList(parent) else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let child = TaskItem(title: trimmed, listID: parent.listID, parentID: parentID)
        if settings.defaultAddTo == .top { data.tasks.insert(child, at: 0) } else { data.tasks.append(child) }
        save(); return child.id
    }

    /// Merges `source` into `target`: task, template, and saved-filter refs
    /// are rewritten (deduplicated), the default tag follows, and source's
    /// children reparent without cycles. When the target is a descendant of
    /// the source, the target takes the source's slot, the source's other
    /// children move under the target, and ancestor links that would cycle
    /// become siblings at the source's slot. The source is then deleted.
    /// Unrelated fields are untouched; exactly one save.
    @discardableResult public func mergeTags(source: UUID, target: UUID) -> Bool {
        guard source != target,
              let sourceTag = data.tags.first(where: { $0.id == source }),
              data.tags.contains(where: { $0.id == target }) else { return false }
        let targetIsDescendant = TagHierarchy.isDescendant(target, of: source, in: data.tags)
        if targetIsDescendant {
            // Ancestors between source and target, read before anything moves.
            let ancestors = Set(TagHierarchy.ancestors(of: target, in: data.tags).map(\.id))
            // Target takes the source's slot first so no link dangles.
            if let targetIndex = data.tags.firstIndex(where: { $0.id == target }) {
                data.tags[targetIndex].parentID = sourceTag.parentID
            }
            for i in data.tags.indices where data.tags[i].parentID == source {
                if data.tags[i].id == target || ancestors.contains(data.tags[i].id) {
                    // Ancestor-of-target links would cycle under the target;
                    // they become siblings at the source's former slot.
                    data.tags[i].parentID = sourceTag.parentID
                } else {
                    data.tags[i].parentID = target
                }
            }
        } else {
            for i in data.tags.indices where data.tags[i].parentID == source {
                data.tags[i].parentID = target
            }
        }
        func repoint(_ ids: [UUID]) -> [UUID] {
            var seen = Set<UUID>()
            var result: [UUID] = []
            for id in ids.map({ $0 == source ? target : $0 }) where seen.insert(id).inserted {
                result.append(id)
            }
            return result
        }
        let now = Date()
        for i in data.tasks.indices where data.tasks[i].tagIDs.contains(source) {
            data.tasks[i].tagIDs = repoint(data.tasks[i].tagIDs); data.tasks[i].updatedAt = now
        }
        for i in data.templates.indices {
            data.templates[i].tagIDs = repoint(data.templates[i].tagIDs)
        }
        for i in data.filters.indices {
            data.filters[i].tagIDs = repoint(data.filters[i].tagIDs)
            // Rule-tree conditions move with the merge (semantics-preserving);
            // deletions never rewrite trees (fail-closed instead).
            if let root = data.filters[i].ruleRoot {
                data.filters[i].ruleRoot = FilterRuleRewrite.repointingTag(from: source, to: target, in: root)
            }
        }
        if settings.defaultTagID == source { settings.defaultTagID = target }
        data.tags.removeAll { $0.id == source }
        data.tags = WorkspaceData.sanitizedTagParents(data.tags)
        save(); return true
    }

    /// Atomically moves tasks to a list (`nil` = Inbox), graph-aware: a moved
    /// parent carries its whole subtree (descendants follow even when not
    /// listed, trashed ones staying trashed), and a moved child detaches
    /// from a parent that stays behind in another list. Every ID is
    /// validated before anything mutates: unknown IDs, deleted tasks,
    /// duplicate IDs in the batch, and unknown target lists all abort with
    /// no mutation and no save. Records already in the target list are left
    /// byte-identical (timestamps preserved); only genuinely moved records
    /// are touched, with a single save. An all-already-there batch succeeds
    /// without saving. Dates, priorities, and status are untouched.
    @discardableResult public func moveTasksToList(ids: [UUID], listID: UUID?) -> Bool {
        guard !ids.isEmpty else { return false }
        if let listID, !data.lists.contains(where: { $0.id == listID }) { return false }
        // Archived lists are read-only destinations: unarchive first.
        // Moving OUT of an archived list stays allowed.
        if let listID, data.lists.first(where: { $0.id == listID })?.isArchived == true { return false }
        var seen = Set<UUID>()
        for id in ids {
            guard seen.insert(id).inserted,
                  let index = data.tasks.firstIndex(where: { $0.id == id }),
                  data.tasks[index].deletedAt == nil else { return false }
        }
        // Carry descendants of every explicitly moved record.
        var movedSet = Set(ids)
        for id in ids {
            for descendant in TaskHierarchy.descendants(of: id, in: data.tasks) {
                movedSet.insert(descendant.id)
            }
        }
        // Last-wins on duplicate IDs: a malformed file never traps.
        var byID: [UUID: TaskItem] = [:]
        for task in data.tasks { byID[task.id] = task }
        let pending = movedSet.filter { byID[$0]?.listID != listID }
        guard !pending.isEmpty else { return true }
        let now = Date()
        for id in pending {
            guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { continue }
            data.tasks[i].listID = listID
            // A child whose parent stays behind in another list detaches;
            // carried links (parent moved too) and same-list links survive.
            if let parentID = data.tasks[i].parentID, !movedSet.contains(parentID),
               byID[parentID]?.listID != listID {
                data.tasks[i].parentID = nil
            }
            data.tasks[i].updatedAt = now
        }
        save()
        return true
    }

    /// Atomically reorders tasks: moves `moving` (in the given relative order)
    /// to just before `target`, or just after it when `afterTarget` is true.
    /// Validates the whole batch first: unknown or deleted records, duplicate
    /// IDs, and self-drops (target inside `moving`) abort with no mutation.
    /// Nothing but array order changes; no other field is touched.
    @discardableResult public func reorderTasks(moving: [UUID], before target: UUID, afterTarget: Bool = false) -> Bool {
        guard !moving.isEmpty, !moving.contains(target) else { return false }
        var seen = Set<UUID>()
        var movers: [TaskItem] = []
        for id in moving {
            guard seen.insert(id).inserted,
                  let task = data.tasks.first(where: { $0.id == id }),
                  task.deletedAt == nil else { return false }
            movers.append(task)
        }
        guard data.tasks.contains(where: { $0.id == target && $0.deletedAt == nil }) else { return false }
        data.tasks.removeAll { moving.contains($0.id) }
        guard let targetIndex = data.tasks.firstIndex(where: { $0.id == target }) else { return false }
        data.tasks.insert(contentsOf: movers, at: afterTarget ? targetIndex + 1 : targetIndex)
        save()
        return true
    }

    /// Atomically reorders lists with the same all-or-nothing validation as
    /// task reordering. Self-drops and unknown IDs abort with no mutation.
    /// The mover adopts the target's folder AND its above/below-folders root
    /// segment, so drops above/below a list place correctly within/across
    /// folders and within the indicated top or trailing root segment. Only
    /// order, the mover's folderID, and its trailing flag change; tasks and
    /// list IDs stay.
    @discardableResult public func reorderLists(moving: UUID, before target: UUID, afterTarget: Bool = false) -> Bool {
        guard moving != target else { return false }
        guard var mover = data.lists.first(where: { $0.id == moving }),
              let targetList = data.lists.first(where: { $0.id == target }) else { return false }
        mover.folderID = targetList.folderID
        mover.belowFolders = targetList.folderID == nil && targetList.belowFolders
        data.lists.removeAll { $0.id == moving }
        guard let targetIndex = data.lists.firstIndex(where: { $0.id == target }) else { return false }
        data.lists.insert(mover, at: afterTarget ? targetIndex + 1 : targetIndex)
        save()
        return true
    }

    // MARK: - Folders (single level; no nesting)

    /// Trims and rejects empty names. Unknown folders and empty batches abort
    /// with no mutation; one save per accepted move.
    @discardableResult public func createFolder(name: String) -> UUID? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let folder = ListFolder(name: cleaned); data.folders.append(folder); save(); return folder.id
    }
    @discardableResult public func renameFolder(id: UUID, name: String) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let index = data.folders.firstIndex(where: { $0.id == id }) else { return false }
        data.folders[index].name = cleaned; save(); return true
    }
    /// Ungroups a folder: the folder row goes away, lists and their tasks stay
    /// (lists keep their IDs, membership clears to top root).
    @discardableResult public func ungroupFolder(id: UUID) -> Bool {
        guard data.folders.contains(where: { $0.id == id }) else { return false }
        data.folders.removeAll { $0.id == id }
        for i in data.lists.indices where data.lists[i].folderID == id { data.lists[i].folderID = nil; data.lists[i].belowFolders = false }
        save(); return true
    }
    @discardableResult public func reorderFolders(moving: UUID, before target: UUID, afterTarget: Bool = false) -> Bool {
        guard moving != target else { return false }
        guard let mover = data.folders.first(where: { $0.id == moving }),
              data.folders.contains(where: { $0.id == target }) else { return false }
        data.folders.removeAll { $0.id == moving }
        guard let targetIndex = data.folders.firstIndex(where: { $0.id == target }) else { return false }
        data.folders.insert(mover, at: afterTarget ? targetIndex + 1 : targetIndex)
        save(); return true
    }
    /// Atomically reorders tags in the persisted array order. Self-drops and
    /// unknown IDs abort with no mutation and no save, as do positional
    /// no-ops that would land the mover back at its own index (reported as
    /// success without touching the store). Only array order changes; tag
    /// IDs, names, colors, and tasks' tag associations stay identical. The
    /// published array is assigned once and only on a real move, with exactly
    /// one save per accepted move.
    @discardableResult public func reorderTags(moving: UUID, before target: UUID, afterTarget: Bool = false) -> Bool {
        guard moving != target else { return false }
        guard let from = data.tags.firstIndex(where: { $0.id == moving }),
              data.tags.contains(where: { $0.id == target }) else { return false }
        var updated = data.tags
        let mover = updated.remove(at: from)
        guard let t = updated.firstIndex(where: { $0.id == target }) else { return false }
        let insertAt = afterTarget ? t + 1 : t
        guard insertAt != from else { return true }
        updated.insert(mover, at: insertAt)
        data.tags = updated
        save(); return true
    }
    /// Drops a list onto a folder or the root heading: assigns membership and
    /// appends to the end of that segment. A nil folder (heading/root drops,
    /// the Move-to-Folder "No folder" item) always lands in the TOP root
    /// segment so legacy order is preserved; the absolute-end strip uses
    /// `moveListToRootEnd` for the trailing segment instead. Unknown
    /// lists/folders and self no-ops validate first; exactly one save.
    @discardableResult public func moveListToFolder(listID: UUID, folderID: UUID?) -> Bool {
        guard let index = data.lists.firstIndex(where: { $0.id == listID }) else { return false }
        if let folderID { guard data.folders.contains(where: { $0.id == folderID }) else { return false } }
        let list = data.lists[index]
        // No-op when membership already matches: still succeeds without saving.
        if list.folderID == folderID { return true }
        data.lists.remove(at: index)
        var updated = list; updated.folderID = folderID; updated.belowFolders = false
        if let folderID {
            let last = data.lists.lastIndex(where: { $0.folderID == folderID })
            data.lists.insert(updated, at: last.map { $0 + 1 } ?? data.lists.endIndex)
        } else {
            // Append after the last TOP root list so legacy order stays stable
            // and trailing rows are never disturbed by heading drops.
            let last = data.lists.lastIndex(where: { $0.folderID == nil && !$0.belowFolders })
            data.lists.insert(updated, at: last.map { $0 + 1 } ?? data.lists.endIndex)
        }
        save(); return true
    }

    /// Drops a list on the absolute-end strip: clears folder membership, marks
    /// trailing root placement, and appends after any existing trailing lists.
    /// A repeat drop when already the last trailing row is a no-op success
    /// without saving. Only array order, folderID, and the trailing flag
    /// change; IDs, tasks, and other orders stay.
    @discardableResult public func moveListToRootEnd(listID: UUID) -> Bool {
        guard let index = data.lists.firstIndex(where: { $0.id == listID }) else { return false }
        let list = data.lists[index]
        let trailingLast = data.lists.last(where: { $0.folderID == nil && $0.belowFolders })
        if list.folderID == nil, list.belowFolders, trailingLast?.id == listID { return true }
        data.lists.remove(at: index)
        var updated = list; updated.folderID = nil; updated.belowFolders = true
        let last = data.lists.lastIndex(where: { $0.folderID == nil && $0.belowFolders })
        data.lists.insert(updated, at: last.map { $0 + 1 } ?? data.lists.endIndex)
        save(); return true
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

    /// One custom-series step with the nominal/adjusted split. Due-date
    /// series use the shared engine stepping policy (`nextDueDateStep`):
    /// nominal chaining where the shape needs it, verbatim adjusted
    /// stepping otherwise, with the adjusted date validated against the
    /// rule end and strict forward progress against the displayed due.
    /// Completion-date series advance from the completion instant and carry
    /// no nominal. Returns the adjusted date, the nominal to record (nil
    /// for the completion anchor), and the next index. Pure, so the
    /// successor path and `nextRecurrenceDate` share it; a nil result ends
    /// the series and never falls back to another step.
    nonisolated private static func nextCustomStep(for task: TaskItem, now: Date, calendar: Calendar) -> (adjusted: Date, nominal: Date?, index: Int)? {
        guard let rule = task.customRecurrence, rule.isValid, let due = task.dueDate else { return nil }
        if rule.anchor == .completionDate {
            guard let next = rule.nextOccurrence(after: due, completedAt: now, calendar: calendar, occurrenceIndex: task.occurrenceIndex),
                  task.recurrenceEndDate.map({ calendar.startOfDay(for: next) <= calendar.startOfDay(for: $0) }) ?? true else { return nil }
            return (next, nil, task.occurrenceIndex + 1)
        }
        guard let step = rule.nextDueDateStep(after: due, nominalBase: task.recurrenceNominalDate, calendar: calendar, occurrenceIndex: task.occurrenceIndex),
              task.recurrenceEndDate.map({ calendar.startOfDay(for: step.adjusted) <= calendar.startOfDay(for: $0) }) ?? true else { return nil }
        return (step.adjusted, step.nominal, task.occurrenceIndex + 1)
    }

    /// Next due date for a repeating task, or nil when the series ends.
    /// Returns the date plus the successor's custom-series index (nil for
    /// legacy series, which carry no index). A valid custom rule supersedes
    /// the legacy enum; both honor the legacy end date. Due-date custom
    /// series advance from the stored nominal (see `nextCustomStep`), so
    /// the returned date already reflects the weekend roll.
    nonisolated public static func nextRecurrenceDate(for task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> (Date, Int?)? {
        guard let due = task.dueDate else { return nil }
        if task.isCustomRepeating {
            guard let step = nextCustomStep(for: task, now: now, calendar: calendar) else { return nil }
            return (step.adjusted, step.index)
        }
        guard task.recurrence != .none,
              let next = nextDate(after: due, rule: task.recurrence,
                                  anchorDay: task.recurrenceAnchorDay,
                                  anchorMonth: task.recurrenceAnchorMonth, calendar: calendar),
              task.recurrenceEndDate.map({ calendar.startOfDay(for: next) <= calendar.startOfDay(for: $0) }) ?? true else { return nil }
        return (next, nil)
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

    /// The Calendar's drag, resize, context-menu and accessible scheduling
    /// controls all use this one store mutation path.
    @discardableResult public func scheduleOnCalendar(id: UUID, operation: CalendarScheduleOperation, calendar: Calendar? = nil) -> CalendarScheduleUndo? {
        guard let original = data.tasks.first(where: { $0.id == id }), original.deletedAt == nil,
              !SmartListEligibility.isArchived(original, lists: data.lists),
              var changed = CalendarScheduling.applying(operation, to: original, displayCalendar: calendar ?? settings.calendar,
                  defaultMinutes: settings.defaultDurationMinutes > 0 ? settings.defaultDurationMinutes : 30) else { return nil }
        if Self.usesDefaultReminder(original, settings: settings) {
            // Let updateTask re-anchor the configured default, including
            // timed <-> all-day conversion; manual reminders already shifted.
            changed.reminderDates = original.reminderDates
            changed.reminderFollowsSchedule = true
        }
        updateTask(changed)
        guard let saved = data.tasks.first(where: { $0.id == id }) else { return nil }
        let before = CalendarScheduleSnapshot(original), after = CalendarScheduleSnapshot(saved)
        guard before != after else { return nil }
        return CalendarScheduleUndo(taskID: id, before: before, after: after,
                                    completedAt: saved.completedAt, wontDoAt: saved.wontDoAt)
    }

    @discardableResult public func undoCalendarSchedule(_ token: CalendarScheduleUndo) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == token.taskID }) else { return false }
        let current = data.tasks[index]
        guard current.deletedAt == nil, !SmartListEligibility.isArchived(current, lists: data.lists),
              current.completedAt == token.completedAt, current.wontDoAt == token.wontDoAt,
              CalendarScheduleSnapshot(current) == token.after else { return false }
        // A known schedule snapshot restores directly: the manual-edit
        // normalization in updateTask would discard the original nominal.
        var restored = token.before.restoring(on: current)
        restored.updatedAt = Date()
        data.tasks[index] = restored
        save()
        return true
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
