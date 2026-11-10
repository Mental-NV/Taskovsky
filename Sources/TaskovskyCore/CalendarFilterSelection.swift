import Foundation

public enum CalendarFilterMark: Equatable, Sendable { case off, mixed, on }
public enum CalendarArrangeSelection: Equatable, Sendable { case calendar, inbox, list(UUID) }

extension TaskCalendarOptions {
    public var isAllSources: Bool { listIDs == nil && includeInbox && tagIDs.isEmpty }

    // All is a separate mode: its children are unmarked. Old tag-only settings
    // used nil lists plus Inbox; those must not turn into an unrestricted union.
    public func selectedListIDs(in data: WorkspaceData) -> [UUID] {
        if isAllSources { return [] }
        return listIDs ?? (tagIDs.isEmpty ? data.lists.filter { !$0.isArchived }.map(\.id) : [])
    }
    public var isInboxSelected: Bool { !isAllSources && !(listIDs == nil && !tagIDs.isEmpty) && includeInbox }

    public func listSelectionState(in data: WorkspaceData) -> CalendarFilterMark {
        if isAllSources { return .off }
        let ids = Set(selectedListIDs(in: data))
        let active = Set(data.lists.filter { !$0.isArchived }.map(\.id))
        if isInboxSelected && active.isSubset(of: ids) { return .on }
        return ids.isEmpty && !isInboxSelected ? .off : .mixed
    }
    public func tagSelectionState(in data: WorkspaceData) -> CalendarFilterMark {
        if isAllSources || tagIDs.isEmpty { return .off }
        let active = Set(data.tags.map(\.id))
        return !active.isEmpty && active.isSubset(of: Set(tagIDs)) ? .on : .mixed
    }

    public mutating func selectAllSources() { listIDs = nil; includeInbox = true; tagIDs = [] }
    public mutating func selectOnlyList(_ id: UUID) { listIDs = [id]; includeInbox = false; tagIDs = [] }

    public mutating func setListSelected(_ id: UUID, _ selected: Bool, data: WorkspaceData) {
        beginSourceSelection(data: data)
        var ids = listIDs ?? []
        if selected { if !ids.contains(id) { ids.append(id) } }
        else { ids.removeAll { $0 == id } }
        listIDs = ids
        finishSourceSelection()
    }
    public mutating func setInboxSelected(_ selected: Bool, data: WorkspaceData) {
        beginSourceSelection(data: data); includeInbox = selected; finishSourceSelection()
    }
    public mutating func setTagSelected(_ id: UUID, _ selected: Bool, data: WorkspaceData) {
        beginSourceSelection(data: data)
        if selected { if !tagIDs.contains(id) { tagIDs.append(id) } }
        else { tagIDs.removeAll { $0 == id } }
        finishSourceSelection()
    }
    public mutating func setListsSelected(_ selected: Bool, data: WorkspaceData) {
        beginSourceSelection(data: data)
        listIDs = selected ? data.lists.filter { !$0.isArchived }.map(\.id) : []
        includeInbox = selected
        finishSourceSelection()
    }
    public mutating func setTagsSelected(_ selected: Bool, data: WorkspaceData) {
        beginSourceSelection(data: data); tagIDs = selected ? data.tags.map(\.id) : []; finishSourceSelection()
    }
    public mutating func clearUnavailableSources(data: WorkspaceData) {
        beginSourceSelection(data: data)
        let lists = Set(data.lists.filter { !$0.isArchived }.map(\.id)), tags = Set(data.tags.map(\.id))
        listIDs = listIDs?.filter { lists.contains($0) }; tagIDs.removeAll { !tags.contains($0) }
        finishSourceSelection()
    }

    public func matchesCalendarSources(_ task: TaskItem, data: WorkspaceData) -> Bool {
        if isAllSources { return true }
        if let id = task.listID, selectedListIDs(in: data).contains(id) { return true }
        if task.listID == nil && isInboxSelected { return true }
        return matchesSelectedTags(task, data: data)
    }
    public func matchesSelectedTags(_ task: TaskItem, data: WorkspaceData) -> Bool {
        tagIDs.contains { SmartListEligibility.taskMatchesTag(task, tagID: $0, tags: data.tags) }
    }

    private mutating func beginSourceSelection(data: WorkspaceData) {
        let ids = selectedListIDs(in: data), inbox = isInboxSelected
        listIDs = ids; includeInbox = inbox
    }
    private mutating func finishSourceSelection() {
        // Only a user command clears an empty selection. A saved empty/stale
        // selection is never silently broadened while decoding or rendering.
        if listIDs?.isEmpty == true && !includeInbox && tagIDs.isEmpty { selectAllSources() }
    }
}
