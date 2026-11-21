import Foundation

public enum TaskTextBatchValidation: Error, Equatable, Sendable {
    case empty, unavailableDestination, invalidLine(Int, TaskCaptureValidation)
}

public struct TaskTextBatch: Sendable {
    public let tasks: [TaskItem]
    public let listName: String

    public init(text: String, destination: TaskDestination, workspace: WorkspaceData, settings: AppSettings,
                now: Date, calendar: Calendar, recognizesDetails: Bool) throws {
        guard Self.isAvailable(in: destination, workspace: workspace) else { throw TaskTextBatchValidation.unavailableDestination }
        let lines = Self.titles(in: text)
        guard !lines.isEmpty else { throw TaskTextBatchValidation.empty }
        var input = TaskCaptureInput.start(destination: destination, workspace: workspace, settings: settings, now: now, calendar: calendar)
        if let listID = input.listID, !Self.isAvailable(in: .list(listID), workspace: workspace) { input.listID = nil }
        input.recognizeDates = recognizesDetails
        input.recognizeTags = recognizesDetails
        listName = workspace.lists.first { $0.id == input.listID }?.name ?? "Inbox"
        tasks = try lines.enumerated().map { index, title in
            input.title = title
            do {
                return try input.task(id: UUID(), now: now, workspace: workspace, settings: settings, calendar: calendar)
            } catch let error as TaskCaptureValidation {
                throw TaskTextBatchValidation.invalidLine(index + 1, error)
            }
        }
    }

    public static func titles(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap {
            let title = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        }
    }

    public static func isAvailable(in destination: TaskDestination, workspace: WorkspaceData) -> Bool {
        switch destination {
        case .all, .today, .tomorrow, .week, .inbox: return true
        case .list(let id): return workspace.lists.contains { $0.id == id && $0.kind == .task && !$0.isArchived }
        case .folder(let id): return workspace.folders.contains { $0.id == id }
        case .tag(let id): return workspace.tags.contains { $0.id == id }
        case .filter(let id): return workspace.filters.contains { $0.id == id }
        case .notes, .reminders, .completed, .wontDo, .summary, .search, .trash: return false
        }
    }
}

extension TaskCreation {
    package enum CapturePresence { case absent, matching, conflicting }

    package static func presence(of tasks: [TaskItem], in workspace: WorkspaceData) -> CapturePresence {
        let ids = Set(tasks.map(\.id))
        guard ids.count == tasks.count else { return .conflicting }
        let existing = workspace.tasks.filter { ids.contains($0.id) }
        guard !existing.isEmpty else { return .absent }
        guard existing.count == tasks.count, Set(existing.map(\.id)) == ids else { return .conflicting }
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            for task in tasks {
                guard let match = byID[task.id], try encoder.encode(task) == encoder.encode(match) else { return .conflicting }
            }
            return .matching
        } catch { return .conflicting }
    }

    package static func insert(_ tasks: [TaskItem], into workspace: inout WorkspaceData, position: TaskPosition) {
        if position == .top { workspace.tasks.insert(contentsOf: tasks, at: 0) }
        else { workspace.tasks.append(contentsOf: tasks) }
    }
}
