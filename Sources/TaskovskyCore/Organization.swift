import Foundation

/// Shared smart-list eligibility: archive vs smart-list exclusion.
///
/// - Archived lists: tasks hide from smart destinations AND stop firing
///   reminders; the archived list itself renders its content read-only.
/// - Excluded (`showsInSmartLists == false`) but unarchived lists: tasks hide
///   from smart destinations but KEEP reminders (reference explanatory text).
/// - Unknown lists (task references a missing list): visible. Archive only
///   hides what it can prove, so a corrupt reference never drops tasks.
public enum SmartListEligibility {
    public static func list(for task: TaskItem, in lists: [TaskList]) -> TaskList? {
        guard let id = task.listID else { return nil }
        return lists.first { $0.id == id }
    }

    /// True when the task sits in an archived list.
    public static func isArchived(_ task: TaskItem, lists: [TaskList]) -> Bool {
        list(for: task, in: lists)?.isArchived ?? false
    }

    /// True when the task must hide from smart destinations (archived, or its
    /// list opted out of smart lists).
    public static func isExcludedFromSmart(_ task: TaskItem, lists: [TaskList]) -> Bool {
        guard let list = list(for: task, in: lists) else { return false }
        return list.isArchived || !list.showsInSmartLists
    }

    /// Archived tasks suppress reminders; excluded-but-unarchived tasks keep
    /// theirs.
    public static func allowsReminders(_ task: TaskItem, lists: [TaskList]) -> Bool {
        !isArchived(task, lists: lists)
    }

    /// Parent-tag navigation policy: a parent row shows tasks tagged with it
    /// or any descendant. Direct membership wins; descendants come from the
    /// hierarchy, which is cycle-safe by construction.
    public static func taskMatchesTag(_ task: TaskItem, tagID: UUID, tags: [TaskTag]) -> Bool {
        if task.tagIDs.contains(tagID) { return true }
        let descendantIDs = Set(TagHierarchy.descendants(of: tagID, in: tags).map(\.id))
        return !descendantIDs.isDisjoint(with: task.tagIDs)
    }
}

/// Pure task-hierarchy traversal. All walks are cycle-safe (visited sets),
/// so even unvalidated input terminates; the workspace decoder additionally
/// clears unknown parents and breaks stored cycles on load, and the store
/// refuses cycle-creating parents.
public enum TaskHierarchy {
    /// Parent-link validation shared by `setTaskParent` and direct record
    /// edits (`updateTask`): unknown IDs, self-parenting, and descendants
    /// (cycles) refuse, as do note, trashed, and archived parents — and
    /// archived or trashed children. A cross-list link normalizes by
    /// relocating the child's subtree into the parent's list instead of
    /// leaving a relationship that spans lists.
    public enum ParentLinkResolution: Equatable {
        case keep
        case relocateSubtree(toList: UUID?)
        case refuse
    }

    public static func resolveParentLink(childID: UUID, parentID: UUID?, tasks: [TaskItem], lists: [TaskList]) -> ParentLinkResolution {
        guard let parentID else { return .keep }
        guard let child = tasks.first(where: { $0.id == childID }),
              child.deletedAt == nil,
              !(child.listID.flatMap { id in lists.first { $0.id == id } }?.isArchived ?? false) else { return .refuse }
        guard parentID != childID,
              let parent = tasks.first(where: { $0.id == parentID }),
              parent.deletedAt == nil,
              parent.kind == .task,
              !(parent.listID.flatMap { id in lists.first { $0.id == id } }?.isArchived ?? false),
              !isDescendant(parentID, of: childID, in: tasks) else { return .refuse }
        if parent.listID != child.listID { return .relocateSubtree(toList: parent.listID) }
        return .keep
    }

    /// Returns nil for an invalid link and false when the link is unchanged.
    public static func setParent(childID: UUID, parentID: UUID?, in data: inout WorkspaceData,
                                 now: Date) -> Bool? {
        guard let index = data.tasks.firstIndex(where: { $0.id == childID }) else { return nil }
        switch resolveParentLink(childID: childID, parentID: parentID, tasks: data.tasks, lists: data.lists) {
        case .refuse: return nil
        case .keep:
            guard data.tasks[index].parentID != parentID else { return false }
        case .relocateSubtree(let listID):
            data.tasks[index].listID = listID
            for descendant in descendants(of: childID, in: data.tasks) {
                if let i = data.tasks.firstIndex(where: { $0.id == descendant.id }) {
                    data.tasks[i].listID = listID
                    data.tasks[i].updatedAt = now
                }
            }
        }
        data.tasks[index].parentID = parentID
        data.tasks = WorkspaceData.sanitizedTaskParents(data.tasks)
        return true
    }

    /// A child inherits its parent's list and starts with an independent schedule and status.
    public static func addChild(id: UUID, to parentID: UUID, title: String, in data: inout WorkspaceData,
                                position: TaskPosition, now: Date) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !data.tasks.contains(where: { $0.id == id }),
              let parent = data.tasks.first(where: { $0.id == parentID }),
              parent.kind == .task, parent.deletedAt == nil,
              !SmartListEligibility.isArchived(parent, lists: data.lists) else { return false }
        let child = TaskItem(id: id, title: trimmed, listID: parent.listID, createdAt: now,
                             updatedAt: now, parentID: parentID)
        if position == .top { data.tasks.insert(child, at: 0) } else { data.tasks.append(child) }
        return true
    }

    public static func children(of id: UUID, in tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.parentID == id }
    }

    /// Top-level tasks: no parent, or a parent unknown to this slice (trashed,
    /// filtered out, or corrupt). Unknown parents render as roots so subtasks
    /// never vanish with their parent.
    public static func roots(in tasks: [TaskItem]) -> [TaskItem] {
        let known = Set(tasks.map(\.id))
        return tasks.filter { task in
            guard let parent = task.parentID else { return true }
            return !known.contains(parent)
        }
    }

    /// All descendants in stable array order (breadth-first).
    public static func descendants(of id: UUID, in tasks: [TaskItem]) -> [TaskItem] {
        var result: [TaskItem] = []
        var seen = Set<UUID>([id])
        var queue = children(of: id, in: tasks)
        while !queue.isEmpty {
            let next = queue.removeFirst()
            guard seen.insert(next.id).inserted else { continue }
            result.append(next)
            queue.append(contentsOf: children(of: next.id, in: tasks))
        }
        return result
    }

    /// True when `candidate` is a strict descendant of `ancestor`.
    public static func isDescendant(_ candidate: UUID, of ancestor: UUID, in tasks: [TaskItem]) -> Bool {
        descendants(of: ancestor, in: tasks).contains { $0.id == candidate }
    }

    /// Display order for a pre-sorted group: roots keep their incoming order
    /// with each subtree nested directly below its parent (depth-first,
    /// children in incoming order). A task whose parent is outside the group
    /// renders at top level. Cycle-safe: leftovers render as roots so nothing
    /// vanishes even if a stored cycle slipped through.
    public static func displayOrder(_ items: [TaskItem]) -> [(task: TaskItem, depth: Int)] {
        var byID: [UUID: TaskItem] = [:]
        for item in items { byID[item.id] = item }
        var result: [(task: TaskItem, depth: Int)] = []
        var emitted = Set<UUID>()
        func emit(_ item: TaskItem, depth: Int) {
            guard emitted.insert(item.id).inserted else { return }
            result.append((item, depth))
            for child in items where child.parentID == item.id {
                emit(child, depth: depth + 1)
            }
        }
        for item in items where item.parentID == nil || byID[item.parentID!] == nil {
            emit(item, depth: 0)
        }
        // Leftovers: cycle members and anything missed render as roots.
        for item in items where !emitted.contains(item.id) {
            emit(item, depth: 0)
        }
        return result
    }

    /// Subtask progress: total children plus finished ones (completed or
    /// Won't Do). Nil when the task has no subtasks.
    public static func progress(of id: UUID, in tasks: [TaskItem]) -> (done: Int, total: Int)? {
        let kids = children(of: id, in: tasks)
        guard !kids.isEmpty else { return nil }
        let done = kids.filter { $0.completedAt != nil || $0.wontDoAt != nil }.count
        return (done, kids.count)
    }

    /// Candidate parents for "Make Subtask Of": active tasks in the same list
    /// (subtasks inherit their parent's list), excluding the task itself and
    /// its descendants so no choice can create a cycle. Capped so menus stay
    /// usable; deeper nesting is managed from the detail view.
    public static func parentCandidates(for task: TaskItem, in tasks: [TaskItem], limit: Int = 25) -> [TaskItem] {
        let forbidden = Set(descendants(of: task.id, in: tasks).map(\.id) + [task.id])
        return tasks.filter { candidate in
            candidate.id != task.id && !forbidden.contains(candidate.id)
                && candidate.listID == task.listID
                && candidate.deletedAt == nil && candidate.completedAt == nil && candidate.wontDoAt == nil
        }.prefix(limit).map { $0 }
    }
}

/// Pure tag-hierarchy traversal. All walks are cycle-safe (visited sets), so
/// even unvalidated input terminates; the workspace decoder additionally
/// breaks stored cycles on load.
public enum TagHierarchy {
    public static func children(of id: UUID, in tags: [TaskTag]) -> [TaskTag] {
        tags.filter { $0.parentID == id }
    }

    public static func roots(in tags: [TaskTag]) -> [TaskTag] {
        // Unknown parents were cleared on load, but stay defensive: a tag
        // whose parent is missing renders as a root rather than vanishing.
        let known = Set(tags.map(\.id))
        return tags.filter { tag in
            guard let parent = tag.parentID else { return true }
            return !known.contains(parent)
        }
    }

    /// All descendants in stable array order (breadth-first).
    public static func descendants(of id: UUID, in tags: [TaskTag]) -> [TaskTag] {
        var result: [TaskTag] = []
        var seen = Set<UUID>([id])
        var queue = children(of: id, in: tags)
        while !queue.isEmpty {
            let next = queue.removeFirst()
            guard seen.insert(next.id).inserted else { continue }
            result.append(next)
            queue.append(contentsOf: children(of: next.id, in: tags))
        }
        return result
    }

    /// The tag plus all descendants, in stable order.
    public static func subtree(of id: UUID, in tags: [TaskTag]) -> [TaskTag] {
        guard tags.contains(where: { $0.id == id }) else { return [] }
        return [tags.first { $0.id == id }! ] + descendants(of: id, in: tags)
    }

    /// True when `candidate` is a strict descendant of `ancestor`.
    public static func isDescendant(_ candidate: UUID, of ancestor: UUID, in tags: [TaskTag]) -> Bool {
        descendants(of: ancestor, in: tags).contains { $0.id == candidate }
    }

    /// Chain from the tag up to its root (nearest parent first). Empty for
    /// roots and unknown tags. Last-wins on duplicate IDs (never traps).
    public static func ancestors(of id: UUID, in tags: [TaskTag]) -> [TaskTag] {
        var byID: [UUID: TaskTag] = [:]
        for tag in tags { byID[tag.id] = tag }
        var result: [TaskTag] = []
        var seen = Set<UUID>([id])
        var cursor = byID[id]?.parentID
        while let current = cursor, let node = byID[current], seen.insert(current).inserted {
            result.append(node)
            cursor = node.parentID
        }
        return result
    }
}
