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
    public var additionalReminderDates: [Date]?
    public var reminderDates: [Date] {
        get { Array(Set(([reminderDate].compactMap { $0 }) + (additionalReminderDates ?? []))).sorted() }
        set {
            let dates = Array(Set(newValue)).sorted()
            reminderDate = dates.first
            additionalReminderDates = dates.count > 1 ? Array(dates.dropFirst()) : nil
        }
    }
    /// Whether the reminder follows the configured schedule default; nil denotes legacy data.
    public var reminderFollowsSchedule: Bool?
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
    /// Inclusive final calendar day for this repeating schedule; nil means no end.
    public var recurrenceEndDate: Date?
    public var recurrenceSourceID: UUID?
    public var wontDoAt: Date?
    public var timeZoneID: String?

    public init(id: UUID = UUID(), title: String, body: String = "", listID: UUID? = nil,
                tagIDs: [UUID] = [], kind: TaskKind = .task, dueDate: Date? = nil,
                hasDueTime: Bool = false, reminderDate: Date? = nil, priority: TaskPriority = .none,
                recurrence: RepeatRule = .none, checklist: [ChecklistItem] = [],
                completedAt: Date? = nil, deletedAt: Date? = nil, createdAt: Date = Date(),
                updatedAt: Date = Date(), recurrenceAnchorDay: Int? = nil, recurrenceAnchorMonth: Int? = nil,
                recurrenceSourceID: UUID? = nil, recurrenceEndDate: Date? = nil, additionalReminderDates: [Date]? = nil, reminderFollowsSchedule: Bool? = nil, wontDoAt: Date? = nil, timeZoneID: String? = nil) {
        self.id = id; self.title = title; self.body = body; self.listID = listID; self.tagIDs = tagIDs
        self.kind = kind; self.dueDate = dueDate; self.hasDueTime = hasDueTime; self.reminderDate = reminderDate
        self.priority = priority; self.recurrence = recurrence; self.checklist = checklist
        self.completedAt = completedAt; self.deletedAt = deletedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.recurrenceAnchorDay = recurrenceAnchorDay; self.recurrenceAnchorMonth = recurrenceAnchorMonth
        self.recurrenceSourceID = recurrenceSourceID; self.recurrenceEndDate = recurrenceEndDate; self.additionalReminderDates = additionalReminderDates; self.reminderFollowsSchedule = reminderFollowsSchedule; self.wontDoAt = wontDoAt; self.timeZoneID = timeZoneID
    }
}

public struct TaskList: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: String
    public var kind: TaskKind
    public var symbol: String?
    public init(id: UUID = UUID(), name: String, color: String, kind: TaskKind = .task, symbol: String? = nil) {
        self.id = id; self.name = name; self.color = color; self.kind = kind; self.symbol = symbol
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
    public var filters: [TaskFilter]
    public var templates: [TaskTemplate]
    public init(tasks: [TaskItem] = [], lists: [TaskList] = [], tags: [TaskTag] = [], filters: [TaskFilter] = [], templates: [TaskTemplate] = []) {
        self.tasks = tasks; self.lists = lists; self.tags = tags; self.filters = filters; self.templates = templates
    }
    private enum CodingKeys: String, CodingKey { case tasks, lists, tags, filters, templates }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try c.decode([TaskItem].self, forKey: .tasks); lists = try c.decode([TaskList].self, forKey: .lists); tags = try c.decode([TaskTag].self, forKey: .tags)
        filters = try c.decodeIfPresent([TaskFilter].self, forKey: .filters) ?? []; templates = try c.decodeIfPresent([TaskTemplate].self, forKey: .templates) ?? TaskTemplate.builtIns
    }
}
