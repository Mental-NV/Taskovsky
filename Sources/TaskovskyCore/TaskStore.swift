import TaskovskyDomain
import Foundation
import Combine

@MainActor
public final class TaskStore: ObservableObject {
    @Published public private(set) var data: WorkspaceData
    @Published public private(set) var storageError: String?
    @Published public var settings: AppSettings {
        didSet { if !publishingSavedSettings { saveSettings() } }
    }
    private var publishingSavedSettings = false
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
                let bytes = try Data(contentsOf: self.fileURL)
                self.data = try Self.decodeWorkspace(bytes)
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

    private static func decodeWorkspace(_ bytes: Data) throws -> WorkspaceData {
        let workspace = try JSONDecoder().decode(WorkspaceData.self, from: bytes)
        if workspace.requiresProtectedTaskCollection {
            let loaded = try JSONSerialization.jsonObject(with: bytes)
            let understood = try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace))
            guard try JSONSerialization.data(withJSONObject: loaded, options: .sortedKeys) ==
                      JSONSerialization.data(withJSONObject: understood, options: .sortedKeys) else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "The protected task data includes unsupported fields or values."])
            }
        }
        return workspace
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
        _ = writeWorkspace()
    }

    private func writeWorkspace(_ replacement: WorkspaceData? = nil) -> Bool {
        writeWorkspaceBytes {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(replacement ?? data)
        }
    }

    private func writeWorkspaceBytes(_ encode: () throws -> Data) -> Bool {
        guard !blockedByLoadFailure else { return false }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encode().write(to: fileURL, options: .atomic)
            if !settingsLoadFailed { storageError = settingsSaveError }
            return true
        } catch {
            storageError = "Could not save workspace: \(error.localizedDescription)"
            return false
        }
    }

    private func saveSettings() { _ = writeSettings(settings) }

    private func writeSettings(_ replacement: AppSettings) -> Bool {
        guard !settingsLoadFailed else { return false }
        do {
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(replacement).write(to: settingsURL, options: .atomic)
            if settingsSaveError != nil, storageError == settingsSaveError { storageError = nil }
            settingsSaveError = nil
            return true
        } catch {
            settingsSaveError = "Could not save settings: \(error.localizedDescription)"
            storageError = settingsSaveError
            return false
        }
    }

    public func saveCalendarSourceColors(_ colors: CalendarColorSource.Overrides,
                                         expected: CalendarColorSource.Overrides) -> Bool {
        guard settings.calendarOptions.sourceColors == expected else { return false }
        guard colors != expected else { return true }
        var replacement = settings
        replacement.calendarOptions.sourceColors = colors
        guard writeSettings(replacement) else { return false }
        publishingSavedSettings = true
        defer { publishingSavedSettings = false }
        settings = replacement
        return true
    }

    public func saveCalendarListColor(id: UUID, expected: String, color: String) -> Bool {
        guard !blockedByLoadFailure, !settingsLoadFailed,
              settings.calendarOptions.sourceColors[.list(id)] == nil else { return false }
        var draft = data
        guard let changed = ListOrganizationCommand.setListColor(id, expected: expected, color: color)
            .apply(to: &draft, now: Date()) else { return false }
        guard let bytes = try? Data(contentsOf: fileURL),
              let saved = try? Self.decodeWorkspace(bytes), saved == data else { return false }
        guard changed else { return true }
        // Patch the loaded document so a color edit preserves fields the model doesn't round-trip.
        guard var document = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              var lists = document["lists"] as? [[String: Any]],
              let index = lists.firstIndex(where: { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) == id }),
              let color = draft.lists.first(where: { $0.id == id })?.color else { return false }
        lists[index]["color"] = color
        document["lists"] = lists
        guard writeWorkspaceBytes({
            try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
        }) else { return false }
        data = draft
        return true
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

    public func setChecklistItemCompleted(taskID: UUID, itemID: UUID, completed: Bool) {
        _ = saveTaskMetadata(.setChecklistCompleted(id: itemID, completed: completed), taskID: taskID)
    }

    public func setTaskProgress(taskID: UUID, percent: Int, expected: Int?) -> Bool {
        guard let original = data.tasks.first(where: { $0.id == taskID }), original.manualProgress == expected else { return false }
        return saveTaskMetadata(.progress(percent), taskID: taskID)
    }

    private func saveTaskMetadata(_ command: TaskMetadataChange, taskID: UUID) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        let original = data.tasks[index]
        guard original.kind == .task, original.deletedAt == nil, !isInArchivedList(original) else { return false }
        do {
            guard var updated = try command.applying(to: original, availableTags: data.tags) else { return true }
            updated.updatedAt = Date()
            var draft = data
            draft.tasks[index] = updated
            guard writeWorkspace(draft) else { return false }
            data = draft
            return true
        } catch {
            return false
        }
    }

    /// Mac schedule editor owns scheduling fields, never the entire opening record.
    public func saveSchedule(_ candidate: TaskItem, expected: TaskItem) -> Bool {
        guard candidate.id == expected.id,
              let index = data.tasks.firstIndex(where: { $0.id == expected.id }) else { return false }
        let current = data.tasks[index]
        guard current.deletedAt == nil, !isInArchivedList(current),
              current.kind == expected.kind, current.completedAt == expected.completedAt,
              current.wontDoAt == expected.wontDoAt,
              CalendarScheduleSnapshot(current) == CalendarScheduleSnapshot(expected) else { return false }
        var updated = CalendarScheduleSnapshot(candidate).restoring(on: current)
        var calendar = settings.calendar
        if let id = updated.timeZoneID, let zone = TimeZone(identifier: id) { calendar.timeZone = zone }
        let schedule = Self.coherentSchedule(dueDate: updated.dueDate, hasDueTime: updated.hasDueTime,
                                            window: updated.scheduledDuration, calendar: calendar)
        updated.dueDate = schedule.dueDate; updated.hasDueTime = schedule.hasDueTime
        updated.scheduledDuration = schedule.window
        TaskSchedulePolicy.reconcileSeries(of: &updated, from: current)
        TaskSchedulePolicy.normalizeEndReminder(of: &updated)
        updated.updatedAt = Date()
        var staged = data; staged.tasks[index] = updated
        guard writeWorkspace(staged) else { return false }
        data = staged
        return true
    }

    public func updateTask(_ task: TaskItem, applyDefaultReminders: Bool = true) {
        guard let index = data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var task = task
        let old = data.tasks[index]
        // Progress has its own save command. A schedule or text draft can
        // carry a snapshot from before that command ran.
        task.manualProgress = old.manualProgress
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
            switch TaskHierarchy.resolveParentLink(childID: task.id, parentID: task.parentID, tasks: data.tasks, lists: data.lists) {
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
        task.sectionID = task.listID == old.listID && task.parentID == nil ? old.sectionID : nil
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
        TaskSchedulePolicy.reconcileSeries(of: &task, from: old)
        TaskSchedulePolicy.normalizeEndReminder(of: &task)
        if applyDefaultReminders {
            TaskSchedulePolicy.reconcileReminders(of: &task, from: old, settings: settings, calendar: settings.calendar)
        }
        task.updatedAt = Date()
        data.tasks[index] = task
        save()
    }

    @discardableResult public func createTask(title: String, listID: UUID? = nil, kind: TaskKind = .task, dueDate: Date? = nil, useDefaultList: Bool = true, preferRecognizedDate: Bool = false, recognizeDates: Bool = true, body: String = "", duration: TaskDurationRange? = nil) -> UUID {
        let result = TaskCreation.make(workspace: data, settings: settings, title: title, listID: listID, kind: kind, dueDate: dueDate, useDefaultList: useDefaultList, preferRecognizedDate: preferRecognizedDate, recognizeDates: recognizeDates, body: body, duration: duration)
        return persistCreatedTask(result)
    }

    /// Save the edited local Summary as one final, metadata-free Inbox note.
    public func createSummaryNote(title: String, body: String) -> UUID? {
        var note = TaskItem(title: title, body: body, kind: .note)
        note.reminderFollowsSchedule = false
        return persistCreatedTaskAtomically(note, tags: [], resolveTitle: false)
    }

    /// Initial Mac QuickEntry capture acknowledges persistence before publishing.
    public func createQuickEntryTask(title: String, listID: UUID? = nil, kind: TaskKind = .task,
                                     dueDate: Date? = nil, useDefaultList: Bool = true,
                                     preferRecognizedDate: Bool = false, recognizeDates: Bool = true,
                                     body: String = "") -> UUID? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let result = TaskCreation.make(workspace: data, settings: settings, title: title, listID: listID,
                                       kind: kind, dueDate: dueDate, useDefaultList: useDefaultList,
                                       preferRecognizedDate: preferRecognizedDate, recognizeDates: recognizeDates, body: body)
        return persistCreatedTaskAtomically(result.task, tags: result.addedTags, resolveTitle: true)
    }

    public func createTask(title: String, inSection sectionID: UUID, listID: UUID, kind: TaskKind,
                           recognizeDates: Bool, body: String) -> UUID? {
        guard let list = data.lists.first(where: { $0.id == listID && !$0.isArchived }),
              list.sections.contains(where: { $0.id == sectionID }) else { return nil }
        let result = TaskCreation.make(workspace: data, settings: settings, title: title, listID: listID,
                                       kind: kind, useDefaultList: false, preferRecognizedDate: true,
                                       recognizeDates: recognizeDates, body: body)
        return persistSectionTask(result.task, tags: result.addedTags, sectionID: sectionID, resolveTitle: true)
    }

    public func createTimelineTask(title: String, on date: Date, listID: UUID?) -> UUID? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              listID == nil || data.lists.contains(where: { $0.id == listID && !$0.isArchived && $0.kind == .task })
        else { return nil }
        let day = settings.calendar.startOfDay(for: date)
        let result = TaskCreation.make(workspace: data, settings: settings, title: title, listID: listID,
                                       dueDate: day, useDefaultList: false, recognizeDates: false, calendar: settings.calendar)
        guard !result.task.title.isEmpty else { return nil }
        return persistCreatedTaskAtomically(result.task, tags: result.addedTags, resolveTitle: false)
    }

    /// Calendar creation publishes task, parsed tags and reminder state only after persistence.
    public func createCalendarTask(title: String, listID: UUID?, duration: TaskDurationRange) -> UUID? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              duration.start.timeIntervalSinceReferenceDate.isFinite,
              duration.end.timeIntervalSinceReferenceDate.isFinite,
              duration.validated(in: settings.calendar) != nil else { return nil }
        let result = TaskCreation.make(workspace: data, settings: settings, title: title, listID: listID,
                                       dueDate: duration.end, useDefaultList: false, recognizeDates: false,
                                       duration: duration)
        guard !result.task.title.isEmpty else { return nil }
        return persistCreatedTaskAtomically(result.task, tags: result.addedTags, resolveTitle: true)
    }

    private func persistCreatedTask(_ result: TaskCreationResult) -> UUID {
        insertCreatedTask(result.task, tags: result.addedTags, into: &data)
        save()
        if settings.urlParsing { resolveURLTitle(for: result.task.id) }
        return result.task.id
    }

    private func persistSectionTask(_ item: TaskItem, tags: [TaskTag], sectionID: UUID, resolveTitle: Bool) -> UUID? {
        var task = item
        task.sectionID = sectionID
        return persistCreatedTaskAtomically(task, tags: tags, resolveTitle: resolveTitle)
    }

    private func persistCreatedTaskAtomically(_ task: TaskItem, tags: [TaskTag], resolveTitle: Bool) -> UUID? {
        var draft = data
        insertCreatedTask(task, tags: tags, into: &draft)
        guard writeWorkspace(draft) else { return nil }
        data = draft
        if resolveTitle && settings.urlParsing { resolveURLTitle(for: task.id) }
        return task.id
    }

    private func insertCreatedTask(_ task: TaskItem, tags: [TaskTag], into draft: inout WorkspaceData) {
        draft.tags.append(contentsOf: tags)
        TaskCreation.insert([task], into: &draft, position: settings.defaultAddTo)
    }

    public enum TextBatchResult { case saved, stale, failed, uncertain }

    public func createTextBatch(_ batch: TaskTextBatch, expected: WorkspaceData, expectedSettings: AppSettings) -> TextBatchResult {
        guard !blockedByLoadFailure else { return .failed }
        if let result = checkSavedTextBatch(batch, expected: data) { return result }
        guard data == expected, settings == expectedSettings else { return .stale }
        var draft = data
        TaskCreation.insert(batch.tasks, into: &draft, position: settings.defaultAddTo)
        if writeWorkspace(draft) {
            data = draft
            return .saved
        }
        return checkSavedTextBatch(batch, expected: expected) ?? .failed
    }

    private func checkSavedTextBatch(_ batch: TaskTextBatch, expected: WorkspaceData) -> TextBatchResult? {
        do {
            let saved = try Self.decodeWorkspace(Data(contentsOf: fileURL))
            switch TaskCreation.presence(of: batch.tasks, in: saved) {
            case .matching:
                data = saved
                if !settingsLoadFailed { storageError = settingsSaveError }
                return .saved
            case .absent where saved == expected: return nil
            case .absent, .conflicting: return .uncertain
            }
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return expected == WorkspaceData() ? nil : .uncertain
        } catch { return .uncertain }
    }

    public static func recognizeDate(in text: String, calendar: Calendar, now: Date = Date()) -> (date: Date, hasTime: Bool, range: Range<String.Index>)? {
        TaskCreation.recognizeDate(in: text, calendar: calendar, now: now)
    }

    /// True when the task sits in an archived list (read-only content).
    private func isInArchivedList(_ task: TaskItem) -> Bool {
        task.listID.flatMap { id in data.lists.first { $0.id == id } }?.isArchived ?? false
    }

    /// nil refuses the command, false accepts a no-op, true persists changes.
    @discardableResult private func commitLifecycle(_ change: (inout TaskLifecycle) -> Bool?) -> Bool {
        var lifecycle = TaskLifecycle(data: data, completionSnapshots: completionSnapshots)
        guard let changed = change(&lifecycle) else { return false }
        if changed {
            guard writeWorkspace(lifecycle.data) else { return false }
            data = lifecycle.data
            completionSnapshots = lifecycle.completionSnapshots
        }
        return true
    }

    @discardableResult public func toggleComplete(id: UUID) -> Bool {
        let calendar = settings.calendar
        return commitLifecycle { $0.toggleComplete(id: id, now: Date(), calendar: calendar) ? true : nil }
    }
    @discardableResult public func undoCompletion(id: UUID) -> Bool {
        commitLifecycle { $0.undoCompletion(id: id, now: Date()) ? true : nil }
    }
    @discardableResult public func markWontDo(id: UUID) -> Bool {
        commitLifecycle { $0.markWontDo(id: id, now: Date()) ? true : nil }
    }
    @discardableResult public func reopenTask(id: UUID) -> Bool {
        commitLifecycle { $0.reopenTask(id: id, now: Date()) ? true : nil }
    }
    @discardableResult public func setPinned(id: UUID, pinned: Bool) -> Bool {
        commitLifecycle { $0.setPinned(id: id, pinned: pinned, now: Date()) }
    }

    /// Duration coherence (pure): when a scheduled window is present it must
    /// be valid, and the due date must equal the window end with
    /// `hasDueTime == !isAllDay`. Invalid windows (end before start) drop —
    /// they can never anchor a due date — and a record is never left
    /// undated holding an absolute window (the end becomes the due date).
    /// Dateless *templates* may still store a bare shape; this applies to
    /// live task records (create, save/update, instantiate, successors).
    nonisolated static func coherentSchedule(dueDate: Date?, hasDueTime: Bool, window: TaskDurationRange?, calendar: Calendar) -> (dueDate: Date?, hasDueTime: Bool, window: TaskDurationRange?) {
        TaskSchedulePolicy.coherentSchedule(dueDate: dueDate, hasDueTime: hasDueTime, window: window, calendar: calendar)
    }

    @discardableResult public func createFilter(_ filter: TaskFilter) -> UUID { data.filters.append(filter); save(); return filter.id }
    public func updateFilter(_ filter: TaskFilter) { guard let i = data.filters.firstIndex(where: { $0.id == filter.id }) else { return }; data.filters[i] = filter; save() }
    public func deleteFilter(id: UUID) { data.filters.removeAll { $0.id == id }; save() }
    @discardableResult public func saveTemplate(from id: UUID, name: String? = nil) -> UUID? {
        guard let task = data.tasks.first(where: { $0.id == id }) else { return nil }
        let template = TaskTemplate(name: name ?? task.title, title: task.title, body: task.body, checklist: task.checklist, priority: task.priority, tagIDs: task.tagIDs, kind: task.kind, richBody: task.richBody?.valid(for: task.body), customRecurrence: task.customRecurrence, scheduledDuration: task.scheduledDuration)
        var staged = data
        staged.templates.append(template)
        guard writeWorkspace(staged) else { return nil }
        data = staged
        return template.id
    }
    @discardableResult public func updateTemplate(_ template: TaskTemplate) -> Bool {
        var staged = data
        if let i = staged.templates.firstIndex(where: { $0.id == template.id }) { staged.templates[i] = template }
        else { staged.templates.append(template) }
        guard writeWorkspace(staged) else { return false }
        data = staged
        return true
    }
    @discardableResult public func deleteTemplate(id: UUID) -> Bool {
        var staged = data
        staged.templates.removeAll { $0.id == id }
        guard writeWorkspace(staged) else { return false }
        data = staged
        return true
    }
    public func reorderTemplates(_ ids: [UUID], expectedOrder: [UUID]) -> Bool {
        var staged = data
        let change = TaskTemplateChange.reorder(ids: ids, expectedOrder: expectedOrder)
        guard let changed = try? change.apply(to: &staged, settings: settings, now: Date(), calendar: settings.calendar)
        else { return false }
        guard changed else { return true }
        guard writeWorkspace(staged) else { return false }
        data = staged
        return true
    }

    @discardableResult public func createTaskFromTemplate(id: UUID, listID: UUID? = nil, dueDate: Date? = nil, useDefaultList: Bool = true, sectionID: UUID? = nil, expectedTemplate: TaskTemplate? = nil) -> UUID? {
        if let expectedTemplate {
            guard expectedTemplate.id == id, data.templates.first(where: { $0.id == id }) == expectedTemplate else { return nil }
        }
        if let sectionID {
            guard data.lists.contains(where: { $0.id == listID && !$0.isArchived && $0.sections.contains(where: { $0.id == sectionID }) })
            else { return nil }
        }
        guard let task = TaskCreation.fromTemplate(workspace: data, settings: settings, id: id, listID: listID, dueDate: dueDate, useDefaultList: useDefaultList) else { return nil }
        if let sectionID { return persistSectionTask(task, tags: [], sectionID: sectionID, resolveTitle: false) }
        return persistCreatedTaskAtomically(task, tags: [], resolveTitle: false)
    }
    @discardableResult public func trashTask(id: UUID) -> Bool {
        commitLifecycle { $0.trashTask(id: id, now: Date()) ? true : nil }
    }
    @discardableResult public func restoreTask(id: UUID) -> Bool {
        commitLifecycle { $0.restoreTask(id: id, now: Date()) ? true : nil }
    }
    @discardableResult public func purgeTask(id: UUID) -> Bool {
        commitLifecycle { $0.purgeTask(id: id, now: Date()) ? true : nil }
    }

    @discardableResult public func duplicateTask(id: UUID) -> UUID? {
        let copyID = UUID()
        return commitLifecycle({ $0.duplicateTask(id: id, copyID: copyID, now: Date()) ? true : nil }) ? copyID : nil
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
        let copyID = UUID()
        guard ListOrganization.duplicateList(id, copyID: copyID, in: &data, now: Date()) else { return nil }
        save()
        return copyID
    }
    public func updateList(_ list: TaskList) {
        guard let index = data.lists.firstIndex(where: { $0.id == list.id }) else { return }
        var list = list
        list.sections = data.lists[index].sections
        // Membership and trailing placement travel on the record itself:
        // callers must carry the stored folderID and belowFolders
        // (EntityEditor(list:) does) or the save resets them. Unknown folder
        // IDs always clear to top root.
        if let folder = list.folderID, !data.folders.contains(where: { $0.id == folder }) { list.folderID = nil; list.belowFolders = false }
        data.lists[index] = list; save()
    }
    @discardableResult public func applySectionChange(_ change: TaskSectionChange) -> Bool? {
        var draft = data
        guard let changed = change.apply(to: &draft, now: Date()) else { return nil }
        guard changed else { return false }
        guard writeWorkspace(draft) else { return nil }
        data = draft
        return true
    }
    public func deleteList(id: UUID) {
        ListOrganization.deleteList(id, in: &data, now: Date())
        save()
    }
    @discardableResult public func createTag(name: String, color: String, parentID: UUID? = nil) -> UUID {
        let normalized = TagOrganization.normalizedName(name)
        if let existing = data.tags.first(where: { TagOrganization.normalizedName($0.name).localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            return existing.id
        }
        // Unknown parents clear to top level, matching the load policy.
        let parent = parentID.flatMap { id in data.tags.contains(where: { $0.id == id }) ? id : nil }
        let tag = TaskTag(name: normalized, color: color, parentID: parent); data.tags.append(tag); save(); return tag.id
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
        var updated = data
        guard TagOrganization.delete(id, in: &updated, now: Date()) else { return }
        data = updated
        if settings.defaultTagID == id { settings.defaultTagID = nil }
        save()
    }

    /// Sets a tag's parent. Rejects unknown IDs, self-parenting, and parents
    /// that would create a cycle (a descendant of the tag). Nil clears to top
    /// level. Exactly one save per accepted change.
    @discardableResult public func setTagParent(id: UUID, parentID: UUID?) -> Bool {
        guard let index = data.tags.firstIndex(where: { $0.id == id }) else { return false }
        guard TagOrganization.allowsParent(parentID, for: id, in: data.tags) else { return false }
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

    @discardableResult public func setTaskParent(id: UUID, parentID: UUID?) -> Bool {
        guard let changed = TaskHierarchy.setParent(childID: id, parentID: parentID, in: &data, now: Date()) else {
            return false
        }
        if changed { save() }
        return true
    }

    @discardableResult public func addSubtask(to parentID: UUID, title: String) -> UUID? {
        let id = UUID()
        guard TaskHierarchy.addChild(id: id, to: parentID, title: title, in: &data,
                                     position: settings.defaultAddTo, now: Date()) else { return nil }
        save()
        return id
    }

    /// Merges `source` into `target`: task, template, and saved-filter refs
    /// are rewritten (deduplicated), the default tag follows, and source's
    /// children reparent without cycles. When the target is a descendant of
    /// the source, the target takes the source's slot, the source's other
    /// children move under the target, and ancestor links that would cycle
    /// become siblings at the source's slot. The source is then deleted.
    /// Unrelated fields are untouched; exactly one save.
    @discardableResult public func mergeTags(source: UUID, target: UUID) -> Bool {
        var updated = data
        guard TagOrganization.merge(source: source, target: target, in: &updated, now: Date()) else { return false }
        data = updated
        if settings.defaultTagID == source { settings.defaultTagID = target }
        save()
        return true
    }

    @discardableResult public func moveTasksToList(ids: [UUID], listID: UUID?) -> Bool {
        commitLifecycle { $0.moveTasksToList(ids: ids, listID: listID, now: Date()) }
    }

    public func applyBatch(_ edit: TaskBatchEdit) throws -> Bool {
        let current = TaskLifecycle(data: data, completionSnapshots: completionSnapshots)
        guard let staged = try edit.applying(to: current, settings: settings, now: Date(),
                                            calendar: settings.calendar) else { return true }
        guard writeWorkspace(staged.data) else { return false }
        data = staged.data
        completionSnapshots = staged.completionSnapshots
        return true
    }

    /// Atomically reorders tasks: moves `moving` (in the given relative order)
    /// to just before `target`, or just after it when `afterTarget` is true.
    /// Validates the whole batch first: unknown or deleted records, duplicate
    /// IDs, and self-drops (target inside `moving`) abort with no mutation.
    /// Nothing but array order changes; no other field is touched.
    @discardableResult public func reorderTasks(moving: [UUID], before target: UUID, afterTarget: Bool = false) -> Bool {
        guard data.reorderTasks(moving: moving, before: target, afterTarget: afterTarget) else { return false }
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
        guard ListOrganization.reorderList(moving, relativeTo: target, after: afterTarget, in: &data) else { return false }
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
        guard ListOrganization.ungroupFolder(id, in: &data) else { return false }
        save()
        return true
    }
    @discardableResult public func reorderFolders(moving: UUID, before target: UUID, afterTarget: Bool = false) -> Bool {
        guard ListOrganization.reorderFolder(moving, relativeTo: target, after: afterTarget, in: &data) else { return false }
        save()
        return true
    }
    /// Atomically reorders tags in the persisted array order. Self-drops and
    /// unknown IDs abort with no mutation and no save, as do positional
    /// no-ops that would land the mover back at its own index (reported as
    /// success without touching the store). Only array order changes; tag
    /// IDs, names, colors, and tasks' tag associations stay identical. The
    /// published array is assigned once and only on a real move, with exactly
    /// one save per accepted move.
    @discardableResult public func reorderTags(moving: UUID, before target: UUID, afterTarget: Bool = false) -> Bool {
        guard let updated = TagOrganization.reordered(data.tags, moving: moving, relativeTo: target, after: afterTarget)
        else { return false }
        guard updated != data.tags else { return true }
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
        TaskSchedulePolicy.defaultReminderDates(due: due, hasTime: hasTime, settings: settings, calendar: calendar)
    }

    nonisolated public static func defaultReminderDate(due: Date, hasTime: Bool, settings: AppSettings, calendar: Calendar) -> Date? {
        defaultReminderDates(due: due, hasTime: hasTime, settings: settings, calendar: calendar).first
    }

    nonisolated public static func usesDefaultReminder(_ task: TaskItem, settings: AppSettings) -> Bool {
        TaskSchedulePolicy.usesDefaultReminder(task, settings: settings, calendar: settings.calendar)
    }

    nonisolated public static func nextRecurrenceDate(for task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> (Date, Int?)? {
        TaskLifecycle.nextRecurrenceDate(for: task, now: now, calendar: calendar)
    }

    nonisolated public static func nextDate(after date: Date, rule: RepeatRule, anchorDay: Int? = nil, anchorMonth: Int? = nil, calendar: Calendar = .current) -> Date? {
        LegacyRecurrence.nextDate(after: date, rule: rule, anchorDay: anchorDay, anchorMonth: anchorMonth, calendar: calendar)
    }

    /// The Calendar's drag, resize, context-menu and accessible scheduling
    /// controls all use this one store mutation path.
    @discardableResult public func scheduleOnCalendar(id: UUID, operation: CalendarScheduleOperation, calendar: Calendar? = nil,
                                                      scope: CalendarScheduleScope = .series) -> CalendarScheduleUndo? {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return nil }
        let original = data.tasks[index]
        guard original.deletedAt == nil,
              !SmartListEligibility.isArchived(original, lists: data.lists),
              let changed = CalendarScheduling.prepared(operation, to: original,
                  displayCalendar: calendar ?? settings.calendar, settings: settings, policyCalendar: settings.calendar,
                  scope: scope, in: data.tasks)
        else { return nil }
        let before = CalendarScheduleSnapshot(original), after = CalendarScheduleSnapshot(changed)
        guard before != after, commitCalendarSchedule(changed, at: index) else { return nil }
        return CalendarScheduleUndo(taskID: id, before: before, after: after,
                                    completedAt: changed.completedAt, wontDoAt: changed.wontDoAt, operation: operation)
    }

    @discardableResult public func undoCalendarSchedule(_ token: CalendarScheduleUndo) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == token.taskID }) else { return false }
        guard let restored = token.restoring(on: data.tasks[index], lists: data.lists, tasks: data.tasks) else { return false }
        return commitCalendarSchedule(restored, at: index)
    }

    private func commitCalendarSchedule(_ task: TaskItem, at index: Int) -> Bool {
        let previous = data.tasks[index]
        var task = task
        task.updatedAt = Date()
        data.tasks[index] = task
        guard !writeWorkspace() else { return true }
        data.tasks[index] = previous
        return false
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
