import Foundation
import Combine

@MainActor
public final class TaskStore: ObservableObject {
    @Published public private(set) var data: WorkspaceData
    @Published public private(set) var storageError: String?
    public let fileURL: URL
    private var blockedByLoadFailure = false
    public var needsRecovery: Bool { blockedByLoadFailure }

    public init(fileURL: URL? = nil, seed: Bool = true) {
        self.fileURL = fileURL ?? Self.defaultFileURL
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
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Taskvovsky", isDirectory: true).appendingPathComponent("workspace.json")
    }

    public func save() {
        guard !blockedByLoadFailure else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
            storageError = nil
        } catch { storageError = "Could not save workspace: \(error.localizedDescription)" }
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

    public func updateTask(_ task: TaskItem) {
        guard let index = data.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var task = task
        let old = data.tasks[index]
        if old.dueDate != task.dueDate || old.recurrence != task.recurrence {
            task.recurrenceAnchorDay = nil; task.recurrenceAnchorMonth = nil
        }
        task.updatedAt = Date()
        data.tasks[index] = task
        save()
    }

    @discardableResult public func createTask(title: String, listID: UUID? = nil, kind: TaskKind = .task, dueDate: Date? = nil) -> UUID {
        let task = TaskItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines), listID: listID, kind: kind, dueDate: dueDate)
        data.tasks.append(task); save(); return task.id
    }

    public func toggleComplete(id: UUID) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt == nil else { return }
        let now = Date()
        if data.tasks[index].completedAt != nil {
            data.tasks[index].completedAt = nil
        } else {
            data.tasks[index].completedAt = now
            let original = data.tasks[index]
            if original.recurrence != .none, !data.tasks.contains(where: { $0.recurrenceSourceID == original.id }),
               let due = original.dueDate,
               let next = Self.nextDate(after: due, rule: original.recurrence,
                                        anchorDay: original.recurrenceAnchorDay,
                                        anchorMonth: original.recurrenceAnchorMonth) {
                var copy = original
                copy.id = UUID(); copy.dueDate = next; copy.completedAt = nil; copy.deletedAt = nil
                copy.reminderDate = original.reminderDate.map { next.addingTimeInterval($0.timeIntervalSince(due)) }
                copy.createdAt = now; copy.updatedAt = now
                copy.recurrenceSourceID = original.id
                copy.recurrenceAnchorDay = original.recurrenceAnchorDay ?? Calendar.current.component(.day, from: due)
                copy.recurrenceAnchorMonth = original.recurrenceAnchorMonth ?? Calendar.current.component(.month, from: due)
                copy.checklist = original.checklist.map { ChecklistItem(title: $0.title) }
                data.tasks.append(copy)
            }
        }
        data.tasks[index].updatedAt = now; save()
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
    @discardableResult public func createList(name: String, color: String, kind: TaskKind = .task) -> UUID {
        let list = TaskList(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color, kind: kind); data.lists.append(list); save(); return list.id
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
        ], lists: [personal, work], tags: [idea])
    }
}
