import Foundation

public enum TagOrganizationCommand: Sendable {
    case save(TaskTag, creating: Bool)
    case delete(UUID)
    case merge(UUID, into: UUID)
    case reorder(UUID, relativeTo: UUID, after: Bool)
    case setCollapsed(UUID, Bool)

    public func apply(to data: inout WorkspaceData, defaultTagID: inout UUID?, now: Date) -> Bool? {
        switch self {
        case .save(var tag, let creating):
            let indices = data.tags.indices.filter { data.tags[$0].id == tag.id }
            guard creating ? indices.isEmpty : indices.count == 1 else { return nil }
            let original = indices.first.map { data.tags[$0] }
            if original.map({ !RichBody.sameCodeUnits($0.name, tag.name) }) ?? true {
                tag.name = TagOrganization.normalizedName(tag.name)
                guard !tag.name.isEmpty, !data.tags.contains(where: {
                    $0.id != tag.id && TagOrganization.normalizedName($0.name).localizedCaseInsensitiveCompare(tag.name) == .orderedSame
                }) else { return nil }
            }
            guard TagOrganization.allowsParent(tag.parentID, for: tag.id, in: data.tags) else { return nil }
            if creating {
                data.tags.append(tag)
            } else {
                guard let index = indices.first, let old = original else { return nil }
                guard old != tag || !RichBody.sameCodeUnits(old.name, tag.name) else { return false }
                data.tags[index] = tag
            }
        case .delete(let id):
            guard data.tags.filter({ $0.id == id }).count == 1, TagOrganization.delete(id, in: &data, now: now)
            else { return nil }
            if defaultTagID == id { defaultTagID = nil }
        case .merge(let source, let target):
            guard data.tags.filter({ $0.id == source || $0.id == target }).count == 2,
                  TagOrganization.merge(source: source, target: target, in: &data, now: now) else { return nil }
            if defaultTagID == source { defaultTagID = target }
        case .reorder(let id, let target, let after):
            guard let order = TagOrganization.reordered(data.tags, moving: id, relativeTo: target, after: after) else { return nil }
            guard order != data.tags else { return false }
            data.tags = order
        case .setCollapsed(let id, let collapsed):
            let indices = data.tags.indices.filter { data.tags[$0].id == id }
            guard indices.count == 1, let index = indices.first else { return nil }
            guard data.tags[index].isCollapsed != collapsed else { return false }
            data.tags[index].isCollapsed = collapsed
        }
        return true
    }
}

public enum TagOrganization {
    public static func allowsParent(_ parentID: UUID?, for tagID: UUID, in tags: [TaskTag]) -> Bool {
        guard let parentID else { return true }
        return parentID != tagID && tags.contains { $0.id == parentID } &&
            !TagHierarchy.isDescendant(parentID, of: tagID, in: tags)
    }

    public static func reordered(_ tags: [TaskTag], moving id: UUID, relativeTo target: UUID, after: Bool) -> [TaskTag]? {
        guard id != target, let from = tags.firstIndex(where: { $0.id == id }),
              tags.contains(where: { $0.id == target }) else { return nil }
        var updated = tags
        let mover = updated.remove(at: from)
        guard let targetIndex = updated.firstIndex(where: { $0.id == target }) else { return nil }
        updated.insert(mover, at: after ? targetIndex + 1 : targetIndex)
        return updated
    }

    public static func normalizedName(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("#") { result.removeFirst(); result = result.trimmingCharacters(in: .whitespacesAndNewlines) }
        return result
    }

    public static func delete(_ id: UUID, in data: inout WorkspaceData, now: Date) -> Bool {
        guard let deleted = data.tags.first(where: { $0.id == id }) else { return false }
        let parent = deleted.parentID
        let parentCycles = parent.map { TagHierarchy.isDescendant($0, of: id, in: data.tags) } ?? false
        data.tags.removeAll { $0.id == id }
        for i in data.tags.indices where data.tags[i].parentID == id {
            data.tags[i].parentID = parentCycles ? nil : parent
        }
        for i in data.tasks.indices where data.tasks[i].tagIDs.contains(id) {
            data.tasks[i].tagIDs.removeAll { $0 == id }; data.tasks[i].updatedAt = now
        }
        for i in data.templates.indices {
            data.templates[i].tagIDs.removeAll { $0 == id }
        }
        // Dead tag IDs persist in saved-filter criteria as no-match (no
        // task can carry them after the sweep above): pruning them would
        // broaden a filter whose only selection was deleted. The editor
        // surfaces them as unavailable for deliberate clearing.
        return true
    }

    public static func merge(source: UUID, target: UUID, in data: inout WorkspaceData, now: Date) -> Bool {
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
        data.tags.removeAll { $0.id == source }
        data.tags = WorkspaceData.sanitizedTagParents(data.tags)
        return true
    }
}
