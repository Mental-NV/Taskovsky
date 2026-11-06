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

public struct ListFolder: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public init(id: UUID = UUID(), name: String) {
        self.id = id; self.name = name
    }
    // No custom decoder: id and name are required. A folder record missing
    // either is malformed and fails the whole workspace decode, which the
    // existing unreadable-file protection preserves — never silently minted
    // with a random UUID or placeholder name that would drop memberships.
}

public struct TaskList: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var color: String
    public var kind: TaskKind
    public var symbol: String?
    public var folderID: UUID?
    /// Trailing root placement: ungrouped lists with `true` render below all
    /// folders instead of above them. Defaults to false so legacy files keep
    /// their prior top root order; unknown folders still clear to top root.
    public var belowFolders: Bool
    public init(id: UUID = UUID(), name: String, color: String, kind: TaskKind = .task, symbol: String? = nil, folderID: UUID? = nil, belowFolders: Bool = false) {
        self.id = id; self.name = name; self.color = color; self.kind = kind; self.symbol = symbol; self.folderID = folderID; self.belowFolders = belowFolders
    }
    private enum CodingKeys: String, CodingKey { case id, name, color, kind, symbol, folderID, belowFolders }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decode(String.self, forKey: .color)
        kind = try c.decodeIfPresent(TaskKind.self, forKey: .kind) ?? .task
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        belowFolders = try c.decodeIfPresent(Bool.self, forKey: .belowFolders) ?? false
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
    public var folders: [ListFolder]
    public init(tasks: [TaskItem] = [], lists: [TaskList] = [], tags: [TaskTag] = [], filters: [TaskFilter] = [], templates: [TaskTemplate] = [], folders: [ListFolder] = []) {
        self.tasks = tasks; self.lists = lists; self.tags = tags; self.filters = filters; self.templates = templates; self.folders = folders
    }
    private enum CodingKeys: String, CodingKey { case tasks, lists, tags, filters, templates, folders }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try c.decode([TaskItem].self, forKey: .tasks); lists = try c.decode([TaskList].self, forKey: .lists); tags = try c.decode([TaskTag].self, forKey: .tags)
        filters = try c.decodeIfPresent([TaskFilter].self, forKey: .filters) ?? []; templates = try c.decodeIfPresent([TaskTemplate].self, forKey: .templates) ?? TaskTemplate.builtIns
        // Only these two keys tolerate absence: a missing `folders` array means
        // a pre-folders file (defaults to empty), and a missing `folderID`
        // means an ungrouped list (defaults to nil, handled in TaskList).
        folders = try c.decodeIfPresent([ListFolder].self, forKey: .folders) ?? []
        // Drop folder memberships that reference unknown folders (legacy or
        // hand-edited files): lists stay, tasks stay, membership clears.
        let known = Set(folders.map(\.id))
        if lists.contains(where: { $0.folderID != nil }) {
            lists = lists.map { var l = $0; if let f = l.folderID, !known.contains(f) { l.folderID = nil }; return l }
        }
    }
}
