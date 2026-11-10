import Foundation

public enum TaskMetadataValidation: Error, Equatable, Sendable {
    case unavailableTag, ambiguousChecklist, missingChecklistItem, emptyChecklistTitle
}

/// Each command changes only the metadata it names. Embedded checklist
/// identities are independent of task hierarchy and rich-body list markers.
public enum TaskMetadataChange: Sendable {
    case priority(TaskPriority)
    case tags([UUID])
    case checklist([ChecklistItem])
    case setChecklistCompleted(id: UUID, completed: Bool)

    public func applying(to original: TaskItem, availableTags: [TaskTag]) throws -> TaskItem? {
        var task = original
        switch self {
        case .priority(let value):
            guard value != original.priority else { return nil }
            task.priority = value
        case .tags(let ids):
            guard ids != original.tagIDs else { return nil }
            let allowed = Set(availableTags.map(\.id)).union(original.tagIDs)
            guard Set(ids).count == ids.count, ids.allSatisfy(allowed.contains) else {
                throw TaskMetadataValidation.unavailableTag
            }
            task.tagIDs = ids
        case .checklist(let items):
            guard !Self.sameChecklist(items, original.checklist) else { return nil }
            guard Set(original.checklist.map(\.id)).count == original.checklist.count,
                  Set(items.map(\.id)).count == items.count else { throw TaskMetadataValidation.ambiguousChecklist }
            let previous = Dictionary(uniqueKeysWithValues: original.checklist.map { ($0.id, $0.title) })
            for item in items {
                // A prior blank title can still be checked, moved or removed.
                if let old = previous[item.id], RichBody.sameCodeUnits(old, item.title) { continue }
                guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw TaskMetadataValidation.emptyChecklistTitle
                }
            }
            task.checklist = items
        case .setChecklistCompleted(let id, let completed):
            let matches = task.checklist.indices.filter { task.checklist[$0].id == id }
            guard matches.count <= 1 else { throw TaskMetadataValidation.ambiguousChecklist }
            guard let index = matches.first else { throw TaskMetadataValidation.missingChecklistItem }
            guard task.checklist[index].isCompleted != completed else { return nil }
            task.checklist[index].isCompleted = completed
        }
        return task
    }

    public static func sameChecklist(_ lhs: [ChecklistItem], _ rhs: [ChecklistItem]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy {
            $0.id == $1.id && $0.isCompleted == $1.isCompleted && RichBody.sameCodeUnits($0.title, $1.title)
        }
    }
}
