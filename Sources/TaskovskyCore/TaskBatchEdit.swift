import Foundation

public enum TaskBatchRefusal: Error, Equatable, Sendable {
    case invalidSelection, readOnlyRecord, unavailableList, unavailableTag, invalidSchedule
}

public struct TaskBatchEdit: Sendable {
    public enum Kind: CaseIterable, Hashable, Sendable {
        case schedule, priority, tags, move, complete, trash

        public func isAvailable(for tasks: [TaskItem], lists: [TaskList]) -> Bool {
            guard !tasks.isEmpty, tasks.allSatisfy({ $0.deletedAt == nil }) else { return false }
            if self == .move { return true }
            guard tasks.allSatisfy({ !SmartListEligibility.isArchived($0, lists: lists) }) else { return false }
            switch self {
            case .schedule, .priority, .complete: return tasks.allSatisfy { $0.kind == .task }
            case .tags, .move, .trash: return true
            }
        }
    }

    public enum Action: Sendable {
        case schedule(Date?), priority(TaskPriority), tags([UUID], remove: Bool)
        case move(UUID?), complete, trash

        public var kind: Kind {
            switch self {
            case .schedule: .schedule
            case .priority: .priority
            case .tags: .tags
            case .move: .move
            case .complete: .complete
            case .trash: .trash
            }
        }
    }

    public let ids: [UUID]
    public let action: Action

    public init(ids: [UUID], action: Action) {
        self.ids = ids
        self.action = action
    }

    /// Returns a staged result or an accepted no-op. The caller publishes the
    /// graph and transient completion snapshots only after a confirmed write.
    public func applying(to current: TaskLifecycle, settings: AppSettings, now: Date,
                         calendar: Calendar) throws -> TaskLifecycle? {
        let data = current.data
        let selectedIDs = Set(ids)
        guard !ids.isEmpty, selectedIDs.count == ids.count,
              Set(data.tasks.map(\.id)).count == data.tasks.count else { throw TaskBatchRefusal.invalidSelection }
        let indices = data.tasks.indices.filter { selectedIDs.contains(data.tasks[$0].id) }
        guard indices.count == ids.count else { throw TaskBatchRefusal.invalidSelection }
        let selected = indices.map { data.tasks[$0] }
        guard action.kind.isAvailable(for: selected, lists: data.lists) else { throw TaskBatchRefusal.readOnlyRecord }

        switch action {
        case .move(let list):
            var staged = current
            guard let changed = staged.moveTasksToList(ids: ids, listID: list, now: now) else {
                throw TaskBatchRefusal.unavailableList
            }
            return changed ? staged : nil
        case .complete, .trash:
            return try applyingLifecycle(to: current, selected: selected, now: now, calendar: calendar)
        case .schedule, .priority, .tags:
            if case .tags(let tags, _) = action {
                let known = Set(data.tags.map(\.id))
                guard !tags.isEmpty, Set(tags).count == tags.count, tags.allSatisfy(known.contains) else {
                    throw TaskBatchRefusal.unavailableTag
                }
            }
            var staged = data
            var changed = false
            for index in indices {
                if var task = try updated(data.tasks[index], in: data, settings: settings, calendar: calendar) {
                    task.updatedAt = now
                    staged.tasks[index] = task
                    changed = true
                }
            }
            return changed ? TaskLifecycle(data: staged, completionSnapshots: current.completionSnapshots) : nil
        }
    }

    private func applyingLifecycle(to current: TaskLifecycle, selected: [TaskItem],
                                   now: Date, calendar: Calendar) throws -> TaskLifecycle? {
        let tasks = Dictionary(uniqueKeysWithValues: current.data.tasks.map { ($0.id, $0) })
        // Visit ancestors first even when intermediate parents are outside
        // the selection. A later selected descendant may already be changed
        // by the ordinary lifecycle cascade.
        let order = selected.enumerated().map { index, task in
            var ancestors = Set<UUID>([task.id])
            var next = task.parentID
            while let id = next, ancestors.insert(id).inserted { next = tasks[id]?.parentID }
            return (task.id, ancestors.count, index)
        }.sorted { ($0.1, $0.2) < ($1.1, $1.2) }
        var staged = current
        var changed = false
        for (id, _, _) in order {
            guard let task = staged.data.tasks.first(where: { $0.id == id }) else { throw TaskBatchRefusal.invalidSelection }
            let command: TaskLifecycleCommand
            if action.kind == .trash {
                if task.deletedAt != nil { continue }
                command = .trash
            } else {
                if task.completedAt != nil { continue }
                command = task.wontDoAt == nil ? .complete : .completeFromWontDo
            }
            guard try staged.apply(command, to: id, now: now, calendar: calendar) else {
                throw TaskBatchRefusal.readOnlyRecord
            }
            changed = true
        }
        return changed ? staged : nil
    }

    private func updated(_ task: TaskItem, in data: WorkspaceData, settings: AppSettings,
                         calendar: Calendar) throws -> TaskItem? {
        switch action {
        case .priority(let value):
            return try TaskMetadataChange.priority(value).applying(to: task, availableTags: data.tags)
        case .tags(let tags, let remove):
            let selected = Set(tags)
            let prior = Set(task.tagIDs)
            let ids = remove ? task.tagIDs.filter { !selected.contains($0) } : task.tagIDs + tags.filter { !prior.contains($0) }
            do { return try TaskMetadataChange.tags(ids).applying(to: task, availableTags: data.tags) }
            catch { throw TaskBatchRefusal.unavailableTag }
        case .schedule(let date):
            let operation: CalendarScheduleOperation
            if let date {
                let local = TaskCalendarProjection.taskCalendar(task, fallback: calendar)
                guard date.timeIntervalSinceReferenceDate.isFinite,
                      task.timeZoneID.map({ TimeZone(identifier: $0) != nil }) ?? true,
                      task.scheduledDuration.map({ $0.validated(in: local) != nil }) ?? true,
                      task.customRecurrence?.isValid != false else { throw TaskBatchRefusal.invalidSchedule }
                operation = CalendarScheduling.moveOnDay(task, day: date, forceAllDay: false, calendar: calendar)
            } else {
                operation = .unschedule
            }
            guard let updated = CalendarScheduling.prepared(operation, to: task, displayCalendar: calendar,
                    settings: settings, policyCalendar: calendar, in: data.tasks) else { throw TaskBatchRefusal.invalidSchedule }
            return CalendarScheduleSnapshot(updated) == CalendarScheduleSnapshot(task) ? nil : updated
        case .move, .complete, .trash:
            return nil
        }
    }
}
