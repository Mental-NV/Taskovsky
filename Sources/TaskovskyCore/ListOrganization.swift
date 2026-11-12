import Foundation

public enum ListIcon {
    public static func emoji(_ value: String) -> String? {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = candidate.unicodeScalars
        guard candidate.count == 1, let first = scalars.first, first.properties.isEmoji else { return nil }
        if first.isASCII {
            return scalars.last?.value == 0x20E3 ? candidate : nil
        }
        return scalars.contains { $0.properties.isEmojiPresentation || $0.value == 0xFE0F } ? candidate : nil
    }

    public static func resolvingName(_ name: String, symbol: String?, previousName: String?) -> (name: String, symbol: String?) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard symbol == nil, previousName.map({ !$0.utf16.elementsEqual(cleaned.utf16) }) ?? true,
              let first = cleaned.first, let icon = emoji(String(first)) else { return (cleaned, symbol) }
        let title = cleaned.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? (cleaned, nil) : (title, icon)
    }
}

public enum ListPlacement: Hashable, Sendable {
    case aboveFolders, folder(UUID), belowFolders

    public init(_ list: TaskList) {
        if let folderID = list.folderID { self = .folder(folderID) }
        else { self = list.belowFolders ? .belowFolders : .aboveFolders }
    }

    public func apply(to list: inout TaskList) {
        if case .folder(let id) = self { list.folderID = id } else { list.folderID = nil }
        list.belowFolders = self == .belowFolders
    }
}

public enum ListOrganizationCommand: Sendable {
    case saveList(TaskList, creating: Bool)
    case setListViewMode(UUID, TaskListViewMode)
    case setListColor(UUID, expected: String, color: String)
    case deleteList(UUID)
    case duplicateList(UUID, copyID: UUID)
    case saveFolder(ListFolder, creating: Bool)
    case ungroupFolder(UUID)
    case reorderList(UUID, relativeTo: UUID, after: Bool)
    case reorderFolder(UUID, relativeTo: UUID, after: Bool)

    /// Returns nil on invalid input, false for an unchanged draft, and true after a mutation.
    public func apply(to data: inout WorkspaceData, now: Date) -> Bool? {
        switch self {
        case .saveList(var list, let creating):
            list.name = list.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !list.name.isEmpty, list.folderID.map({ id in data.folders.contains { $0.id == id } }) ?? true
            else { return nil }
            let index = data.lists.firstIndex { $0.id == list.id }
            if creating {
                guard index == nil else { return nil }
                list.viewMode = .list
                list.sections = []
                data.lists.append(list)
            } else {
                guard let index else { return nil }
                let original = data.lists[index]
                list.viewMode = original.viewMode
                list.sections = original.sections
                guard list != original || !RichBody.sameCodeUnits(list.name, original.name) else { return false }
                let placement = ListPlacement(list)
                if placement == ListPlacement(original) { data.lists[index] = list }
                else {
                    data.lists.remove(at: index)
                    let last = data.lists.lastIndex { ListPlacement($0) == placement }
                    data.lists.insert(list, at: last.map { $0 + 1 } ?? data.lists.endIndex)
                }
            }
            return true
        case .setListViewMode(let id, let mode):
            let matches = data.lists.indices.filter { data.lists[$0].id == id }
            guard matches.count == 1, let index = matches.first, !data.lists[index].isArchived else { return nil }
            guard data.lists[index].viewMode != mode else { return false }
            data.lists[index].viewMode = mode
            return true
        case .setListColor(let id, let expected, let color):
            let matches = data.lists.indices.filter { data.lists[$0].id == id }
            guard matches.count == 1, let index = matches.first, !data.lists[index].isArchived,
                  data.lists[index].color == expected,
                  let color = CalendarColorSource.Overrides.normalizedHex(color) else { return nil }
            guard CalendarColorSource.Overrides.normalizedHex(expected) != color else { return false }
            data.lists[index].color = color
            return true
        case .deleteList(let id):
            guard data.lists.contains(where: { $0.id == id }) else { return nil }
            ListOrganization.deleteList(id, in: &data, now: now)
            return true
        case .duplicateList(let id, let copyID):
            return ListOrganization.duplicateList(id, copyID: copyID, in: &data, now: now) ? true : nil
        case .saveFolder(var folder, let creating):
            folder.name = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !folder.name.isEmpty else { return nil }
            let index = data.folders.firstIndex { $0.id == folder.id }
            if creating {
                guard index == nil else { return nil }
                data.folders.append(folder)
            } else {
                guard let index else { return nil }
                let original = data.folders[index]
                guard folder != original || !RichBody.sameCodeUnits(folder.name, original.name) else { return false }
                data.folders[index] = folder
            }
            return true
        case .ungroupFolder(let id):
            return ListOrganization.ungroupFolder(id, in: &data) ? true : nil
        case .reorderList(let id, let target, let after):
            return ListOrganization.reorderList(id, relativeTo: target, after: after, in: &data) ? true : nil
        case .reorderFolder(let id, let target, let after):
            return ListOrganization.reorderFolder(id, relativeTo: target, after: after, in: &data) ? true : nil
        }
    }
}

public enum ListOrganization {
    public static func deleteList(_ id: UUID, in data: inout WorkspaceData, now: Date) {
        data.lists.removeAll { $0.id == id }
        for index in data.tasks.indices where data.tasks[index].listID == id {
            data.tasks[index].listID = nil
            data.tasks[index].updatedAt = now
        }
        // Keep unavailable filter IDs so deleting a list cannot broaden a saved filter.
    }

    public static func duplicateList(_ id: UUID, copyID: UUID, in data: inout WorkspaceData, now: Date) -> Bool {
        guard var copy = data.lists.first(where: { $0.id == id }),
              !data.lists.contains(where: { $0.id == copyID }) else { return false }
        let members = data.tasks.filter { $0.listID == id && $0.deletedAt == nil }
        guard Set(members.map(\.id)).count == members.count else { return false }
        guard Set(copy.sections.map(\.id)).count == copy.sections.count else { return false }
        let idMap = Dictionary(uniqueKeysWithValues: members.map { ($0.id, UUID()) })
        let sectionMap = Dictionary(uniqueKeysWithValues: copy.sections.map { ($0.id, UUID()) })
        copy.sections = copy.sections.map { TaskSection(id: sectionMap[$0.id]!, name: $0.name) }
        copy.id = copyID
        copy.name += " copy"
        copy.isArchived = false
        copy.isPinned = false
        data.lists.append(copy)
        for task in members {
            var duplicate = task
            duplicate.discardOccurrenceBaselineForCopy()
            duplicate.id = idMap[task.id]!
            duplicate.listID = copyID
            duplicate.parentID = task.parentID.flatMap { idMap[$0] }
            duplicate.sectionID = duplicate.parentID == nil ? task.sectionID.flatMap { sectionMap[$0] } : nil
            duplicate.checklist = task.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }
            duplicate.recurrenceSourceID = nil
            duplicate.createdAt = now
            duplicate.updatedAt = now
            data.tasks.append(duplicate)
        }
        return true
    }

    public static func ungroupFolder(_ id: UUID, in data: inout WorkspaceData) -> Bool {
        guard data.folders.contains(where: { $0.id == id }) else { return false }
        data.folders.removeAll { $0.id == id }
        for index in data.lists.indices where data.lists[index].folderID == id {
            ListPlacement.aboveFolders.apply(to: &data.lists[index])
        }
        return true
    }

    public static func reorderList(_ id: UUID, relativeTo target: UUID, after: Bool, in data: inout WorkspaceData) -> Bool {
        guard id != target, var mover = data.lists.first(where: { $0.id == id }),
              let targetList = data.lists.first(where: { $0.id == target }) else { return false }
        ListPlacement(targetList).apply(to: &mover)
        data.lists.removeAll { $0.id == id }
        if let targetIndex = data.lists.firstIndex(where: { $0.id == target }) {
            data.lists.insert(mover, at: after ? targetIndex + 1 : targetIndex)
        }
        return true
    }

    public static func reorderFolder(_ id: UUID, relativeTo target: UUID, after: Bool, in data: inout WorkspaceData) -> Bool {
        guard id != target, let mover = data.folders.first(where: { $0.id == id }),
              data.folders.contains(where: { $0.id == target }) else { return false }
        data.folders.removeAll { $0.id == id }
        if let targetIndex = data.folders.firstIndex(where: { $0.id == target }) {
            data.folders.insert(mover, at: after ? targetIndex + 1 : targetIndex)
        }
        return true
    }
}
