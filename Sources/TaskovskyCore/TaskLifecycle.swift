import Foundation

public enum TaskLifecycleCommand: Equatable, Sendable {
    case complete, reopen, wontDo, trash, restore, purge
    case setPinned(Bool)
    case move(UUID?)
}

public enum TaskLifecycleRefusal: Error, Equatable, Sendable {
    case missing, archived, wrongStatus, invalidDestination
}

/// Shared graph mutations and transient snapshots used to prove pristine
/// recurrence successors. Only `data` is part of the saved workspace.
public struct TaskLifecycle {
    public private(set) var data: WorkspaceData
    public private(set) var completionSnapshots: [UUID: [TaskItem]]

    public init(data: WorkspaceData, completionSnapshots: [UUID: [TaskItem]] = [:]) {
        self.data = data
        self.completionSnapshots = completionSnapshots
    }

    private func isInArchivedList(_ task: TaskItem) -> Bool {
        SmartListEligibility.isArchived(task, lists: data.lists)
    }

    /// Shared eligibility for the phone action surface and transaction.
    public static func refusal(for command: TaskLifecycleCommand, task: TaskItem,
                               lists: [TaskList]) -> TaskLifecycleRefusal? {
        if task.deletedAt != nil {
            switch command {
            case .restore, .purge: return nil
            default: return .wrongStatus
            }
        }
        if case .move(let target) = command {
            if let target, !lists.contains(where: { $0.id == target && !$0.isArchived }) {
                return .invalidDestination
            }
            return nil
        }
        if SmartListEligibility.isArchived(task, lists: lists) { return .archived }
        let active = task.completedAt == nil && task.wontDoAt == nil
        switch command {
        case .complete: return task.kind == .task && active ? nil : .wrongStatus
        case .reopen: return task.kind == .task && !active ? nil : .wrongStatus
        case .wontDo: return task.kind == .task && task.wontDoAt == nil ? nil : .wrongStatus
        case .setPinned: return active ? nil : .wrongStatus
        case .trash, .move: return nil
        case .restore, .purge: return .wrongStatus
        }
    }

    public mutating func apply(_ command: TaskLifecycleCommand, to id: UUID,
                               now: Date, calendar: Calendar) throws -> Bool {
        guard let task = data.tasks.first(where: { $0.id == id }) else { throw TaskLifecycleRefusal.missing }
        if let refusal = Self.refusal(for: command, task: task, lists: data.lists) { throw refusal }
        switch command {
        case .complete: return toggleComplete(id: id, now: now, calendar: calendar)
        case .reopen: return reopenTask(id: id, now: now)
        case .wontDo: return markWontDo(id: id, now: now)
        case .trash: return trashTask(id: id, now: now)
        case .restore: return restoreTask(id: id, now: now)
        case .purge: return purgeTask(id: id, now: now)
        case .setPinned(let pinned): return setPinned(id: id, pinned: pinned, now: now) ?? false
        case .move(let listID): return moveTasksToList(ids: [id], listID: listID, now: now) ?? false
        }
    }

    public mutating func toggleComplete(id: UUID, now: Date, calendar: Calendar) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }),
              data.tasks[index].deletedAt == nil,
              !isInArchivedList(data.tasks[index]) else { return false }
        if data.tasks[index].completedAt != nil {
            return undoCompletion(id: id, now: now)
        }
        completeSubtree(rootID: id, now: now, calendar: calendar)
        return true
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
    private mutating func completeSubtree(rootID: UUID, now: Date, calendar: Calendar) {
        guard let rootIndex = data.tasks.firstIndex(where: { $0.id == rootID }) else { return }
        let original = data.tasks[rootIndex]
        data.tasks[rootIndex].wontDoAt = nil
        data.tasks[rootIndex].completedAt = now
        data.tasks[rootIndex].updatedAt = now
        var calendar = calendar
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
    private mutating func cascadeCompleteDescendants(of rootID: UUID, now: Date, spawning: Bool, calendar: Calendar) {
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
    private mutating func cloneSubtreeIntoSuccessor(originalRootID: UUID, newParentID: UUID, parentDue: Date, successorDue: Date, now: Date, calendar: Calendar) -> [TaskItem] {
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
            let schedule = TaskSchedulePolicy.coherentSchedule(dueDate: next, hasDueTime: original.hasDueTime, window: anchored, calendar: calendar)
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

    public mutating func undoCompletion(id: UUID, now: Date) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].completedAt != nil else { return false }
        guard !isInArchivedList(data.tasks[index]) else { return false }
        data.tasks[index].completedAt = nil; data.tasks[index].updatedAt = now
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
                    data.tasks[i].completedAt = nil; data.tasks[i].updatedAt = now
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
        return true
    }

    /// Removes pristine spawned records, retaining any that anchor surviving
    /// content: a pristine spawn with an edited descendant — or a user-added
    /// descendant — stays as their required ancestor instead of leaving a
    /// dangling parent link. Retention propagates upward (an ancestor of a
    /// retained record is itself retained). Never deletes user data; records
    /// that cannot be proven pristine (e.g. after a reload, which drops the
    /// in-memory snapshots) are retained.
    private mutating func removePristineSpawns(_ snapshots: [TaskItem]) {
        guard !snapshots.isEmpty else { return }
        var removable: Set<UUID> = []
        for snapshot in snapshots {
            if data.tasks.contains(where: { $0.id == snapshot.id && $0 == snapshot &&
                $0.title.utf16.elementsEqual(snapshot.title.utf16) && $0.body.utf16.elementsEqual(snapshot.body.utf16) }) {
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
    public mutating func markWontDo(id: UUID, now: Date) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }),
              data.tasks[index].deletedAt == nil, !isInArchivedList(data.tasks[index]) else { return false }
        data.tasks[index].wontDoAt = now
        data.tasks[index].completedAt = nil
        data.tasks[index].updatedAt = now
        return true
    }

    public mutating func reopenTask(id: UUID, now: Date) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }),
              data.tasks[index].deletedAt == nil, !isInArchivedList(data.tasks[index]) else { return false }
        if data.tasks[index].completedAt != nil { _ = undoCompletion(id: id, now: now) }
        // Undo can remove successors from earlier positions in stored order.
        guard let reopenedIndex = data.tasks.firstIndex(where: { $0.id == id }) else { return false }
        data.tasks[reopenedIndex].wontDoAt = nil
        data.tasks[reopenedIndex].completedAt = nil
        data.tasks[reopenedIndex].updatedAt = now
        return true
    }

    /// Pins or unpins a task. Completed, Won't Do, and trashed records refuse
    /// (returning false with no mutation) so they can never become pinned
    /// active rows; the stored flag survives status changes so reopening or
    /// restoring brings the pin back.
    @discardableResult public mutating func setPinned(id: UUID, pinned: Bool, now: Date) -> Bool? {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }),
              data.tasks[index].deletedAt == nil,
              data.tasks[index].completedAt == nil,
              data.tasks[index].wontDoAt == nil,
              !isInArchivedList(data.tasks[index]) else { return nil }
        guard data.tasks[index].isPinned != pinned else { return false }
        data.tasks[index].isPinned = pinned
        data.tasks[index].updatedAt = now
        return true
    }
    /// Trashes a task and its whole non-trashed subtree in one instant,
    /// recording each cascaded child with its exact stamp in the persisted
    /// ledger. Restore revives only children whose stamp is untouched, so
    /// separately trashed children (different stamps) stay in Trash.
    public mutating func trashTask(id: UUID, now: Date) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt == nil else { return false }
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
        return true
    }
    /// Restores a trashed task and the descendants trashed with it (same
    /// stamp). Separately trashed children keep their own stamps and stay.
    public mutating func restoreTask(id: UUID, now: Date) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt != nil else { return false }
        data.tasks[index].deletedAt = nil; data.tasks[index].updatedAt = now
        if let cascadeIndex = data.trashCascades.firstIndex(where: { $0.parentID == id }) {
            let cascade = data.trashCascades[cascadeIndex]
            for child in cascade.children {
                if let i = data.tasks.firstIndex(where: { $0.id == child.id }),
                   data.tasks[i].deletedAt == child.deletedAt {
                    data.tasks[i].deletedAt = nil; data.tasks[i].updatedAt = now
                }
            }
            data.trashCascades.remove(at: cascadeIndex)
        }
        return true
    }
    /// Permanently removes one trashed record. Refuses missing IDs and active
    /// items. Surviving children (trashed or restored) detach to top level
    /// instead of dangling, and cascade ledgers naming the record are
    /// dropped. Never touches lists, tags, or templates.
    @discardableResult public mutating func purgeTask(id: UUID, now: Date) -> Bool {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }), data.tasks[index].deletedAt != nil else { return false }
        data.tasks.remove(at: index)
        for i in data.tasks.indices where data.tasks[i].parentID == id {
            data.tasks[i].parentID = nil; data.tasks[i].updatedAt = now
        }
        pruneCascades(naming: id)
        completionSnapshots.removeValue(forKey: id)
        for key in completionSnapshots.keys {
            completionSnapshots[key]?.removeAll { $0.id == id }
        }
        return true
    }

    /// Drops cascade ledger entries that name a removed record: entries
    /// parented at it go away, and child references to it shed.
    private mutating func pruneCascades(naming id: UUID) {
        data.completionCascades.removeAll { $0.parentID == id }
        for i in data.completionCascades.indices {
            data.completionCascades[i].children.removeAll { $0.id == id }
        }
        data.trashCascades.removeAll { $0.parentID == id }
        for i in data.trashCascades.indices {
            data.trashCascades[i].children.removeAll { $0.id == id }
        }
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
    @discardableResult public mutating func moveTasksToList(ids: [UUID], listID: UUID?, now: Date) -> Bool? {
        guard !ids.isEmpty else { return nil }
        if let listID, !data.lists.contains(where: { $0.id == listID }) { return nil }
        // Archived lists are read-only destinations: unarchive first.
        // Moving OUT of an archived list stays allowed.
        if let listID, data.lists.first(where: { $0.id == listID })?.isArchived == true { return nil }
        var seen = Set<UUID>()
        for id in ids {
            guard seen.insert(id).inserted,
                  let index = data.tasks.firstIndex(where: { $0.id == id }),
                  data.tasks[index].deletedAt == nil else { return nil }
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
        guard !pending.isEmpty else { return false }
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
        return true
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
    private static func nextCustomStep(for task: TaskItem, now: Date, calendar: Calendar) -> (adjusted: Date, nominal: Date?, index: Int)? {
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
    public static func nextRecurrenceDate(for task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> (Date, Int?)? {
        guard let due = task.dueDate else { return nil }
        if task.isCustomRepeating {
            guard let step = nextCustomStep(for: task, now: now, calendar: calendar) else { return nil }
            return (step.adjusted, step.index)
        }
        guard task.recurrence != .none,
              let next = LegacyRecurrence.nextDate(after: due, rule: task.recurrence,
                                  anchorDay: task.recurrenceAnchorDay,
                                  anchorMonth: task.recurrenceAnchorMonth, calendar: calendar),
              task.recurrenceEndDate.map({ calendar.startOfDay(for: next) <= calendar.startOfDay(for: $0) }) ?? true else { return nil }
        return (next, nil)
    }

}
