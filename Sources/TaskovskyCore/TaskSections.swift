import Foundation

public struct TaskSection: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct TaskSectionChange: Sendable {
    public enum Operation: Sendable {
        case create(TaskSection)
        case rename(UUID, name: String)
        case remove(UUID)
        case reorder(UUID, relativeTo: UUID, after: Bool)
        case assign(taskID: UUID, sectionID: UUID?)
        case assignTasks([UUID], sectionID: UUID?)
    }

    public let listID: UUID
    public let operation: Operation

    public init(listID: UUID, operation: Operation) {
        self.listID = listID
        self.operation = operation
    }

    /// Nil refuses an invalid or stale change. False leaves the workspace untouched.
    public func apply(to data: inout WorkspaceData, now: Date) -> Bool? {
        guard let listIndex = data.lists.firstIndex(where: { $0.id == listID }),
              !data.lists[listIndex].isArchived else { return nil }
        var sections = data.lists[listIndex].sections

        switch operation {
        case .create(var section):
            section.name = section.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !section.name.isEmpty, !sections.contains(where: { $0.id == section.id }) else { return nil }
            sections.append(section)
        case .rename(let id, let proposedName):
            let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, let index = sections.firstIndex(where: { $0.id == id }) else { return nil }
            guard !RichBody.sameCodeUnits(sections[index].name, name) else { return false }
            sections[index].name = name
        case .remove(let id):
            guard let index = sections.firstIndex(where: { $0.id == id }) else { return nil }
            sections.remove(at: index)
            for index in data.tasks.indices where data.tasks[index].listID == listID && data.tasks[index].sectionID == id {
                data.tasks[index].sectionID = nil
                data.tasks[index].updatedAt = now
            }
        case .reorder(let id, let target, let after):
            guard id != target, let source = sections.firstIndex(where: { $0.id == id }) else { return nil }
            let section = sections.remove(at: source)
            guard let destination = sections.firstIndex(where: { $0.id == target }) else { return nil }
            sections.insert(section, at: destination + (after ? 1 : 0))
            guard sections.map(\.id) != data.lists[listIndex].sections.map(\.id) else { return false }
        case .assign(let taskID, let sectionID):
            return assign([taskID], to: sectionID, sections: sections, data: &data, now: now)
        case .assignTasks(let taskIDs, let sectionID):
            return assign(taskIDs, to: sectionID, sections: sections, data: &data, now: now)
        }
        data.lists[listIndex].sections = sections
        return true
    }

    private func assign(_ taskIDs: [UUID], to sectionID: UUID?, sections: [TaskSection],
                        data: inout WorkspaceData, now: Date) -> Bool? {
        let ids = Set(taskIDs)
        guard !ids.isEmpty, sectionID.map({ id in sections.contains { $0.id == id } }) ?? true else { return nil }
        let indices = data.tasks.indices.filter { ids.contains(data.tasks[$0].id) }
        guard indices.count == ids.count, Set(indices.map { data.tasks[$0].id }) == ids,
              indices.allSatisfy({
                  let task = data.tasks[$0]
                  return task.listID == listID && task.parentID == nil && task.deletedAt == nil
              }) else { return nil }
        let changes = indices.filter { data.tasks[$0].sectionID != sectionID }
        for index in changes {
            data.tasks[index].sectionID = sectionID
            data.tasks[index].updatedAt = now
        }
        return !changes.isEmpty
    }
}

/// The caller supplies its visible rows in display order. A hidden parent can
/// still supply the section for a visible descendant.
public struct TaskSectionGroup: Identifiable, Sendable {
    public let section: TaskSection?
    public let tasks: [TaskItem]
    public var id: UUID? { section?.id }
    public var title: String { section?.name ?? "No Section" }

    public static func project(_ rows: [TaskItem], for list: TaskList, in data: WorkspaceData) -> [Self] {
        let parents = Dictionary(data.tasks.lazy.filter { $0.listID == list.id && $0.deletedAt == nil }.map { ($0.id, $0) },
                                 uniquingKeysWith: { first, _ in first })
        let known = Set(list.sections.map(\.id))
        var tasksBySection: [UUID: [TaskItem]] = [:]
        var unassigned: [TaskItem] = []
        for task in rows where task.listID == list.id {
            var root = task
            var visited: Set<UUID> = [task.id]
            while let parent = root.parentID.flatMap({ parents[$0] }), visited.insert(parent.id).inserted {
                root = parent
            }
            if let section = root.sectionID, known.contains(section) {
                tasksBySection[section, default: []].append(task)
            } else {
                unassigned.append(task)
            }
        }
        return [Self(section: nil, tasks: unassigned)] + list.sections.map {
            Self(section: $0, tasks: tasksBySection[$0.id] ?? [])
        }
    }
}
