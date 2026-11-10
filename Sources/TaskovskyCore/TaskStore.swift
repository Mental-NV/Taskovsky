import TaskovskyDomain
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
        TaskSchedulePolicy.reconcileSeries(of: &task, from: old)
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
        let result = TaskCreation.make(workspace: data, settings: settings, title: title, listID: listID, kind: kind, dueDate: dueDate, useDefaultList: useDefaultList, preferRecognizedDate: preferRecognizedDate, recognizeDates: recognizeDates, body: body, duration: duration)
        data.tags.append(contentsOf: result.addedTags)
        if settings.defaultAddTo == .top { data.tasks.insert(result.task, at: 0) } else { data.tasks.append(result.task) }
        save(); if settings.urlParsing { resolveURLTitle(for: result.task.id) }; return result.task.id
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
            data = lifecycle.data
            completionSnapshots = lifecycle.completionSnapshots
            save()
        }
        return true
    }

    public func toggleComplete(id: UUID) {
        let calendar = settings.calendar
        commitLifecycle { $0.toggleComplete(id: id, now: Date(), calendar: calendar) }
    }
    public func undoCompletion(id: UUID) {
        commitLifecycle { $0.undoCompletion(id: id, now: Date()) }
    }
    public func markWontDo(id: UUID) {
        commitLifecycle { $0.markWontDo(id: id, now: Date()) }
    }
    public func reopenTask(id: UUID) {
        commitLifecycle { $0.reopenTask(id: id, now: Date()) }
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
        data.templates.append(template); save(); return template.id
    }
    public func updateTemplate(_ template: TaskTemplate) { if let i = data.templates.firstIndex(where: { $0.id == template.id }) { data.templates[i] = template } else { data.templates.append(template) }; save() }
    public func deleteTemplate(id: UUID) { data.templates.removeAll { $0.id == id }; save() }
    @discardableResult public func createTaskFromTemplate(id: UUID, listID: UUID? = nil, dueDate: Date? = nil, useDefaultList: Bool = true) -> UUID? {
        guard let task = TaskCreation.fromTemplate(workspace: data, settings: settings, id: id, listID: listID, dueDate: dueDate, useDefaultList: useDefaultList) else { return nil }
        if settings.defaultAddTo == .top { data.tasks.insert(task, at: 0) } else { data.tasks.append(task) }; save(); return task.id
    }
    public func trashTask(id: UUID) {
        commitLifecycle { $0.trashTask(id: id, now: Date()) }
    }
    public func restoreTask(id: UUID) {
        commitLifecycle { $0.restoreTask(id: id, now: Date()) }
    }
    @discardableResult public func purgeTask(id: UUID) -> Bool {
        commitLifecycle { $0.purgeTask(id: id, now: Date()) ? true : nil }
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

    @discardableResult public func moveTasksToList(ids: [UUID], listID: UUID?) -> Bool {
        commitLifecycle { $0.moveTasksToList(ids: ids, listID: listID, now: Date()) }
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
    @discardableResult public func scheduleOnCalendar(id: UUID, operation: CalendarScheduleOperation, calendar: Calendar? = nil) -> CalendarScheduleUndo? {
        guard let original = data.tasks.first(where: { $0.id == id }), original.deletedAt == nil,
              !SmartListEligibility.isArchived(original, lists: data.lists),
              var changed = CalendarScheduling.applying(operation, to: original, displayCalendar: calendar ?? settings.calendar,
                  defaultMinutes: settings.defaultDurationMinutes > 0 ? settings.defaultDurationMinutes : 30) else { return nil }
        // A schedule no-op must not rewrite reminder policy, recurrence
        // position, timestamps or the file just because an editor was saved.
        guard CalendarScheduleSnapshot(changed) != CalendarScheduleSnapshot(original) else { return nil }
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
