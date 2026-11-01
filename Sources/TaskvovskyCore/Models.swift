import Foundation

public enum TaskPriority: String, Codable, CaseIterable, Sendable { case none, low, medium, high }
public enum RepeatRule: String, Codable, CaseIterable, Sendable { case none, daily, weekdays, weekly, monthly, yearly }
public enum TaskKind: String, Codable, CaseIterable, Sendable { case task, note }

public struct ChecklistItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id; self.title = title; self.isCompleted = isCompleted
    }
}

public struct TaskItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var listID: UUID?
    public var tagIDs: [UUID]
    public var kind: TaskKind
    public var dueDate: Date?
    public var hasDueTime: Bool
    public var reminderDate: Date?
    public var priority: TaskPriority
    public var recurrence: RepeatRule
    public var checklist: [ChecklistItem]
    public var completedAt: Date?
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    /// The original day of month for a repeating schedule, retained across short months.
    public var recurrenceAnchorDay: Int?
    /// The original month for a yearly schedule, retained across leap years.
    public var recurrenceAnchorMonth: Int?
    public var recurrenceSourceID: UUID?

    public init(id: UUID = UUID(), title: String, body: String = "", listID: UUID? = nil,
                tagIDs: [UUID] = [], kind: TaskKind = .task, dueDate: Date? = nil,
                hasDueTime: Bool = false, reminderDate: Date? = nil, priority: TaskPriority = .none,
                recurrence: RepeatRule = .none, checklist: [ChecklistItem] = [],
                completedAt: Date? = nil, deletedAt: Date? = nil, createdAt: Date = Date(),
                updatedAt: Date = Date(), recurrenceAnchorDay: Int? = nil, recurrenceAnchorMonth: Int? = nil,
                recurrenceSourceID: UUID? = nil) {
        self.id = id; self.title = title; self.body = body; self.listID = listID; self.tagIDs = tagIDs
        self.kind = kind; self.dueDate = dueDate; self.hasDueTime = hasDueTime; self.reminderDate = reminderDate
        self.priority = priority; self.recurrence = recurrence; self.checklist = checklist
        self.completedAt = completedAt; self.deletedAt = deletedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.recurrenceAnchorDay = recurrenceAnchorDay; self.recurrenceAnchorMonth = recurrenceAnchorMonth
        self.recurrenceSourceID = recurrenceSourceID
    }
}

public struct TaskList: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: String
    public var kind: TaskKind
    public init(id: UUID = UUID(), name: String, color: String, kind: TaskKind = .task) {
        self.id = id; self.name = name; self.color = color; self.kind = kind
    }
}

public struct TaskTag: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: String
    public init(id: UUID = UUID(), name: String, color: String) {
        self.id = id; self.name = name; self.color = color
    }
}

public struct WorkspaceData: Codable, Equatable, Sendable {
    public var tasks: [TaskItem]
    public var lists: [TaskList]
    public var tags: [TaskTag]
    public init(tasks: [TaskItem] = [], lists: [TaskList] = [], tags: [TaskTag] = []) {
        self.tasks = tasks; self.lists = lists; self.tags = tags
    }
}
