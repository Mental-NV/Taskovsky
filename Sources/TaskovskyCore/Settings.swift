import Foundation

public enum SmartListKey: String, Codable, CaseIterable, Sendable { case all, today, tomorrow, week, inbox, summary, tags, filters, completed, wontDo, trash }
public enum SmartListVisibility: String, Codable, CaseIterable, Sendable { case show, hidden, showIfNotEmpty }
public enum DefaultDate: String, Codable, CaseIterable, Sendable { case none, today, tomorrow, dayAfterTomorrow, nextWeek }
public enum DueReminder: String, Codable, CaseIterable, Sendable { case none, onTime, fiveMinutesBefore, fifteenMinutesBefore, thirtyMinutesBefore, oneHourBefore, oneDayBefore
    public var offset: TimeInterval? { switch self { case .none: nil; case .onTime: 0; case .fiveMinutesBefore: -300; case .fifteenMinutesBefore: -900; case .thirtyMinutesBefore: -1800; case .oneHourBefore: -3600; case .oneDayBefore: -86400 } }
}
public enum AllDayReminder: String, Codable, CaseIterable, Sendable { case none, onDay9, dayBefore9, twoDaysBefore9, threeDaysBefore9, weekBefore9 }
public enum TaskPosition: String, Codable, CaseIterable, Sendable { case top, bottom }

public struct AppSettings: Codable, Equatable, Sendable {
    public var smartListVisibility: [SmartListKey: SmartListVisibility] = [.all: .hidden, .today: .show, .tomorrow: .hidden, .week: .show, .inbox: .show, .summary: .hidden, .tags: .show, .filters: .show, .completed: .show, .wontDo: .showIfNotEmpty, .trash: .show]
    /// Persisted deterministic smart-list order. Nil denotes legacy files and
    /// decodes to the default order; normalization appends missing keys in
    /// default order and drops duplicates/unknown values. Hidden keys keep
    /// their slots so showing them later restores their position; only the
    /// filtered visible order is shown, never a resaved scramble of hidden keys.
    public var smartListOrder: [SmartListKey]? = nil
    public var startWeekOn = 2
    public var showWeekNumbers = false
    public var enableTimeZone = false
    public var dateRecognition = true
    public var removeDateText = false
    public var removeTagText = true
    public var urlParsing = true
    public var defaultDate: DefaultDate = .none
    public var defaultReminder: DueReminder = .onTime
    public var allDayReminder: AllDayReminder = .none
    public var timedReminderDefaults: [DueReminder]? = nil
    public var allDayReminderDefaults: [AllDayReminder]? = nil
    public var effectiveTimedReminderDefaults: [DueReminder] { (timedReminderDefaults ?? [defaultReminder]).filter { $0 != .none } }
    public var effectiveAllDayReminderDefaults: [AllDayReminder] { (allDayReminderDefaults ?? [allDayReminder]).filter { $0 != .none } }
    public var defaultPriority: TaskPriority = .none
    public var defaultTagID: UUID? = nil
    public var defaultListID: UUID? = nil
    public var defaultAddTo: TaskPosition = .top
    public var overduePosition: TaskPosition = .top
    public var completionSound = true
    public var hasInstalledBuiltInTemplates = false
    public init() {}
    private enum CodingKeys: String, CodingKey { case smartListVisibility, smartListOrder, startWeekOn, showWeekNumbers, enableTimeZone, dateRecognition, removeDateText, removeTagText, urlParsing, defaultDate, defaultReminder, allDayReminder, timedReminderDefaults, allDayReminderDefaults, defaultPriority, defaultTagID, defaultListID, defaultAddTo, overduePosition, completionSound, hasInstalledBuiltInTemplates }
    public init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy: CodingKeys.self)
        if let values = try c.decodeIfPresent([SmartListKey: SmartListVisibility].self, forKey: .smartListVisibility) { smartListVisibility.merge(values) { _, new in new } }
        smartListOrder = try c.decodeIfPresent([SmartListKey].self, forKey: .smartListOrder)
        startWeekOn = try c.decodeIfPresent(Int.self, forKey: .startWeekOn) ?? startWeekOn
        showWeekNumbers = try c.decodeIfPresent(Bool.self, forKey: .showWeekNumbers) ?? showWeekNumbers
        enableTimeZone = try c.decodeIfPresent(Bool.self, forKey: .enableTimeZone) ?? enableTimeZone
        dateRecognition = try c.decodeIfPresent(Bool.self, forKey: .dateRecognition) ?? dateRecognition
        removeDateText = try c.decodeIfPresent(Bool.self, forKey: .removeDateText) ?? removeDateText
        removeTagText = try c.decodeIfPresent(Bool.self, forKey: .removeTagText) ?? removeTagText
        urlParsing = try c.decodeIfPresent(Bool.self, forKey: .urlParsing) ?? urlParsing
        defaultDate = try c.decodeIfPresent(DefaultDate.self, forKey: .defaultDate) ?? defaultDate
        defaultReminder = try c.decodeIfPresent(DueReminder.self, forKey: .defaultReminder) ?? defaultReminder
        allDayReminder = try c.decodeIfPresent(AllDayReminder.self, forKey: .allDayReminder) ?? allDayReminder
        timedReminderDefaults = try c.decodeIfPresent([DueReminder].self, forKey: .timedReminderDefaults)
        allDayReminderDefaults = try c.decodeIfPresent([AllDayReminder].self, forKey: .allDayReminderDefaults)
        defaultPriority = try c.decodeIfPresent(TaskPriority.self, forKey: .defaultPriority) ?? defaultPriority
        defaultTagID = try c.decodeIfPresent(UUID.self, forKey: .defaultTagID)
        defaultListID = try c.decodeIfPresent(UUID.self, forKey: .defaultListID)
        defaultAddTo = try c.decodeIfPresent(TaskPosition.self, forKey: .defaultAddTo) ?? defaultAddTo
        overduePosition = try c.decodeIfPresent(TaskPosition.self, forKey: .overduePosition) ?? overduePosition
        completionSound = try c.decodeIfPresent(Bool.self, forKey: .completionSound) ?? completionSound
        hasInstalledBuiltInTemplates = try c.decodeIfPresent(Bool.self, forKey: .hasInstalledBuiltInTemplates) ?? false
    }
    public var calendar: Calendar { var calendar = Calendar.current; calendar.firstWeekday = min(7, max(1, startWeekOn)); return calendar }
}

extension AppSettings {
    /// Canonical sidebar order. Sidebar group structure (documented boundary):
    /// top destinations `[all, today, tomorrow, week, inbox, summary]` render
    /// above the Lists/Filters/Tags sections; bottom system destinations
    /// `[completed, wontDo, trash]` render below them. `tags`/`filters` keys
    /// control section visibility and are never draggable rows. Reordering is
    /// constrained within each group and can never cross the boundary.
    public static let defaultSmartListOrder: [SmartListKey] = [.all, .today, .tomorrow, .week, .inbox, .summary, .tags, .filters, .completed, .wontDo, .trash]
    public static let topSmartGroup: [SmartListKey] = [.all, .today, .tomorrow, .week, .inbox, .summary]
    public static let bottomSmartGroup: [SmartListKey] = [.completed, .wontDo, .trash]
    /// Normalized full order: stored order first (deduped), then any missing
    /// default keys appended in default order. Legacy nil decodes to default.
    public var effectiveSmartListOrder: [SmartListKey] {
        var seen = Set<SmartListKey>()
        var result: [SmartListKey] = []
        for key in smartListOrder ?? [] where seen.insert(key).inserted { result.append(key) }
        for key in Self.defaultSmartListOrder where seen.insert(key).inserted { result.append(key) }
        return result
    }
    /// Atomically reorders one smart key within its group. Cross-group moves,
    /// unknown groups (tags/filters sections), self-drops, and unknown keys
    /// abort with no mutation.
    @discardableResult public mutating func reorderSmartList(moving: SmartListKey, before target: SmartListKey, afterTarget: Bool = false) -> Bool {
        guard moving != target else { return false }
        func group(of key: SmartListKey) -> [SmartListKey]? {
            if Self.topSmartGroup.contains(key) { return Self.topSmartGroup }
            if Self.bottomSmartGroup.contains(key) { return Self.bottomSmartGroup }
            return nil
        }
        guard let movingGroup = group(of: moving), let targetGroup = group(of: target), movingGroup == targetGroup else { return false }
        var order = effectiveSmartListOrder
        guard let from = order.firstIndex(of: moving) else { return false }
        order.remove(at: from)
        // The target survives the removal (moving != target is checked above).
        guard let targetIndex = order.firstIndex(of: target) else { return false }
        order.insert(moving, at: afterTarget ? targetIndex + 1 : targetIndex)
        smartListOrder = order
        return true
    }
}

/// Manual-sort (None, including legacy "Manual") grouping: every active
/// task/note shares one group regardless of due date or priority, so items
/// with different dates reorder freely without rewriting those fields.
/// Completed/Won't-Do history and Trash stay separate. The Reminders
/// destination keeps its semantic Due/Upcoming split (documented scope).
public enum ManualGroupPolicy {
    public enum Bucket: Equatable { case deleted, history, active }
    public static func bucket(completedAt: Date?, wontDoAt: Date?, deletedAt: Date?) -> Bucket {
        if deletedAt != nil { return .deleted }
        if completedAt != nil || wontDoAt != nil { return .history }
        return .active
    }
    public static let activeGroupTitle = "Tasks"
}

/// Persisted task-sort values. Legacy installs stored `"Manual"`; the picker
/// now shows `"None"` (manual order) for both. `"Date"` and every other stored
/// value is preserved untouched.
public enum TaskSortPolicy {
    public static let manualLegacyRaw = "Manual"
    public static let manualRaw = "None"
    public static let reorderDisabledMessage = "Manual drag and drop is not supported while sorting is enabled. Choose None in Sort to reorder tasks."
    public static func normalized(_ raw: String) -> String { raw == manualLegacyRaw ? manualRaw : raw }
    public static func isManual(_ raw: String) -> Bool { normalized(raw) == manualRaw }
    public static func canReorder(_ raw: String) -> Bool { isManual(raw) }
}

public enum FilterDateRule: String, Codable, CaseIterable, Sendable { case all, today, tomorrow, next7, overdue, noDate }
public enum FilterStatus: String, Codable, CaseIterable, Sendable { case active, completed, wontDo, all }
public struct TaskFilter: Codable, Identifiable, Equatable, Sendable {
    /// Reserved selection identifier for tasks whose listID is nil (Inbox).
    public static let inboxListID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    public var id: UUID; public var name: String; public var listIDs: [UUID]; public var tagIDs: [UUID]; public var priority: TaskPriority?; public var dateRule: FilterDateRule; public var status: FilterStatus; public var keyword: String
    public init(id: UUID = UUID(), name: String, listIDs: [UUID] = [], tagIDs: [UUID] = [], priority: TaskPriority? = nil, dateRule: FilterDateRule = .all, status: FilterStatus = .active, keyword: String = "") { self.id = id; self.name = name; self.listIDs = listIDs; self.tagIDs = tagIDs; self.priority = priority; self.dateRule = dateRule; self.status = status; self.keyword = keyword }
    private enum CodingKeys: String, CodingKey { case id, name, listIDs, tagIDs, priority, dateRule, status, keyword }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        listIDs = try c.decodeIfPresent([UUID].self, forKey: .listIDs) ?? []; tagIDs = try c.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        priority = try c.decodeIfPresent(TaskPriority.self, forKey: .priority); dateRule = try c.decodeIfPresent(FilterDateRule.self, forKey: .dateRule) ?? .all; status = try c.decodeIfPresent(FilterStatus.self, forKey: .status) ?? .active
        keyword = try c.decodeIfPresent(String.self, forKey: .keyword) ?? ""
    }
    public func matches(_ task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard TaskSearch.matches(task, query: keyword), task.deletedAt == nil, (listIDs.isEmpty || listIDs.contains(task.listID ?? Self.inboxListID)), (tagIDs.isEmpty || !Set(tagIDs).isDisjoint(with: task.tagIDs)), priority == nil || task.priority == priority else { return false }
        switch status { case .active: if task.completedAt != nil || task.wontDoAt != nil { return false }; case .completed: if task.completedAt == nil { return false }; case .wontDo: if task.wontDoAt == nil { return false }; case .all: break }
        let start = calendar.startOfDay(for: now)
        switch dateRule { case .all: return true; case .noDate: return task.dueDate == nil; case .today: return task.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false; case .tomorrow: return task.dueDate.map { due in calendar.date(byAdding: .day, value: 1, to: now).map { calendar.isDate(due, inSameDayAs: $0) } ?? false } ?? false; case .next7: guard let due = task.dueDate, let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }; return due >= start && due < end; case .overdue: guard let due = task.dueDate else { return false }; return task.hasDueTime ? due < now : due < start }
    }
}
public struct TaskTemplate: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID; public var name: String; public var title: String; public var body: String; public var checklist: [ChecklistItem]; public var priority: TaskPriority; public var tagIDs: [UUID]; public var kind: TaskKind
    public init(id: UUID = UUID(), name: String, title: String, body: String = "", checklist: [ChecklistItem] = [], priority: TaskPriority = .none, tagIDs: [UUID] = [], kind: TaskKind = .task) { self.id = id; self.name = name; self.title = title; self.body = body; self.checklist = checklist; self.priority = priority; self.tagIDs = tagIDs; self.kind = kind }
}
extension TaskTemplate {
    public static var builtIns: [TaskTemplate] {
        [
            TaskTemplate(name: "To-dos before work", title: "To-dos before work", checklist: ["Reflection on yesterday", "Check emails", "Check tasks in Inbox", "Find the 3 most important tasks"].map { ChecklistItem(title: $0) }),
            TaskTemplate(name: "Daily record", title: "Daily record", body: "What have I accomplished today?\n\nWhat's the highlight of the day?"),
            TaskTemplate(name: "Things to pack for travelling", title: "Things to pack for travelling", checklist: ["Passport", "Charger", "Umbrella", "Tote bag", "Clothes"].map { ChecklistItem(title: $0) })
        ]
    }
}
public enum TaskSearch {
    public static func matches(_ task: TaskItem, query: String) -> Bool { let q = query.trimmingCharacters(in: .whitespacesAndNewlines); return q.isEmpty || ([task.title, task.body] + task.checklist.map(\.title)).contains { $0.localizedCaseInsensitiveContains(q) } }
}
